{ The ECL script interpreter: the fetch and dispatch loop, the opcode handlers and the main game loop. The operand
  decoder and the GBVM access routines (LoadEclVars, GetEclVar, CombineBytesToWord, WriteGbvm, ...) are in EclMenu.
  SETUP MONSTER and ENCOUNTER keep the monster and its picture in GDVars.monId and monPicId. }
{$O+,F+,I-,S+,A+}
unit EclVm;

interface

{ Run the game: prime the interpreter's state, take the starting script (82 in demo mode, 1 for a new game, else the one
  last run), load it unless a saved game brought it, and run its on-load entry. In demo mode the party is then
  dismissed. Otherwise, until the party is defeated: read the exploring menu (camping and searching run while they are
  asked for), run the script's first entry, resolve the party's move and run its second entry; a NEWECL hands over
  through NewEclDone. }
procedure GameLoop;

{ Finish a NEWECL: free the GOSUB stack, load script GDVars.eclScript and start it (EclMenu.EclInit), stop the running
  script and flag the change for NewEclDone. }
procedure FinishNewEcl;

implementation

uses Types, Crt, SoundDrv, DaxIo, Border, Camp, CharHlp, ClassCal, Combat, CopyProt, Ending, EclMenu, FxEngine, Debug,
  GameIo, MenuCore, Money, Explore, Portrait, PostCbt, MapView, GameTime, SaveLoad, Shop, Temple, Vault, View3D, Music,
  TextRend, GDConsts, GDVars, MapTiles, CharGen, C_Class, C_Ifc, C_Msg, C_Npc,
  C_Pic, C_Gbvm;

const
  { GBVM zone 0: the two 3D graphics-loaded flags LOAD FILES tests }
  FIRST_GFX_LOADED = $4BE7;
  SECOND_GFX_LOADED = $4BE8;
  { GBVM zone 0: set to 1 to enter the vault }
  ENTER_VAULT = $4CFC;
  { GBVM zone 1: the distance SETUP MONSTER asks for }
  MONSTER_DIST_REQUESTED = $7EC0;
  { GBVM zone 1: set by COMBAT to enter the temple }
  ENTER_TEMPLE = $7EE2;
  { GBVM zone 1: DIVIDE's remainder }
  DIVIDE_REMAINDER = $7F3F;
  { GBVM zone 1: set by COMBAT to enter the shop }
  ENTER_SHOP = $7F6C;
  { GBVM zone 1: the result of a yes-or-no choice }
  MENU_CHOICE = $7F79;
  { Types.TWork.charClass's value for a cleric/ranger }
  CLASS_CLERIC_RANGER = 10;

type
  { a creature record as SPELL reads it: the spell slots after the record's first 30 bytes }
  PSpellRec = ^TSpellRec;
  TSpellRec = record
    spellsLead: array[0..$1D] of Byte;
    spells: array[0..102] of Byte;
  end;

  { the icon set LOAD MONSTER loads }
  TStr12 = String[12];

procedure DispatchEclCommand; forward;

procedure EnterCamp; forward;

procedure CallEclScript(vmAddr: Word); forward;

{ EXIT, opcode $00: ends the script. Redraws the view frame if the copy protection showed, restores the saved current
  character, clears the monster flags and the graphics flag, stops the interpreter, empties the gosub stack and puts the
  text cursor back at row 17, column 1. }
procedure EclExit;
begin
  if GDVars.protectionShown <> 0 then Border.DrawViewFrame;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  GDVars.protectionShown := 0;
  GDVars.eclStop := 1;
  Inc(GDVars.eclScriptInstructionPtr);
  while GDVars.eclStack <> nil do begin
    GDVars.eclStackPrev := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.eclStackPrev;
  end;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  GDVars.curCol := 1;
  GDVars.ecl3dClearFlag := 0;
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclScriptInstructionPtr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  leftValue: Word;
  rightValue: Word;
  leftText: String;
  rightText: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.varTypes[1] >= $80) or (GDVars.varTypes[2] >= $80) then begin
    leftText := GDVars.gbStrings[1];
    rightText := GDVars.gbStrings[2];
    EclMenu.EclCompareStr(leftText, rightText);
  end else begin
    leftValue := EclMenu.GetEclVar(1);
    rightValue := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(leftValue, rightValue);
  end;
end;

{ ADD, SUBTRACT, DIVIDE and MULTIPLY, opcodes $04..$07: combines its first two arguments and stores the result at the
  GBVM address in its third. SUBTRACT takes the first from the second; DIVIDE leaves the remainder in the zone's
  division remainder. }
procedure EclArithmetic;
var
  vmAddr: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclMenu.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclMenu.GetEclVar(i);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  case GDVars.curOpcode of
    4: r := v[1] + v[2];
    5: r := v[2] - v[1];
    6: begin
         r := v[1] div v[2];
         GDVars.gbvmZone1Ptr^[EclVm.DIVIDE_REMAINDER] := v[1] mod v[2];
       end;
    7: r := v[1] * v[2];
  end;
  EclMenu.WriteGbvm(vmAddr, r);
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  n := EclMenu.GetEclVar(1);
  if n < 255 then Inc(n);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  roll := Trunc(Random(n));
  EclMenu.WriteGbvm(vmAddr, roll);
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var
  v: Word;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  if GDVars.varTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(vmAddr, v);
  end else
    EclMenu.WriteGbvmString(vmAddr, GDVars.gbStrings[1]);
end;

{ LOAD CHARACTER, opcode $0A: makes the party member at the position in the low 7 bits of its argument current, or sets
  the character-not-found flag when there is none. With bit 7 set and both removal flags raised, that member is removed
  from the party and the party redrawn. }
procedure EclLoadCharacter;
var
  p: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  savedIndex: Byte;
  idx: Byte;
  i: Byte;
  flag80: Byte;
begin
  GDVars.restoreChar := 1;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := EclMenu.GetEclVar(1);
  p := GDVars.creatureList;
  flag80 := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.nextCharAddr;
      Inc(i);
    end;
  if p <> nil then begin
    GDVars.curChar := p;
    GDVars.characterNotFound := 0;
  end else
    GDVars.characterNotFound := 1;
  if (flag80 <> 0) and (GDVars.statusCleared) and (GDVars.nameCleared) then begin
    if GDVars.savedChar = GDVars.curChar then
      GDVars.restoreChar := 0;
    CharGen.RemoveCreature(False, True);
    CharHlp.DisplayParty(GDVars.curChar);
    GDVars.statusCleared := False;
    GDVars.nameCleared := False;
  end;
end;

{ SETUP MONSTER, opcode $0C: sets the monster and its picture, stores the requested monster distance and the actual one
  (capped by the open distance ahead), and draws the monster. }
procedure EclSetupMonster;
var
  { Unused in this version; see the other implementations of this routine. }
  distance: array[0..1] of Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.monId := EclMenu.GetEclVar(1);
  GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED] := EclMenu.GetEclVar(2);
  GDVars.monPicId := EclMenu.GetEclVar(3);
  GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                      GDVars.partyPos.facing);
  if GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED] < GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] then
    GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                         GDVars.monsterFlags);
end;

{ LOAD MONSTER, opcode $0B: loads the monster its first argument names, scaling a hostile one's hit points by the
  difficulty, and appends it to the creature list with the CPIC icon its third argument names; then appends copies up to
  the count in its second argument, each with copies of the monster's item and effect lists, built at the head so in
  reverse order. The list holds at most 63 creatures. }
procedure EclLoadMonster;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PWork;
  q: Types.PWork;
  cr: Types.PWork;
  savedCur: Types.PWork;
  tmpl: Types.TWork;
  nm: TStr12;
  it: Types.PItemRec;
  tmpIt: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  tmpEf: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := GDVars.curChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.creatureCnt >= 63 then Exit;
  p := nil;
  q := nil;
  id := EclMenu.GetEclVar(1);
  EclMenu.InitCreature(id, Pointer(cr), Pointer(it), Pointer(ef));
  if cr^.hostile = 1 then begin
    if cr^.npc = C_Npc.NON_PLAYER then
      Inc(cr^.npc, 49);
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] >= 0) and (GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] < 5) then begin
      cr^.hpCur := cr^.hpCur * (GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] + 2) div 4;
      cr^.evMaxHp := cr^.evMaxHp * (GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] + 2) div 4;
      if (cr^.hpCur = 0) or (cr^.evMaxHp = 0) then begin
        cr^.hpCur := 1;
        cr^.evMaxHp := 1;
      end;
    end;
  end;
  tmpl := cr^;
  invHead := it;
  effHead := ef;
  count := EclMenu.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclMenu.GetEclVar(3);
  p := GDVars.creatureList;
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.currentIconAnimation);
  if (GDVars.iconAnimation[GDVars.currentIconAnimation, 0] = nil) or
      (GDVars.iconAnimation[GDVars.currentIconAnimation, 1] = nil) then
    GDVars.displayStatusLineProc('Icon not found');
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  p^.nextCharAddr := cr;
  p := p^.nextCharAddr;
  p^.orderNumber := GDVars.currentIconAnimation;
  p^.nextCharAddr := nil;
  Inc(GDVars.creatureCnt);
  Inc(i);
  while (i <= count) and (GDVars.creatureCnt < 63) do begin
    GetMem(q, SizeOf(Types.TWork));
    p^.nextCharAddr := q;
    p := p^.nextCharAddr;
    p^ := tmpl;
    p^.orderNumber := GDVars.currentIconAnimation;
    p^.nextCharAddr := nil;
    p^.effects := nil;
    p^.items := nil;
    Inc(i);
    Inc(GDVars.creatureCnt);
    while it <> nil do begin
      if p^.items = nil then begin
        GetMem(p^.items, SizeOf(Types.TItemRec));
        Types.PItemRec(p^.items)^ := it^;
        Types.PItemRec(p^.items)^.next := nil;
      end else begin
        tmpIt := p^.items;
        GetMem(p^.items, SizeOf(Types.TItemRec));
        Types.PItemRec(p^.items)^ := it^;
        Types.PItemRec(p^.items)^.next := tmpIt;
      end;
      it := it^.next;
    end;
    it := invHead;
    while ef <> nil do begin
      if p^.effects = nil then begin
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        Types.PEffectRec(p^.effects)^ := ef^;
        Types.PEffectRec(p^.effects)^.next := nil;
      end else begin
        tmpEf := p^.effects;
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        Types.PEffectRec(p^.effects)^ := ef^;
        Types.PEffectRec(p^.effects)^.next := tmpEf;
      end;
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(GDVars.currentIconAnimation);
  GDVars.creatureListContainsFlag := 1;
  GDVars.curChar := savedCur;
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] > 0 then begin
    Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
    EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST],
                           GDVars.monsterFlags);
  end;
  Inc(GDVars.eclScriptInstructionPtr);
end;

{ PICTURE, opcode $0E: shows the picture its argument names: from 120 up a big picture, below it a PIC animation in the
  view window, or, while zone 1's portrait head is set, that portrait with the picture as its body. 255 redraws the map
  view over the script's pictures and sprite. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclMenu.LoadEclVars(1);
  picId := EclMenu.GetEclVar(1);
  if picId <> C_Pic.NO_PICTURE then begin
    GDVars.monsterFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD] = C_Pic.NO_PICTURE then begin
      GDVars.picDrawn := True;
      if picId >= 120 then begin
        Portrait.freeAnimation(GDVars.animationData);
        Portrait.freePortraitBufs;
        GameIo.kbdNoop;
        Portrait.DisplayBigPic(picId);
        GDVars.mapRedrawPending := 0;
      end else begin
        Portrait.loadAnimation('PIC', picId, 0, GDVars.animationData);
        Portrait.displayImageBuf(3, 3, True, GDVars.animationData.frames[1].pic);
      end;
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.PORTRAIT_HEAD]), picId);
  end else begin
    if ((GDVars.savedInterfaceState <> C_Ifc.EXPLORING) or (GDVars.interfaceState = C_Ifc.EXPLORING)) and
        ((GDVars.eclGraphics) or (GDVars.sprShown)) then begin
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.sprShown := False;
      GDVars.picDrawn := True;
    end;
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False;
  end;
end;

{ INPUT NUMBER, opcode $0F: prompts in light green for a number, limited by its first argument, and stores it at the
  GBVM address in its second. }
procedure EclInputNumber;
var
  q: String[1];
  v: Word;
  vmAddr: Word;
  limit: Word;
begin
  EclMenu.LoadEclVars(2);
  limit := EclMenu.GetEclVar(1);
  q := '';
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  v := Money.inputNumber(limit, q, 10, 0);
  EclMenu.WriteGbvm(vmAddr, v);
end;

{ INPUT STRING, opcode $10: reads up to 40 characters, a space when nothing is typed, and stores them at the GBVM
  address in its second argument. }
procedure EclInputString;
var
  q: String[1];
  vmAddr: Word;
  s: String;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  s := TextRend.ReadString(q, LightGreen, Black, 40);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(vmAddr, s);
end;

{ PRINT and PRINTCLEAR, opcodes $11 and $12: shows its argument, a number or a string, in the message window; PRINTCLEAR
  first clears the window and starts at its top. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  if GDVars.varTypes[1] < $80 then
    GDVars.gbStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.curOpcode = $11 then
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                  Black, False, GDVars.gbStrings[1])
  else begin
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                  Black, True, GDVars.gbStrings[1]);
  end;
  GDVars.msgDelayFlag := 0;
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  if GDVars.eclStack <> nil then begin
    GDVars.eclScriptInstructionPtr := GDVars.eclStack^.addr;
    GDVars.eclStackPrev := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.eclStackPrev;
  end else
    EclVm.EclExit;
end;

{ COMPARE AND, opcode $14: sets the equal flag when its first two arguments are equal and its last two are equal, else
  the not-equal flag. }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ IF, opcodes $16..$1B (=, <>, <, >, <=, >=): skips the next command unless its comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  case GDVars.curOpcode of
    $16: if not GDVars.cmpFlags[0] then EclMenu.SkipEclCmd;
    $17: if not GDVars.cmpFlags[1] then EclMenu.SkipEclCmd;
    $18: if not GDVars.cmpFlags[2] then EclMenu.SkipEclCmd;
    $19: if not GDVars.cmpFlags[3] then EclMenu.SkipEclCmd;
    $1A: if not GDVars.cmpFlags[4] then EclMenu.SkipEclCmd;
    $1B: if not GDVars.cmpFlags[5] then EclMenu.SkipEclCmd;
  end;
end;

procedure FinishNewEcl;
begin
  while GDVars.eclStack <> nil do begin
    GDVars.eclStackPrev := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.eclStackPrev;
  end;
  GDVars.eclStack := nil;
  EclMenu.LoadEclScript(GDVars.eclScript);
  EclMenu.EclInit;
  GDVars.eclStop := 1;
  GDVars.newEclFlag := 1;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
end;

{ NEWECL, opcode $20: records the running script as the one to return to and switches to the script its argument
  names. }
procedure EclNewEcl;
var
  newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := GDVars.eclScript;
  newId := EclMenu.GetEclVar(1);
  GDVars.eclScript := newId;
  EclVm.FinishNewEcl;
end;

{ LOAD FILES and LOAD PIECES, opcodes $21 and $37: $21 loads the 3D map its first argument names unless that is 255 or
  127. $37 loads the wall sets its three arguments name into slots 1 to 3: a first argument of 127 loads set 0 into slot
  1 alone; while both of zone 0's graphics flags are set only slots 1 and 3 load; otherwise a 255 empties its slot. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.filesLoaded := 1;
  for i := 1 to 3 do
    f[i] := EclMenu.GetEclVar(i);
  if GDVars.curOpcode = $21 then begin
    GDVars.mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) then begin
      GDVars.gbvmZone0Ptr^[C_Gbvm.GEO_MAP_ID] := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.gbvmZone1Ptr^[C_Gbvm.MOVE_LOCK] := 0;
    end;
  end else begin
    GDVars.piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.gbvmZone0Ptr^[EclVm.FIRST_GFX_LOADED] <> 0) and
      (GDVars.gbvmZone0Ptr^[EclVm.SECOND_GFX_LOADED] <> 0) then begin
      if f[1] <> 255 then
        View3D.LoadWallSet(f[1], 1);
      if f[3] <> 255 then
        View3D.LoadWallSet(f[3], 3);
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i)
        else begin
          GDVars.wallSetCache[i].wallDefId := -1;
          GDVars.wallSetCache[i].symbolSlot := -1;
        end;
  end;
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  vmAddr: Word;
  rightValue: Word;
  leftValue: Word;
  r: Byte;
begin
  EclMenu.LoadEclVars(3);
  leftValue := EclMenu.GetEclVar(1);
  rightValue := EclMenu.GetEclVar(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  if GDVars.curOpcode = $2F then
    r := leftValue and rightValue
  else
    r := leftValue or rightValue;
  EclMenu.EclCompareInt(0, r);
  EclMenu.WriteGbvm(vmAddr, r);
end;

{ GETTABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  idx := EclMenu.GetEclVar(2);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  sum := idx + addr1;
  v := EclMenu.ReadGbvm(sum);
  EclMenu.WriteGbvm(addr2, v);
end;

{ SAVETABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  vmAddr: Word;
  v: Word;
  sum: Word;
begin
  EclMenu.LoadEclVars(3);
  v := EclMenu.GetEclVar(1);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  idx := EclMenu.GetEclVar(3);
  sum := vmAddr + idx;
  EclMenu.WriteGbvm(sum, v);
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  vmAddr: Word;
begin
  GDVars.bottomMsgCleared := 0;
  redraw := True;
  q := '';
  i := 1;
  EclMenu.LoadEclVars(3);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  msg := GDVars.gbStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclScriptInstructionPtr);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := 1;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                Black, True, msg);
  while list <> nil do begin
    list^.name := GDVars.gbStrings[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, LightMagenta, LightGreen, White, C_Msg.TEXT_LEFT, GDVars.curRow + 1, C_Msg.TEXT_RIGHT,
                          C_Msg.TEXT_BOTTOM, list, False, redraw, idx, list);
  EclMenu.WriteGbvm(vmAddr, idx);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ HORIZONTAL MENU, opcode $2B: builds a '~A ~B ~C' horizontal menu from the strings that follow, as many as its second
  argument says, and stores the chosen index at the address in its first. A single choice also accepts Enter, and the
  joystick wording of the continue prompt becomes the keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  vmAddr: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  q := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclScriptInstructionPtr);
  EclMenu.LoadEclVars(count);
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := White;
    mCol := White;
    if GDVars.gbStrings[1] = 'PRESS BUTTON OR RETURN TO CONTINUE.' then
      GDVars.gbStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := White;
    mCol := LightGreen;
  end;
  anim := (GDVars.eclGraphics) and (GDVars.picDrawn);
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.gbStrings[i] + ' ';
  menu := menu + '~' + GDVars.gbStrings[count];
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclMenu.WriteGbvm(vmAddr, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEARMONSTERS, opcode $1C: forgets the loaded monsters (their count, the loaded flag and the next icon slot) and
  empties the treasure: its money and its item list. }
procedure EclClearMonsters;
var
  next: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  node: array[0..1] of Byte;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  GDVars.creatureCnt := 0;
  GDVars.creatureListContainsFlag := 0;
  GDVars.currentIconAnimation := 8;
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  while GDVars.treasureItems <> nil do begin
    next := GDVars.treasureItems^.next;
    FreeMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
    GDVars.treasureItems := next;
  end;
end;

{ PARTY STRENGTH, opcode $1D: stores the party's rating at the address in its first argument: for each member, (4 per
  cleric level + hit points + 5 per point of armor class below 0 + 5 per point of THAC0 below 21 + 8 per magic-user
  level) div 10, from the stored, 60-biased armor class and THAC0; the magic-user and cleric levels add the former-class
  levels when the earlier class's abilities count again. Note: the byte sum can overflow. }
procedure EclPartyStrength;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Byte;
  vmAddr: Word;
  p: Types.PWork;
begin
  EclMenu.LoadEclVars(1);
  strength := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur;
    th := p^.thac0Cur;
    mage := p^.classLevels[C_Class.MAGE_LEVEL] + p^.classLevels2[C_Class.MAGE_LEVEL] *
      ClassCal.EarlierClassActive(Types.PWork(p));
    cleric := p^.classLevels[C_Class.CLERIC_LEVEL] + p^.classLevels2[C_Class.CLERIC_LEVEL] *
      ClassCal.EarlierClassActive(Types.PWork(p));
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    Inc(strength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.nextCharAddr;
  end;
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.WriteGbvm(vmAddr, strength);
end;

{ CHECKPARTY, opcode $1E: scans the party for the attribute its first argument names, less $7FFF: -32767 looks for a
  member with the effect its second argument names; $A5..$AC take the lowest, highest and average of a thief skill, and
  $9F the same of the current movement. The three figures and the found flag go to the GBVM addresses in its last four
  arguments, the effect search writing zeros for the figures. Any other attribute writes nothing. }
procedure EclCheckParty;
var
  { signed }
  attr: Integer;
  sum: Integer;
  effId: Byte;
  p: Types.PWork;
  found: Byte;
  eff: Types.PEffectRec;
  { min/max/avg }
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;
  idx: Byte;

  { writes the four results }
  procedure WriteResults;
  begin
    EclMenu.WriteGbvm(addr1, outv[1]);
    EclMenu.WriteGbvm(addr2, outv[2]);
    EclMenu.WriteGbvm(addr3, outv[3]);
    EclMenu.WriteGbvm(addr4, ShortInt(found));
  end;

begin
  EclMenu.LoadEclVars(6);
  p := GDVars.creatureList;
  found := 0;
  if GDVars.varTypes[1] = 1 then
    attr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
  else
    attr := EclMenu.GetEclVar(1);
  effId := EclMenu.GetEclVar(2);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.varLo[5], GDVars.varHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  Dec(attr, $7FFF);
  case attr of
    { key $8001: active-effect search }
    -32767: begin
      while (p <> nil) and (found = 0) do begin
        found := Byte(CharHlp.HasEffect(Types.PWork(p), effId, eff));
        p := p^.nextCharAddr;
      end;
      FillChar(outv, SizeOf(outv), 0);
      WriteResults;
    end;
    $A5..$AC: begin
      idx := attr - $A4;
      while p <> nil do begin
        Inc(count);
        if p^.evThiefSkills[idx] < outv[1] then
          outv[1] := p^.evThiefSkills[idx];
        if p^.evThiefSkills[idx] > outv[2] then
          outv[2] := p^.evThiefSkills[idx];
        Inc(sum, p^.evThiefSkills[idx]);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      WriteResults;
    end;
    $9F: begin
      while p <> nil do begin
        Inc(count);
        if p^.movementCur < outv[1] then
          outv[1] := p^.movementCur;
        if p^.movementCur > outv[2] then
          outv[2] := p^.movementCur;
        Inc(sum, p^.movementCur);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      WriteResults;
    end;
  end;
end;

{ PARTY SURPRISE, opcode $22: stores 1 at its first argument's address when the party holds a ranger or a cleric/ranger,
  else 0, and 0 at its second's. }
procedure EclPartySurprise;
var
  p: Types.PWork;
  mod1: Byte;
  mod2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rangerDead: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclMenu.LoadEclVars(2);
  p := GDVars.creatureList;
  mod1 := 0;
  mod2 := 0;
  rangerDead := 0;
  while p <> nil do begin
    if (p^.charClass = C_Class.RANGER) or (p^.charClass = EclVm.CLASS_CLERIC_RANGER) then begin
      mod1 := 1;
      rangerDead := 1;
    end;
    p := p^.nextCharAddr;
  end;
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  EclMenu.WriteGbvm(addr1, mod1);
  EclMenu.WriteGbvm(addr2, mod2);
end;

{ SURPRISE, opcode $23: rolls a six-sided die for each side against v4 + 2 - v1 and v2 + 2 - v3 and writes which side is
  surprised (1 or 2, 0 when neither is) to a fixed script address. Note: the final test overrides the both-sides result
  3, and the address lies outside the GBVM banks, where writes store nothing, so the result is lost. }
procedure EclSurprise;
var
  firstRoll: Byte;
  secondRoll: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  firstThreshold: ShortInt;
  secondThreshold: ShortInt;
begin
  EclMenu.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  firstThreshold := v[4] + 2 - v[1];
  secondThreshold := v[2] + 2 - v[3];
  firstRoll := FxEngine.RollDice(1, 6);
  secondRoll := FxEngine.RollDice(1, 6);
  if firstRoll <= firstThreshold then
    if secondRoll <= secondThreshold then
      result := 3
    else
      result := 1;
  if secondRoll <= secondThreshold then
    result := 2;
  EclMenu.WriteGbvm($2CB, result);
end;

{ COMBAT, opcode $24. With no monsters loaded and no duel set up, it enters the vault, the shop or the temple when zone
  0 or zone 1 asks for one, else runs the end of a combat. Otherwise, while combat is disabled, it records result 0 and
  stops there; else it settles the monsters' distance and runs the combat and its end. Each of these is wrapped in
  SoundDrv.SoundCommand(255) while sound is on and SoundDrv.SoundSuspend while it is off. Last it returns to exploring,
  keeps bit 0 of the search flags, clears the monster pictures and redraws the screen. }
procedure EclCombat;
var
  dist: Word;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  if (GDVars.creatureListContainsFlag = 0) and (not GDVars.duelFlag) then begin
    if GDVars.gbvmZone0Ptr^[EclVm.ENTER_VAULT] = 1 then begin
      GDVars.gbvmZone0Ptr^[EclVm.ENTER_VAULT] := 0;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      Vault.poolVault;
    end else if GDVars.gbvmZone1Ptr^[EclVm.ENTER_SHOP] = 1 then begin
      GDVars.gbvmZone1Ptr^[EclVm.ENTER_SHOP] := 0;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      Shop.shopMainMenu;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
    end else if GDVars.gbvmZone1Ptr^[EclVm.ENTER_TEMPLE] = 1 then begin
      GDVars.gbvmZone1Ptr^[EclVm.ENTER_TEMPLE] := 0;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      Temple.templeMainMenu;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
    end else begin
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      PostCbt.PostCombat;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
    end;
  end else begin
    if GDVars.combatDisabled <> 0 then begin
      GDVars.gbvmZone1Ptr^[C_Gbvm.COMBAT_RESULT] := 0;
      Exit;
    end;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      dist := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
      if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] >= $80 then
        GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] and $7F
      else if dist < GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] then
        GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := dist;
      Combat.CombatMain;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      PostCbt.PostCombat;
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
      if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;
      if GDVars.duelFlag then
        GDVars.duelFlag := False;
  end;
  GDVars.interfaceState := C_Ifc.EXPLORING;
  GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] := GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] and 1;
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  CharHlp.DisplayNoncombatInterface;
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  found: Byte;
begin
  found := 0;
  EclMenu.LoadEclVars(2);
  sel := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclScriptInstructionPtr);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (found = 0) do begin
    if sel = i then begin
      if GDVars.curOpcode = $25 then
        GDVars.eclScriptInstructionPtr := EclMenu.CombineBytesToWord(GDVars.varLo[i + 1], GDVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      found := 1;
    end else
      Inc(i);
  end;
end;

{ TREASURE, opcode $27: sets the treasure's seven money amounts from its first seven arguments, then adds to its item
  list by its eighth: below $80 the items of that record of ITEM<disk>.DAX (a missing record quits the game), 255
  nothing, and any other value that many random items less $80. Each item goes at the head of the list. Note: random
  rolls of 91 and 92 fall in two arms of the item table, and the first one wins. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  treasureMsg: String[22];
  it: Types.TItemRec;
  tmp: Types.PItemRec;
  walk: Types.PItemRec;
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  itemId: Byte;
  readOfs: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PBytes;
begin
  EclMenu.LoadEclVars(8);
  for i := 0 to 6 do
    GDVars.treasureMoney[i] := EclMenu.GetEclVar(Byte(i) + 1);
  tId := EclMenu.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.virtualDiskNumber, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, Black, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    readOfs := 0;
    repeat
      Move(data^[readOfs], it, SizeOf(it));
      it.next := nil;
      Inc(readOfs, SizeOf(Types.TItemRec));
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    until readOfs >= sizeRead;
    FreeMem(data, sizeRead);
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..60: begin
          roll2 := FxEngine.RollDice(1, 100);
          case roll2 of
            1..47, 50..59:
              if roll2 = 45 then
                itemId := 59
              else
                itemId := roll2;
            60..90: begin
              roll2 := FxEngine.RollDice(1, 10);
              case roll2 of
                1..4: itemId := 36;
                5..7: itemId := 35;
                8: itemId := 34;
                9: itemId := 37;
                10: itemId := 38;
              end;
            end;
            91..94: itemId := 73;
            95..97: itemId := 93;
            98..100: itemId := 77;
          else
            itemId := 59;
          end;
        end;
        61..85: itemId := 61;
        86..92: itemId := 62;
        91..98: begin
          roll3 := FxEngine.RollDice(1, 15);
          case roll3 of
            1..9: itemId := 71;
            10: itemId := 84;
            11..15: itemId := 79;
          end;
        end;
        99, 100: itemId := 59;
      end;
      Money.generateRandomItem(itemId, it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(GDVars.curChar, Types.PItemRec(walk), 0, 0, False, False);
      walk := walk^.next;
    end;
  end;
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  inv: Types.PItemRec;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := EclMenu.GetEclVar(1);
  pct := EclMenu.GetEclVar(2);
  fraction := (100 - pct) / 100;
  chance := EclMenu.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      inv := p^.items;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.nextCharAddr;
    end;
  end;
end;

{ ENCOUNTER MENU, opcode $29: runs the encounter menu until combat, flight, parley or the monsters' retreat ends it;
  WAIT and ADVANCE update the encounter and repeat. Stores the outcome at the address in its fourth argument: 0 when the
  monsters flee, 1 for combat, 2 when the party flees, 3 for parley. }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  vmAddr: Word;
begin
  GDVars.currentlyEclOpcodeFlag := 1;
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclMenu.LoadEclVars(14);
  GDVars.monId := EclMenu.GetEclVar(1);
  GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED] := EclMenu.GetEclVar(2);
  GDVars.monPicId := EclMenu.GetEclVar(3);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  for i := 0 to 4 do
    resp[i] := EclMenu.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GDVars.gbStrings[i];
  fleePar := EclMenu.GetEclVar(13);
  fleeMon := EclMenu.GetEclVar(14);
  GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                      GDVars.partyPos.facing);
  if GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED] < GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] then
    GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] := GDVars.gbvmZone1Ptr^[EclVm.MONSTER_DIST_REQUESTED];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                         GDVars.monsterFlags);
  repeat
    anim := (GDVars.eclGraphics) and (GDVars.picDrawn) and (GDVars.picArcId <> 80);
    clearW := True;
    waited := False;
    GDVars.curCol := 1;
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    case GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] of
      0: begin
        k := 1;
        repeat
          msg := msgs[k];
          Inc(k);
        until (msg <> '') or (k > 3);
      end;
      1: begin
        k := 2;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 2);
      end;
      2: begin
        k := 3;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 3);
      end;
    end;
    if msg = '' then
      clearW := False;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                  Black, clearW, msg);
    if (GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0)) and
        (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclMenu.WriteGbvm(vmAddr, 1)
        else begin
          if loMove >= fleePar then
            EclMenu.WriteGbvm(vmAddr, 2)
          else
            EclMenu.WriteGbvm(vmAddr, 1);
        end;
      1:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1: begin
            waited := True;
            TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                          LightGreen, Black, True, 'Both sides wait.');
          end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
          3: begin
            if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.monsterFlags);
            end else
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, Black, True, 'Both sides wait.');
            waited := True;
          end;
          4:
            if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclMenu.WriteGbvm(vmAddr, 0);
              GDVars.curCol := 1;
              GDVars.curRow := C_Msg.MESSAGE_TOP;
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, Black, True, 'The monsters flee.');
            end else
              EclMenu.WriteGbvm(vmAddr, 1);
          1..4: begin
            EclMenu.WriteGbvm(vmAddr, 0);
            GDVars.curCol := 1;
            GDVars.curRow := C_Msg.MESSAGE_TOP;
            TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                          LightGreen, Black, True, 'The monsters flee.');
          end;
        end;
      3:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1, 3: begin
            if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.monsterFlags);
            end else
              TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                            LightGreen, Black, True, 'Both sides wait.');
            waited := True;
          end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
          4:
            if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
        end;
      4:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1, 3, 4:
            if GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.monsterFlags);
              waited := True;
            end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
        end;
    end;
  until not waited;
  MenuCore.ClearBottomLine;
  GDVars.msgDelayFlag := 0;
  GDVars.currentlyEclOpcodeFlag := 0;
end;

{ PARLAY, opcode $2C: offers Haughty, Sly, Nice, Meek and Abusive and stores the script's value for the chosen attitude
  at the sixth argument's address. }
procedure EclParlay;
var
  sel: Byte;
  reply: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  vmAddr: Word;
  space: Char;
begin
  EclMenu.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclMenu.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen,
                                               White, False, False);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  reply := v[sel];
  EclMenu.WriteGbvm(vmAddr, reply);
end;

{ The item test FIND ITEM and DESTROY ITEMS share.
  @param(a The name parts to match.)
  @param(b An item's name parts.)
  @returns(True when all three are equal.) }
function ItemMatches(a, b: Types.TItemNameIds): Boolean;
var
  i: Byte;
begin
  ItemMatches := False;
  for i := 1 to 3 do
    if a[i] <> b[i] then
      Exit;
  ItemMatches := True;
end;

{ FIND ITEM, opcode $32: looks through the party's items for one of the item type its first argument names (0: any)
  whose three name parts match its other three, from the third part to the first (ItemMatches; a 0 second argument
  matches any). The compare flags are cleared first; a hit sets the equal flag, otherwise the not-equal flag is set. }
procedure EclFindMatchingItem;
var
  target: Byte;
  p: Types.PWork;
  item: Types.PItemRec;
  match: Types.TItemNameIds;
begin
  EclMenu.LoadEclVars(4);
  target := EclMenu.GetEclVar(1);
  match[3] := EclMenu.GetEclVar(2);
  match[2] := EclMenu.GetEclVar(3);
  match[1] := EclMenu.GetEclVar(4);
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.cmpFlags[1] := True;
  p := GDVars.creatureList;
  while p <> nil do begin
    item := p^.items;
    while item <> nil do begin
      if ((target = 0) or (target = item^.itemType)) and
          ((match[3] = 0) or EclVm.ItemMatches(match, item^.nameIds)) then begin
        GDVars.cmpFlags[0] := True;
        GDVars.cmpFlags[1] := False;
        Exit;
      end;
      item := item^.next;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ DELAY, opcode $3A: waits the message delay; no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  TextRend.PauseOnly;
end;

{ DAMAGE, opcode $2E: rolls its second argument's dice (the low 7 bits) of its third's sides, plus its fourth, and deals
  it by its first. With bit 7 set the damage is magical, against a saving throw of the type in the fifth argument's low
  3 bits adjusted by the first's low 5 bits: bit 6 strikes each member, and bit 5 then skips the save; else the fifth
  argument's bit 7 strikes the current character (its save type less 1, 0 for none); else one member. Bit 4 deals the
  damage on a save too. With bit 7 clear the first argument counts attacks, each rolled against the fifth and dealing a
  fresh roll. A single member is the current character when the second argument's bit 7 is set, else one picked at
  random. When the whole party is down it shows the death message; last it waits for Enter. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  atkLo: Byte;
  varOp: Byte;
  bonus: Byte;
  target: Byte;
  saveTy: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PWork;
  q: Types.PWork;
  savedCur: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  areaAtk: Byte;
  saveBit: Byte;
  { the second argument's bit 7: strike the current character }
  fromCur: Boolean;
begin
  savedCur := GDVars.curChar;
  damageType := 0;
  areaAtk := 0;
  p := GDVars.creatureList;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  dice := EclMenu.GetEclVar(2);
  if (dice and $80) <> 0 then
    fromCur := True
  else
    fromCur := False;
  dice := dice and $7F;
  sides := EclMenu.GetEclVar(3);
  bonus := EclMenu.GetEclVar(4);
  varOp := EclMenu.GetEclVar(5);
  dmg := FxEngine.RollDice(dice, sides) + bonus;
  saveBit := attack and $10;
  if (attack and $40) <> 0 then
    areaAtk := 1
  else if fromCur then
    target := EclMenu.FindCurCharIdx(GDVars.curChar) + 1
  else
    target := FxEngine.RollDice(1, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]));
  if (attack and $80) <> 0 then begin
    atkLo := attack and $1F;
    saveTy := varOp and $7;
    if areaAtk <> 0 then begin
      while p <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
          EclMenu.EclInflictDamage(dmg, p)
        else if saveBit <> 0 then
          EclMenu.EclInflictDamage(dmg, p);
        p := p^.nextCharAddr;
      end;
    end else if (varOp and $80) <> 0 then begin
      if (saveTy = 0) or not FxEngine.RollSavingThrow(GDVars.curChar, saveTy - 1, atkLo) then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar);
    end else begin
      for i := 2 to target do
        p := p^.nextCharAddr;
      if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
        EclMenu.EclInflictDamage(dmg, p)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end else begin
    for i := 1 to attack do begin
      p := GDVars.creatureList;
      if fromCur then
        target := EclMenu.FindCurCharIdx(GDVars.curChar) + 1
      else
        target := FxEngine.RollDice(1, Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]));
      j := 1;
      while j < target do begin
        p := p^.nextCharAddr;
        Inc(j);
      end;
      if FxEngine.AttackRollNoAttacker(p, varOp) then
        EclMenu.EclInflictDamage(dmg, p);
      dmg := FxEngine.RollDice(dice, sides) + bonus;
    end;
  end;
  q := GDVars.creatureList;
  GDVars.partyDefeated := True;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GDVars.partyDefeated := False;
    q := q^.nextCharAddr;
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindowFrame;
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, Black, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, Black, 'press <enter>/<return> to continue');
end;

{ SPRITE OFF, opcode $31: when a sprite is showing, redraws the map view over it. }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  if GDVars.sprShown then begin
    GDVars.mapRedrawPending := 1;
    MapView.DisplayMapView;
    GDVars.sprShown := False;
    GDVars.eclGraphics := False;
  end;
end;

{ CLOCK, opcode $34: advances the clock by its first argument in the unit its second names. }
procedure EclClock;
var
  amount: Byte;
  timeUnit: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(1);
  timeUnit := EclMenu.GetEclVar(2);
  GameTime.AdvanceTime(amount, timeUnit);
end;

{ PRINT RETURN, opcode $33: moves the text cursor to column 1 of the next line and clears the pending-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  TextRend.AdvanceTextCursor;
end;

{ CLEAR BOX, opcode $3D: redraws the view frame, the party and the status line, shows the current picture's first frame
  in the view window, and marks the view as cleared. }
procedure EclClearBox;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  Border.DrawViewFrame;
  CharHlp.DisplayParty(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  Portrait.displayImageBuf(3, 3, True, GDVars.animationData.frames[1].pic);
  CharHlp.PrintPositionAndTime;
  GDVars.characterSelectionActive := 0;
  GDVars.ecl3dClearFlag := 1;
end;

{ WHO, opcode $39: has the player pick a party member, with its string argument as the prompt; the pick becomes the
  current character. }
procedure EclWho;
var
  msg: String;
begin
  EclMenu.LoadEclVars(1);
  msg := GDVars.gbStrings[1];
  CharHlp.SelectChar(msg, False, GDVars.curChar);
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument, then recomputes its armor class and redraws the party. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: array[1..4] of Byte;
  id: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  id := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(id);
  morale := EclMenu.GetEclVar(2);
  morale := morale div 2;
  morale := morale or C_Npc.NON_PLAYER;
  GDVars.curChar^.npc := morale;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ SPELL, opcode $3B: looks for the spell its first argument names in each member's spell slots 0 to 80 in turn, and
  stores the slot found, or 255 for none, at its second argument's GBVM address and the member's place at its third's. }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  p: Types.PWork;
  found: Byte;
  innerDone: Byte;
  addr1: Word;
  addr2: Word;
begin
  found := 0;
  EclMenu.LoadEclVars(3);
  spellId := EclMenu.GetEclVar(1);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  slot := 0;
  idx := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (found = 0) do begin
    innerDone := 0;
    slot := 0;
    repeat
      if PSpellRec(p)^.spells[slot] = spellId then
        found := 1
      else if slot < 80 then
        Inc(slot)
      else
        innerDone := 1;
    until (innerDone <> 0) or (found <> 0);
    p := p^.nextCharAddr;
    if (p <> nil) and (found = 0) then
      Inc(idx);
  end;
  if found = 0 then
    slot := 255;
  EclMenu.WriteGbvm(addr1, slot);
  EclMenu.WriteGbvm(addr2, idx);
end;

{ CALL, opcode $2D: runs the engine service its argument's address names, less $7FFF: $AE11 redraws the 3D view when the
  script's pictures or the party's position changed; 1 and 2 start a mirror duel and a duel; $880A waits for Enter and
  $880D asks yes or no into zone 1's menu choice and the compare flags; $8810 converts money; $3201 plays the music or
  sound effect in GDVars.sndEffect; $401F steps the party forward; $401B re-reads the map cell; $E804 shows the next
  frame of the current animation. Any other value does nothing. }
procedure EclCall;
var
  vmAddr: Word;
  magicKey: Word;
  { Unused in this version; see the other implementations of this routine. }
  choice: Word;
begin
  EclMenu.LoadEclVars(1);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  magicKey := vmAddr - $7FFF;
  case magicKey of
    $AE11: begin
             GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
             if GDVars.filesLoaded <> 0 then
               if (GDVars.eclGraphics) or (GDVars.sprShown) or (GDVars.picRegionW) or (GDVars.movedParty) or
                   (GDVars.redrawSky) then begin
                 GDVars.mapRedrawPending := 1;
                 MapView.DisplayMapView;
                 CharHlp.PrintPositionAndTime;
                 GDVars.redrawSky := False;
                 GDVars.picRegionW := False;
                 GDVars.movedParty := False;
                 GDVars.eclGraphics := False;
                 GDVars.sprShown := False;
                 View3D.RefreshCurrentMapCell;
               end;
           end;
    1: EclMenu.CharFightsAlone(1);
    2: EclMenu.CharFightsAlone(0);
    $880A: begin
             choice := EclMenu.MenuHorizontalCharacterSelect('', '~Press Enter to continue.', LightMagenta, White,
                                                             White, True, (GDVars.eclGraphics) and (GDVars.picDrawn));
             TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                           LightGreen, Black, True, '');
           end;
    $880D: begin
             GDVars.gbvmZone1Ptr^[EclVm.MENU_CHOICE] :=
               EclMenu.MenuHorizontalCharacterSelect('', '~Yes ~No', LightMagenta, LightGreen, White, False,
                                                     (GDVars.eclGraphics) and (GDVars.picDrawn));
             TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                           LightGreen, Black, True, '');
             EclMenu.EclCompareInt(GDVars.gbvmZone1Ptr^[EclVm.MENU_CHOICE], 1);
           end;
    $8810:
      Money.convertMoney(3);
    $3201: if GDVars.sndEffect > $7F then
             Music.StartMusic(GDVars.sndEffect and $7F)
           else
             SoundDrv.SoundCommand(GDVars.sndEffect);
    $401F: EclMenu.EclMoveForward;
    $401B: View3D.RefreshCurrentMapCell;
    $E804: begin
             Portrait.displayImageBuf(3, 3, True, GDVars.animationData.frames[GDVars.animationData.current].pic);
             Inc(GDVars.animationData.current);
             if GDVars.animationData.current > GDVars.animationData.count then
               GDVars.animationData.current := 1;
             TextRend.PauseOnly;
           end;
  end;
end;

{ Runs the camp: the script's camp entry (GDVars.eclScriptEntries[3]), the camp menu and, when a rest was interrupted, a
  redraw and the script's interruption entry (GDVars.eclScriptEntries[4]); then redraws the map view and marks the game
  unsaved. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.eclScriptEntries[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.eclScriptEntries[4]);
  end;
  GDVars.mapRedrawPending := 1;
  MapView.DisplayMapView;
  GDVars.recentlySavedGameFlag := 0;
end;

{ PROGRAM's service $12: brings each member to full hit points and enables it, redraws the party, and sets the equal
  flag when any member changed, else the not-equal flag. }
procedure HealPartyForProgram;
var
  p: Types.PWork;
  changed: Byte;
begin
  p := GDVars.creatureList;
  changed := 0;
  while p <> nil do begin
    if (p^.hpCur <> p^.evMaxHp) or (p^.enabled = 0) then begin
      changed := 1;
      p^.enabled := 1;
      p^.hpCur := p^.evMaxHp;
    end;
    p := p^.nextCharAddr;
  end;
  CharHlp.DisplayParty(GDVars.curChar);
  if changed <> 0 then
    EclMenu.EclCompareInt(1, 1)
  else
    EclMenu.EclCompareInt(0, 1);
end;

{ PROGRAM, opcode $38: after restoring a saved current character, runs the service its argument names: 0 CharGen's main
  menu, 3 the party's defeat and EXIT, 6 Money.ConvertMoney(3), 8 the victory ending (Ending.WinGame), 9 the camp
  (keeping the instruction pointer) and EXIT, $11 a cleared screen, $12 HealPartyForProgram. Any other value does
  nothing. }
procedure EclProgram;
var
  prog: Byte;
  savedIp: Word;
  { Unused in this version; see the other implementations of this routine. }
  savedMode: array[1..6] of Byte;
begin
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  EclMenu.LoadEclVars(1);
  prog := EclMenu.GetEclVar(1);
  case prog of
    0: CharGen.MainMenu;
    8: Ending.WinGame;
    9: begin
         savedIp := GDVars.eclScriptInstructionPtr;
         EclVm.EnterCamp;
         GDVars.eclScriptInstructionPtr := savedIp;
         EclVm.EclExit;
       end;
    3: begin
         GDVars.partyDefeated := True;
         EclVm.EclExit;
       end;
    6:
      Money.convertMoney(3);
    $11: TextRend.ClearRect(0, 0, 39, 24);
    $12: EclVm.HealPartyForProgram;
  end;
end;

{ PROTECTION, opcode $3C: clears the monster pictures, reads its argument, which it does not use, runs the copy
  protection and redraws the screen. }
procedure EclProtection;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[0..7] of Byte;
begin
  FillChar(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags), 0);
  GDVars.eclGraphics := False;
  EclMenu.LoadEclVars(1);
  CopyProt.CopyProtection;
  CharHlp.DisplayNoncombatInterface;
end;

{ DUMP, opcode $3E: removes the current character from the party, keeps the character that becomes current as the saved
  character to restore, and redraws the party. }
procedure EclDump;
var
  { Unused in this version; see the other implementations of this routine. }
  index: array[0..1] of Byte;
begin
  Inc(GDVars.eclScriptInstructionPtr);
  CharGen.RemoveCreature(False, True);
  GDVars.savedChar := GDVars.curChar;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ FIND SPECIAL, opcode $3F: clears the compare flags, then sets the equal flag when the current character has the effect
  in its argument, the not-equal flag otherwise. }
procedure EclFindSpecial;
var
  { the check's out value, never read }
  node: Types.PEffectRec;
  v: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  if CharHlp.HasEffect(GDVars.curChar, v, node) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ DESTROY ITEMS, opcode $40: removes the first item in the party that FIND ITEM's test matches: of the item type its
  first argument names (0: any) with the name parts in its other three (a 0 second argument matches any). }
procedure EclTakeItem;
var
  target: Byte;
  p: Types.PWork;
  item: Types.PItemRec;
  nextItem: Types.PItemRec;
  match: Types.TItemNameIds;
begin
  EclMenu.LoadEclVars(4);
  target := EclMenu.GetEclVar(1);
  match[3] := EclMenu.GetEclVar(2);
  match[2] := EclMenu.GetEclVar(3);
  match[1] := EclMenu.GetEclVar(4);
  p := GDVars.creatureList;
  while p <> nil do begin
    item := p^.items;
    while item <> nil do begin
      nextItem := item^.next;
      if ((target = 0) or (target = item^.itemType)) and
          ((match[3] = 0) or EclVm.ItemMatches(match, item^.nameIds)) then begin
        CharHlp.RemoveItem(Types.PWork(p), Types.PItemRec(item));
        CharHlp.RecalcStats(Types.PWork(p));
        Exit;
      end;
      item := nextItem;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ Opcode $41, which Debug.OpcodeName leaves unnamed: awards its second argument's experience to each enabled member when
  its first is nonzero, else to the current character, divided among the classes in which the character has a level. }
procedure EclAwardExperience;
var
  amount: Word;
  whole: Byte;
  p: Types.PWork;
  i: ShortInt;
  classCount: Byte;
  share: Word;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(2);
  whole := EclMenu.GetEclVar(1);
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  GDVars.curCol := 1;
  if whole <> 0 then begin
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                  Black, True,
                                  'Congratulations the party gains ' + CharHlp.Uint16Str(amount) +
                                  ' experience points!');
    TextRend.PauseOnly;
    p := GDVars.creatureList;
    while p <> nil do begin
      classCount := 0;
      for i := 0 to 6 do
        if p^.classLevels[i] > 0 then Inc(classCount);
      share := amount div classCount;
      if p^.enabled <> 0 then
        Inc(p^.experience, share);
      p := p^.nextCharAddr;
    end;
  end else begin
    p := GDVars.curChar;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                  Black, True,
                                  'Congratulations ' + p^.name + ' gains ' + CharHlp.Uint16Str(amount) +
                                  ' experience points!');
    TextRend.PauseOnly;
    classCount := 0;
    for i := 0 to 6 do
      if p^.classLevels[i] > 0 then Inc(classCount);
    share := amount div classCount;
    if p^.enabled <> 0 then
      Inc(p^.experience, share);
  end;
end;

{ Runs the handler for the current opcode. }
procedure DispatchEclCommand;
begin
  case GDVars.curOpcode of
    $00: EclVm.EclExit;
    $01: EclVm.EclGoto;
    $02: EclVm.EclGosubCmd;
    $03: EclVm.EclCompare;
    $04, $05, $06, $07: EclVm.EclArithmetic;
    $08: EclVm.EclRandom;
    $09: EclVm.EclSave;
    $0A: EclVm.EclLoadCharacter;
    $0B: EclVm.EclLoadMonster;
    $0C: EclVm.EclSetupMonster;
    $0D: EclVm.EclApproach;
    $0E: EclVm.EclPicture;
    $0F: EclVm.EclInputNumber;
    $10: EclVm.EclInputString;
    $11, $12: EclVm.EclPrint;
    $13: EclVm.EclReturn;
    $14: EclVm.EclCompareAnd;
    $15: EclVm.EclVMenu;
    $16, $17, $18, $19, $1A, $1B: EclVm.EclIf;
    $1C: EclVm.EclClearMonsters;
    $1D: EclVm.EclPartyStrength;
    $1E: EclVm.EclCheckParty;
    $20: EclVm.EclNewEcl;
    $21, $37: EclVm.EclLoadFiles;
    $22: EclVm.EclPartySurprise;
    $23: EclVm.EclSurprise;
    $24: EclVm.EclCombat;
    $25, $26: EclVm.EclOnGoto;
    $27: EclVm.EclTreasure;
    $28: EclVm.EclRob;
    $29: EclVm.EclEncounter;
    $2A: EclVm.EclGetTable;
    $2B: EclVm.EclHMenu;
    $2C: EclVm.EclParlay;
    $2D: EclVm.EclCall;
    $2E: EclVm.EclDamage;
    $2F, $30: EclVm.EclAndOr;
    $31: EclVm.EclSpriteOff;
    $32: EclVm.EclFindMatchingItem;
    $33: EclVm.EclPrintReturn;
    $34: EclVm.EclClock;
    $35: EclVm.EclSaveTable;
    $36: EclVm.EclAddNpc;
    $38: EclVm.EclProgram;
    $39: EclVm.EclWho;
    $3A: EclVm.EclDelay;
    $3B: EclVm.EclSpell;
    $3C: EclVm.EclProtection;
    $3D: EclVm.EclClearBox;
    $3E: EclVm.EclDump;
    $3F: EclVm.EclFindSpecial;
    $40: EclVm.EclTakeItem;
    $41: EclVm.EclAwardExperience;
  end;
end;

{ Run the script from vmAddr until it stops or the party is defeated; each handler advances the instruction pointer
  itself. While GDConsts.debugOn is set, each opcode's name is written to GDVars.debugFile.
  @param(vmAddr The script address to start at.) }
procedure CallEclScript(vmAddr: Word);
begin
  GDVars.eclScriptInstructionPtr := vmAddr;
  GDVars.eclStop := 0;
  while (GDVars.eclStop = 0) and (not GDVars.partyDefeated) do begin
    GDVars.prevOpcode := GDVars.curOpcode;
    GDVars.curOpcode := GDVars.gbvmScriptPtr^[GDVars.eclScriptInstructionPtr];
    if GDConsts.debugOn <> 0 then begin
      {$I+}
      WriteLn(GDVars.debugFile, Debug.OpcodeName(GDVars.curOpcode));
      {$I-}
    end;
    EclVm.DispatchEclCommand;
  end;
  GDVars.eclStop := 0;
end;

{ Finishes a NEWECL: for each newly loaded block it frees the animation, forgets the saved picture, refreshes the cell
  event, clears the zone-1 leave-map word and runs the block's on-load entry script. If that loads no further block, it
  records the block as the last one entered, redraws the map view (when the view's files are loaded and the party has
  not just left the 3D view, or when it stays in the 3D view), runs two more of the block's entry scripts, then restores
  and redisplays the selected character. A NEWECL in any of those scripts repeats it for the next block. The interface
  state is remembered at the end. }
procedure NewEclDone;
begin
  repeat
    Portrait.freeAnimation(GDVars.animationData);
    GDVars.savedPictureName[0] := #0;
    GDVars.savedPictureId := C_Pic.NO_PICTURE;
    GDVars.newEclFlag := 0;
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 0;
    GDVars.savedChar := GDVars.curChar;
    EclVm.CallEclScript(GDVars.eclScriptEntries[5]);
    if GDVars.newEclFlag = 0 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := GDVars.eclScript;
    if GDVars.newEclFlag = 0 then begin
      if (((GDVars.savedInterfaceState <> C_Ifc.EXPLORING) or (GDVars.interfaceState = C_Ifc.EXPLORING)) and
          (GDVars.filesLoaded <> 0)) or
          ((GDVars.savedInterfaceState = C_Ifc.EXPLORING) and (GDVars.interfaceState = C_Ifc.EXPLORING)) then
        MapView.DisplayMapView;
      GDVars.newEclFlag := 0;
      EclVm.CallEclScript(GDVars.eclScriptEntries[1]);
      if GDVars.newEclFlag = 0 then begin
        EclVm.CallEclScript(GDVars.eclScriptEntries[2]);
        if GDVars.newEclFlag = 0 then begin
          GDVars.curChar := GDVars.savedChar;
          CharHlp.DisplayParty(GDVars.curChar);
        end;
      end;
    end;
  until GDVars.newEclFlag = 0;
  GDVars.savedInterfaceState := GDVars.interfaceState;
end;

procedure GameLoop;
var
  cmd: Char;
begin
  GDVars.savedChar := GDVars.curChar;
  GDVars.mapRedrawPending := 1;
  GDVars.protectionShown := 0;
  GDVars.piecesLoaded := 0;
  GDVars.mapLoaded := 0;
  GDVars.restoreChar := 0;
  GDVars.filesLoaded := 0;
  GDVars.characterSelectionActive := 1;
  GDVars.interfaceState := C_Ifc.EXPLORING;
  GDVars.newEclFlag := 0;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] = 0 then begin
    GDVars.characterSelectionActive := 0;
    if GDVars.demoMode then
      GDVars.eclScript := 82
    else begin
      GDVars.eclScript := 1;
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  end else
    GDVars.eclScript := Byte(GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT]);
  if (GDVars.loadedSavedGameFlag = 0) or (GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] = 0) then
    EclMenu.LoadEclScript(GDVars.eclScript)
  else
    GDVars.filesLoaded := 1;
  EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.eclScriptEntries[5]);
  if GDVars.demoMode then begin
    repeat
      CharGen.RemoveCreature(True, True);
    until GDVars.creatureList = nil;
  end else begin
    if GDVars.newEclFlag = 0 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := GDVars.eclScript
    else
      EclVm.NewEclDone;
    if GDVars.loadedSavedGameFlag <> 0 then begin
      if GDVars.characterSelectionActive = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.mapRedrawPending := 1;
      MapView.DisplayMapView;
    end;
    GDVars.loadedSavedGameFlag := 0;
    repeat
      cmd := Explore.MapMainMenu;
      GDVars.savedChar := GDVars.curChar;
      if GDVars.newEclFlag = 0 then
        GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := GDVars.eclScript;
      while ((GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] > 1) or (UpCase(cmd) = 'E')) and
          (not GDVars.partyDefeated) do begin
        if UpCase(cmd) = 'E' then begin
          EclVm.EnterCamp;
        end else begin
          GDVars.searchModeFlag := GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] and 1;
          GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] := 1;
          GDVars.mapRedrawPending := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.eclScriptEntries[2]);
          if GDVars.newEclFlag <> 0 then
            EclVm.NewEclDone;
          GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] := GDVars.searchModeFlag;
        end;
        if not GDVars.partyDefeated then begin
          cmd := Explore.MapMainMenu;
          GDVars.savedChar := GDVars.curChar;
        end;
      end;
      if not GDVars.partyDefeated then
        EclVm.CallEclScript(GDVars.eclScriptEntries[1]);
      if GDVars.newEclFlag <> 0 then
        EclVm.NewEclDone
      else if not GDVars.partyDefeated then begin
        GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_X] := GDVars.partyPos.mapX;
        GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_Y] := GDVars.partyPos.mapY;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        GDVars.eclGraphics := False;
        GDVars.picDrawn := True;
        EclVm.CallEclScript(GDVars.eclScriptEntries[2]);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone;
      end;
    until GDVars.partyDefeated;
    GDVars.partyDefeated := False;
  end;
end;

{ The initialization hooks FinishNewEcl into GDVars. }
begin
  GDVars.finishNewEclProc := EclVm.FinishNewEcl;
end.
