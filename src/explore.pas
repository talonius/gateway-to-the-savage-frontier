{ The 3D map's main menu, MapMainMenu, and the step it asks for, ResolveMovement: through an open side, or at a locked
  door the Bash, Pick and Knock menu. The step wraps at the map's edges; a move off the edge is MoveForward's, which
  sets zone 1's leave-map flag. movementMenus is in GDConsts. }
{$O+,F+,S+,A+}
unit Explore;

interface

{ Carries out the step the map menu asked for. In the 3D view, an open way (barrier type 1) moves the party; a locked
  barrier (types 2 and 3) offers Bash, Pick and Knock as the door flags, the party's thieves and its memorized Knock
  spells allow, and when nothing can be offered ChangeBarrierImpassable is called. On a held barrier (type 3) Pick only
  uses up the attempt. When the zone's move lock is 255 the lock is cleared instead. The portraits and the big animation
  are freed on the way out. }
procedure ResolveMovement;

{ Runs the map menu until a command ends it: a move ahead, Encamp or Look, or a developer command.
  @returns(The key of the command that ended it.) }
function MapMainMenu: Char;

implementation

uses Crt, GDConsts, GDVars, C_Keys, DevMenu, GeoEdit, View3D, TextRend, Camp, FxEngine,
  ClassCal, SoundDrv, GameTime, MenuCore, ViewChar, GameIo, CharHlp, Border,
  Portrait, Raster, Types, C_Status, C_Class, C_Dir, C_Ifc, C_Msg, C_Pic, C_Spell, C_Gbvm;

const
  { the ECL entry Look runs }
  ECL_ENTRY_SEARCH = 2;
  { spellNames[31] is Knock }
  SPELL_KNOCK = 31;
  { thiefSkills' Open Locks entry, the second skill }
  OPEN_LOCKS = $EB;
  { SoundDrv's footstep, as CbtActs plays it for a combat step }
  STEP_SOUND = 10;
  { zone 1's move lock while the party may not move }
  MOVE_LOCKED = 255;

{ Meant to clear the barrier bits of one side of a map cell. Note: it exits at once, so nothing is changed.
  @param(x Cell column.)
  @param(y Cell row.)
  @param(facing Side of the cell.) }
procedure ChangeBarrierImpassable(x, y, facing: ShortInt);
begin
  Exit;
  case Byte(facing) of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC;
  end;
end;

{ Opens the barrier on one side of a 3D map cell (barrier type 1). A cell outside the 16x16 map is ignored.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.) }
procedure ChangeBarrierPassable(x, y, facing: ShortInt);
begin
  if (x < 0) or (x > SizeOf(GDVars.map3d^.barriers[0]) - 1) or (y < 0) or
      (y > SizeOf(GDVars.map3d^.barriers) div SizeOf(GDVars.map3d^.barriers[0]) - 1) then Exit;
  case Byte(facing) of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F or $40;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF or $10;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3 or $04;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC or $01;
  end;
end;

{ Tells whether any party member has levels in a class, counting a former class only while ClassCal.EarlierClassActive
  says it still applies.
  @param(idx The class.)
  @returns(True when a member has the class.) }
function PartyHasClass(idx: ShortInt): Boolean;
var
  p: Types.PWork;
  found: Boolean;
begin
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    if (p^.classLevels[idx] > 0) or
        ((p^.classLevels2[idx] > 0) and (ClassCal.EarlierClassActive(Types.PWork(p)) <> 0)) then
      found := True;
    p := p^.nextCharAddr;
  end;
  PartyHasClass := found;
end;

{ Has each party member in turn try to bash open the barrier ahead until one succeeds, by Strength: a held barrier (type
  3) needs Strength 18/91 or more, and a weaker member marks it unbashable; other barriers use the plain Strength table.
  On success both sides of the barrier become open.
  @returns(True when the barrier was opened.) }
function BashDoor: Boolean;
var
  p: Types.PWork;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do begin
      if
         View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
         = 3 then begin
        case strCur of
          18: case mgExStrCur of
                 91..99: if FxEngine.RollDice(1, 6) = 1 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 2 then success := True;
               else
                 GDVars.doorOpeningBoolean[0] := 0;
               end;
          19, 20: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          21, 22: if FxEngine.RollDice(1, 6) <= 4 then success := True;
          23: if FxEngine.RollDice(1, 6) <= 5 then success := True;
          24: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          25: success := True;
        else
          GDVars.doorOpeningBoolean[0] := 0;
        end;
      end else
        case strCur of
          3..7: if FxEngine.RollDice(1, 6) = 1 then success := True;
          8..15: if FxEngine.RollDice(1, 6) <= 2 then success := True;
          16..17: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          18: case mgExStrCur of
                 0..50: if FxEngine.RollDice(1, 6) <= 3 then success := True;
                 51..99: if FxEngine.RollDice(1, 6) <= 4 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 5 then success := True;
               end;
          19, 20: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          21: if FxEngine.RollDice(1, 10) <= 9 then success := True;
          22, 23: if FxEngine.RollDice(1, 12) <= 11 then success := True;
          24: if FxEngine.RollDice(1, 20) <= 19 then success := True;
          25: success := True;
        end;
    end;
    p := p^.nextCharAddr;
  end;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDX[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDY[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  BashDoor := success;
end;

{ Has the party pick the lock of the door ahead: each member in turn rolls d100 against its Open Locks skill, and the
  roll counts only for a member who is okay. The Pick choice closes at this door whatever the result. Success opens the
  door from both sides.
  @returns(True when the door was opened.) }
function PickLock: Boolean;
var
  p: Types.PWork;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[Explore.OPEN_LOCKS])
        and (status = C_Status.OKAY) then
        success := True;
    p := p^.nextCharAddr;
  end;
  GDVars.doorOpeningBoolean[1] := 0;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDX[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDY[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  PickLock := success;
end;

{ Finds a memorized spell in a character's spell slots.
  @param(spellId The spell.)
  @param(cr The character.)
  @returns(The slot, or 255 when the spell is not memorized.) }
function FindMemorizedSpell(spellId: Byte; cr: Types.PWork): Byte;
var
  i: Byte;
begin
  i := 0;
  while (i <= C_Spell.MEMORIZED_SPELL_SLOTS - 1) and (cr^.memorizedSpells[i] <> spellId) do
    Inc(i);
  if i <= C_Spell.MEMORIZED_SPELL_SLOTS - 1 then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Finds a party member with a spell memorized.
  @param(spellId The spell.)
  @returns(The first party member with it memorized, or nil.) }
function FindCharWithSpell(spellId: Byte): Types.PWork;
var
  p: Types.PWork;
begin
  p := GDVars.creatureList;
  while (p <> nil) and (Explore.FindMemorizedSpell(spellId, p) = 255) do
    p := p^.nextCharAddr;
  FindCharWithSpell := p;
end;

{ Casts the first memorized Knock in the party, marking the slot to be relearned. Unlike BashDoor and PickLock it leaves
  the barrier as it is: the party steps through, and the door stays locked.
  @returns(True when a member cast it.) }
function PartyCastsKnock: Boolean;
var
  p: Types.PWork;
begin
  p := Explore.FindCharWithSpell(Explore.SPELL_KNOCK);
  if p <> nil then begin
    p^.memorizedSpells[Explore.FindMemorizedSpell(Explore.SPELL_KNOCK,
                                                  p)] := Explore.SPELL_KNOCK or C_Spell.PENDING_FLAG;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ A move ahead: the step itself is ResolveMovement's. Through a side that is not blocked, a step off the map clamps the
  party to the edge and sets zone 1's leave-map flag. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GDVars.partyPos.mapX;
  ny := GDVars.partyPos.mapY;
  f := GDVars.partyPos.facing;
  GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 0;
  if
     View3D.GetBarrierType(nx, ny, f)
     <> 0 then begin
    Inc(nx, GDConsts.dirDX[f]);
    Inc(ny, GDConsts.dirDY[f]);
    if nx > SizeOf(GDVars.map3d^.barriers[0]) - 1 then begin
      GDVars.partyPos.mapX := SizeOf(GDVars.map3d^.barriers[0]) - 1;
      GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GDVars.partyPos.mapX := 0;
      GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny > SizeOf(GDVars.map3d^.barriers) div SizeOf(GDVars.map3d^.barriers[0]) - 1 then begin
      GDVars.partyPos.mapY := SizeOf(GDVars.map3d^.barriers) div SizeOf(GDVars.map3d^.barriers[0]) - 1;
      GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GDVars.partyPos.mapY := 0;
      GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 1;
    end;
  end;
end;

{ Steps the party ahead, wrapping at the map's edges, re-reads the cell, re-arms the three door commands and advances
  the clock one unit of digit 1, or while searching one of digit 2, ten times as long (GDConsts.unitScale). }
procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(Explore.STEP_SOUND);
  Inc(GDVars.partyPos.mapX, GDConsts.dirDX[GDVars.partyPos.facing]);
  Inc(GDVars.partyPos.mapY, GDConsts.dirDY[GDVars.partyPos.facing]);
  if GDVars.partyPos.mapX < 0 then GDVars.partyPos.mapX := SizeOf(GDVars.map3d^.barriers[0]) - 1;
  if GDVars.partyPos.mapX > SizeOf(GDVars.map3d^.barriers[0]) - 1 then GDVars.partyPos.mapX := 0;
  if GDVars.partyPos.mapY <
      0 then GDVars.partyPos.mapY := SizeOf(GDVars.map3d^.barriers) div SizeOf(GDVars.map3d^.barriers[0]) - 1;
  if GDVars.partyPos.mapY >
      SizeOf(GDVars.map3d^.barriers) div SizeOf(GDVars.map3d^.barriers[0]) - 1 then GDVars.partyPos.mapY := 0;
  FillChar(GDVars.doorOpeningBoolean, SizeOf(GDVars.doorOpeningBoolean), 1);
  View3D.RefreshCurrentMapCell;
  if GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] and 1 > 0 then
    GameTime.AdvanceTime(1, 2)
  else
    GameTime.AdvanceTime(1, 1);
end;

{ The offset into movementMenus of the menus with the developer menu's G, while GDVars.superMode is set.
  @returns(3 in super mode, else 0.) }
function MovementMenuMode: Byte;
begin
  if GDVars.superMode <> 0 then
    MovementMenuMode := 3
  else
    MovementMenuMode := 0
end;

function MapMainMenu: Char;
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuText: String[40];
  viewDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  oldZone: Pointer;
begin
  GDVars.gbvmZone1Ptr^[C_Gbvm.MOVE_LOCK] := 0;
  case Char(GDVars.interfaceState) of
  Chr(C_Ifc.EXPLORING): begin
    done := False;
    repeat
      GDVars.canClickParty := 1;
      if GDVars.partyClickMode = 0 then begin
        if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then
          c := MenuCore.MenuHorizontal('', GDConsts.movementMenus[Explore.MovementMenuMode + 1], LightMagenta,
                                       LightGreen, White,
                                       True, False, ext)
        else
          c := MenuCore.MenuHorizontal('', GDConsts.movementMenus[Explore.MovementMenuMode + 2], LightMagenta,
                                       LightGreen, White,
                                       True, False, ext)
      end else
        c := MenuCore.MenuHorizontal('Move (Use arrow keys):', GDConsts.movementMenus[3], LightMagenta, LightGreen,
                                     White, True,
                                     False, ext);
      GDVars.canClickParty := 0;
      if GDVars.partyClickMode = 0 then begin
        if not ext then begin
          case c of
          'M': begin
                 MenuCore.ClearBottomLine;
                 GDVars.partyClickMode := 1
               end;
          { the start-up password forces it }
          'A': if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0) and
            ((GDVars.gbvmZone0Ptr^[C_Gbvm.NO_AUTOMAP] = 0) or
             (ParamStr(2) = GDVars.commandText)) then begin
                 GDVars.automapOn := GDVars.automapOn = False;
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end else
                 TextRend.PrintAndPause('Not Here', Yellow, Black);
          'C': if GDVars.curChar^.status = C_Status.OKAY then begin
                 GDVars.horizChoice := 1;
                 Camp.NoncombatCastMenu;
               end;
          'V': begin
                 GDVars.horizChoice := 1;
                 ViewChar.ViewCharMenu(viewDone);
                 GameIo.KbdNoop;
               end;
          'E': begin
                 done := True;
                 GDVars.horizChoice := 1;
               end;
          'S': GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] := GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] xor 1;
          'L': begin
                 GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] := GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] or 2;
                 GameTime.AdvanceTime(1, 2);
                 GDVars.eclScriptInstructionPtr := GDVars.eclScriptEntries[Explore.ECL_ENTRY_SEARCH];
                 done := True;
               end;
          'G': if GDVars.superMode <> 0 then
                 DevMenu.DeveloperMenu(done);
          end;
        end else begin
          ViewChar.SelectPrevNextChar(c);
          CharHlp.DisplayParty(GDVars.curChar);
          if c = C_Keys.DELETE_KEY then
            GeoEdit.GeoEditor
        end
      end else if not GDVars.extFlag then begin
        case c of C_Keys.NONE, 'E': GDVars.partyClickMode := 0 end
      end else begin
          case c of
          C_Keys.UP: begin
                 Explore.MoveForward;
                 done := True;
               end;
          C_Keys.DOWN: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
                 SoundDrv.SoundCommand(Explore.STEP_SOUND);
                 View3D.RefreshCurrentMapCell;
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
          C_Keys.LEFT: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
                 SoundDrv.SoundCommand(Explore.STEP_SOUND);
                 View3D.RefreshCurrentMapCell;
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
          C_Keys.RIGHT: begin
                 GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
                 SoundDrv.SoundCommand(Explore.STEP_SOUND);
                 View3D.RefreshCurrentMapCell;
                 View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
               end;
        else begin
          ViewChar.SelectPrevNextChar(c);
          CharHlp.DisplayParty(GDVars.curChar);
          if c = C_Keys.DELETE_KEY then
            GeoEdit.GeoEditor;
        end;
        end;
          end;
      CharHlp.PrintPositionAndTime;
    until done;
    end;
  end;
  if GDVars.bottomMsgCleared = 0 then begin
    Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    GDVars.bottomMsgCleared := 1;
  end;
  MapMainMenu := c;
end;

procedure ResolveMovement;
var
  moved: Boolean;
  extendedKey: Boolean;
  menuStr: String[40];
  choice: Char;
begin
  moved := False;
  case Char(GDVars.interfaceState) of
  Chr(C_Ifc.EXPLORING):
    if GDVars.gbvmZone1Ptr^[C_Gbvm.MOVE_LOCK] < Explore.MOVE_LOCKED then begin
      GDVars.mapRedrawPending := 1;
      case View3D.GetBarrierType
        (GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) of
        1: moved := True;
        2: begin
             menuStr[0] := #0;
             if GDVars.doorOpeningBoolean[0] <> 0 then
               menuStr := 'Bash';
             if (GDVars.doorOpeningBoolean[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF_LEVEL) then
               menuStr := menuStr + ' Pick';
             if (GDVars.doorOpeningBoolean[2] <> 0) and (Explore.FindCharWithSpell(Explore.SPELL_KNOCK) <> nil) then
               menuStr := menuStr + ' Knock';
             menuStr := menuStr + ' Exit';
             if menuStr = ' Exit' then
               Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
             else begin
               choice := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen, White, False, False,
                                                 extendedKey);
               case choice of
                 'B': moved := Explore.BashDoor;
                 'P': moved := Explore.PickLock;
                 'K': moved := Explore.PartyCastsKnock;
               end;
             end;
           end;
        { the magic lock: Pick only spends the party's try }
        3: begin
             menuStr[0] := #0;
             if GDVars.doorOpeningBoolean[0] <> 0 then
               menuStr := 'Bash';
             if (GDVars.doorOpeningBoolean[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF_LEVEL) then
               menuStr := menuStr + ' Pick';
             if (GDVars.doorOpeningBoolean[2] <> 0) and (Explore.FindCharWithSpell(Explore.SPELL_KNOCK) <> nil) then
               menuStr := menuStr + ' Knock';
             menuStr := menuStr + ' Exit';
             if menuStr = ' Exit' then
               Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing)
             else begin
               choice := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen, White, False, False,
                                                 extendedKey);
               case choice of
                 'B': moved := Explore.BashDoor;
                 'P': GDVars.doorOpeningBoolean[1] := 0;
                 'K': moved := Explore.PartyCastsKnock;
               end;
             end;
           end;
      end;
      if moved then
        Explore.MovePartyForward3D;
      CharHlp.PrintPositionAndTime;
    end else
      GDVars.gbvmZone1Ptr^[C_Gbvm.MOVE_LOCK] := 0;
  end;
  Portrait.FreeAnimation(GDVars.animationData);
  Raster.FreePic(Types.PImgBuf(GDVars.portraitCache[1].pic));
  Raster.FreePic(Types.PImgBuf(GDVars.portraitCache[2].pic));
  GDVars.portraitCache[1].pictureId := C_Pic.NO_PICTURE;
  GDVars.portraitCache[2].pictureId := C_Pic.NO_PICTURE;
end;

begin
end.
