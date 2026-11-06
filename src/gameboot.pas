{ The resident start-up unit. Its initialization, which runs after ModeInit's and before every overlay unit's, is the
  boot: it refuses to run unless its first parameter is the key START passes, records the current directory and the one
  GAME.EXE runs from, asks for any of the three game disks' paths it cannot find, reads GAME.CFG's adapter letter and
  disk paths, opens GAME.OVR, asks for the graphics adapter when GAME.CFG is missing or stale, and sizes the heap and
  the overlay buffer, or reports the memory missing and halts. Config calls EditPathLine, EnsureTrailingBackslash and
  ReadChoice for its own questions, and GameIo calls AdjustHeap when the game quits. The state it sets is in the shared
  data: the directories, GAME.CFG's text, adapter letter and staleness, the INT 66h vector, the heap it needs, and the
  Tandy heap reserve. }
{$A+}
{$I-,V-}
unit GameBoot;

interface

type
  { a path EditPathLine edits }
  TStr79 = String[79];

{ Appends a backslash to path unless it already ends with one.
  @param(path The path, changed in place.) }
procedure EnsureTrailingBackslash(var path: String);

{ Waits for a digit key from minimum to maximum, after discarding waiting keys; Escape quits the game. Clears the screen
  once a digit is taken.
  @returns(The digit's value.)
  @param(minimum The lowest digit taken.)
  @param(maximum The highest digit taken.) }
function ReadChoice(minimum, maximum: Byte): Byte;

{ Echoes s and edits it from the keyboard until Enter: letters, digits, ':' after a drive letter, '.' and '\' where a
  path allows them, and Backspace; Escape quits the game. A lone drive letter A to P gains a colon, and the result is
  expanded with Dos.FExpand.
  @param(s The path, edited in place.) }
procedure EditPathLine(var s: TStr79);

{ Gives back the 16 KB the boot takes from the top of the heap for a Tandy, once. }
procedure AdjustHeap;

implementation

uses Crt, Dos, Overlay, GDConsts, GDVars, C_Keys, Types;

const
  { EditPathLine takes no letter or digit past it }
  MAX_PATH_CHARS = 67;
  { 16 KB of HeapEnd kept for a Tandy's video }
  GFX_RESERVE_PARAS = 1024;
  { The heap the game needs, in bytes, and what each adapter adds or a missing sound driver saves. }
  BASE_MEM_NEEDED = 267696;
  EGA_TANDY_MEM_NEEDED = 36032;
  VGA_MEM_NEEDED = 69552;
  NO_SOUND_DRIVER_SAVING = 36016;
  { Below this many bytes for the overlay buffer the boot warns, asking for 1000 more than lack. }
  LOW_MEMORY_BYTES = 64000;
  LOW_MEMORY_MARGIN = 1000;

var
  heapEndW: Types.TPointerWords absolute HeapEnd;

{ Give back the Tandy heap reserve and end the program. }
procedure AbortWithHeapAdjust;
begin
  GameBoot.AdjustHeap;
  Halt(0);
end;

procedure EnsureTrailingBackslash(var path: String);
begin
  if (Length(path) = 0) or (path[Length(path)] <> '\') then
    path := path + '\';
end;

{ True when Dos.FindFirst finds path and path is not empty: DaxIo.FileExists's test.
  @param(path The file's path.)
  @returns(True when it exists.) }
function InstallFileExists(path: Types.TStr80): Boolean;
var
  sr: SearchRec;
begin
  FindFirst(path, 0, sr);
  InstallFileExists := (DosError = 0) and (Length(path) <> 0);
end;

{ Reads a key; an extended key's scan code is read too and the result is #0.
  @returns(The key, or #0 for an extended key.) }
function GetCharCollapsingExtended: Char;
var
  c: Char;
begin
  c := ReadKey;
  if c = #0 then begin
    c := ReadKey;
    GetCharCollapsingExtended := #0;
  end else
    GetCharCollapsingExtended := c;
end;

{ Discards every waiting key. }
procedure DrainCrtKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  while KeyPressed do
    ch := ReadKey;
end;

function ReadChoice(minimum, maximum: Byte): Byte;
var
  key: Char;
begin
  GameBoot.DrainCrtKeys;
  repeat
    key := GameBoot.GetCharCollapsingExtended;
    if key = C_Keys.ESCAPE then GameBoot.AbortWithHeapAdjust;
  until (key in ['0'..'9']) and ((Ord(key) - Ord('0')) in [minimum..maximum]);
  ClrScr;
  ReadChoice := Ord(key) - Ord('0');
end;

procedure AdjustHeap;
begin
  if not GDConsts.isHeapEndLowered then Exit;
  heapEndW.seg := heapEndW.seg + GameBoot.GFX_RESERVE_PARAS;
  GDConsts.isHeapEndLowered := False;
end;

procedure EditPathLine(var s: TStr79);
var
  i: Byte;
  key: Char;

  { Add key to s and echo it. }
  procedure AppendKeyAndEcho;
  begin
    s := s + key;
    Write(key);
  end;

begin
  GameBoot.DrainCrtKeys;
  for i := 1 to Length(s) do
    Write(s[i]);
  repeat
    key := UpCase(GameBoot.GetCharCollapsingExtended);
    case key of
      C_Keys.ESCAPE:
        GameBoot.AbortWithHeapAdjust;
      ':':
        if (Length(s) = 1) and (s[1] in ['A'..'Z']) then AppendKeyAndEcho;
      '.':
        if (Length(s) > 0) and not (s[Length(s)] in ['.', ':', '\']) then AppendKeyAndEcho;
      '\':
        if (Length(s) = 0) or (s[Length(s)] <> '\') then AppendKeyAndEcho;
      'A'..'Z', '0'..'9':
        if Length(s) < GameBoot.MAX_PATH_CHARS then AppendKeyAndEcho;
      C_Keys.BACKSPACE:
        if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          Write(C_Keys.BACKSPACE);
          Write(' ');
          Write(C_Keys.BACKSPACE);
        end;
    end;
  until key = C_Keys.ENTER;
  { the drive letters }
  if (Length(s) = 1) and (s[1] in ['A'..'P']) then
    s := s + ':';
  s := FExpand(s);
  WriteLn;
end;

{ Report 'Out of memory!', give back the Tandy heap reserve and end the program with code 100. }
procedure AbortOutOfMemory;
begin
  WriteLn('Out of memory!');
  GameBoot.AdjustHeap;
  Halt(100);
end;

{ Report the bytes missing, give back the Tandy heap reserve and end the program with code 100.
  @param(shortfall The bytes missing.) }
procedure AbortOutOfMemoryBy(shortfall: LongInt);
var
  { Unused in this version; see the other implementations of this routine. }
  bytesNeeded: Word;
begin
  Write('Out of memory by ');
  Write(shortfall);
  WriteLn(' bytes');
  GameBoot.AdjustHeap;
  Halt(100);
end;

{ Keeps the directory of the running program in GDVars.exeDir. }
procedure CaptureExeDir;
var
  name: NameStr;
  ext: ExtStr;
begin
  FSplit(ParamStr(0), GDVars.exeDir, name, ext);
end;

{ Says so, discards waiting keys and waits for one, read straight from Crt. }
procedure PressAnyKey;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  WriteLn('Press any key to continue');
  GameBoot.DrainCrtKeys;
  ch := ReadKey;
end;

begin
  CheckBreak := False;
  if ParamStr(1) <> 'UseStart' then
  begin
    WriteLn('Execute START, not GAME.');
    GameBoot.AdjustHeap;
    Halt(0);
  end;
  GetDir(0, GDVars.currentDir);
  GameBoot.EnsureTrailingBackslash(GDVars.currentDir);
  if Lo(DosVersion) < 3 then
    GDVars.exeDir := GDVars.currentDir
  else
    GameBoot.CaptureExeDir;
  while not GameBoot.InstallFileExists(GDVars.exeDir + 'game.exe') do
  begin
    WriteLn('Path of AD&D game disk 1:');
    GameBoot.EditPathLine(GDVars.exeDir);
    GameBoot.EnsureTrailingBackslash(GDVars.exeDir);
  end;
  GDVars.disk2Dir := GDVars.exeDir;
  GDVars.disk3Dir := GDVars.exeDir;
  GDVars.isConfigStale := True;
  if GameBoot.InstallFileExists(GDVars.exeDir + 'game.cfg') then
  begin
    Assign(GDVars.cfgText, GDVars.exeDir + 'game.cfg');
    Reset(GDVars.cfgText);
    ReadLn(GDVars.cfgText, GDVars.cfgChar);
    ReadLn(GDVars.cfgText);
    ReadLn(GDVars.cfgText);
    ReadLn(GDVars.cfgText);
    ReadLn(GDVars.cfgText, GDVars.disk3Dir);
    ReadLn(GDVars.cfgText, GDVars.disk2Dir);
    if not Eof(GDVars.cfgText) then begin
      ReadLn(GDVars.cfgText);
      GDVars.isConfigStale := False;
    end;
    Close(GDVars.cfgText);
    if IOResult <> 0 then GDVars.isConfigStale := True;
    ClrScr;
  end;
  while not GameBoot.InstallFileExists(GDVars.disk2Dir + 'game.ovr') do
  begin
    GDVars.isConfigStale := True;
    WriteLn('Path of AD&D game disk 2:');
    GameBoot.EditPathLine(GDVars.disk2Dir);
    GameBoot.EnsureTrailingBackslash(GDVars.disk2Dir);
  end;
  OvrInit(GDVars.disk2Dir + 'GAME.OVR');
  if OvrResult <> 0 then GameBoot.AbortOutOfMemory;
  OvrInitEMS;
  { Disk 3 is looked for once on the other floppy drive before the player is asked. }
  if not GameBoot.InstallFileExists(GDVars.disk3Dir + 'ecl2.dax') then
  begin
    if UpCase(GDVars.disk3Dir[1]) = 'A' then
      GDVars.disk3Dir[1] := 'B'
    else
      GDVars.disk3Dir[1] := Pred(GDVars.disk3Dir[1]);
    repeat
      GDVars.isConfigStale := True;
      WriteLn('Keep game disk 1/2 in current drive.');
      WriteLn('Place game disk 3 in other drive.');
      WriteLn('Select the drive containing game disk 3:');
      GameBoot.EditPathLine(GDVars.disk3Dir);
      GameBoot.EnsureTrailingBackslash(GDVars.disk3Dir);
    until GameBoot.InstallFileExists(GDVars.disk3Dir + 'ecl2.dax');
  end;
  if GDVars.isConfigStale then begin
    ClrScr;
    Write('GRAPHICS ADAPTER TYPE ([1] CGA  [2] EGA  [3] Tandy 1000  [4] VGA):  ');
    case GameBoot.ReadChoice(1, 4) of
      1: GDVars.cfgChar := 'C';
      2: GDVars.cfgChar := 'E';
      3: GDVars.cfgChar := 'T';
      4: GDVars.cfgChar := 'V';
    end;
  end;
  GetIntVec($66, GDConsts.int66Vector);
  GDVars.memNeeded := GameBoot.BASE_MEM_NEEDED;
  if GDVars.cfgChar = 'T' then
  begin
    Inc(GDVars.memNeeded, GameBoot.EGA_TANDY_MEM_NEEDED);
    { HeapEnd 16 KB below a 64 KB boundary }
    if (heapEndW.seg and $FFF) = $C00 then begin
      heapEndW.seg := heapEndW.seg - GameBoot.GFX_RESERVE_PARAS;
      GDConsts.isHeapEndLowered := True;
    end;
  end;
  if GDVars.cfgChar = 'V' then Inc(GDVars.memNeeded, GameBoot.VGA_MEM_NEEDED);
  if GDVars.cfgChar = 'E' then Inc(GDVars.memNeeded, GameBoot.EGA_TANDY_MEM_NEEDED);
  if GDConsts.int66Vector = nil then Dec(GDVars.memNeeded, GameBoot.NO_SOUND_DRIVER_SAVING);
  if MemAvail < GDVars.memNeeded then
    GameBoot.AbortOutOfMemoryBy(GDVars.memNeeded - MemAvail);
  if (MemAvail - GDVars.memNeeded) + OvrGetBuf < GameBoot.LOW_MEMORY_BYTES then begin
    Write('Memory low.  Try to free up another ');
    Write(GameBoot.LOW_MEMORY_BYTES - ((MemAvail - GDVars.memNeeded) + OvrGetBuf) + GameBoot.LOW_MEMORY_MARGIN);
    WriteLn(' bytes.');
    GameBoot.PressAnyKey;
  end;
  OvrSetBuf((MemAvail - GDVars.memNeeded) + OvrGetBuf);
  if OvrResult <> 0 then GameBoot.AbortOutOfMemory;
end.
