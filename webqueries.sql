-- ============================================================================
-- THE WEB MACHINE X :: v0.3
-- Deterministic schema, fixed-point ledgers, WMX0 binary frame audit log,
-- views, triggers, indexes, and CLI verification queries.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- SECTION 1: CORE SYSTEM & LANGUAGE REGISTRY TABLES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS wmx_meta (
  meta_key        VARCHAR(64) PRIMARY KEY,
  meta_val        VARCHAR(255) NOT NULL,
  updated_seq     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS wmx_languages (
  lang_id         INTEGER PRIMARY KEY,
  lang_code       VARCHAR(16) NOT NULL UNIQUE,
  lang_name       VARCHAR(64) NOT NULL,
  lang_tag_hex    VARCHAR(8) NOT NULL,
  runtime_mode    VARCHAR(32) NOT NULL DEFAULT 'BARE_METAL',
  active_flag     INTEGER NOT NULL DEFAULT 1 CHECK (active_flag IN (0, 1))
);

CREATE TABLE IF NOT EXISTS wmx_modules (
  module_id       INTEGER PRIMARY KEY,
  lang_id         INTEGER NOT NULL REFERENCES wmx_languages(lang_id),
  file_name       VARCHAR(128) NOT NULL UNIQUE,
  role_name       VARCHAR(64) NOT NULL,
  line_count      INTEGER NOT NULL DEFAULT 0 CHECK (line_count >= 0),
  status_code     INTEGER NOT NULL DEFAULT 0,
  checksum_fnv1a  VARCHAR(16) NOT NULL DEFAULT '811C9DC5'
);

CREATE TABLE IF NOT EXISTS wmx_milestones (
  milestone_id    INTEGER PRIMARY KEY,
  milestone_num   INTEGER NOT NULL UNIQUE,
  total_lines     INTEGER NOT NULL CHECK (total_lines >= 0),
  frame_magic     INTEGER NOT NULL DEFAULT 1464686640, -- 0x574D5830 ('WMX0')
  notes           VARCHAR(255) NOT NULL DEFAULT ''
);

-- ----------------------------------------------------------------------------
-- SECTION 2: MANIFEST & FIXED-POINT (4-DECIMAL) LEDGER TABLES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS wmx_manifest (
  entry_id        INTEGER PRIMARY KEY,
  section_name    VARCHAR(64) NOT NULL DEFAULT '',
  key_name        VARCHAR(64) NOT NULL,
  val_kind        VARCHAR(24) NOT NULL DEFAULT 'string',
  val_text        VARCHAR(512) NOT NULL DEFAULT '',
  fixed4_scaled   INTEGER NOT NULL DEFAULT 0,
  UNIQUE (section_name, key_name)
);

CREATE TABLE IF NOT EXISTS wmx_ledger_accounts (
  account_id      INTEGER PRIMARY KEY,
  account_code    VARCHAR(32) NOT NULL UNIQUE,
  account_title   VARCHAR(128) NOT NULL,
  currency_code   VARCHAR(8) NOT NULL DEFAULT 'WMX',
  balance_scaled  INTEGER NOT NULL DEFAULT 0, -- * 10000 precision
  locked_flag     INTEGER NOT NULL DEFAULT 0 CHECK (locked_flag IN (0, 1))
);

CREATE TABLE IF NOT EXISTS wmx_ledger_entries (
  entry_seq       INTEGER PRIMARY KEY,
  account_id      INTEGER NOT NULL REFERENCES wmx_ledger_accounts(account_id),
  source_lang_id  INTEGER NOT NULL REFERENCES wmx_languages(lang_id),
  op_type         VARCHAR(16) NOT NULL CHECK (op_type IN ('DEBIT', 'CREDIT', 'ADJUST')),
  amount_scaled   INTEGER NOT NULL, -- * 10000 precision
  cobol_pic       VARCHAR(20) NOT NULL DEFAULT '+000000000000000000',
  ref_token       VARCHAR(64) NOT NULL DEFAULT ''
);

-- ----------------------------------------------------------------------------
-- SECTION 3: WMX0 BINARY FRAME & STREAM AUDIT LOG
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS wmx_frames (
  frame_seq       INTEGER PRIMARY KEY,
  magic_u32       INTEGER NOT NULL DEFAULT 1464686640, -- 0x574D5830
  lang_id         INTEGER NOT NULL REFERENCES wmx_languages(lang_id),
  flags_u16       INTEGER NOT NULL DEFAULT 0,
  payload_len     INTEGER NOT NULL DEFAULT 0 CHECK (payload_len >= 0),
  checksum_fnv1a  VARCHAR(16) NOT NULL,
  status_code     INTEGER NOT NULL DEFAULT 0,
  payload_preview VARCHAR(255) NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS wmx_ring_events (
  event_seq       INTEGER PRIMARY KEY,
  ring_name       VARCHAR(32) NOT NULL DEFAULT 'MAIN_RING',
  action_name     VARCHAR(16) NOT NULL CHECK (action_name IN ('PUSH', 'POP', 'PEEK', 'CLEAR')),
  item_label      VARCHAR(64) NOT NULL DEFAULT '',
  ring_size       INTEGER NOT NULL DEFAULT 0 CHECK (ring_size >= 0),
  ring_capacity   INTEGER NOT NULL DEFAULT 64 CHECK (ring_capacity > 0),
  status_code     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS wmx_diagnostics (
  diag_id         INTEGER PRIMARY KEY,
  component_name  VARCHAR(64) NOT NULL,
  severity_code   VARCHAR(16) NOT NULL DEFAULT 'INFO',
  exit_status     INTEGER NOT NULL DEFAULT 0,
  message_text    VARCHAR(255) NOT NULL
);

-- ----------------------------------------------------------------------------
-- SECTION 4: INDEXES FOR DETERMINISTIC LOOKUPS
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_modules_lang_id
  ON wmx_modules(lang_id);

CREATE INDEX IF NOT EXISTS idx_manifest_section_key
  ON wmx_manifest(section_name, key_name);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_account
  ON wmx_ledger_entries(account_id, entry_seq);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_lang
  ON wmx_ledger_entries(source_lang_id);

CREATE INDEX IF NOT EXISTS idx_frames_lang_status
  ON wmx_frames(lang_id, status_code);

CREATE INDEX IF NOT EXISTS idx_ring_events_name
  ON wmx_ring_events(ring_name, event_seq);

CREATE INDEX IF NOT EXISTS idx_diagnostics_status
  ON wmx_diagnostics(exit_status, component_name);

-- ----------------------------------------------------------------------------
-- SECTION 5: TRIGGERS FOR LEDGER & INTEGRITY ENFORCEMENT
-- ----------------------------------------------------------------------------

CREATE TRIGGER IF NOT EXISTS trg_ledger_insert_credit
AFTER INSERT ON wmx_ledger_entries
WHEN NEW.op_type = 'CREDIT'
BEGIN
  UPDATE wmx_ledger_accounts
     SET balance_scaled = balance_scaled + NEW.amount_scaled
   WHERE account_id = NEW.account_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_ledger_insert_debit
AFTER INSERT ON wmx_ledger_entries
WHEN NEW.op_type = 'DEBIT'
BEGIN
  UPDATE wmx_ledger_accounts
     SET balance_scaled = balance_scaled - NEW.amount_scaled
   WHERE account_id = NEW.account_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_ledger_insert_adjust
AFTER INSERT ON wmx_ledger_entries
WHEN NEW.op_type = 'ADJUST'
BEGIN
  UPDATE wmx_ledger_accounts
     SET balance_scaled = NEW.amount_scaled
   WHERE account_id = NEW.account_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_meta_bump_on_milestone
AFTER INSERT ON wmx_milestones
BEGIN
  UPDATE wmx_meta
     SET meta_val = CAST(NEW.milestone_num AS TEXT),
         updated_seq = updated_seq + 1
   WHERE meta_key = 'current_milestone';
END;
-- ----------------------------------------------------------------------------
-- SECTION 6: SEED METADATA & MULTI-LANGUAGE STACK
-- ----------------------------------------------------------------------------

REPLACE INTO wmx_meta (meta_key, meta_val, updated_seq) VALUES
  ('project_name',      'The Web Machine X v0.3', 1),
  ('frame_magic_hex',   '0x574D5830',        1),
  ('fixed_scale',       '10000',             1),
  ('current_milestone', '277',               1),
  ('platform_target',   'UNIX_BARE_METAL',   1);

REPLACE INTO wmx_languages (lang_id, lang_code, lang_name, lang_tag_hex, runtime_mode, active_flag) VALUES
  (1,  'PAS',  'Free Pascal',      '0x0001', 'BARE_METAL', 1),
  (2,  'F90',  'Fortran 90',       '0x0002', 'BARE_METAL', 1),
  (3,  'CBL',  'COBOL',            '0x0003', 'FIXED4',     1),
  (4,  'SQL',  'Structured Query', '0x0004', 'RELATIONAL', 1),
  (5,  'RB',   'Ruby Stdlib',      '0x0005', 'SCRIPT_CLI', 1),
  (6,  'RS',   'Rust Native',      '0x0006', 'BARE_METAL', 1),
  (7,  'CPP',  'C++ Native',       '0x0007', 'BARE_METAL', 1),
  (8,  'C',    'C Native',         '0x0008', 'BARE_METAL', 1),
  (9,  'PY',   'Python Native',    '0x0009', 'SCRIPT_CLI', 1),
  (10, 'JS',   'JavaScript',       '0x000A', 'CLIENT_DOM', 1),
  (11, 'TS',   'TypeScript',       '0x000B', 'TYPED_DOM',  1),
  (12, 'HTML', 'HTML5 Markup',     '0x000C', 'DOCUMENT',   1),
  (13, 'CSS',  'CSS3 Stylesheet',  '0x000D', 'STYLESHEET', 1),
  (14, 'SCSS', 'Sass Stylesheet',  '0x000E', 'STYLESHEET', 1),
  (15, 'JSON', 'JSON Data',        '0x000F', 'SERIALIZED', 1),
  (16, 'ASM',  'Assembly Native',  '0x0010', 'ISA_DIRECT', 1),
  (17, 'HS',   'Haskell Native',   '0x0011', 'PURE_FUNC',  1),
  (18, 'CS',   'C# Native',        '0x0012', 'MANAGED',    1);

-- ----------------------------------------------------------------------------
-- SECTION 7: SEED MODULES, MILESTONES & MANIFEST ENTRIES
-- ----------------------------------------------------------------------------

REPLACE INTO wmx_modules (module_id, lang_id, file_name, role_name, line_count, status_code, checksum_fnv1a) VALUES
  (1, 1,  'wmx_system.pas', 'arena_and_raw_io',   260, 0, '811C9DC5'),
  (2, 1,  'wmx_parser.pas', 'zero_copy_lexer',    340, 0, 'A3F9102B'),
  (3, 1,  'webcore.pas',    'core_pascal_engine', 410, 0, '4C8E7710'),
  (4, 2,  'numeric.f90',    'numeric_kernels',    520, 0, '9D1104C2'),
  (5, 3,  'coresys.cbl',    'fixed4_ledger',      390, 0, '7E2B619F'),
  (6, 4,  'webqueries.sql', 'schema_and_views',   400, 0, '3B509D8A'),
  (7, 5,  'corenum.rb',     'ruby_frame_engine',  385, 0, '5C53A1D1'),
  (8, 9,  'webnum.py',      'python_helpers',     240, 0, '1F6A8840');

REPLACE INTO wmx_milestones (milestone_id, milestone_num, total_lines, frame_magic, notes) VALUES
  (1, 270, 27100, 1464686640, 'Pre-refactor baseline'),
  (2, 275, 27520, 1464686640, 'Frame protocol stabilization'),
  (3, 277, 27750, 1464686640, 'Current verified milestone');

REPLACE INTO wmx_manifest (entry_id, section_name, key_name, val_kind, val_text, fixed4_scaled) VALUES
  (1,  'engine',       'magic',         'hex',    '$574D5830',    1464686640),
  (2,  'engine',       'languages',     'int',    '18',           180000),
  (3,  'engine',       'tick_rate',     'fixed4', '0.0166',       166),
  (4,  'engine',       'mode',          'string', 'bare-metal',   0),
  (5,  'cobol_ledger', 'reserve_floor', 'fixed4', '25000.5000',   250005000),
  (6,  'cobol_ledger', 'max_frame_kb',  'int',    '4096',         40960000),
  (7,  'ruby_engine',  'precision',     'int',    '4',            40000),
  (8,  'ruby_engine',  'sample_a',      'fixed4', '250.5000',     2505000),
  (9,  'ruby_engine',  'sample_b',      'fixed4', '4.0000',       40000),
  (10, 'pascal_sys',   'sector_bytes',  'int',    '4096',         40960000);

-- ----------------------------------------------------------------------------
-- SECTION 8: SEED LEDGER ACCOUNTS, ENTRIES, FRAMES & DIAGNOSTICS
-- ----------------------------------------------------------------------------

REPLACE INTO wmx_ledger_accounts (account_id, account_code, account_title, currency_code, balance_scaled, locked_flag) VALUES
  (1, 'WMX-SYS-001', 'Bare-Metal Core Reserve',  'WMX', 0, 0),
  (2, 'WMX-CBL-002', 'COBOL Fixed4 Settlement', 'WMX', 0, 0),
  (3, 'WMX-RB-003',  'Ruby Stream Buffer Pool', 'WMX', 0, 0);

REPLACE INTO wmx_ledger_entries (entry_seq, account_id, source_lang_id, op_type, amount_scaled, cobol_pic, ref_token) VALUES
  (1, 1, 1, 'CREDIT', 100000000, '+0000000000100000000', 'INIT-PAS-01'),
  (2, 2, 3, 'CREDIT', 250005000, '+000000000250005000', 'INIT-CBL-02'),
  (3, 3, 5, 'CREDIT', 2505000,   '+0000000000002505000', 'INIT-RB-03'),
  (4, 3, 5, 'DEBIT',  40000,     '+0000000000000040000', 'FEE-RB-04');

REPLACE INTO wmx_frames (frame_seq, magic_u32, lang_id, flags_u16, payload_len, checksum_fnv1a, status_code, payload_preview) VALUES
  (1, 1464686640, 5, 1, 22, '5C53A1D1', 0, 'NODE=WMX_X;PRECISION=4'),
  (2, 1464686640, 1, 0, 16, '811C9DC5', 0, 'ARENA_INIT_1024K'),
  (3, 1464686640, 3, 2, 20, '7E2B619F', 0, 'PIC_S9_14_V9_4_SYNC');

REPLACE INTO wmx_ring_events (event_seq, ring_name, action_name, item_label, ring_size, ring_capacity, status_code) VALUES
  (1, 'MAIN_RING', 'PUSH',  'M1',   1, 3, 0),
  (2, 'MAIN_RING', 'PUSH',  'M2',   2, 3, 0),
  (3, 'MAIN_RING', 'PUSH',  'M3',   3, 3, 0),
  (4, 'MAIN_RING', 'PUSH',  'M4',   3, 3, 3),
  (5, 'MAIN_RING', 'POP',   'M1',   2, 3, 0);

REPLACE INTO wmx_diagnostics (diag_id, component_name, severity_code, exit_status, message_text) VALUES
  (1, 'wmx_system.pas', 'INFO', 0, 'Arena allocator initialized cleanly'),
  (2, 'corenum.rb',     'INFO', 0, 'WMX0 frame roundtrip verified (0x5C53A1D1)'),
  (3, 'webqueries.sql', 'INFO', 0, 'Schema and fixed-point triggers loaded');

-- ----------------------------------------------------------------------------
-- SECTION 9: ANALYTICAL & AUDIT VIEWS
-- ----------------------------------------------------------------------------

CREATE VIEW v_wmx_module_summary AS
SELECT
  m.module_id,
  l.lang_code,
  l.lang_name,
  m.file_name,
  m.role_name,
  m.line_count,
  m.status_code,
  m.checksum_fnv1a
FROM wmx_modules m
JOIN wmx_languages l ON l.lang_id = m.lang_id;

CREATE VIEW v_wmx_ledger_formatted AS
SELECT
  a.account_id,
  a.account_code,
  a.account_title,
  a.balance_scaled,
  (a.balance_scaled / 10000) AS whole_part,
  ABS(a.balance_scaled % 10000) AS frac_part_4dp,
  a.locked_flag
FROM wmx_ledger_accounts a;

CREATE VIEW v_wmx_frame_audit AS
SELECT
  f.frame_seq,
  l.lang_code,
  f.flags_u16,
  f.payload_len,
  f.checksum_fnv1a,
  f.status_code,
  f.payload_preview
FROM wmx_frames f
JOIN wmx_languages l ON l.lang_id = f.lang_id;

-- ----------------------------------------------------------------------------
-- SECTION 10: VERIFICATION & DIAGNOSTIC QUERIES (400 LINES TOTAL)
-- ----------------------------------------------------------------------------

SELECT 'The Web Machine X v0.2' AS project_name;

SELECT '--- ACTIVE LANGUAGES (18-STACK) ---' AS section_header;
SELECT lang_id, lang_code, lang_name, lang_tag_hex, runtime_mode
  FROM wmx_languages
 WHERE active_flag = 1
 ORDER BY lang_id;

SELECT '--- REGISTERED MODULES & LINE COUNTS ---' AS section_header;
SELECT module_id, lang_code, file_name, role_name, line_count, status_code
  FROM v_wmx_module_summary
 ORDER BY module_id;

SELECT '--- FIXED-POINT ACCOUNT BALANCES ---' AS section_header;
SELECT account_code, account_title, balance_scaled, whole_part, frac_part_4dp
  FROM v_wmx_ledger_formatted
 ORDER BY account_id;

SELECT '--- WMX0 FRAME AUDIT LOG ---' AS section_header;
SELECT frame_seq, lang_code, payload_len, checksum_fnv1a, status_code, payload_preview
  FROM v_wmx_frame_audit
 ORDER BY frame_seq;

SELECT '--- MANIFEST FIXED4 & INT VALUES ---' AS section_header;
SELECT section_name, key_name, val_kind, val_text, fixed4_scaled
  FROM wmx_manifest
 ORDER BY entry_id;

SELECT '--- RING BUFFER EVENTS ---' AS section_header;
SELECT event_seq, ring_name, action_name, item_label, ring_size, ring_capacity, status_code
  FROM wmx_ring_events
 ORDER BY event_seq;

SELECT '--- TOTAL MODULE LINES & MILESTONE CHECK ---' AS section_header;
SELECT
  (SELECT COUNT(*) FROM wmx_languages) AS total_languages,
  (SELECT COUNT(*) FROM wmx_modules)   AS total_modules,
  (SELECT SUM(line_count) FROM wmx_modules) AS module_lines_sum,
  (SELECT milestone_num FROM wmx_milestones ORDER BY milestone_num DESC LIMIT 1) AS latest_milestone,
  (SELECT total_lines FROM wmx_milestones ORDER BY milestone_num DESC LIMIT 1) AS latest_total_lines;

SELECT '--- DIAGNOSTICS ---' AS section_header;
SELECT diag_id, component_name, severity_code, exit_status, message_text
  FROM wmx_diagnostics
 ORDER BY diag_id
