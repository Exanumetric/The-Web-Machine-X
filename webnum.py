#!/usr/bin/env python3
# ==============================================================================
# THE WEB MACHINE X :: PYTHON ORCHESTRATION & TELEMETRY CORE (webnum.py)
# Architecture: Zero-Dependency Polyglot Build Validator & Telemetry Engine
# Target Environment: Python 3.x on Fedora Linux (ThinkPad X13 Gen 1)
# ==============================================================================

import os
import sys
import time
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ------------------------------------------------------------------------------
# 1. Configuration & Global Constants
# ------------------------------------------------------------------------------

PROJECT_NAME = "The Web Machine X"
MILESTONE_VERSION = 261
TOTAL_BASELINE_LINES = 26148
SYSTEM_SEED = 0x55AA7733

# Master Polyglot Registry reflecting current milestone allocations
REGISTRY_DATA: List[Tuple[str, str, int, bool]] = [
    ("index.html",   "HTML",       12042, True),
    ("style.css",    "CSS",        12014, True),
    ("system.asm",   "Assembly",     486, True),
    ("numeric.f90",  "Fortran",      486, True),
    ("script.js",    "JavaScript",   272, True),
    ("syssharp.cs",  "C#",           180, True),
    ("syscode.hs",   "Haskell",      174, True),
    ("sysnum.c",     "C",            158, True),
    ("json_db.json", "JSON",         158, True),
    ("websys.cpp",   "C++",          156, True),
    ("mountnum.rs",  "Rust",         145, True), # Integrated Systems Core
    ("webnum.py",    "Python",       150, True), # Orchestration Core
    ("main.scss",    "SCSS",          14, True),
    ("types.ts",     "TypeScript",     8, True),
]

# ------------------------------------------------------------------------------
# 2. Subsystem Module Representation
# ------------------------------------------------------------------------------

class SubsystemModule:
    """Represents an individual language layer or asset in The Web Machine X."""
    def __init__(self, filename: str, language: str, line_count: int, active: bool):
        self.filename = filename
        self.language = language
        self.line_count = line_count
        self.active = active

    def __repr__(self) -> str:
        status = "READY" if self.active else "PENDING"
        return f"[{status}] {self.language:<12} :: {self.filename} ({self.line_count} lines)"


class PolyglotRegistry:
    """Manages the collection of polyglot subsystems and computes aggregates."""
    def __init__(self, raw_data: List[Tuple[str, str, int, bool]]):
        self.modules: List[SubsystemModule] = [
            SubsystemModule(fname, lang, lines, active) 
            for fname, lang, lines, active in raw_data
        ]

    def get_total_lines(self) -> int:
        """Sums the line counts of all active modules."""
        return sum(mod.line_count for mod in self.modules if mod.active)

    def sort_by_lines(self, descending: bool = True) -> List[SubsystemModule]:
        """Returns modules sorted by their line allocation."""
        return sorted(self.modules, key=lambda m: m.line_count, reverse=descending)

    def verify_baseline(self, expected_total: int) -> bool:
        """Verifies if the computed line sum matches the milestone baseline."""
        return self.get_total_lines() == expected_total


# ------------------------------------------------------------------------------
# 3. Deterministic Hashing & Telemetry Engine
# ------------------------------------------------------------------------------

class TelemetryEngine:
    """Computes cryptographic and mathematical check values for build verification."""
    def __init__(self, milestone: int, seed: int):
        self.milestone = milestone
        self.seed = seed
        self.timestamp = time.time()

    def compute_deterministic_checksum(self, registry: PolyglotRegistry) -> str:
        """Generates a stable hex checksum based on line distribution and seed."""
        hasher = hashlib.sha256()
        payload = f"{self.milestone}:{self.seed}:{registry.get_total_lines()}"
        hasher.update(payload.encode('utf-8'))
        
        for mod in sorted(registry.modules, key=lambda m: m.filename):
            mod_signature = f"{mod.filename}:{mod.language}:{mod.line_count}:{int(mod.active)}"
            hasher.update(mod_signature.encode('utf-8'))
            
        digest_int = int(hasher.hexdigest(), 16)
        masked = (digest_int + self.seed * 31337) % 0xFFFFFFFF
        return f"0x{masked:08X}"


# ------------------------------------------------------------------------------
# 4. Diagnostic & Reporting Interface
# ------------------------------------------------------------------------------

def print_banner() -> None:
    print("==========================================================")
    print(f"The Web Machine X v0.3")
    print("==========================================================")


def run_diagnostics(registry: PolyglotRegistry, engine: TelemetryEngine) -> None:
    print(f"[ACTIVE] Processing Milestone #{engine.milestone} in sovereign polyglot environment.")
    print(f"[TIME]   System Timestamp : {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(engine.timestamp))}")
    print("----------------------------------------------------------")
    print(" Registered Polyglot Subsystems & Line Allocations:")
    
    sorted_mods = registry.sort_by_lines(descending=True)
    for mod in sorted_mods:
        print(f" {mod}")

    total_lines = registry.get_total_lines()
    checksum = engine.compute_deterministic_checksum(registry)
    is_valid = registry.verify_baseline(TOTAL_BASELINE_LINES)

    print("----------------------------------------------------------")
    print(f" Validated Subsystem Line Sum : {total_lines} lines")
    print(f" Expected Milestone Baseline  : {TOTAL_BASELINE_LINES} lines")
    print(f" Baseline Synchronization     : {'[VERIFIED SUCCESS]' if is_valid else '[MISMATCH WARNING]'}")
    print(f" Pure Functional Checksum     : {checksum}")
    print("==========================================================")


# ------------------------------------------------------------------------------
# 5. Build Pipeline Export & CLI Handler
# ------------------------------------------------------------------------------

def export_telemetry_report(output_path: str, registry: PolyglotRegistry, engine: TelemetryEngine) -> None:
    """Exports structured build metrics to a local JSON manifest."""
    report_data = {
        "project": PROJECT_NAME,
        "milestone": engine.milestone,
        "timestamp": engine.timestamp,
        "total_lines": registry.get_total_lines(),
        "baseline_match": registry.verify_baseline(TOTAL_BASELINE_LINES),
        "checksum": engine.compute_deterministic_checksum(registry),
        "subsystems": [
            {
                "filename": m.filename,
                "language": m.language,
                "lines": m.line_count,
                "active": m.active
            }
            for m in registry.modules
        ]
    }
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(report_data, f, indent=4)
        print(f"[EXPORT] Telemetry manifest successfully written to: {output_path}")
    except IOError as e:
        print(f"[ERROR] Failed to write export manifest: {e}", file=sys.stderr)


def main() -> int:
    print_banner()
    
    registry = PolyglotRegistry(REGISTRY_DATA)
    engine = TelemetryEngine(milestone=MILESTONE_VERSION, seed=SYSTEM_SEED)
    
    # CLI Argument Handling for Build Pipeline Integration
    args = sys.argv[1:]
    if args:
        target_path = args[0]
        run_diagnostics(registry, engine)
        print(f"[TARGET] Registering sync path: {target_path}")
        export_telemetry_report(target_path, registry, engine)
    else:
        run_diagnostics(registry, engine)
        print("[INFO] Execution completed in standalone orchestration mode.")
        
    return 0


if __name__ == "__main__":
    sys.exit(main())

# ==============================================================================
# End of webnum.py :: Milestone 261 Python Orchestration Core
# ==============================================================================
