{ The combat round loop. CombatMain runs rounds until the fight is over: each round it gives the creatures their turns
  in initiative order (CombatAi plays quick-fighting creatures, the command menu the rest) and then ends the round, when
  time advances, effects tick, dying creatures bleed and the party may be asked to continue. The command menu (Move Aim
  Use Cast Turn Guard Quick Delay Bandage Z View Speed End) dispatches to CbtActs, ViewChar and CharHlp; its Move and
  Speed items open this unit's movement and game-speed menus. Combat owns no storage; its state lives in GDVars. }
{$O+,F+,S+}
{$A+}
{$R-}
unit Combat;

interface

{ Run a battle: set the combat interface state and the in-combat spell targeting, set up the fight
  (CombatSt.CombatStart), play rounds until EndOfRound or a missing side ends it, then clean up. }
procedure CombatMain;

implementation

uses GDConsts, GDVars, C_Keys, C_Class, C_Cond, C_Dir, C_Ifc, C_Npc, C_Spell, C_Status, C_Terr, CharHlp,
  Raster, TextRend, FxEngine, Border, GameTime, GameIo, Crt, CbtMap, CombatAi, CombatSt, CbtActs, Types, Magic,
  ViewChar, MenuCore, C_Gbvm;

procedure NextCreature(var next: Types.PWork); forward;

procedure CreatureAction(creature: Types.PWork); forward;

procedure ManualControl(creature: Types.PWork); forward;

procedure CombatMenu(creature: Types.PWork; var ch: Char); forward;

function ContinueBattle: Boolean; forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(creature: Types.PWork; firstCh: Char; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PWork; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(creature: Types.PWork); forward;

{ Free the two cloud lists (FxEngine's arena nodes), the arena and the moving-icon sheet, clear the screen, restore the
  non-combat palette, clear zone 0's underwater flag, and point the cast-target handler back at the non-combat menu. }
procedure CombatDoneCleanup;
var
  next: Types.PArenaNode;
  { Unused in this version; see the other implementations of this routine. }
  nodeCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  effectScan: array[0..7] of Byte;
begin
  while GDVars.linkedListStinkingPtr <> nil do begin
    next := Types.PArenaNode(GDVars.linkedListStinkingPtr)^.next;
    FreeMem(GDVars.linkedListStinkingPtr, SizeOf(Types.TArenaNode));
    GDVars.linkedListStinkingPtr := next;
  end;
  while GDVars.cloudkillList <> nil do begin
    next := Types.PArenaNode(GDVars.cloudkillList)^.next;
    FreeMem(GDVars.cloudkillList, SizeOf(Types.TArenaNode));
    GDVars.cloudkillList := next;
  end;
  FreeMem(GDVars.combatArenaPtr, SizeOf(Types.TArena));
  GDVars.combatArenaPtr := nil;
  Raster.FreePic(GDVars.moveIconSheet);
  TextRend.ClearScreen;
  CbtMap.SetNoncombatPalette;
  GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] := 0;
  @GDVars.spellFps.targetMenu := @Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  done: Boolean;
  creature: Types.PWork;
begin
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  @GDVars.spellFps.targetMenu := @CbtActs.SelectCombatTargets;
  CombatSt.CombatStart;
  done := False;
  if ((not GDVars.demoMode and (GDVars.eligibleCount = 0)) or (GDVars.teamCount[0] = 0) or
      ((GDVars.teamCount[1] = 0) and (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 0))) then
    done := True;
  while done = False do begin
    CbtMap.CountTeams;
    creature := GDVars.creatureList;
    while creature <> nil do begin
      CbtActs.BeginRound(creature);
      creature := creature^.nextCharAddr;
    end;
    GDVars.gbvmZone1Ptr^[C_Gbvm.SURPRISE] := 0;
    Combat.NextCreature(creature);
    while (creature <> nil) and (GDVars.combatTransition = 0) do begin
      Combat.CreatureAction(creature);
      Combat.NextCreature(creature);
    end;
    Combat.EndOfRound(done);
  end;
  Combat.CombatDoneCleanup;
  GDVars.msgDelayFlag := 1;
end;

{ Picks the creature that acts next: the highest initiative, ties going to the higher 1d100 roll and, on a full tie, to
  the later creature in the list.
  @param(next Receives the creature, or nil when no creature has initiative left.) }
procedure NextCreature(var next: Types.PWork);
var
  best: Byte;
  bestRoll: Byte;
  roll: Byte;
  p: Types.PWork;
begin
  best := 0;
  bestRoll := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    roll := FxEngine.RollDice(1, 100);
    if p^.combatAddr^.initiative > best then
      bestRoll := roll;
    if (p^.combatAddr^.initiative >= best) and (roll >= bestRoll) then begin
      bestRoll := roll;
      best := p^.combatAddr^.initiative;
      next := p;
    end;
    p := p^.nextCharAddr;
  end;
  if best = 0 then
    next := nil;
end;

{ One creature's turn: clear its flank counters and guard and run its turn-start effects; with initiative left (20
  becomes 19) center the view on it, run its action-start effects (and condition 21 when it is not casting), then
  CombatAi plays a quick-fighting creature and ManualControl the rest.
  @param(creature The creature.) }
procedure CreatureAction(creature: Types.PWork);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  creature^.combatAddr^.attackerCount := 0;
  creature^.combatAddr^.flankTotal := 0;
  creature^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, creature);
  if creature^.combatAddr^.initiative <= 0 then
    Exit;
  if creature^.combatAddr^.initiative = 20 then
    creature^.combatAddr^.initiative := 19;
  GDVars.curChar := creature;
  GDVars.combatMapVisible := Byte((creature^.hostile = 0) or
                                    CbtMap.CombatIconVisible(creature, 0));
  CbtMap.DisplayMapViewCentered(creature, 2, True);
  CharHlp.RecalcStats(creature);
  GDVars.combatRedraw := 1;
  CharHlp.CombatPrintCreatureInfo(creature);
  FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, creature);
  if creature^.combatAddr^.spellCast = 0 then
    { condition 21, which the confusion effect watches }
    FxEngine.TriggerEffectsWithCondition(21, creature);
  if creature^.combatAddr^.initiative > 0 then
    if creature^.quickfight <> 0 then
      CombatAi.CombatAiControl(creature)
    else
      Combat.ManualControl(creature);
  CbtMap.RedrawArenaCell(CbtMap.CombatCellX(creature),
                         CbtMap.CombatCellY(creature));
end;

{ The player's turn: finish the spell already being cast (spellCast), or, for a creature on the party's side, run the
  command menu until a command ends the turn. A disabled creature only clears its guard.
  @param(creature The creature.) }
procedure ManualControl(creature: Types.PWork);
var
  ch: Char;
  done: Boolean;
  p: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..3] of Byte;
  aimTarget: Pointer;
  spell: Byte;
begin
  GDVars.horizChoice := 1;
  if creature^.enabled <> 0 then begin
    if creature^.combatAddr^.spellCast > 0 then begin
      spell := creature^.combatAddr^.spellCast;
      creature^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, False, True, done);
      done := CharHlp.ClearGuard(creature);
    end else begin
      done := False;
      while (done = False) and (creature^.hostile = 0) do begin
        GDConsts.isArenaClickPending := False;
        Combat.CombatMenu(creature, ch);
        if not GDVars.extFlag then begin
          case ch of
            'Q': begin
                   Combat.TurnOnAuto(creature);
                   MenuCore.ClearBottomLine;
                   GameIo.DrainKeys;
                   Delay(200);
                   done := True;
                   CombatAi.CombatAiControl(creature);
                 end;
            'M': Combat.MoveMenu(creature, ' ', done);
            'V': begin
                   ViewChar.ViewCharMenu(done);
                   CbtActs.RecalcAttacksLeft(creature);
                   if done = False then
                     CharHlp.DisplayCombatInterface;
                 end;
            'A': CbtActs.CombatAimMenu(creature, 255, 1, 0, 1, done, aimTarget);
            'U': begin
                   GDVars.horizChoice := 2;
                   ViewChar.UseItemMenu(done);
                   CbtActs.RecalcAttacksLeft(creature);
                   if done = False then
                     CharHlp.DisplayCombatInterface;
                 end;
            'C': CbtActs.CastSpellCombat(0, 0, done);
            'T': begin
                   CbtActs.CombatTurnUndead(creature);
                   done := CharHlp.ClearGuard(creature);
                 end;
            'Z': begin
                   if CbtActs.VictoryCheat then begin
                     CbtMap.DisplayMapViewCentered(creature, 3, False);
                     done := True;
                   end else
                     CharHlp.PrintBottomLine('That doesn''t work');
                 end;
            'G': done := CharHlp.Guard(creature);
            'D': begin
                   creature^.combatAddr^.initiative := 1;
                   done := True;
                 end;
            'E': done := CharHlp.ClearGuard(creature);
            'B': begin
                   { the result is kept in breathAim, which nothing here reads }
                   GDVars.breathAim := CharHlp.BandageDying(True);
                   done := CharHlp.ClearGuard(creature);
                 end;
            'S': Combat.SpeedMenu;
            ' ': begin
                   p := GDVars.creatureList;
                   while p <> nil do begin
                     if p^.npc < C_Npc.NON_PLAYER then
                       p^.quickfight := 0;
                     p := p^.nextCharAddr;
                   end;
                 end;
          end;
        end else begin
          case ch of
            { Alt-M scan code }
            #50: begin
                    GDVars.quickMagic := GDVars.quickMagic = False;
                    if GDVars.quickMagic then
                      CharHlp.PrintBottomLine('Magic On')
                    else
                      CharHlp.PrintBottomLine('Magic Off');
                  end;
            { Alt-Q scan code }
            #16: begin
                    creature^.combatAddr^.initiative := 20;
                    p := GDVars.creatureList;
                    while p <> nil do begin
                      Combat.TurnOnAuto(p);
                      p := p^.nextCharAddr;
                    end;
                    MenuCore.ClearBottomLine;
                    Delay(200);
                    done := True;
                  end;
          end;
        end;
        if done = False then begin
          CbtMap.DisplayMapViewCentered(creature, 2, True);
          GDVars.combatRedraw := 1;
          CharHlp.CombatPrintCreatureInfo(creature);
        end;
      end;
    end;
  end else
    done := CharHlp.ClearGuard(creature);
end;

{ Build the command list and run the horizontal menu until an accepted key arrives. hasSpell doubles as the menu's
  extended-key answer.
  @param(creature The creature whose commands are offered.)
  @param(ch Receives the command key, or the scan code of Alt-Q or Alt-M.) }
procedure CombatMenu(creature: Types.PWork; var ch: Char);
var
  menu: String[80];
  i: Byte;
  hasSpell: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  lastTarget: array[1..4] of Byte;
begin
  menu := '';
  if creature^.combatAddr^.movement > 0 then
    menu := menu + 'Move ';
  menu := menu + 'Aim ';
  if creature^.numberOfItems > 0 then
    menu := menu + 'Use ';
  hasSpell := False;
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
    if creature^.memorizedSpells[i] in [1..100] then
      hasSpell := True;
  if hasSpell and (creature^.combatAddr^.castAllowed <> 0)
     and (GDVars.gbvmZone0Ptr^[C_Gbvm.ANTI_MAGIC] = 0) then
    menu := menu + 'Cast ';
  if ((CbtActs.TotalClassLevel(creature, C_Class.CLERIC_LEVEL) > 0) or
      (CbtActs.TotalClassLevel(creature, C_Class.PALADIN_LEVEL) > 2))
     and (creature^.combatAddr^.usedTurnUndead = 0) then
    menu := menu + 'Turn ';
  if not CharHlp.HasRangedWeapon(creature)
     or CharHlp.HasThrowableWeapon(creature) then
    menu := menu + 'Guard ';
  menu := menu + 'Quick ';
  menu := menu + '@Delay ';
  if CharHlp.BandageDying(False) then
    menu := menu + 'Bandage ';
  if GDVars.superMode <> 0 then
    menu := menu + 'Z ';
  menu := menu + 'View Speed End';
  repeat
    GDVars.joyClickA := 1;
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, hasSpell);
    GDVars.joyClickA := 0;
    if hasSpell then
      if not (ch in [#16, #50]) then
        ch := C_Keys.NONE;
  until ch in [#16, ' ', #50, 'A', 'B', 'C', 'D', 'E', 'G', 'M', 'Q', 'S', 'T', 'U', 'V', 'Z'];
  TextRend.PrintSpaces(0, 23, Black, 40);
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

{ Ask 'Continue Battle:'.
  @returns(True on Y.) }
function ContinueBattle: Boolean;
begin
  Border.ClearBox(23, 1, 38, 21);
  ContinueBattle := MenuCore.YesNoMenuClear('Continue Battle:', LightMagenta, LightGreen, White) = 'Y';
end;

{ End the round: time advances, round-end and terrain effects tick, and dying creatures bleed toward death. Then decide
  whether the fight is over, the round limit included, and when the hostile side is gone let the player choose to fight
  on.
  @param(done Set when the fight is over.) }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  { counted and never read }
  count: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  Inc(GDVars.combatRoundCounterCount);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.creatureList;
  count := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.ROUND_END, p);
    FxEngine.ConsiderTerrainEffects(p, 0);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(count);
    p := p^.nextCharAddr;
  end;
  if CharHlp.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CbtMap.CountTeams;
  CbtMap.ScrollView(GDVars.combatArenaPtr^.ox + 3, GDVars.combatArenaPtr^.oy + 3, 255,
                    C_Dir.CENTER);
  if ((not GDVars.demoMode and (GDVars.eligibleCount = 0)) or (GDVars.teamCount[0] = 0) or
      ((GDVars.teamCount[1] = 0) and (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 0)) or
      (GDVars.combatTransition <> 0) or (GDVars.combatRoundCounterCount >= GDVars.roundLimit)) then
    done := True;
  if (GDVars.eligibleCount <> 0) and (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0) and
      (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 0) and not GDVars.demoMode then
    if Combat.ContinueBattle then
      done := False;
end;

{ Move one cell at a time by the direction keys, attacking a creature in the way and offering to flee toward terrain 0
  (off the arena), until the movement is spent or the player stops; Escape undoes the move. firstCh seeds the first key.
  @param(creature The moving creature.)
  @param(firstCh The first key, or ' ' to ask for one.)
  @param(done Set when the move ends the creature's turn.) }
procedure MoveMenu(creature: Types.PWork; firstCh: Char; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: ShortInt;
  startY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Char;
  hasStinkCloud: Byte;
  hasCloudkill: Byte;
  moveCost: Byte;
begin
  GDVars.arenaMoveActive := 1;
  savedMove := creature^.combatAddr^.movement;
  savedDir := creature^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(creature);
  startY := CbtMap.CombatCellY(creature);
  ch := firstCh;
  done := False;
  dir := C_Dir.CENTER;
  while (creature^.combatAddr^.movement > 1) and (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) do begin
    Border.ClearBox(24, 24, 39, 24);
    if ch = ' ' then
      ch :=
        MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + CharHlp.Uint8Str(creature^.combatAddr^.movement div 2) +
        ' ', '', LightGreen, LightGreen, White, True, False, GDVars.doneRoundFlag);
    case ch of
      { Escape: undo the move }
      C_Keys.NONE: begin
            creature^.combatAddr^.movement := savedMove;
            CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(creature));
            done := CbtMap.IsValidCreatureLoc(creature, startX, startY, False) = False;
            CbtMap.ScrollView(CbtMap.CombatCellX(creature),
                              CbtMap.CombatCellY(creature), 0, C_Dir.CENTER);
            creature^.combatAddr^.direction := savedDir;
            dir := C_Dir.CENTER;
          end;
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
    else
      dir := C_Dir.CENTER;
    end;
    if dir < C_Dir.CENTER then begin
      CbtMap.SetCreatureFacing(creature, dir, 0, 0);
      CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx, hasStinkCloud, hasCloudkill);
      if crIdx > 0 then
        Combat.MeleeAttack(creature, GDVars.creaturePtr[crIdx], done)
      else if terrIdx = 0 then begin
        if (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1) or
            (MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) = 'Y') then
          done := CbtActs.AttemptFlee(creature, dir)
        else
          done := False;
      end else begin
        if Odd(dir) then
          moveCost := GDConsts.terrainInfo[terrIdx].cost * 3
        else
          moveCost := GDConsts.terrainInfo[terrIdx].cost * 2;
        if GDConsts.terrainInfo[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE then
          moveCost := C_Terr.TERRAIN_IMPASSABLE;
        if moveCost > creature^.combatAddr^.movement then
          CharHlp.PrintBottomLine('can''t go there')
        else begin
          CbtActs.AttacksOfOpportunity(creature, dir);
          if creature^.enabled = 0 then
            done := CharHlp.ClearGuard(creature)
          else begin
            if creature^.combatAddr^.movement > 0 then
              CbtActs.CombatMoveCreature(creature, dir);
            if creature^.enabled = 0 then
              done := CharHlp.ClearGuard(creature);
            FxEngine.ConsiderTerrainEffects(creature, 1);
            if CharHlp.IsHelpless(creature) then
              done := CharHlp.ClearGuard(creature);
          end;
        end;
      end;
    end;
    if (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) then
      ch := ' ';
  end;
  if creature^.combatAddr^.movement < 2 then
    creature^.combatAddr^.movement := 0;
  GDVars.arenaMoveActive := 0;
end;

{ Makes MoveMenu's attack on a creature in the way, refused with a ranged weapon that cannot be thrown. Once an attack
  on an ally is confirmed, the target is locked, and a sweep is tried before a normal attack.
  @param(att The attacker.)
  @param(def The creature attacked.)
  @param(done Receives True when the attacker's actions are over; left as it was when the attack is refused.) }
procedure MeleeAttack(att, def: Types.PWork; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    if CbtActs.SweepAttack(att, def) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(att, def);
      CbtActs.MakeAttack(att, def, False, nil, done);
    end;
  end;
end;

{ Adjusts the game delay: Slower (offered below 9) raises it, Faster (offered above 0) lowers it, and Exit or Escape
  leaves. }
procedure SpeedMenu;
var
  menu: String[40];
  query: String[40];
  ch: Char;
begin
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + CharHlp.Uint8Str(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.doneRoundFlag);
    case ch of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(creature The creature to hand to the AI.) }
procedure TurnOnAuto(creature: Types.PWork);
begin
  creature^.quickfight := 1;
  if (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.hostile = creature^.hostile) then begin
    creature^.combatAddr^.other := nil;
  end;
end;

begin
end.
