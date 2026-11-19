program main;

{$mode objfpc}{$H+}
{$RANGECHECKS ON}
{$OVERFLOWCHECKS ON}

const
  WMX_VERSION_MAJOR = 1;
  WMX_VERSION_MINOR = 0;
  WMX_SECTOR_SIZE   = 4096;
  WMX_MAX_PATH      = 1024;
  WMX_ARENA_DEFAULT = 1048576; // 1 MiB static/arena block

  // Deterministic Exit & Status Codes
  WMX_OK            = 0;
  WMX_ERR_NOMEM     = 1;
  WMX_ERR_IO        = 2;
  WMX_ERR_BOUNDS    = 3;
  WMX_ERR_INVALID   = 4;

type
  TWmxStatus = LongInt;

  // Hardware-aligned arena allocator (zero heap fragmentation)
  TWmxArena = record
    BasePtr  : PByte;
    Capacity : SizeUInt;
    Offset   : SizeUInt;
    Peak     : SizeUInt;
  end;

  // Fixed-header binary frame for cross-language IPC (Fortran/COBOL/Rust/C++)
  PWmxFrameHeader = ^TWmxFrameHeader;
  TWmxFrameHeader = packed record
    Magic      : UInt32;   // $574D5830 ('WMX0')
    LangTag    : UInt16;   // Domain identifier
    Flags      : UInt16;
    PayloadLen : UInt32;
    Checksum   : UInt32;   // FNV-1a 32-bit digest
  end;

function AlignUp(Value, Alignment: SizeUInt): SizeUInt; inline;
var
  Mask: SizeUInt;
begin
  if Alignment <= 1 then
    Exit(Value);
  Mask := Alignment - 1;
  Result := (Value + Mask) and (not Mask);
end;

function WmxArenaInit(out Arena: TWmxArena; Bytes: SizeUInt): TWmxStatus;
begin
  Arena.BasePtr := nil;
  Arena.Capacity := 0;
  Arena.Offset := 0;
  Arena.Peak := 0;

  if Bytes = 0 then
    Exit(WMX_ERR_INVALID);

  GetMem(Arena.BasePtr, Bytes);
  if Arena.BasePtr = nil then
    Exit(WMX_ERR_NOMEM);

  FillChar(Arena.BasePtr^, Bytes, 0);
  Arena.Capacity := Bytes;
  Result := WMX_OK;
end;

function WmxArenaAlloc(var Arena: TWmxArena; Bytes: SizeUInt; Align: SizeUInt = 16): Pointer;
var
  AlignedOffset: SizeUInt;
  NextOffset: SizeUInt;
begin
  Result := nil;
  if (Arena.BasePtr = nil) or (Bytes = 0) then
    Exit;

  AlignedOffset := AlignUp(Arena.Offset, Align);
  if AlignedOffset > Arena.Capacity then
    Exit;

  NextOffset := AlignedOffset + Bytes;
  if (NextOffset < AlignedOffset) or (NextOffset > Arena.Capacity) then
    Exit;

  Result := Arena.BasePtr + AlignedOffset;
  Arena.Offset := NextOffset;
  if Arena.Offset > Arena.Peak then
    Arena.Peak := Arena.Offset;
end;

procedure WmxArenaReset(var Arena: TWmxArena);
begin
  if Arena.BasePtr <> nil then
    FillChar(Arena.BasePtr^, Arena.Offset, 0);
  Arena.Offset := 0;
end;

procedure WmxArenaFree(var Arena: TWmxArena);
begin
  if Arena.BasePtr <> nil then
  begin
    FreeMem(Arena.BasePtr, Arena.Capacity);
    Arena.BasePtr := nil;
  end;
  Arena.Capacity := 0;
  Arena.Offset := 0;
  Arena.Peak := 0;
end;

function WmxFnv1a32(Data: Pointer; Len: SizeUInt): UInt32;
const
  FNV_OFFSET_32 = UInt32($811C9DC5);
  FNV_PRIME_32  = UInt32($01000193);
var
  P: PByte;
  I: SizeUInt;
  Hash: UInt32;
begin
  Hash := FNV_OFFSET_32;
  if (Data = nil) or (Len = 0) then
    Exit(Hash);

  P := PByte(Data);
  for I := 0 to Len - 1 do
  begin
    Hash := Hash xor P[I];
    Hash := Hash * FNV_PRIME_32;
  end;
  Result := Hash;
end;

function WmxMemCompare(A, B: Pointer; Len: SizeUInt): Boolean;
var
  PA, PB: PByte;
  I: SizeUInt;
  Diff: Byte;
begin
  if Len = 0 then
    Exit(True);
  if (A = nil) or (B = nil) then
    Exit(False);

  PA := PByte(A);
  PB := PByte(B);
  Diff := 0;
  // Constant-time comparison loop
  for I := 0 to Len - 1 do
    Diff := Diff or (PA[I] xor PB[I]);

  Result := (Diff = 0);
end;

function WmxWriteFrame(const FilePath: RawByteString; LangTag: UInt16;
  Payload: Pointer; PayloadLen: UInt32): TWmxStatus;
var
  F: File;
  Header: TWmxFrameHeader;
  Written: SizeInt;
begin
  if (PayloadLen > 0) and (Payload = nil) then
    Exit(WMX_ERR_INVALID);

  Header.Magic := $574D5830;
  Header.LangTag := LangTag;
  Header.Flags := 0;
  Header.PayloadLen := PayloadLen;
  Header.Checksum := WmxFnv1a32(Payload, PayloadLen);

  {$I-}
  Assign(F, FilePath);
  Rewrite(F, 1);
  if IOResult <> 0 then
    Exit(WMX_ERR_IO);

  BlockWrite(F, Header, SizeOf(TWmxFrameHeader), Written);
  if (IOResult <> 0) or (Written <> SizeOf(TWmxFrameHeader)) then
  begin
    Close(F);
    Exit(WMX_ERR_IO);
  end;

  if PayloadLen > 0 then
  begin
    BlockWrite(F, Payload^, PayloadLen, Written);
    if (IOResult <> 0) or (SizeUInt(Written) <> PayloadLen) then
    begin
      Close(F);
      Exit(WMX_ERR_IO);
    end;
  end;

  Close(F);
  {$I+}
  if IOResult <> 0 then
    Exit(WMX_ERR_IO);

  Result := WMX_OK;
end;

function WmxReadFrame(const FilePath: RawByteString; var Arena: TWmxArena;
  out Header: TWmxFrameHeader; out PayloadOut: Pointer): TWmxStatus;
var
  F: File;
  BytesRead: SizeInt;
  Digest: UInt32;
begin
  PayloadOut := nil;
  FillChar(Header, SizeOf(TWmxFrameHeader), 0);

  {$I-}
  Assign(F, FilePath);
  Reset(F, 1);
  if IOResult <> 0 then
    Exit(WMX_ERR_IO);

  BlockRead(F, Header, SizeOf(TWmxFrameHeader), BytesRead);
  if (IOResult <> 0) or (BytesRead <> SizeOf(TWmxFrameHeader)) then
  begin
    Close(F);
    Exit(WMX_ERR_IO);
  end;

  if Header.Magic <> $574D5830 then
  begin
    Close(F);
    Exit(WMX_ERR_INVALID);
  end;

  if Header.PayloadLen > 0 then
  begin
    PayloadOut := WmxArenaAlloc(Arena, Header.PayloadLen, 16);
    if PayloadOut = nil then
    begin
      Close(F);
      Exit(WMX_ERR_NOMEM);
    end;

    BlockRead(F, PayloadOut^, Header.PayloadLen, BytesRead);
    if (IOResult <> 0) or (UInt32(BytesRead) <> Header.PayloadLen) then
    begin
      Close(F);
      Exit(WMX_ERR_IO);
    end;
  end;

  Close(F);
  {$I+}
  if IOResult <> 0 then
    Exit(WMX_ERR_IO);

  Digest := WmxFnv1a32(PayloadOut, Header.PayloadLen);
  if Digest <> Header.Checksum then
    Exit(WMX_ERR_INVALID);

  Result := WMX_OK;
end;

function WmxTargetPlatform: ShortString;
begin
  {$IF DEFINED(DARWIN)}
  Result := 'macOS (Darwin Native)';
  {$ELSEIF DEFINED(FREEBSD)}
  Result := 'FreeBSD Native';
  {$ELSEIF DEFINED(OPENBSD)}
  Result := 'OpenBSD Native';
  {$ELSEIF DEFINED(NETBSD)}
  Result := 'NetBSD Native';
  {$ELSEIF DEFINED(LINUX)}
  Result := 'Linux Native';
  {$ELSE}
  Result := 'POSIX Generic';
    {$ENDIF}
end;

begin
  Writeln('The Web Machine X: ', WmxTargetPlatform, ' v0.2');
end.
