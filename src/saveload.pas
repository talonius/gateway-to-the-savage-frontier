{ Save, load and character-file I/O. The unit owns every on-disk format the game writes: the savgam<A..J>.dat party file
  (fixed GBVM bank blocks plus one CHRDAT record per member), the per-character .guy with its .swg item list and .fx
  effect list, the .sav saved-game member, and the read-only import path (.cha and .spc). Around them are the disk-swap,
  disk-full and Overwrite dialogs, the creature-list bookkeeping that threads a loaded record into the party and gives
  it an icon slot, and SyncVault, which makes the chosen save slot's vault file active.

  saveFileSizes holds the three record sizes by save mode: the work record, the saved TCharRecord and the imported
  roster header that LoadChar reads in mode 2. The saved TCharRecord is read and written whole everywhere except
  ConvertPoolRecord, which unpacks it field by field into the work record.

  Work-record fields this unit uses: npc (above $7F triggers the recalc in AddCharToParty), randomId, orderNumber (the
  icon-animation slot 0..7), itemsAddr, next, and combatAddr, which LoadChar sets to nil alongside items, effects and
  next. }
{$O+,F+,I-,S+,A+}
unit SaveLoad;

interface

uses Types;

type
  TStr8 = String[8];

{ Lists the characters that can be added. In save mode 0 it scans the save directory for *.guy (other modes list
  nothing), and for each matching file whose padded name is not already in the creature list builds a pair of name
  nodes, the display name in a and the disk file name in b.
  @param(a Receives the display names.)
  @param(b Receives the file names, in step with a.) }
procedure LoadCharlist(var a, b: Types.PItemRec);

{ In save mode 0, makes sure the save directory exists before a save or load. It looks the directory up with FindFirst
  and, on error 2 or 18, asks for drives A and B whether the save disk is in (telling the player to put it in on No) and
  then makes the directory; any other error asks for the save disk on A or B, and on a hard disk reports the error. It
  repeats until the directory is found or made (or error 5). Other save modes skip the check.
  @returns(False when a hard disk reports an error, else True.) }
function CheckSaveDir: Boolean;

{ Rebuilds the current creature's combat icon: loads its CHEAD/CBODY class glyphs, merges them over the slot images, and
  (when loading) remaps the palette from the stored color nibbles.
  @param(loading True to remap the palette.) }
procedure LoadCharIconAnim(loading: Boolean);

{ Deletes a character's .guy, .swg and .fx files from the save directory.
  @param(cr The character, whose name gives the file names.) }
procedure DeleteCharacterFiles(cr: Types.PWork);

{ Writes a party member or saved game to disk: a disk-full retry through DiskFree, an overwrite dialog, then the .guy
  (or .sav), .swg (items) and .fx (effects) files.
  @param(cr The character, a work record.)
  @param(fname The saved-game member's name, or empty to save a .guy under the character's name.) }
procedure SaveChar(cr: Types.PCharRecord; fname: TStr8);

{ Loads a character or party-member record into the work record cr^. Three save formats (GDVars.characterImportMode): 0,
  a whole work record read straight into cr^; 1, a saved TCharRecord unpacked by ConvertPoolRecord; 2, an imported
  roster entry, whose header is read and either matched to an existing .guy or .cha file on disk (SavedNameExists,
  MergeHillsfarRecord, ConvertPoolRecord) or imported inline. Then it loads the item (.swg) and effect (.fx) lists.
  @param(name The file name, with its extension.)
  @param(cr Receives the character.)
  @param(savedGame Unused.)
  @param(askDisk True to ask for the save disk, else for the game disk.) }
procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);

{ Loads a monster's record and its item and effect lists from MON<disk>CHA/SPC/ITM.dax. The CHA entry is a whole work
  record, moved into cr^; SPC is the effect list and ITM the item list, each built one node per record.
  @param(id The monster's record.)
  @param(cr Receives the monster.) }
procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);

{ Adds a monster to the party, unless it already has 8 members, with its combat icon from CPIC.
  @param(id The monster number, also kept as its creature ID.) }
procedure AddCreatureToParty(id: Byte);

{ Presents the savgam<A..J>.dat load menu, then reads the GBVM memory zones and party members back from the chosen file:
  it reloads each saved party member (.sav) through LoadChar and AddCharToParty, deletes the stale files, rebuilds each
  creature's combat icon, and restores the interface state. }
procedure LoadGame;

{ Presents the 'A B C..J' savgam slot menu, checks the disk space for the party, then writes savgam<slot>.dat (the fixed
  GBVM zones and one CHRDAT<slot><n> name per party member) and saves each member through SaveChar, deleting the stale
  roster files. }
procedure SaveGame;

{ Appends a character to the party, makes it current, gives it the first free order slot, and counts it in the party
  size; an NPC also has its class values recalculated. Note: with all eight order slots taken, the order slot is left at
  8.
  @param(cr The character.) }
procedure AddCharToParty(cr: Types.PCharRecord);

implementation

uses C_Effect, C_Ifc, C_Npc, C_Race, C_Screen, C_Stat, C_Status, C_Video, Dos, Money, CharHlp, DaxIo, MapTiles, CharGen,
  MenuCore, TextRend, ViewChar, FxEngine, ClassCal, GameIo, Blit, View3D, Crt, GDConsts, GDVars, C_Keys, C_Gbvm;

const
  { GBVM zone 0: the game speed a saved game keeps }
  GAME_SPEED = $4BFC;
  { GBVM zone 0: the picture flags a saved game keeps, monster pictures in bit 1 and portraits in bit 0 }
  PICTURE_FLAGS = $4BFF;
  { GBVM zone 1: the virtual disk number a saved game keeps }
  DISK_NUMBER = $7F12;

type

  { GBVM bank 1 (GDVars.gbvmZone1Ptr) as LoadGame reads it as bytes, through slZone1: the low byte of the virtual disk
    number SaveGame stores (SaveLoad.DISK_NUMBER). }
  PZone1 = ^TZone1;
  TZone1 = record
    diskNumberLead: array[$000..$623] of Byte;
    diskNumber: Byte;
  end;

  { C-string view for CStrToStr: a far pointer to raw Char bytes. }
  TCharArr = array[0..65534] of Char;
  PCharArr = ^TCharArr;

  { LoadGame's types }
  { GBVM bank 0 (GDVars.gbvmZone0Ptr) as LoadGame reads it as bytes, through slZone2: the low bytes of the GEO map's
    number (C_Gbvm.GEO_MAP_ID) and of the game speed (SaveLoad.GAME_SPEED). }
  PState = ^TState;
  TState = record
    mapIdLead: array[$000..$189] of Byte;
    mapId: Byte;
    gameDelayLead: array[$18B..$1F7] of Byte;
    gameDelay: Byte;
  end;

  { the imported character record (mode 2); buf2 points at it }
  PHillsfarRec = ^THillsfarRec;

  { a saved name }
  TStr15 = String[15];

{ Every variable below is an absolute alias onto GDConsts or GDVars storage. }
var
  slZone1: PZone1 absolute
    GDVars.gbvmZone1Ptr;
  { LoadGame's state }
  slZone2: PState absolute
    GDVars.gbvmZone0Ptr;

function CStrToStr(src: PCharArr): String; forward;

procedure MergeIcon(a, b: Types.PImgBuf); forward;

{ Convert a C (null-terminated) string to a Pascal String: scan src for the terminating #0 to obtain the length, Move
  that many bytes into a local String, set its length byte, and return the String. Called from ScanSaveFiles and
  LoadChar.
  @param(src The C string.)
  @returns(The Pascal string.) }
function CStrToStr(src: PCharArr): String;
var
  i: Byte;
  s: String;
begin
  i := 0;
  while src^[i] > #0 do
    Inc(i);
  Move(src^, s[1], i);
  s[0] := Chr(i);
  CStrToStr := s;
end;

procedure LoadCharlist(var a, b: Types.PItemRec);

  { Add the unlisted characters of the files matching pattern of size expectSize to outA and outB. }
  procedure ScanSaveFiles(pattern: Types.TStr80; name1Ofs, name2Ofs, expectSize: Word; var outA, outB: Types.PItemRec);
  var
    { Unused in this version; see the other implementations of this routine. }
    mode: ShortInt;
    displayNode: Types.PItemRec;
    displayTail: Types.PItemRec;
    fileNode: Types.PItemRec;
    fileTail: Types.PItemRec;
    { creatureList walker }
    cr: Types.PWork;
    sr: SearchRec;
    { BlockRead result }
    cnt: Word;
    f: File;
    { 'from saved game X' suffix }
    buf2: String[80];
    { status byte }
    n2len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    nameBuffer: array[0..18] of Byte;
  begin
    displayNode := nil;
    fileNode := nil;
    mode := DosError;
    FindFirst(pattern, 0, sr);
    while DosError = 0 do begin
      Assign(f, GDVars.saveDir + sr.Name);
      Reset(f, 1);
      if FileSize(f) = expectSize then begin
        GetMem(displayNode, SizeOf(Types.TItemNode));
        GetMem(fileNode, SizeOf(Types.TItemNode));
        FillChar(displayNode^, SizeOf(Types.TItemNode), 0);
        FillChar(fileNode^, SizeOf(Types.TItemNode), 0);
        Seek(f, name1Ofs);
        BlockRead(f, displayNode^, SizeOf(TStr15), cnt);
        { The status byte follows the name directly; name2Ofs is unused. }
        BlockRead(f, n2len, SizeOf(n2len));
        fileNode^.name := sr.Name;
        if Copy(sr.Name, 9, 4) = '.SAV' then
          buf2 := 'from saved game ' + sr.Name[7]
        else
          buf2 := '';
        displayNode^.name := displayNode^.name + Copy(GDConsts.nameBlanks, 1, 15 - Length(displayNode^.name)) + buf2;
        cr := GDVars.creatureList;
        while (cr <> nil) and
            (Copy(displayNode^.name, 1, 15) <>
             cr^.name + Copy(GDConsts.nameBlanks, 1, 15 - Length(cr^.name))) do
          cr := cr^.next;
        if (n2len > 127) or (cr <> nil) then begin
          FreeMem(displayNode, SizeOf(Types.TItemNode));
          FreeMem(fileNode, SizeOf(Types.TItemNode));
          displayNode := nil;
          fileNode := nil;
        end;
        if displayNode <> nil then begin
          if outA = nil then begin
            outA := Types.PItemRec(displayNode);
            displayTail := Types.PItemRec(outA);
            outB := Types.PItemRec(fileNode);
            fileTail := Types.PItemRec(outB);
          end else begin
            displayTail^.next := displayNode;
            displayTail := displayTail^.next;
            fileTail^.next := fileNode;
            fileTail := fileTail^.next;
          end;
        end;
      end;
      Close(f);
      FindNext(sr);
    end;
  end;

begin
  a := nil;
  b := nil;
  if not SaveLoad.CheckSaveDir then Exit;
  case GDVars.characterImportMode of
    0: ScanSaveFiles(GDVars.saveDir + '*.guy', GDConsts.saveNameOffsets[GDVars.characterImportMode],
                     GDConsts.saveName2Offsets[GDVars.characterImportMode],
                     GDConsts.saveFileSizes[GDVars.characterImportMode], a, b);
  end;
end;

function CheckSaveDir: Boolean;
var
  err: Integer;
  sr: SearchRec;
  key: Char;
begin
  CheckSaveDir := False;
  case GDVars.characterImportMode of
    0:
      repeat
        repeat
          FindFirst(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1), Directory, sr);
          err := DosError;
          case err of
            0: ;
            2, 18:
              begin
                if UpCase(GDVars.saveDir[1]) < 'C' then begin
                  key := MenuCore.YesNoMenu
                    ('Is your save disk in drive ' + GDVars.saveDir[1] + ':? ', LightMagenta, LightGreen, White);
                  if key <> 'Y' then
                    TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':');
                end;
                MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1));
                err := DosError;
              end;
          else
            if UpCase(GDVars.saveDir[1]) < 'C' then
              TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
            else begin
              TextRend.DisplayAndPause(Yellow, Black, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
              Exit;
            end;
          end;
        until err in [0, 5];
      until err in [0, 5];
  end;
  CheckSaveDir := True;
end;

{ Merge two combat-icon images.
  @param(a The image merged in.)
  @param(b The image merged into.) }
procedure MergeIcon(a, b: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  count: array[0..1] of Byte;
  i: Word;
begin
  for i := 0 to a^.frameSize - 1 do begin
    if GDVars.displayMode <> C_Video.VM_VGA then begin
      b^.transp^[i] := b^.transp^[i] and a^.transp^[i];
      b^.data[i] := (b^.data[i] or a^.data[i]) and not b^.transp^[i];
    end else if b^.data[i] = b^.mode3Extra then
      b^.data[i] := a^.data[i];
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  savedSlot: array[0..3] of Byte;
  arr1: Types.TColorTab;
  arr2: Types.TColorTab;
  i: Byte;
begin
  DaxIo.PushState(1);
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconHeightSuffix[cgIconSizeColors[0]], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconHeightSuffix[cgIconSizeColors[0]], iconBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconAnimation[11, 0], GDVars.iconAnimation[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconAnimation[11, 1], GDVars.iconAnimation[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        arr1[i] := i;
        arr2[i] := i;
      end;
      for i := 1 to 6 do begin
        arr2[GDConsts.defIconCol[i]] := cgIconSizeColors[i] and $0F;
        arr2[GDConsts.defIconCol[i] + 8] := (cgIconSizeColors[i] and $F0) shr 4;
      end;
      Blit.RemapPic(arr1, arr2, 0, False, GDVars.iconAnimation[orderNumber, 0]);
      Blit.RemapPic(arr1, arr2, 0, False, GDVars.iconAnimation[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
  GameIo.DrainKeys;
end;

procedure DeleteCharacterFiles(cr: Types.PWork);
var
  tmpName: String[80];
  { Unused in this version; see the other implementations of this routine. }
  fullPath: array[0..127] of Byte;
begin
  tmpName := GDVars.saveDir + DaxIo.SanitizeFileName(cr^.name);
  DaxIo.DeleteIfPresent(tmpName + '.guy');
  DaxIo.DeleteIfPresent(tmpName + '.swg');
  DaxIo.DeleteIfPresent(tmpName + '.fx');
end;

procedure SaveChar(cr: Types.PCharRecord; fname: TStr8);
var
  f: file;
  { target file name }
  fn: Types.TStr40;
  { '.guy'/'.sav' }
  ext: String[4];
  { retry/overwrite selector 'O'/'N' }
  flag: Char;
  { item walker }
  it: Types.PItemRec;
  { effect walker }
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  list: array[0..23] of Byte;
  { DosError }
  err: Integer;
  { size on disk }
  total: Word;
  { MenuHorizontal's extended-key flag }
  redraw: Boolean;
begin
  GDVars.characterImportMode := 0;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    total := 0;
    Inc(total, SizeOf(Types.TWork));
    if Types.PWork(cr)^.itemsAddr <> nil then begin
      it := Types.PWork(cr)^.itemsAddr;
      while it <> nil do begin
        Inc(total, SizeOf(Types.TItemRec));
        it := it^.next;
      end;
    end;
    if Types.PWork(cr)^.effects <> nil then begin
      eff := Types.PWork(cr)^.effects;
      while eff <> nil do begin
        Inc(total, SizeOf(Types.TEffectRec));
        eff := eff^.next;
      end;
    end;
    flag := 'O';
    if total > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
      TextRend.DisplayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
      flag := MenuCore.MenuHorizontal('Lose character? ', 'Ok  Try another disk', LightMagenta, LightGreen, White,
                                      False, False, redraw);
    end;
  until flag = 'O';
  if Length(fname) = 0 then begin
    ext := '.guy';
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(cr^.name, '.'));
  end else begin
    ext := '.sav';
    fn := fname;
  end;
  repeat
    Assign(f, GDVars.saveDir + fn + ext);
    Reset(f, 1);
    err := DosError;
    if not (err in [0, 2]) then
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, Black, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until (err = 0) or (err = 2);
  Close(f);
  flag := 'N';
  while (flag = 'N') and (Length(fname) = 0)
        and DaxIo.FileExists(GDVars.saveDir + fn + ext) do begin
    flag := MenuCore.YesNoMenu('Overwrite ' + fn + '? ', Yellow, LightGreen, White);
    if flag = 'N' then begin
      fn := '';
      while Length(fn) = 0 do
        fn := TextRend.ReadString('New file name: ', LightGreen, Black, 8);
    end;
  end;
  Assign(f, GDVars.saveDir + fn + ext);
  Rewrite(f, 1);
  BlockWrite(f, cr^, SizeOf(Types.TWork));
  Close(f);
  DaxIo.DeleteIfPresent(GDVars.saveDir + fn + '.swg');
  if Types.PWork(cr)^.itemsAddr <> nil then begin
    Assign(f, GDVars.saveDir + fn + '.swg');
    Rewrite(f, 1);
    it := Types.PWork(cr)^.itemsAddr;
    while it <> nil do begin
      BlockWrite(f, it^, SizeOf(it^));
      it := it^.next;
    end;
    Close(f);
  end;
  DaxIo.DeleteIfPresent(GDVars.saveDir + fn + '.fx');
  if Types.PWork(cr)^.effects <> nil then begin
    Assign(f, GDVars.saveDir + fn + '.fx');
    Rewrite(f, 1);
    eff := Types.PWork(cr)^.effects;
    while eff <> nil do begin
      BlockWrite(f, eff^, SizeOf(eff^));
      eff := eff^.next;
    end;
    Close(f);
  end;
end;

procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);
var
  f: file;
  res: Word;
  tail: Types.PItemRec;
  itemBuf: Pointer;
  effTail: Types.PEffectRec;
  effBuf: Pointer;
  msg: String[40];
  ok: Byte;
  { mode 1's saved record }
  savedBuf: Types.PCharRecord;
  { mode 2's imported record }
  hillsfarRec: PHillsfarRec;
  i: ShortInt;
  curCharBak: Types.PWork;
  baseName: String[255];
  name15: String[15];
  ext: String[4];
  { Unused in this version; see the other implementations of this routine. }
  retry: Byte;

  {$F+}
  { Tells whether the save directory holds an ext file whose stored name is name15. }
  function SavedNameExists: Boolean;
  var
    sr: SearchRec;
    fname: String[15];
    f: file;
  begin
    fname := '';
    FindFirst(GDVars.saveDir + '*' + ext, 0, sr);
    while (DosError = 0) and (fname <> name15) do begin
      ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + sr.Name, msg, #0, f));
      Seek(f, 0);
      BlockRead(f, fname, SizeOf(fname), res);
      Close(f);
      FindNext(sr);
    end;
    SavedNameExists := fname = name15;
  end;

  { Converts the Pool record in savedBuf into cr, keeping the ability scores within the race's limits. }
  procedure ConvertPoolRecord;
  var
    i: ShortInt;
    j: ShortInt;
  begin
    with Types.PWork(cr)^ do begin
      slRace := savedBuf^.race;
      slGender := savedBuf^.gender;
      name := savedBuf^.name;
      for i := 0 to 5 do begin
        slStats[i].permanent := savedBuf^.abilities[i];
        case i of
          0: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].strMin[ShortInt(slGender)] then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].strMin[ShortInt(slGender)];
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].strMax[ShortInt(slGender)] then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].strMax[ShortInt(slGender)];
             end;
          1: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].intMin then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].intMin;
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].intMax then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].intMax;
             end;
          2: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].wisMin then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].wisMin;
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].wisMax then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].wisMax;
             end;
          3: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].dexMin then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].dexMin;
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].dexMax then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].dexMax;
             end;
          4: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].conMin then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].conMin;
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].conMax then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].conMax;
             end;
          5: begin
               if slStats[i].permanent < GDConsts.raceLim[ShortInt(slRace)].chaMin then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].chaMin;
               if slStats[i].permanent > GDConsts.raceLim[ShortInt(slRace)].chaMax then
                 slStats[i].permanent := GDConsts.raceLim[ShortInt(slRace)].chaMax;
             end;
        end;
        slStats[i].current := slStats[i].permanent;
      end;
      slStats[6].permanent := savedBuf^.strExc;
      if GDConsts.raceLim[ShortInt(slRace)].exStrMax[ShortInt(slGender)] > slStats[C_Stat.STRENGTH].permanent then
        slStats[C_Stat.STRENGTH].permanent := GDConsts.raceLim[ShortInt(slRace)].exStrMax[ShortInt(slGender)];
      slStats[6].current := savedBuf^.strExc;
      thac0Base := savedBuf^.thac0Base;
      slCharClass := savedBuf^.charClass;
      age := savedBuf^.age;
      hpMax := savedBuf^.hpMax;
      Move(savedBuf^.spellsKnown, slSpellsKnown, SizeOf(savedBuf^.spellsKnown));
      knowsAnimateDead := 0;
      attackLevel := savedBuf^.attackLevel;
      iconDimensions := savedBuf^.iconDimensions;
      Move(savedBuf^.saves, saves, SizeOf(savedBuf^.saves));
      moveRate := savedBuf^.movementBase;
      slLevelHighest := savedBuf^.levelHighest;
      levelAtChange := slLevelHighest;
      drainedLevels := savedBuf^.drainedLevels;
      drainedHps := savedBuf^.drainedHps;
      slLevelUndead := savedBuf^.levelUndead;
      Move(savedBuf^.thiefSkills, slThiefSkills, SizeOf(savedBuf^.thiefSkills));
      afterEffects := savedBuf^.afterEffects;
      npc := savedBuf^.npc;
      modified := savedBuf^.modified;
      afterModified := savedBuf^.afterModified;
      beforeCoins := savedBuf^.beforeCoins;
      platinum := 300;
      Move(savedBuf^.classLevels, slClericLevel, SizeOf(savedBuf^.classLevels));
      charType := savedBuf^.charType;
      slAlignment := savedBuf^.alignment;
      Move(savedBuf^.attacks, attacks, 2);
      Move(savedBuf^.unarmedRollsA, slBaseRolls, SizeOf(savedBuf^.unarmedRollsA));
      Move(savedBuf^.unarmedDiceA, slBaseDice, SizeOf(savedBuf^.unarmedDiceA));
      Move(savedBuf^.unarmedModA, baseMod, SizeOf(savedBuf^.unarmedModA));
      acBase := savedBuf^.acBase;
      useStrength := savedBuf^.useStrength;
      randomId := savedBuf^.randomId;
      experience := savedBuf^.experience;
      classMask := savedBuf^.itemLimits;
      hpRolled := savedBuf^.hpRolled;
      for j := 1 to 3 do begin
        clericSlots[j] := savedBuf^.clericSpells[j];
        mageSlots[j] := savedBuf^.mageSpells[j];
      end;
      xpAward := savedBuf^.xpAward;
      xpBonusPerHp := savedBuf^.xpBonusPerHp;
      portraitHead := savedBuf^.portraitHead;
      portraitBody := savedBuf^.portraitBody;
      iconHead := savedBuf^.iconHead;
      iconBody := savedBuf^.iconBody;
      iconSizeColors[0] := savedBuf^.iconSize;
      iconColors := savedBuf^.iconColors;
      numberOfItems := savedBuf^.numberOfItems;
      Move(savedBuf^.equipped, slEquipped, SizeOf(savedBuf^.equipped));
      handsEquipped := savedBuf^.handsEquipped;
      slSaveBonus := savedBuf^.saveBonus;
      encumbrance := savedBuf^.encumbrance;
      status := savedBuf^.status;
      enabled := savedBuf^.enabled;
      slHostile := savedBuf^.hostile;
      thac0Cur := savedBuf^.thac0Cur;
      Move(savedBuf^.acCur, slAcCur, 2);
      Move(savedBuf^.curAttacks, curAttacks, 2);
      Move(savedBuf^.curRollsA, slCurRolls, SizeOf(savedBuf^.curRollsA));
      Move(savedBuf^.curDiceA, slCurDice, SizeOf(savedBuf^.curDiceA));
      Move(savedBuf^.curModA, slCurMod, SizeOf(savedBuf^.curModA));
      hpCur := savedBuf^.hpCur;
      movementCur := savedBuf^.movementCur;
    end;
  end;

  { Raise cr toward the imported hillsfarRec, train it, and set its level and HP fields. }
  procedure MergeHillsfarRecord;
  var
    i: ShortInt;
    { Unused in this version; see the other implementations of this routine. }
    classIndex: Byte;
    j: ShortInt;
  begin
    with Types.PWork(cr)^ do begin
      if slStats[C_Stat.STRENGTH].permanent < hillsfarRec^.strength then begin
        slStats[C_Stat.STRENGTH].permanent := hillsfarRec^.strength;
        slStats[C_Stat.STRENGTH].current := hillsfarRec^.strength;
      end;
      if slStats[6].permanent < hillsfarRec^.strExc then begin
        slStats[6].permanent := hillsfarRec^.strExc;
        slStats[6].current := hillsfarRec^.strExc;
      end;
      for i := 1 to 5 do
        if slStats[i].permanent < hillsfarRec^.otherAbilities[$15 + i] then begin
          slStats[i].permanent := hillsfarRec^.otherAbilities[$15 + i];
          slStats[i].current := slStats[i].permanent;
        end;
      if experience < hillsfarRec^.experience then
        experience := hillsfarRec^.experience;
      if ViewChar.CreatureCoinValueInGold(Pointer(cr)) < hillsfarRec^.gold then begin
        for j := 0 to 4 do
          Money.dropMoney(Types.PWork(cr), Types.PWork(cr)^.coinsA[j], j);
        Money.givePlatinum(hillsfarRec^.gold div 5);
      end;
      if Types.PWork(cr)^.age < hillsfarRec^.age then
        Types.PWork(cr)^.age := hillsfarRec^.age;
      slClericLevel := Byte(hillsfarRec^.isCleric > 0);
      slMageLevel := Byte(hillsfarRec^.isMage > 0);
      slFighterLevel := Byte(hillsfarRec^.isFighter > 0);
      slThiefLevel := Byte(hillsfarRec^.isThief > 0);
      slLevelHighest := 1;
      if hillsfarRec^.setsScriptFlag <> 0 then
        scriptFlag := 1;
      GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] := 255;
      GDVars.characterMenuDone := 0;
      GDVars.isAutoTraining := True;
      repeat
        CharGen.TrainingMenu;
      until GDVars.characterMenuDone <> 0;
      GDVars.isAutoTraining := False;
      GDVars.curChar := curCharBak;
      hpMax := hillsfarRec^.hpMax;
      hpRolled := hpMax - CharGen.ConHpBonus(Types.PWork(cr));
      hpCur := hillsfarRec^.hpCur;
    end;
  end;

begin
  if askDisk then begin
    msg := 'Put save disk in ';
    GDVars.promptDrive := GDVars.saveDir[1];
  end else
    msg := GDConsts.insertDiskDrive[GDVars.virtualDiskNumber];
  ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + name, msg, #0, f));
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Loading...Please Wait');
  FillChar(cr^, SizeOf(Types.TWork), 0);
  case GDVars.characterImportMode of
    0: begin
         BlockRead(f, cr^, SizeOf(Types.TWork), res);
         Close(f);
         Types.PWork(cr)^.itemsAddr := nil;
         Types.PWork(cr)^.effects := nil;
         Types.PWork(cr)^.combatAddr := nil;
         Types.PWork(cr)^.next := nil;
       end;
    1: begin
         GetMem(savedBuf, SizeOf(Types.TCharRecord));
         BlockRead(f, savedBuf^, SizeOf(Types.TCharRecord), res);
         Close(f);
         Types.PWork(cr)^.itemsAddr := nil;
         Types.PWork(cr)^.effects := nil;
         Types.PWork(cr)^.combatAddr := nil;
         Types.PWork(cr)^.next := nil;
         ConvertPoolRecord;
         FreeMem(savedBuf, SizeOf(Types.TCharRecord));
       end;
    2: begin
         GetMem(hillsfarRec, SizeOf(Types.THillsfarRec));
         BlockRead(f, hillsfarRec^, SizeOf(Types.THillsfarRec), res);
         Close(f);
         Types.PWork(cr)^.itemsAddr := nil;
         Types.PWork(cr)^.effects := nil;
         Types.PWork(cr)^.combatAddr := nil;
         Types.PWork(cr)^.next := nil;
         name15 := SaveLoad.CStrToStr(PCharArr(@hillsfarRec^.name4));
         ext := '.guy';
         ok := Byte(SavedNameExists);
         if ok <> 0 then begin
           { matched an existing .guy character }
           baseName := name;
           Delete(baseName, Pos('.', name), 4);
           ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + baseName + ext, msg, #0, f));
           BlockRead(f, cr^, SizeOf(Types.TWork), res);
           Close(f);
           Types.PWork(cr)^.itemsAddr := nil;
           Types.PWork(cr)^.effects := nil;
           Types.PWork(cr)^.combatAddr := nil;
           Types.PWork(cr)^.next := nil;
           curCharBak := GDVars.curChar;
           GDVars.curChar := Types.PWork(cr);
           MergeHillsfarRecord;
           if hillsfarRec^.chimeCharges > 0 then begin
             tail := CharHlp.MakeItem(70, 168, 167, 87, 0, 0, 0, 0, 0, 0, 0, hillsfarRec^.chimeCharges * 200,
                                      hillsfarRec^.chimeCharges, 31, 0);
             CharHlp.AddItemCopy(Types.PWork(cr), tail);
           end;
           if hillsfarRec^.wandCharges > 0 then begin
             tail := CharHlp.MakeItem(79, 206, 167, 69, 1, 0, 0, 0, 0, 1, 0, hillsfarRec^.wandCharges * 350,
                                      hillsfarRec^.wandCharges, 65, 0);
             CharHlp.AddItemCopy(Types.PWork(cr), tail);
           end;
           if hillsfarRec^.ringCharges > 0 then begin
             tail := CharHlp.MakeItem(69, 168, 167, 66, 0, 0, 0, 0, 0, 0, 0, hillsfarRec^.ringCharges * 200,
                                      hillsfarRec^.ringCharges, 31, 0);
             CharHlp.AddItemCopy(Types.PWork(cr), tail);
           end;
           if hillsfarRec^.healingPotions > 0 then begin
             tail := CharHlp.MakeItem(70, 185, 167, 64, 0, 0, 0, 0, 0, hillsfarRec^.healingPotions * 10, 0,
                                      hillsfarRec^.healingPotions * 400, hillsfarRec^.healingPotions, 62, 0);
             CharHlp.AddItemCopy(Types.PWork(cr), tail);
           end;
         end else begin
           name15 := SaveLoad.CStrToStr(PCharArr(@hillsfarRec^.name4));
           ext := '.cha';
           ok := Byte(SavedNameExists);
           if ok <> 0 then begin
             { matched an existing .cha character }
             GetMem(savedBuf, SizeOf(Types.TCharRecord));
             baseName := name;
             Delete(baseName, Pos('.', name), 4);
             ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + baseName + ext, msg, #0, f));
             BlockRead(f, savedBuf^, SizeOf(Types.TCharRecord), res);
             Close(f);
             ConvertPoolRecord;
             FreeMem(savedBuf, SizeOf(Types.TCharRecord));
             curCharBak := GDVars.curChar;
             GDVars.curChar := Types.PWork(cr);
             MergeHillsfarRecord;
           end else begin
             { import the character inline }
             curCharBak := GDVars.curChar;
             GDVars.curChar := Types.PWork(cr);
             with Types.PWork(cr)^ do begin
               for GDVars.sharedLoopIndex := 1 to 6 do
                 iconSizeColors[GDVars.sharedLoopIndex] := GDConsts.defIconCol[GDVars.sharedLoopIndex] +
                   ((GDConsts.defIconCol[GDVars.sharedLoopIndex] + 8) * 16);
               acBase := 50;
               thac0Base := 40;
               status := C_Status.OKAY;
               enabled := 1;
               portraitHead := 1;
               portraitBody := 1;
               iconDimensions := 1;
               randomId := Random(256);
               orderNumber := 10;
               attacks := 2;
               slBaseRolls := 1;
               slBaseDice := 2;
               useStrength := 1;
               moveRate := 12;
               name := SaveLoad.CStrToStr(PCharArr(@hillsfarRec^.name4));
               slStats[C_Stat.STRENGTH].permanent := hillsfarRec^.strength;
               slStats[C_Stat.STRENGTH].current := hillsfarRec^.strength;
               slStats[6].permanent := hillsfarRec^.strExc;
               slStats[6].current := hillsfarRec^.strExc;
               for i := 1 to 5 do begin
                 slStats[i].permanent := hillsfarRec^.otherAbilities[$15 + i];
                 slStats[i].current := slStats[i].permanent;
               end;
               slRace := hillsfarRec^.race + 1;
               if slRace = 6 then
                 slRace := C_Race.HUMAN;
               case slRace of
                 C_Race.HALFLING: begin
                      iconSizeColors[0] := 1;
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                    end;
                 C_Race.DWARF: begin
                      iconSizeColors[0] := 1;
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.DWARF_THAC0, 0, 255, False);
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.DWARF_ARMOR_CLASS_VS_GIANTS, 0, 255, False);
                    end;
                 C_Race.GNOME: begin
                      iconSizeColors[0] := 1;
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.GNOME_THAC0, 0, 255, False);
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.DWARF_ARMOR_CLASS_VS_GIANTS, 0, 255, False);
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.GNOME_ARMOR_CLASS_BONUS, 0, 255, False);
                    end;
                 C_Race.ELF: begin
                      iconSizeColors[0] := 2;
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.ELF_RESISTANCE, 0, 255, False);
                    end;
                 C_Race.HALF_ELF: begin
                      iconSizeColors[0] := 2;
                      FxEngine.AddEffect(Types.PWork(cr), C_Effect.HALF_ELF_RESISTANCE, 0, 255, False);
                    end;
               else
                 iconSizeColors[0] := 2;
               end;
               slCharClass := GDConsts.importClassIds[hillsfarRec^.classCode and $F];
               age := hillsfarRec^.age;
               slClericLevel := Byte(hillsfarRec^.isCleric > 0);
               slMageLevel := Byte(hillsfarRec^.isMage > 0);
               slFighterLevel := Byte(hillsfarRec^.isFighter > 0);
               slThiefLevel := Byte(hillsfarRec^.isThief > 0);
               slLevelHighest := 1;
               slGender := hillsfarRec^.gender;
               slAlignment := hillsfarRec^.alignment;
               experience := hillsfarRec^.experience;
               if slMageLevel > 0 then begin
                 knowsDetectMagic := 1;
                 knowsReadMagic := 1;
                 knowsShield := 1;
                 knowsSleep := 1;
               end;
               GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] := 255;
               GDVars.characterMenuDone := 0;
               GDVars.isAutoTraining := True;
               repeat
                 CharGen.TrainingMenu;
               until GDVars.characterMenuDone <> 0;
               GDVars.isAutoTraining := False;
               Money.givePlatinum(300);
               GDVars.curChar := curCharBak;
               hpMax := hillsfarRec^.hpMax;
               hpRolled := hpMax - CharGen.ConHpBonus(Types.PWork(cr));
               hpCur := hillsfarRec^.hpCur;
             end;
           end;
         end;
         FreeMem(hillsfarRec, SizeOf(Types.THillsfarRec));
       end;
  end;
  if GDVars.characterImportMode = 0 then
    Delete(name, Pos('.', name), 4)
  else
    name := DaxIo.SanitizeFileName(cr^.name);
  if DaxIo.FileExists(GDVars.saveDir + name + '.swg') then begin
    GetMem(itemBuf, SizeOf(Types.TItemRec));
    ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + name + '.swg', msg, #0, f));
    repeat
      BlockRead(f, itemBuf^, SizeOf(Types.TItemRec), res);
      if res = SizeOf(Types.TItemRec) then begin
        if Types.PWork(cr)^.itemsAddr = nil then begin
          GetMem(Types.PWork(cr)^.itemsAddr, SizeOf(Types.TItemRec));
          tail := Types.PWork(cr)^.itemsAddr;
        end else begin
          GetMem(tail^.next, SizeOf(Types.TItemRec));
          tail := tail^.next;
        end;
        tail^ := Types.PItemRec(itemBuf)^;
        tail^.next := nil;
      end;
    until res <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(itemBuf, SizeOf(Types.TItemRec));
  end;
  if DaxIo.FileExists(GDVars.saveDir + name + '.fx') then begin
    GetMem(effBuf, SizeOf(Types.TEffectRec));
    ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + name + '.fx', msg, #0, f));
    repeat
      BlockRead(f, effBuf^, SizeOf(Types.TEffectRec), res);
      if res = SizeOf(Types.TEffectRec) then begin
        if Types.PWork(cr)^.effects = nil then begin
          GetMem(Types.PWork(cr)^.effects, SizeOf(Types.TEffectRec));
          effTail := Types.PWork(cr)^.effects;
        end else begin
          GetMem(effTail^.next, SizeOf(Types.TEffectRec));
          effTail := effTail^.next;
        end;
        effTail^ := Types.PEffectRec(effBuf)^;
        effTail^.next := nil;
      end;
    until res <> SizeOf(Types.TEffectRec);
    Close(f);
    FreeMem(effBuf, SizeOf(Types.TEffectRec));
  end;
  if GDVars.characterImportMode = 1 then
    if DaxIo.FileExists(GDVars.saveDir + name + '.spc') then begin
      GetMem(effBuf, SizeOf(Types.TEffectRec));
      ok := Byte(DaxIo.OpenWithRetry(GDVars.saveDir + name + '.spc', msg, #0, f));
      repeat
        BlockRead(f, effBuf^, SizeOf(Types.TEffectRec), res);
        if res = SizeOf(Types.TEffectRec) then
          if Types.PEffectRec(effBuf)^.id in [18, 26, 47, 48, 97, 107, 124] then begin
            if Types.PWork(cr)^.effects = nil then begin
              GetMem(Types.PWork(cr)^.effects, SizeOf(Types.TEffectRec));
              effTail := Types.PWork(cr)^.effects;
            end else begin
              GetMem(effTail^.next, SizeOf(Types.TEffectRec));
              effTail := effTail^.next;
            end;
            effTail^ := Types.PEffectRec(effBuf)^;
            effTail^.next := nil;
          end;
      until res <> SizeOf(Types.TEffectRec);
      Close(f);
      FreeMem(effBuf, SizeOf(Types.TEffectRec));
    end;
  GameIo.DrainKeys;
  CharHlp.RecalcStats(Types.PWork(cr));
  ClassCal.RecalcClassStats(Types.PWork(cr));
  GDVars.promptDrive := GDVars.disk3Dir[1];
end;

procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);
var
  size: Word;
  data: Types.PBytes;
  readOfs: Word;
  it: Types.PItemRec;
  eff: Types.PEffectRec;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  roll: array[0..1] of Byte;
begin
  Str(GDVars.virtualDiskNumber, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size = 0 then begin
    TextRend.DisplayAndPause(White, Black, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(data^, cr^, SizeOf(Types.TWork));
  with Types.PWork(cr)^ do begin
    itemsAddr := nil;
    effects := nil;
    next := nil;
    combatAddr := nil;
  end;
  FreeMem(data, size);
  GDVars.suppressingInsertDiskFlag := 1;

  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    readOfs := 0;
    GetMem(Types.PWork(cr)^.effects, SizeOf(Types.TEffectRec));
    eff := Types.PWork(cr)^.effects;
    repeat
      Move(data^[readOfs], eff^, SizeOf(eff^));
      eff^.next := nil;
      Inc(readOfs, SizeOf(Types.TEffectRec));
      if readOfs < size then begin
        GetMem(eff^.next, SizeOf(Types.TEffectRec));
        eff := eff^.next;
      end;
    until readOfs >= size;
    FreeMem(data, size);
  end;

  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    readOfs := 0;
    GetMem(Types.PWork(cr)^.itemsAddr, SizeOf(Types.TItemRec));
    it := Types.PWork(cr)^.itemsAddr;
    repeat
      Move(data^[readOfs], it^, SizeOf(it^));
      it^.next := nil;
      Inc(readOfs, SizeOf(Types.TItemRec));
      if readOfs < size then begin
        GetMem(it^.next, SizeOf(Types.TItemRec));
        it := it^.next;
      end;
    until readOfs >= size;
    FreeMem(data, size);
  end;

  GDVars.suppressingInsertDiskFlag := 0;
  GameIo.DrainKeys;
end;

procedure AddCreatureToParty(id: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  cr: Types.PWork;
begin
  if GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] > 7 then Exit;
  GetMem(cr, SizeOf(Types.TWork));
  SaveLoad.LoadCreatureData(id, Types.PCharRecord(cr));
  cr^.randomId := id;
  SaveLoad.AddCharToParty(Types.PCharRecord(cr));
  MapTiles.LoadIconAnim('CPIC', id, cr^.orderNumber);
end;

procedure AddCharToParty(cr: Types.PCharRecord);
var
  p: Types.PWork;
  used: array[0..7] of Byte;
begin
  Types.PWork(cr)^.orderNumber := 255;
  if GDVars.creatureList = nil then
    GDVars.creatureList := Types.PWork(cr)
  else begin
    p := GDVars.creatureList;
    while p^.next <> nil do
      p := p^.next;
    p^.next := Types.PWork(cr);
  end;
  GDVars.curChar := Types.PWork(cr);
  FillChar(used, SizeOf(used), 0);
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..7] then
      used[p^.orderNumber] := 1;
    p := p^.next;
  end;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]);
  if Types.PWork(cr)^.npc > C_Npc.MORALE_MASK then
    ClassCal.RecalcClassStats(Types.PWork(cr));
end;

{ Make the selected save slot's vault file active. If the slot has no vault, remove the stale active vault instead.
  @param(src The vault file copied.)
  @param(dst The vault file written.) }
procedure SyncVault(src, dst: String);
var
  { Unused in this version; see the other implementations of this routine. }
  status: array[0..1] of Byte;
  inFile: file;
  outFile: file;
  got: Word;
  put: Word;
  buf: array[0..2047] of Byte;
begin
  if not DaxIo.FileExists(src) then
    DaxIo.DeleteIfPresent(dst)
  else begin
    Assign(inFile, src);
    Reset(inFile, 1);
    Assign(outFile, dst);
    Rewrite(outFile, 1);
    repeat
      BlockRead(inFile, buf, SizeOf(buf), got);
      BlockWrite(outFile, buf, got, put);
    until (got = 0) or (put <> got);
    Close(inFile);
    Close(outFile);
  end;
end;

procedure LoadGame;
var
  { party-member names (block-read) }
  names: array[1..8] of String[40];
  f: file;
  i: Byte;
  { GetMem'd, then list walker }
  cr: Types.PWork;
  sanName: String[40];
  { BlockRead result }
  res: Word;
  { party count from file }
  partyRead: Byte;
  { Unused in this version; see the other implementations of this routine. }
  openRes: Boolean;
  { menu letter }
  ch: Char;
  { MenuHorizontal's extended-key flag, never read }
  ext: Boolean;
  { accumulated letter list }
  menu: String[20];
begin
  GDVars.characterImportMode := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  menu := '';
  for ch := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.saveDir + 'savgam' + ch + '.dat') then
      menu := menu + ch + ' ';
  if Length(menu) = 0 then Exit;
  Delete(menu, Length(menu), 1);
  repeat
    ch := MenuCore.MenuHorizontal('Load Which Game: ', menu, LightMagenta, LightGreen, White, False, False, ext);
  until ((ch in ['A'..'J']) and DaxIo.FileExists(GDVars.saveDir + 'savgam' + ch + '.dat')) or (ch = C_Keys.NONE);
  if ch = C_Keys.NONE then Exit;
  openRes := DaxIo.OpenWithRetry(GDVars.saveDir + 'savgam' + ch + '.dat', 'Put save disk in ' + GDVars.saveDir, #1, f);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Loading...Please Wait');
  GDVars.loadedSavedGameFlag := 1;
  BlockRead(f, GDVars.virtualDiskNumber, SizeOf(GDVars.virtualDiskNumber), res);
  BlockRead(f, GDVars.gbvmZone0Ptr^, SizeOf(Types.TZone0), res);
  BlockRead(f, GDVars.gbvmZone1Ptr^, SizeOf(Types.TZone1), res);
  BlockRead(f, GDVars.gbvmZone2Ptr^, SizeOf(Types.TZone2), res);
  BlockRead(f, GDVars.gbvmScriptPtr^, SizeOf(Types.TZone3), res);
  BlockRead(f, GDVars.partyPos, SizeOf(GDVars.partyPos), res);
  BlockRead(f, GDVars.savedInterfaceState, SizeOf(GDVars.savedInterfaceState), res);
  BlockRead(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState), res);
  for i := 1 to 3 do begin
    BlockRead(f, GDVars.wallSetCache[i].wallDefId, SizeOf(GDVars.wallSetCache[i].wallDefId), res);
    BlockRead(f, GDVars.wallSetCache[i].symbolSlot, SizeOf(GDVars.wallSetCache[i].symbolSlot), res);
  end;
  BlockRead(f, partyRead, SizeOf(partyRead), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  SaveLoad.SyncVault(GDVars.saveDir + 'vault.' + ch, GDVars.saveDir + 'vault.dat');
  GDVars.monsterPicturesFlag := GDVars.gbvmZone0Ptr^[SaveLoad.PICTURE_FLAGS] shr 1;
  GDVars.portraitsFlag := GDVars.gbvmZone0Ptr^[SaveLoad.PICTURE_FLAGS] and 1;
  GDVars.gameDelay := slZone2^.gameDelay;
  GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] := 0;
  for i := 1 to partyRead do begin
    sanName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(names[i], '.'));
    if DaxIo.FileExists(GDVars.saveDir + sanName + '.sav') then begin
      GetMem(cr, SizeOf(Types.TWork));
      SaveLoad.LoadChar(sanName + '.sav', Types.PCharRecord(cr), True, True);
      SaveLoad.AddCharToParty(Types.PCharRecord(cr));
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  cr := GDVars.creatureList;
  while cr <> nil do begin
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.next;
  end;
  GDVars.curChar := GDVars.creatureList;
  while GDVars.curChar <> nil do begin
    if GDVars.curChar^.npc < C_Npc.NON_PLAYER then
      SaveLoad.LoadCharIconAnim(True)
    else begin
      GDVars.suppressingInsertDiskFlag := 1;
      MapTiles.LoadIconAnim('CPIC', GDVars.curChar^.randomId, GDVars.curChar^.orderNumber);
      GDVars.suppressingInsertDiskFlag := 0;
    end;
    GDVars.curChar := GDVars.curChar^.next;
  end;
  GDVars.curChar := GDVars.creatureList;
  GDVars.virtualDiskNumber := slZone1^.diskNumber;
  if GDVars.interfaceState <> C_Ifc.MAIN_MENU then begin
    if GDVars.wallSetCache[1].wallDefId > 0 then
      View3D.Load3DMap(slZone2^.mapId);
    for i := 1 to 3 do
      if GDVars.wallSetCache[i].wallDefId > 0 then
        View3D.LoadWallSet
          (GDVars.wallSetCache[i].wallDefId, GDVars.wallSetCache[i].symbolSlot);
  end;
  GameIo.DrainKeys;
  MenuCore.ClearBottomLine;
  GDVars.savedInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
end;

procedure SaveGame;

  { Returns the bytes the members' files need: a record each plus its items and effects. }
  function ComputePartySaveSize: Word;
  var
    cr: Types.PWork;
    it: Types.PItemRec;
    eff: Types.PEffectRec;
    total: Word;
  begin
    total := 0;
    cr := GDVars.creatureList;
    while cr <> nil do begin
      Inc(total, SizeOf(Types.TWork));
      if cr^.itemsAddr <> nil then begin
        it := cr^.itemsAddr;
        while it <> nil do begin
          Inc(total, SizeOf(Types.TItemRec));
          it := it^.next;
        end;
      end;
      if cr^.effects <> nil then begin
        eff := cr^.effects;
        while eff <> nil do begin
          Inc(total, SizeOf(Types.TEffectRec));
          eff := eff^.next;
        end;
      end;
      cr := cr^.next;
    end;
    ComputePartySaveSize := total;
  end;

var
  { per-member CHRDAT filenames }
  charNames: array[1..8] of Types.TStr40;
  f: file;
  { party index / member count }
  i: Byte;
  { creatureList walker }
  cr: Types.PWork;
  { Str(i) }
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  fileName: String[40];
  { MenuHorizontal var ext }
  sel: Boolean;
  { chosen slot letter (or #0) }
  choice: Char;
  { DosError }
  err: Integer;
  { required disk bytes }
  needed: Word;
begin
  repeat
    choice := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta, LightGreen, White,
                                      False, GDVars.interfaceState = C_Ifc.CAMPING, sel);
  until choice in [C_Keys.NONE, 'A'..'J'];
  if choice = C_Keys.NONE then Exit;
  GDVars.characterImportMode := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(GDVars.saveDir + 'savgam' + choice + '.dat') then
    needed := 0
  else
    { the blocks a new savgam file starts with: the disk number, the GBVM zones, the map position and the interface
      states. Note: SSI leaves out the blocks that follow them, the three saved positions, the member count and the
      CHRDAT names, so the estimate falls short of the file by their size. }
    needed := SizeOf(GDVars.virtualDiskNumber) + SizeOf(Types.TZone0) + SizeOf(Types.TZone1) + SizeOf(Types.TZone2) +
      SizeOf(Types.TZone3) + SizeOf(GDVars.partyPos) + SizeOf(GDVars.savedInterfaceState) +
      SizeOf(GDVars.interfaceState);
  Inc(needed, ComputePartySaveSize);
  if needed > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
    TextRend.DisplayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
    Exit;
  end;
  repeat
    Assign(f, GDVars.saveDir + 'savgam' + choice + '.dat');
    Rewrite(f, 1);
    err := DosError;
    if not (err in [0, 2, 18]) then
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, Black, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until err in [0, 2, 18];
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Saving...Please Wait');
  GDVars.gbvmZone0Ptr^[SaveLoad.GAME_SPEED] := GDVars.gameDelay;
  GDVars.gbvmZone0Ptr^[SaveLoad.PICTURE_FLAGS] := GDVars.monsterPicturesFlag * 2 + GDVars.portraitsFlag;
  GDVars.gbvmZone1Ptr^[SaveLoad.DISK_NUMBER] := GDVars.virtualDiskNumber;
  BlockWrite(f, GDVars.virtualDiskNumber, SizeOf(GDVars.virtualDiskNumber));
  BlockWrite(f, GDVars.gbvmZone0Ptr^, SizeOf(Types.TZone0));
  BlockWrite(f, GDVars.gbvmZone1Ptr^, SizeOf(Types.TZone1));
  BlockWrite(f, GDVars.gbvmZone2Ptr^, SizeOf(Types.TZone2));
  BlockWrite(f, GDVars.gbvmScriptPtr^, SizeOf(Types.TZone3));
  BlockWrite(f, GDVars.partyPos, SizeOf(GDVars.partyPos));
  BlockWrite(f, GDVars.savedInterfaceState, SizeOf(GDVars.savedInterfaceState));
  BlockWrite(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState));
  for i := 1 to 3 do begin
    BlockWrite(f, GDVars.wallSetCache[i].wallDefId, SizeOf(GDVars.wallSetCache[i].wallDefId));
    BlockWrite(f, GDVars.wallSetCache[i].symbolSlot, SizeOf(GDVars.wallSetCache[i].symbolSlot));
  end;
  i := 0;
  cr := GDVars.creatureList;
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    charNames[i] := 'CHRDAT' + choice + numStr;
    cr := cr^.next;
  end;
  BlockWrite(f, i, SizeOf(i));
  BlockWrite(f, charNames[1], SizeOf(charNames));
  Close(f);
  cr := GDVars.creatureList;
  i := 0;
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    SaveLoad.SaveChar(Types.PCharRecord(cr), 'CHRDAT' + choice + numStr);
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.next;
  end;
  GDVars.recentlySavedGameFlag := 1;
  SaveLoad.SyncVault(GDVars.saveDir + 'vault.dat', GDVars.saveDir + 'vault.' + choice);
  MenuCore.ClearBottomLine;
end;

begin
end.
