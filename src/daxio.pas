{ DAX archive loading and the file helpers around it. LoadDax finds a record in a DAX archive, reads it and decompresses
  it into a new buffer; OpenWithRetry looks for a game file in the configured directories and asks for its disk on the
  status line until it is found. PushState and PopState switch the virtual disk the prompts and archive names use.
  invalidFileChars and the disk prompts are in GDConsts; the directories, the virtual disk and the compressed-record
  buffer are in GDVars. }
{$O+,F+,I-,R-,S+,V-,B-,A+}
unit DaxIo;
interface
uses C_Screen, C_Video, Dos, GDConsts, GDVars, GameIo, Crt, Types;

type
  TStr20 = string[20];

{ Opens a game file for reading in one-byte records. A name without a directory is looked for in GDVars.exeDir, then
  GDVars.disk2Dir and GDVars.disk3Dir where they differ from it. A missing file is asked for with promptMsg and
  GDVars.promptDrive's letter when the directory last tried is on a floppy drive, below 'C', and with 'Check install'
  otherwise.
  @param(fileName The file, with or without a directory.)
  @param(promptMsg The disk prompt, which the drive letter follows.)
  @param(noPrompt Non-zero gives up on a missing file instead of asking.)
  @param(f Receives the open file.)
  @returns(True when the file is open in f.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var f: file): Boolean;

{ Tells whether a normal file matching a name exists.
  @param(name The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(name: Types.TStr80): Boolean;

{ Delete the occurrences of del in src that one scan from the left finds.
  @param(src The string.)
  @param(del The text to delete.)
  @returns(src without them.) }
function SanitizeString(src, del: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr80;

{ Loads record fileId of the archive fileName + ext into a new buffer. A missing record is looked for again in the
  archive named with the virtual disk's number appended, unless the name already ends in a digit or starts with 'MON';
  neither attempt asks for a missing archive. Then, unless the insert-disk prompt is suppressed, the disk is asked for
  and both tried again.
  @param(fileName The archive's base name.)
  @param(ext Its extension.)
  @param(fileId The record.)
  @param(sizeRead Set to the record's decompressed size, 0 when it is missing.)
  @param(data Set to the buffer, sizeRead bytes, nil when the record is missing.) }
procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PBytes);

{ Selects another virtual disk, remembering the current one for PopState.
  @param(v The virtual disk to select.) }
procedure PushState(v: Byte);

{ Returns to the disk PushState remembered. }
procedure PopState;

{ Erases the named file if it exists.
  @param(name The file's path.) }
procedure DeleteIfPresent(name: Types.TStr80);
implementation

const
  { INT 10h function: moves page BH's cursor to row DH, column DL }
  BIOS_SET_CURSOR_POS = $02;
  { INT 10h function: writes AL CX times at the cursor in attribute BL }
  BIOS_WRITE_CHAR_ATTR = $09;
  { the character WriteBlock writes }
  SOLID_BLOCK = 219;
  { The largest compressed record LoadDaxCore accepts; a larger one shows 'tempsize' and ends the game. }
  MAX_COMPRESSED_SIZE = 40050;

{ Frees a block allocated by AllocRounded, with the same rounding of its size.
  @param(p The block.)
  @param(n The size it was allocated with.) }
procedure FreeRounded(var p: Pointer; n: Word);
begin FreeMem(p, (n + 7) and $FFF8) end;

{ Empty. LoadDaxCore calls it on each way out. }
procedure EndDiskAccess; begin end;

{ Allocates a block with its size rounded up to a multiple of eight bytes.
  @param(p Receives the block.)
  @param(n The size wanted.) }
procedure AllocRounded(var p: Pointer; n: Word);
begin GetMem(p, (n + 7) and $FFF8) end;

{ Writes a run of one character in text mode through the video BIOS on page 0, placing the cursor first. On CGA the
  attribute is translated through the CGA attribute table.
  @param(col Text column.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many copies to write.)
  @param(ch The character.) }
procedure WriteChar(col, row, attr, count, ch: Byte);
begin
 GDVars.interruptRegisters.AH := DaxIo.BIOS_SET_CURSOR_POS; GDVars.interruptRegisters.BH := 0;
 GDVars.interruptRegisters.DH := row; GDVars.interruptRegisters.DL := col;
 Intr($10, Registers(GDVars.interruptRegisters));
 GDVars.interruptRegisters.AH := DaxIo.BIOS_WRITE_CHAR_ATTR; GDVars.interruptRegisters.AL := ch;
 GDVars.interruptRegisters.BH := 0;
 if GDVars.displayMode = C_Video.VM_CGA then GDVars.interruptRegisters.BL := GDConsts.attrTable[attr]
 else GDVars.interruptRegisters.BL := attr;
 GDVars.interruptRegisters.CX := count; Intr($10, Registers(GDVars.interruptRegisters))
end;

{ Writes a string in text mode through the video BIOS, one character per column.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin n := Length(source); for i := 1 to n do begin
 DaxIo.WriteChar(col, row, attr, 1, Ord(source[i])); Inc(col) end end;

{ Writes a run of solid block characters through the BIOS.
  @param(col Column of the first block.)
  @param(row Row of the run.)
  @param(attr Text attribute.)
  @param(count Number of blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);
begin DaxIo.WriteChar(col, row, attr, count, DaxIo.SOLID_BLOCK) end;

{ Shows a message on the bottom text row over a cleared bar, waits for a key, then clears the bar.
  @param(attr Attribute of the message.)
  @param(message The message.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin DaxIo.WriteBlock(0, C_Screen.STATUS_ROW, 0, 40); DaxIo.WriteString(0, C_Screen.STATUS_ROW, attr, message);
 key := GameIo.ReadGameKey; DaxIo.WriteBlock(0, C_Screen.STATUS_ROW, 0, 40) end;

procedure DeleteIfPresent(name: Types.TStr80);
var f: file;
begin if DaxIo.FileExists(name) then begin Assign(f, name); Erase(f) end end;

function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var f: file): Boolean;
var
 found: Boolean;
 { Unused in this version; see the other implementations of this routine. }
 swapTmp: Types.TStr80;
 dir: DirStr;
 oldDir: DirStr; name: NameStr; ext: ExtStr;
begin
 FSplit(fileName, dir, name, ext); if dir = '' then dir := GDVars.exeDir;
 repeat
  oldDir := dir;
  found := DaxIo.FileExists(oldDir + name + ext);
  if not found then
   if GDVars.disk2Dir <> GDVars.exeDir then begin
    oldDir := GDVars.disk2Dir; found := DaxIo.FileExists(oldDir + name + ext) end;
  if not found then
   if GDVars.disk3Dir <> GDVars.exeDir then begin
    oldDir := GDVars.disk3Dir; found := DaxIo.FileExists(oldDir + name + ext) end;
  if (not found) and (noPrompt = #0) then
   if oldDir[1] < 'C' then DaxIo.PromptBox(Yellow, promptMsg + GDVars.promptDrive + ':')
   else DaxIo.PromptBox(Yellow, 'Couldn''t find ' + name + ext + '. Check install.')
 until found or (noPrompt <> #0);
 if found then begin Assign(f, oldDir + name + ext); Reset(f, 1) end;
 OpenWithRetry := found
end;

function FileExists(name: Types.TStr80): Boolean;
var sr: SearchRec;
begin FindFirst(name, 0, sr); FileExists := (DosError = 0) and (name <> '') end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin delLen := Length(del); limit := Length(src) - delLen + 1; i := 1;
 while i <= limit do
  if Copy(src, i, delLen) = del then begin
   Delete(src, i, delLen); limit := Length(src) - delLen + 1
  end else Inc(i);
 SanitizeString := src end;

function SanitizeFileName(name: string): Types.TStr80;
var i: Byte;
begin
 for i := 1 to 10 do name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
 name := Copy(name, 1, 8);
 for i := 1 to Length(name) do name[i] := UpCase(name[i]);
 SanitizeFileName := name
end;

{ Expands DAX run-length data. A control byte from 0 to $7E copies the next control + 1 bytes; one from $81 to $FF
  repeats the next byte -control times. The data is read at least once, even when it is empty, and neither buffer's
  bounds are checked. Note: control bytes $7F and $80 do not advance the input, so such data loops forever.
  @param(src The compressed data.)
  @param(dst Receives the expanded data.)
  @param(lenCompressed Length of the compressed data.)
  @param(lenDecompressed Unused.) }
procedure DecompressDaxBuffer(var src, dst: Types.PBytes; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word; b: ShortInt;
begin srcIdx := 0; dstIdx := 0; repeat b := src^[srcIdx]; case b of
 0..126: begin Move(src^[srcIdx + 1], dst^[dstIdx], b + 1); Inc(srcIdx, b + 2); Inc(dstIdx, b + 1) end;
 -127..-1: begin b := -b; FillChar(dst^[dstIdx], b, src^[srcIdx + 1]); Inc(srcIdx, 2); Inc(dstIdx, b) end
 end until srcIdx >= lenCompressed end;

{ Opens an archive twice, one handle for its entry directory from the start and one positioned at the first data byte.
  Note: if the second open fails, the first handle is left open.
  @param(fileName The archive's base name.)
  @param(ext Its extension.)
  @param(headerSize Receives the offset of the first data byte.)
  @param(dataFile Receives the handle positioned at the data.)
  @param(indexFile Receives the handle that reads the directory.)
  @returns(True when both opens succeeded.) }
function OpenDax(fileName, ext: TStr20; var headerSize: Word; var dataFile, indexFile: file): Boolean;
var
  nread: Word;
  { Unused in this version; see the other implementations of this routine. }
  ioStatus: Word;
begin
 if DaxIo.OpenWithRetry(fileName + ext, GDConsts.insertDiskDrive[GDVars.virtualDiskNumber],
                  Char(GDVars.suppressingInsertDiskFlag), dataFile) then begin
  if not DaxIo.OpenWithRetry(fileName + ext, GDConsts.insertDiskDrive[GDVars.virtualDiskNumber],
                       Char(GDVars.suppressingInsertDiskFlag), indexFile) then begin
   OpenDax := False; Exit end;
  BlockRead(indexFile, headerSize, SizeOf(headerSize), nread); Inc(headerSize, 2); Seek(dataFile,
                                                                                        headerSize); OpenDax := True
 end else OpenDax := False
end;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(indexFile The directory handle.) }
procedure CloseDax(var dataFile, indexFile: file); begin Close(dataFile); Close(indexFile) end;

{ LoadDax's single attempt: the record fileId of fileName + ext, or sizeRead 0 and data nil.
  @param(fileName The archive's base name.)
  @param(ext Its extension.)
  @param(fileId The record.)
  @param(sizeRead Set to the record's decompressed size, 0 when it is missing.)
  @param(data Set to the new buffer, nil when the record is missing.) }
procedure LoadDaxCore(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PBytes);
var
  compSize: Word;
  offset: LongInt;
  id: Byte;
  n: Word;
  dataFile: file;
  indexFile: file;
  hdrSize: Word;
  numStr: String[6];
  { Unused in this version; see the other implementations of this routine. }
  tries: Byte;
begin
 if not DaxIo.OpenDax(fileName, ext, hdrSize, dataFile, indexFile) then begin
  sizeRead := 0; data := nil; DaxIo.EndDiskAccess; Exit end;
 repeat
  BlockRead(indexFile, id, SizeOf(id), n); BlockRead(indexFile, offset, SizeOf(offset), n);
  BlockRead(indexFile, sizeRead, SizeOf(sizeRead), n);
  BlockRead(indexFile, compSize, SizeOf(compSize), n);
  if compSize > DaxIo.MAX_COMPRESSED_SIZE then begin Str(LongInt(compSize), numStr);
   DaxIo.PromptBox(Yellow, 'tempsize ' + numStr); GameIo.ExitGame end
 until (id = fileId) or (FilePos(indexFile) >= hdrSize);
 if id <> fileId then begin
  sizeRead := 0; data := nil; DaxIo.CloseDax(dataFile, indexFile); DaxIo.EndDiskAccess; Exit end;
 DaxIo.AllocRounded(GDVars.daxCompressedFilePtr, compSize); GetMem(data, sizeRead);
 Seek(dataFile, hdrSize + offset); BlockRead(dataFile, GDVars.daxCompressedFilePtr^, compSize, n);
 DaxIo.CloseDax(dataFile, indexFile);
 DaxIo.DecompressDaxBuffer(Types.PBytes(GDVars.daxCompressedFilePtr), data, compSize, sizeRead);
 DaxIo.FreeRounded(GDVars.daxCompressedFilePtr, compSize); DaxIo.EndDiskAccess
end;

procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PBytes);
var
  diskText: String[1];
  savedSuppress: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fullPath: String[82];
  { Unused in this version; see the other implementations of this routine. }
  attempts: Word;
begin
 Str(LongInt(GDVars.virtualDiskNumber), diskText);
 sizeRead := 0; savedSuppress := GDVars.suppressingInsertDiskFlag;
 repeat
  GDVars.suppressingInsertDiskFlag := 1;
  DaxIo.LoadDaxCore(fileName, ext, fileId, sizeRead, data);
  if (sizeRead = 0) and not (fileName[Length(fileName)] in ['0'..'9']) and (Copy(fileName, 1, 3) <> 'MON') then begin
    GDVars.suppressingInsertDiskFlag := 1;
    DaxIo.LoadDaxCore(fileName + diskText, ext, fileId, sizeRead, data)
  end;
  GDVars.suppressingInsertDiskFlag := savedSuppress;
  if (sizeRead <> 0) or (GDVars.suppressingInsertDiskFlag <> 0) then Exit;
  DaxIo.PromptBox(Yellow, GDConsts.insertDiskDrive[GDVars.virtualDiskNumber] + GDVars.disk3Dir[1] + ':');
 until False
end;

procedure PushState(v: Byte);
begin GDVars.previousVirtualDisk := GDVars.virtualDiskNumber; GDVars.virtualDiskNumber := v end;

procedure PopState; begin GDVars.virtualDiskNumber := GDVars.previousVirtualDisk end;
begin end.
