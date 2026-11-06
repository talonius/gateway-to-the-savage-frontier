{ The ECL virtual machine's support routines. LoadEclVars decodes an instruction's operands at the ECL instruction
  pointer into GDVars.varTypes, varHi and varLo (unpacking the 6-bit strings into GDVars.gbStrings) and GetEclVar gives
  an operand's value. ReadGbvm, WriteGbvm and WriteGbvmString address GBVM memory: GbvmZone sorts an address into one of
  the four banks behind GDVars' bank pointers, whose arrays are declared at the banks' own GBVM addresses, or zone 4,
  the registers and party cells the routines map by hand; zone 1 reads and writes some cells through the current
  character's work record (SpecialReadZ1, SpecialWriteZ1). The rest serve single ECL commands: the script's loading and
  entry addresses, the encounter's pictures, the menus, COMPARE, GOSUB, the mirror duel, robbery and damage. gbClassMap
  is in GDConsts. }
{$O+,F+,S+}
{$A+}
unit EclMenu;

interface

uses Types, C_Status, C_Effect, C_Dir, C_Gbvm, C_Ifc, C_Msg, C_Npc, C_Pic, TextRend, MapTiles, SaveLoad, ViewChar,
  CharHlp, MenuCore, DaxIo, View3D, MapView, ClassCal, FxEngine, Crt, GDConsts, GDVars, C_Keys, Portrait;

{ Reads the value of a loaded script argument: type 0 is an immediate byte, types 1, 3 and $80 read the GBVM word at the
  argument's address, and types 2 and $81 are an immediate word. Other types leave the result undefined.
  @param(idx The argument, from 1.)
  @returns(The argument's value.) }
function GetEclVar(idx: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Start a loaded script: clear the GOSUB stack and the encounter state, read its five entry addresses, and, unless a
  saved game was loaded, clear the script's own cells. }
procedure EclInit;

{ Loads a script block from ECL<disk>.DAX into the cleared script zone, skipping its 2-byte header, and keeps retrying
  (with disk prompts on) until the block loads.
  @param(scriptId The script's block in the file.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates and loads a monster.
  @param(id The monster's record.)
  @param(cr Receives the monster.)
  @param(inv Receives the head of its item list.)
  @param(eff Receives the head of its effect list.) }
procedure InitCreature(id: Byte; var cr: Pointer; var inv: Pointer; var eff: Pointer);

{ Works out how far ahead a monster can appear. Outside the 3D view it is 2, also stored as the zone's monster distance;
  in it, the number of open cells (at most 2) walking from the position in the facing before a wall.
  @param(x The starting column.)
  @param(y The starting row.)
  @param(facing The direction, 0, 2, 4 or 6.)
  @returns(The distance in cells, 0..2.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Records a portrait's head and body, loads them and shows them at cell (3, 3).
  @param(headId The head picture.)
  @param(bodyId The body picture.) }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Show an encounter's sprite in the 3D view and, when it stands next to the party, its close-up picture (a PIC, or the
  portrait C_Gbvm.PORTRAIT_HEAD names).
  @param(sprId The sprite, 255 for none.)
  @param(picId The close-up picture.)
  @param(dist The encounter's distance, 0 when next to the party.)
  @param(flags Which pictures are already loaded; updated.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lowByte The low byte.)
  @param(highByte The high byte.)
  @returns(The word.) }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Finds a creature's place in the creature list.
  @param(cr The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(cr: Types.PWork): Byte;

{ Store value at GBVM address vmAddr; a zone-1 cell may also change the current character.
  @param(vmAddr The GBVM address.)
  @param(value The value to store.) }
procedure WriteGbvm(vmAddr, value: Word);

{ Read a GBVM cell; some zone-1 cells come from the current character's work record (SpecialReadZ1).
  @param(vmAddr The GBVM address.)
  @returns(The value.) }
function ReadGbvm(vmAddr: Word): Word;

{ Writes a string, zero-terminated, at a GBVM address in any zone; the zone-1 base address sets the current character's
  name instead. Addresses outside the zones are ignored.
  @param(vmAddr The GBVM address.)
  @param(s The string.) }
procedure WriteGbvmString(vmAddr: Word; s: String);

{ Runs a horizontal menu with ~ hotkeys; extended keys select the previous or next character.
  @param(query The prompt.)
  @param(menu The menu, with ~ before each hotkey.)
  @param(qCol The prompt's color.)
  @param(mCol The menu's color.)
  @param(hlCol The hotkeys' color.)
  @param(enterOk True to accept Enter.)
  @param(animate True to animate the menu picture while waiting.)
  @returns(The hotkey's place from 0; 0 for Enter; 255 for a letter or digit that is not a hotkey.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk,
                                       animate: Boolean): Byte;

{ Runs a vertical list menu for a script, with ~ hotkeys in its commands; the key it returns is not kept.
  @param(query The prompt.)
  @param(menu The commands, with ~ before each hotkey.)
  @param(qCol The prompt's and the labels' color.)
  @param(mCol The entries' color.)
  @param(hlCol The highlight color.)
  @param(ulCol Left column of the box.)
  @param(ulRow Top row of the box.)
  @param(lrCol Right column of the box.)
  @param(lrRow Bottom row of the box.)
  @param(list The entries.)
  @param(addExit True to offer Exit.)
  @param(redraw True to draw the page; cleared once it is drawn.)
  @param(idx The highlighted entry, from 0.)
  @param(sel Receives the highlighted entry; nil for Exit or an empty list.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(varIdx The argument holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Sets up a duel: each creature not named as the current character is disabled. A mirror duel appends a hostile copy of
  the current character named ROLF, with the CPIC icon; its items are copied in reverse order and its effects are not.
  @param(mirror Nonzero for a mirror duel; stored in the mirror-duel script variable.) }
procedure CharFightsAlone(mirror: ShortInt);

{ Step the party one cell ahead, wrapping at the map's edges. }
procedure EclMoveForward;

{ Keep fraction of each of cr's coins.
  @param(fraction The part of each kind of coin kept.)
  @param(cr The character robbed.) }
procedure RobMoney(fraction: Real; cr: Pointer);

{ Steals each of a creature's items on a roll within the chance; an item heavier than 255 takes 90 off the chance and
  one heavier than 24 takes 50. Note: the reductions come off the chance itself, so they add up over the items.
  @param(chance The chance, in percent.)
  @param(cr The creature.) }
procedure RobItems(chance: Byte; cr: Pointer);

{ Step the instruction pointer over one instruction without running it. }
procedure SkipEclCmd;

{ Finds the party's highest and lowest movement, haste doubling and otherwise slow halving it. Both start from the first
  member's unadjusted movement, so that value always lies within them. Note: the first member is read before the check
  for nil, so an empty party is read through nil.
  @param(hiMove Receives the highest movement.)
  @param(loMove Receives the lowest movement.) }
procedure MoveExtremes(var hiMove, loMove: Byte);

{ Deals script damage to a creature with a message, then redraws the party panel; a dead creature is skipped. The
  creature dies when the damage is more than 10 above its hit points; otherwise the message gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(cr The creature.) }
procedure EclInflictDamage(dmg: Word; cr: Pointer);

implementation

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; vmAddr: Word); forward;

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.varTypes[i] := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr + 1];
    GDVars.varLo[i] := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr + 2];
    GDVars.eclScriptInstructionPtr := GDVars.eclScriptInstructionPtr + 2;
    case GDVars.varTypes[i] of
      1, 2, 3: begin
        Inc(GDVars.eclScriptInstructionPtr);
        GDVars.varHi[i] := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.varLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.eclScriptInstructionPtr);
        GDVars.varHi[i] := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr];
        v := EclMenu.CombineBytesToWord(GDVars.varLo[i], GDVars.varHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.eclScriptInstructionPtr);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.varLo[idx];
  vLo := GDVars.varHi[idx];
  case GDVars.varTypes[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  i: Word;
begin
  while GDVars.eclStack <> nil do begin
    GDVars.eclStackPrev := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(GDVars.eclStack^));
    GDVars.eclStack := GDVars.eclStackPrev;
  end;
  GDVars.eclGraphics := False;
  GDVars.protectionShown := 0;
  GDVars.statusCleared := False;
  GDVars.nameCleared := False;
  GDVars.wallColorSel := 65;
  GDVars.ceilFloorColorSel := 9;
  GDVars.picRegionW := True;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.currentIconAnimation := 8;
  { the script bank's first address }
  GDVars.eclScriptInstructionPtr := $8000;
  GDVars.breathAim := False;
  GDVars.eclStack := nil;
  GDVars.eclStackPrev := nil;
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD] := 255;
  GDVars.gbvmZone1Ptr^[C_Gbvm.REST_SAFE_TIME] := 0;
  GDVars.gbvmZone1Ptr^[C_Gbvm.REST_INTERRUPT_PERCENT] := 0;
  GDVars.gbvmZone0Ptr^[C_Gbvm.ANTI_MAGIC] := 0;
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptEntries[1] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptEntries[2] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptEntries[3] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptEntries[4] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptEntries[5] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] := 1;
  if GDVars.loadedSavedGameFlag = 0 then begin
    for i := 1 to 32 do
      { cells $4C00..$4C1F }
      GDVars.gbvmZone0Ptr^[i + $4BFF] := 0;
    for i := 0 to 9 do
      GDVars.gbvmZone1Ptr^[i + $7F79] := 0;
  end;
end;

procedure LoadEclScript(scriptId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  scriptSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  scriptOffset: Word;
  s: String[1];
  sizeRead: Word;
  data: Types.PBytes;
begin
  FillChar(GDVars.gbvmScriptPtr^, SizeOf(GDVars.gbvmScriptPtr^), 0);
  GDVars.suppressingInsertDiskFlag := 0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
    Str(GDVars.virtualDiskNumber, s);
    DaxIo.loadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  until sizeRead >= 2;
  Move(data^[2], GDVars.gbvmScriptPtr^, sizeRead - 2);
  FreeMem(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var cr: Pointer; var inv: Pointer; var eff: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
begin
  cr := nil;
  GetMem(cr, SizeOf(Types.TWork));
  SaveLoad.LoadCreatureData(id, Types.PCharRecord(cr));
  inv := Types.PWork(cr)^.itemsAddr;
  eff := Types.PWork(cr)^.effects;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then begin
    MaxMonsterDist := 2;
    GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.picDrawn := False;
  GDVars.currentPortraitHead := headId;
  GDVars.currentPortraitBody := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDist: Byte;
begin
  spriteDist := dist + 1;
  if (sprId <> 255) and not flags[1] then begin
    if not flags[0] then begin
      if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then begin
        if GDVars.automapOn then begin
          GDVars.automapOn := False;
          GDVars.mapRedrawPending := 1;
          MapView.DisplayMapView;
        end;
        Portrait.LoadAnimation('SPRIT', sprId, 1, GDVars.animationData);
        flags[0] := True;
        GDVars.sprShown := True;
      end;
    end else begin
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    if (GDVars.interfaceState = C_Ifc.EXPLORING) and (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0) then
      Portrait.Show3DSprite(spriteDist, GDVars.animationData);
  end;
  if picId = C_Pic.NO_PICTURE then Exit;
  if flags[1] then
    if GDVars.picIdShown = GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD] then
      Exit;
  if dist <> 0 then Exit;
  if GDVars.interfaceState <> C_Ifc.EXPLORING then Exit;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then Exit;
  if (GDVars.currentlyEclOpcodeFlag <> 0) and (GDVars.encounterCloseUpFlag = 0) then Exit;
  GDVars.picIdShown := Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD]);
  GDVars.eclGraphics := True;
  if GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GDVars.animationData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animationData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD]), picId);
    flags[1] := True;
    GDVars.picDrawn := False;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

{ Turns a 6-bit game character into ASCII: 0 to 31 become @ to _, higher codes stay as they are.
  @param(c The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

{ Finds the GBVM bank holding an address.
  @param(vmAddr The GBVM address.)
  @returns(0 for $4B00..$4EFF, 1 for $7C00..$7FFF, 2 for $7A00..$7BFF, 3 (the script) for $8000..$9DFF, and 4 for
    anything else.) }
function GbvmZone(vmAddr: Word): Byte;
begin
  GbvmZone := 4;
  if (vmAddr >= $4B00) and (vmAddr <= $4EFF) then GbvmZone := 0;
  if (vmAddr >= $7C00) and (vmAddr <= $7FFF) then GbvmZone := 1;
  if (vmAddr >= $7A00) and (vmAddr <= $7BFF) then GbvmZone := 2;
  if (vmAddr >= $8000) and (vmAddr <= $9DFF) then GbvmZone := 3;
end;

function FindCurCharIdx(cr: Types.PWork): Byte;
var
  idx: Byte;
  p: Types.PWork;
  found: Boolean;
begin
  p := GDVars.creatureList;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = cr then
      found := True
    else begin
      Inc(idx);
      p := p^.nextCharAddr;
    end;
  end;
  FindCurCharIdx := idx;
end;

{ The zone-1 cells read from the current character's work record, or computed; found is False for any other cell. A
  handled cell whose arm assigns nothing returns an undefined result.
  @param(vmAddr The GBVM address.)
  @param(found Cleared when the cell is not one of these.)
  @returns(The value.) }
function SpecialReadZ1(vmAddr: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  vmAddr := vmAddr - $7C00;
  case vmAddr of
    $14..$19: SpecialReadZ1 := GDVars.curChar^.fxStats[ShortInt(vmAddr + 0 - $14)].current;
    $20..$70: SpecialReadZ1 := GDVars.curChar^.memorizedSpells[vmAddr - $20];
    $72: SpecialReadZ1 := GDVars.curChar^.race;
    $73: SpecialReadZ1 := GDVars.curChar^.charClass;
    $9B: SpecialReadZ1 := GDVars.curChar^.emSecondSave;
    $A0: SpecialReadZ1 := GDVars.curChar^.terrType;
    $A5..$AC: begin
      t := vmAddr - $A4;
      SpecialReadZ1 := GDVars.curChar^.emThiefSkills[t];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB, $BD, $BF, $C1, $C3, $C5, $C7:
                SpecialReadZ1 := GDVars.curChar^.coinsA[ShortInt((vmAddr - $BB) div 2 + 0)];
    $C9..$D0: SpecialReadZ1 := ClassCal.EarlierClassActive(GDVars.curChar) *
      GDVars.curChar^.emClassB[ShortInt(GDConsts.gbClassMap[vmAddr])] +
      GDVars.curChar^.emClassA[ShortInt(GDConsts.gbClassMap[vmAddr])];
    $D6: SpecialReadZ1 := GDVars.curChar^.gender;
    $D8: SpecialReadZ1 := GDVars.curChar^.alignment;
    $E4: SpecialReadZ1 := GDVars.curChar^.emScriptFlag and 1;
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    $100: begin
      if GDVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
      if GDVars.characterNotFound = 1 then
        SpecialReadZ1 := 0;
      GDVars.characterNotFound := 0;
    end;
    $10C:
      if (GDVars.curChar^.hostile = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    $10D: ;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    { the loyalty base, by charisma }
    $2CF:
      case GDVars.curChar^.emChaCur of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.virtualDiskNumber;
    $33E: SpecialReadZ1 := GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

{ The side effects of a store to a zone-1 cell on the current character, the disk, the wall sets and the creature dumps.
  @param(vmAddr The GBVM address.)
  @param(value The value stored.) }
procedure SpecialWriteZ1(vmAddr, value: Word);
var
  t: Byte;
begin
  vmAddr := vmAddr - $7C00;
  case vmAddr of
    0:
      if value = 0 then GDVars.nameCleared := True;
    $20..$70: begin
      t := vmAddr - $20;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    $B8: begin
      if value > 178 then Dec(value, 50);
      GDVars.curChar^.npc := value;
    end;
    $BB, $BD, $BF, $C1, $C3, $C5, $C7:
      GDVars.curChar^.coinsA[ShortInt((vmAddr - $BB) div 2 + 0)] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.xpBonusPerHp := value;
    $100: begin
      if value >= $80 then
        GDVars.curChar^.enabled := 0;
      case value and $7F of
        1: GDVars.curChar^.statusS := C_Status.OKAY;
        2: GDVars.curChar^.statusS := C_Status.GONE;
        3: GDVars.curChar^.statusS := C_Status.DEAD_STATUS;
        4: GDVars.curChar^.statusS := C_Status.DYING;
        5: GDVars.curChar^.statusS := C_Status.UNCONSCIOUS;
        6: GDVars.curChar^.statusS := C_Status.RUNNING;
        7: GDVars.curChar^.statusS := C_Status.STONED;
      end;
      if value = 0 then GDVars.statusCleared := True;
    end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    $312: DaxIo.pushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
end;

procedure WriteGbvm(vmAddr, value: Word);
var
  zone: Byte;
  ok: Boolean;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  case zone of
    0: begin
      { before the store: the sky colors redraw the sky; IN_DUNGEON's arm is empty }
      case vmAddr - $4B00 of
        $FD, $FE:
          GDVars.redrawSky := True;
        $E6: ;
      end;
      GDVars.gbvmZone0Ptr^[vmAddr] := value;
    end;
    1: begin
      GDVars.gbvmZone1Ptr^[vmAddr] := value;
      EclMenu.SpecialWriteZ1(vmAddr, value);
    end;
    2:
      GDVars.gbvmZone2Ptr^[vmAddr] := value;
    3:
      GDVars.gbvmScriptPtr^[vmAddr] := value;
    4:
      case vmAddr of
        $FB: ;
        $FC: ;
        $B1: ;
        $3DE: GDVars.sndEffect := value;
        $B8: GDVars.writeReg1 := value;
        $B9: GDVars.writeReg2 := value;
        { the party's X }
        $C04B: begin
          GDVars.movedParty := True;
          GDVars.partyPos.mapX := value;
        end;
        { the party's Y }
        $C04C: begin
          GDVars.partyPos.mapY := value;
          GDVars.movedParty := True;
        end;
        { the party's facing, 0..3 mod 4 }
        $3B2, $C04D: begin
          repeat
            ok := True;
            case value of
              0: GDVars.partyPos.facing := C_Dir.NORTH;
              1: GDVars.partyPos.facing := C_Dir.EAST;
              2: GDVars.partyPos.facing := C_Dir.SOUTH;
              3: GDVars.partyPos.facing := C_Dir.WEST;
            else begin
              ok := False;
              Dec(value, 4);
            end;
            end;
          until ok = True;
          GDVars.movedParty := True;
        end;
        $C059: begin
          GDVars.wallColorSel := value;
          GDVars.picRegionW := True;
        end;
        $C05F: begin
          GDVars.ceilFloorColorSel := value;
          GDVars.picRegionW := True;
        end;
        $D022: ;
      end;
  end;
end;

function ReadGbvm(vmAddr: Word): Word;
var
  zone: Byte;
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  offset: Word;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  found := False;
  case zone of
    0:
      ReadGbvm := GDVars.gbvmZone0Ptr^[vmAddr];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(vmAddr, found);
      if not found then
        ReadGbvm := GDVars.gbvmZone1Ptr^[vmAddr];
    end;
    2:
      ReadGbvm := GDVars.gbvmZone2Ptr^[vmAddr];
    3:
      ReadGbvm := GDVars.gbvmScriptPtr^[vmAddr];
    4:
      case vmAddr of
        $B1: ReadGbvm := GDVars.readReg3;
        $FB: ReadGbvm := GDVars.readReg1;
        $FC: ReadGbvm := GDVars.readReg2;
        $33D: ReadGbvm := GDVars.partyPos.facing;
        $35F: ;
        $C04B: ReadGbvm := GDVars.partyPos.mapX;
        $C04C: ReadGbvm := GDVars.partyPos.mapY;
        $3B2, $C04D: ReadGbvm := GDVars.partyPos.facing div 2;
        $C04E: ReadGbvm := GDVars.partyPos.wallAhead;
        $C04F: ReadGbvm := GDVars.partyPos.eventAtCell;
        $C059: ;
      end;
  end;
end;

procedure WriteGbvmString(vmAddr: Word; s: String);
var
  zone: Byte;
  len: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  len := Length(s);
  case zone of
    0: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.gbvmZone0Ptr^[vmAddr + i] := Ord(s[i + 1]);
      GDVars.gbvmZone0Ptr^[vmAddr + len] := 0;
    end;
    1:
      if vmAddr = $7C00 then
        GDVars.curChar^.name := s
      else begin
        if len > 0 then
          for i := 0 to len - 1 do
            GDVars.gbvmZone1Ptr^[vmAddr + i] := Ord(s[i + 1]);
        GDVars.gbvmZone1Ptr^[vmAddr + len] := 0;
      end;
    2: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.gbvmZone2Ptr^[vmAddr + i] := Ord(s[i + 1]);
      GDVars.gbvmZone2Ptr^[vmAddr + len] := 0;
    end;
    3: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.gbvmScriptPtr^[vmAddr + i] := Ord(s[i + 1]);
      GDVars.gbvmScriptPtr^[vmAddr + len] := 0;
    end;
  end;
end;

{ Decodes packed 6-bit game characters at the script's instruction pointer into a script string, four characters to
  three bytes; zero characters are dropped. The instruction pointer ends on the last byte read.
  @param(len The number of packed bytes.)
  @param(strIdx The script string to fill.) }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  sixBits: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclScriptInstructionPtr);
      prev := cur;
      cur := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr];
      Inc(i);
    end;
    case phase of
      1:
        sixBits := cur shr 2;
      2: begin
        sixBits := prev shl 6 + cur shr 2;
        sixBits := sixBits shr 2;
      end;
      3: begin
        sixBits := prev shl 4 + cur shr 4;
        sixBits := sixBits shr 2;
      end;
      4:
        sixBits := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if sixBits <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBits);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    sixBits := cur and $3F;
    if sixBits <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBits);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
end;

{ Copies the zero-terminated string at a GBVM address into a script string. The zone-1 base address gives the current
  character's name; addresses outside the zones give an empty string.
  @param(strIdx The script string filled.)
  @param(vmAddr The GBVM address.) }
procedure DerefGbString(strIdx: Byte; vmAddr: Word);
var
  zone: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.gbvmZone0Ptr^[vmAddr + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.gbvmZone0Ptr^[vmAddr + i]));
        Inc(i);
      end;
    1:
      if vmAddr = $7C00 then
        GDVars.gbStrings[strIdx] := GDVars.curChar^.name
      else
        while GDVars.gbvmZone1Ptr^[vmAddr + i] <> 0 do begin
          GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.gbvmZone1Ptr^[vmAddr + i]));
          Inc(i);
        end;
    2:
      while GDVars.gbvmZone2Ptr^[vmAddr + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.gbvmZone2Ptr^[vmAddr + i]));
        Inc(i);
      end;
    3:
      while GDVars.gbvmScriptPtr^[vmAddr + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.gbvmScriptPtr^[vmAddr + i]));
        Inc(i);
      end;
  end;
end;

{ Prepares a script menu string: lowercases it, removes each '~' and uppercases the letter after it as a hotkey. Note:
  the lowercasing adds $20 to digits too, turning them into letters P..Y.
  @param(menu The menu string, prepared in place.)
  @param(opts Receives the hotkeys in order.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk,
                                       animate: Boolean): Byte;
var
  opts: Types.TStr40;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  EclMenu.MenuToOptions(menu, opts);
  repeat
    GDConsts.isEclMenuActive := True;
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, True, animate, ext);
    GDConsts.isEclMenuActive := False;
    if ext then begin
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar);
      ch := C_Keys.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_Keys.ENTER) and enterOk);
  case ch of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
  MenuCore.ClearBottomLine;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  opts: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, menu, qCol, mCol, hlCol, ulCol, ulRow, lrCol, lrRow, list, addExit, redraw,
                              idx, sel);
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclGosub(varIdx: Byte);
begin
  if GDVars.eclStack = nil then begin
    GetMem(GDVars.eclStack, SizeOf(GDVars.eclStack^));
    GDVars.eclStack^.next := nil;
  end else begin
    GDVars.eclStackPrev := GDVars.eclStack;
    GetMem(GDVars.eclStack, SizeOf(GDVars.eclStack^));
    GDVars.eclStack^.next := GDVars.eclStackPrev;
  end;
  GDVars.eclStack^.addr := GDVars.eclScriptInstructionPtr;
  GDVars.eclScriptInstructionPtr := EclMenu.CombineBytesToWord(GDVars.varLo[varIdx], GDVars.varHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPos.facing of
    C_Dir.NORTH: if GDVars.partyPos.mapY > 0 then Dec(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 15;
    C_Dir.EAST: if GDVars.partyPos.mapX < 15 then Inc(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 0;
    C_Dir.SOUTH: if GDVars.partyPos.mapY < 15 then Inc(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 0;
    C_Dir.WEST: if GDVars.partyPos.mapX > 0 then Dec(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 15;
  end;
  View3D.RefreshCurrentMapCell;
  GDVars.movedParty := True;
end;

procedure CharFightsAlone(mirror: ShortInt);
var
  p: Types.PWork;
  clone: Types.PWork;
  cur: Types.PWork;
  srcIt: Types.PItemRec;
  tmp: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  srcEff: Pointer;
begin
  GDVars.duelFlag := True;
  GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] := mirror;
  cur := GDVars.curChar;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.name <> cur^.name then
      p^.enabled := 0;
    p := p^.nextCharAddr;
  end;
  if mirror = 0 then Exit;
  MapTiles.LoadIconAnim('CPIC', 11, GDVars.currentIconAnimation);
  p := GDVars.creatureList;
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  GetMem(clone, SizeOf(clone^));
  clone^ := cur^;
  clone^.enabled := 1;
  clone^.nextCharAddr := nil;
  clone^.name := 'ROLF';
  clone^.quickfight := 1;
  clone^.hostile := 1;
  clone^.npc := C_Npc.ANIMATED_NON_PLAYER;
  clone^.orderNumber := GDVars.currentIconAnimation;
  clone^.effects := nil;
  clone^.itemsAddr := nil;
  p^.nextCharAddr := clone;
  p := p^.nextCharAddr;
  srcIt := Types.PItemRec(cur^.itemsAddr);
  while srcIt <> nil do begin
    if p^.itemsAddr = nil then begin
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      Types.PItemRec(p^.itemsAddr)^ := srcIt^;
      Types.PItemRec(p^.itemsAddr)^.next := nil;
    end else begin
      tmp := Types.PItemRec(p^.itemsAddr);
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      Types.PItemRec(p^.itemsAddr)^ := srcIt^;
      Types.PItemRec(p^.itemsAddr)^.next := Types.PItemRec(tmp);
    end;
    srcIt := Types.PItemRec(srcIt^.next);
  end;
end;

procedure RobMoney(fraction: Real; cr: Pointer);
begin
  Types.PWork(cr)^.coinsA[0] := Trunc(Types.PWork(cr)^.coinsA[0] * fraction);
  Types.PWork(cr)^.coinsA[1] := Trunc(Types.PWork(cr)^.coinsA[1] * fraction);
  Types.PWork(cr)^.coinsA[2] := Trunc(Types.PWork(cr)^.coinsA[2] * fraction);
  Types.PWork(cr)^.coinsA[3] := Trunc(Types.PWork(cr)^.coinsA[3] * fraction);
  Types.PWork(cr)^.coinsA[4] := Trunc(Types.PWork(cr)^.coinsA[4] * fraction);
  Types.PWork(cr)^.coinsA[5] := Trunc(Types.PWork(cr)^.coinsA[5] * fraction);
  Types.PWork(cr)^.coinsA[6] := Trunc(Types.PWork(cr)^.coinsA[6] * fraction);
end;

procedure RobItems(chance: Byte; cr: Pointer);
var
  roll: Byte;
  it: Types.PItemRec;
  nxt: Types.PItemRec;
begin
  it := Types.PItemRec(Types.PWork(cr)^.itemsAddr);
  while it <> nil do begin
    if it^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if it^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    nxt := Types.PItemRec(it^.next);
    if roll <= chance then
      CharHlp.RemoveItem(Types.PWork(cr), Types.PItemRec(it));
    it := nxt;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.curOpcode := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr];
  case GDVars.curOpcode of
    1, 2, $A, $E, $11, $12, $1D, $20, $2D, $32, $34, $36, $38, $39,
    $3C, $3F, $40:
      EclMenu.LoadEclVars(1);
    3, 8, 9, $F, $10, $1F, $22:
      EclMenu.LoadEclVars(2);
    4..7, $B, $C, $21, $28, $2A, $2F, $30, $35, $37, $3B:
      EclMenu.LoadEclVars(3);
    $14, $23:
      EclMenu.LoadEclVars(4);
    $2E:
      EclMenu.LoadEclVars(5);
    $1E, $2C:
      EclMenu.LoadEclVars(6);
    $27:
      EclMenu.LoadEclVars(8);
    $29:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclScriptInstructionPtr);
  end;
end;

procedure MoveExtremes(var hiMove, loMove: Byte);
var
  p: Types.PWork;
  eff: Types.PEffectRec;
  m: Byte;
begin
  p := GDVars.creatureList;
  hiMove := p^.movementCur;
  loMove := p^.movementCur;
  while p <> nil do begin
    m := p^.movementCur;
    if CharHlp.HasEffect(p, C_Effect.HASTED, eff) then
      m := m * 2
    else if CharHlp.HasEffect(p, C_Effect.SLOWED, eff) then
      m := m div 2;
    if m > hiMove then hiMove := m;
    if m < loMove then loMove := m;
    p := p^.nextCharAddr;
  end;
end;

procedure EclInflictDamage(dmg: Word; cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  msg: String;
  dmgStr: String[3];
  pause: Boolean;
begin
  if Types.PWork(cr)^.status = C_Status.DEAD_STATUS then Exit;
  pause := False;
  Str(dmg, dmgStr);
  if Types.PWork(cr)^.hpCur + 10 < dmg then
    msg := '  ' + Types.PWork(cr)^.name + ' dies. '
  else
    msg := '  ' + Types.PWork(cr)^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
  if GDVars.curRow > C_Msg.TEXT_BOTTOM then begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    pause := True;
    TextRend.DisplayAndPause(White, Black, 'press <enter>/<return> to continue');
  end else
    pause := False;
  GDVars.curCol := C_Msg.TEXT_RIGHT;
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, White, Black,
                                pause, msg);
  CharHlp.InflictDamage(Types.PWork(cr), dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayParty(GDVars.curChar);
end;

begin
end.
