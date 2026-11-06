{ The computer's side of combat. CombatAiControl plays one turn of a creature under computer control, whether a monster,
  an NPC or a quick-fighting party member. It may re-roll the creature's stance (the row of aiDirOffsets its steps try)
  and checks its morale; then it finishes a spell being cast, or uses a magic item, or turns undead, or readies its best
  weapon and, until its actions run out, casts a memorized spell or moves and attacks. A key press can take over: Alt-M
  toggles quick magic, Space stops quick fighting, Alt-X is CbtActs' victory cheat. Its stepper's last step direction,
  stall count and move state are in GDVars. }
{$O+,F+}
{$A+}
{$R-}
{$S+}
unit CombatAi;

interface

uses Types, C_Class, C_Cond, C_Dir, C_Effect, C_Equip, C_Item, C_Msg, C_Npc, C_Spell, C_Status, C_Terr, GDConsts,
  GDVars, CbtMap, Pathing, CbtActs, Magic, ViewChar, CharHlp, FxEngine, ClassCal, MenuCore, TextRend, GameIo, Crt,
  C_Gbvm;

{ Play one turn of a creature under computer control: its morale check, then a spell, an item, turning undead, or its
  weapons.
  @param(cr The creature whose turn it is.) }
procedure CombatAiControl(cr: Types.PWork);

implementation

const
  { Types.TWork.equipped's shield slot }
  EQUIP_SHIELD = 1;
  { Types.TWork.charClass's value for a magic-user }
  CLASS_MAGE = 5;

function TurnUndeadAi(cr: Types.PWork): Boolean; forward;

function SelectItemToUse(cr: Types.PWork): Boolean; forward;

function SelectSpellToCast(cr: Types.PWork): Boolean; forward;

function AiMoveAttack(cr: Types.PWork): Boolean; forward;

function FinishRound(cr: Types.PWork): Boolean; forward;

function CheckKeystroke(cr: Types.PWork): Boolean; forward;

function CheckMorale(cr: Types.PWork): Boolean; forward;

procedure EquipWeaponAndArmor(cr: Types.PWork); forward;

function DecideCastSpell(cr: Types.PWork; spell, minPri: Byte): Boolean; forward;

procedure CombatAiControl(cr: Types.PWork);
var
  stance: Byte;
  done: Boolean;
  dir: Byte;
begin
  done := CombatAi.CheckKeystroke(cr);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if cr^.enabled = 0 then
    done := CharHlp.ClearGuard(cr);
  stance := cr^.combatAddr^.aiStance;
  if (stance = 0) or (stance > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    stance := FxEngine.RollDice(1, 8);
    if stance = 8 then
      stance := FxEngine.RollDice(1, 2) + 4
    else
      stance := FxEngine.RollDice(1, 4);
  end;
  cr^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(cr);
  if (cr^.combatAddr^.fleeing <> 0) and (cr^.combatAddr^.turned = 0) then
    CharHlp.PrintCreatureMessage(cr, 'flees in panic', C_Msg.MESSAGE_ROW, True);
  if not done then begin
    if cr^.combatAddr^.spellCast > 0 then begin
      Magic.CastSpell(cr^.combatAddr^.spellCast, True, True, done);
      done := CharHlp.ClearGuard(cr);
    end else if CombatAi.SelectItemToUse(cr) then
      done := CharHlp.ClearGuard(cr)
    else if CombatAi.TurnUndeadAi(cr) then
      done := CharHlp.ClearGuard(cr)
    else begin
      CombatAi.EquipWeaponAndArmor(cr);
      done := CombatAi.CheckKeystroke(cr);
      while not done do begin
        if (cr^.combatAddr^.castAllowed <> 0) and CombatAi.SelectSpellToCast(cr) then
          done := True
        else if CbtActs.AcquireTarget(cr, 255, 1, 0)
                and (cr^.combatAddr^.initiative > 0)
                and (cr^.enabled <> 0) then
          done := CombatAi.AiMoveAttack(cr)
        else
          done := CombatAi.FinishRound(cr);
      end;
    end;
  end;
  if (cr^.enabled <> 0) and (cr^.combatAddr^.other <> nil) then begin
    dir := CbtActs.DirTowardTarget(cr, cr^.combatAddr^.other);
    if dir <> cr^.combatAddr^.direction then
      CbtMap.SetCreatureFacing(cr, dir, 0, 0);
  end;
  done := CombatAi.CheckKeystroke(cr);
end;

{ Turn undead when cr has not tried it this fight, has a cleric level, and an undead enemy is there.
  @param(cr The creature.)
  @returns(True when it turned undead.) }
function TurnUndeadAi(cr: Types.PWork): Boolean;
var
  tgt: Pointer;
begin
  if (cr^.combatAddr^.usedTurnUndead = 0)
     and (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(cr), C_Class.CLERIC_LEVEL)) > 0)
     and CbtActs.FindTurnUndeadTarget(cr, tgt) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(cr);
  end else
    TurnUndeadAi := False;
end;

{ Whether cr should cast spell, of AI priority at least minPri: a helpful spell unless it is a cure with no one to cure
  (CbtActs.FindCureTarget), an aimed one when some enemy is in range and, for an area spell, no enemy's cell as the aim
  point would catch a creature on cr's side that fails its save.
  @param(cr The caster.)
  @param(spell The spell.)
  @param(minPri The lowest AI priority accepted.)
  @returns(True when the spell is worth casting.) }
function DecideCastSpell(cr: Types.PWork; spell, minPri: Byte): Boolean;
var
  tgt: Types.PWork;
  cnt: Byte;
  j: Byte;

  { Whether spell aimed at x, y would catch a creature on the caster's side that fails its save. }
  function AreaHitsNonEnemy(x, y: ShortInt; spell: Byte): Boolean;
  var
    i: Byte;
    filter: Byte;
  begin
    AreaHitsNonEnemy := False;
    if GDVars.curChar^.hostile = 0 then
      filter := 254
    else
      filter := 8;
    Pathing.BuildTargetList(x, y, GDConsts.spellTable[spell].aiRadius, 255, 1, GDVars.combatArenaPtr);
    for i := 1 to GDVars.targetCount do
      if (ShortInt(CharHlp.NotHostile(GDVars.curChar)) <>
          GDVars.creaturePtr[GDVars.combatTargetData[i].idx]^.hostile) and
          (GDConsts.spellTable[spell].saveResult <> 1) and
          (not FxEngine.RollSavingThrow(GDVars.creaturePtr[GDVars.combatTargetData[i].idx],
                                        GDConsts.spellTable[spell].saveType, filter)) then
        AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellTable[spell].aiPriority < minPri then Exit;
  if (GDConsts.spellTable[spell].offensive = 0)
     and CbtActs.FindCureTarget(spell, cr, tgt) then
    DecideCastSpell := True
  else begin
    cnt := CharHlp.CountTargets(Pointer(cr), Magic.CalcSpellRange(spell));
    if cnt > 0 then
      if GDConsts.spellTable[spell].aiRadius = 0 then
        DecideCastSpell := True
      else begin
        { one unsafe aim rejects the spell }
        for j := 1 to cnt do
          if AreaHitsNonEnemy(GDVars.combatArenaLocation[GDVars.potentialTargetCreature[j]].x,
                              GDVars.combatArenaLocation[GDVars.potentialTargetCreature[j]].y,
                              spell) then Exit;
        DecideCastSpell := True;
      end;
  end;
end;

function AiCanStep(cr: Types.PWork; attempt, baseDir: Byte; var edge: Boolean): Boolean; forward;

procedure AiMoveStep(cr: Types.PWork); forward;

function CalcWeaponPriority(cr: Types.PWork; it: Types.PItemRec): Byte; forward;

function FindMissile(cr: Types.PWork; w: Types.PItemRec; var sel: Types.PItemRec): Boolean; forward;

{ Uses an equipped item's spell when the creature may use items, an enemy team remains and there is no antimagic. Over
  1d7 passes the lowest AI priority accepted falls from 7, and the first equipped item that is not readable, has a
  special below $80 and a spell DecideCastSpell accepts is used. Item effects above 56 map to the spell entries 23
  lower.
  @param(cr The creature.)
  @returns(True when an item was used.) }
function SelectItemToUse(cr: Types.PWork): Boolean;
var
  lowPri: Byte;
  roll: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
  effect: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Pointer;
  it: Types.PItemRec;
  chosen: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosen := nil;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  if (cr^.combatAddr^.itemUseAllowed <> 0)
     and (GDVars.teamCount[ShortInt(CharHlp.NotHostile(cr))] > 0)
     and (GDVars.gbvmZone0Ptr^[C_Gbvm.ANTI_MAGIC] = 0) then
    for i := 1 to roll do begin
      it := cr^.itemsAddr;
      while (it <> nil) and (chosen = nil) do begin
        effect := it^.effect;
        slot := GDVars.baseItems[it^.itemType].slot;
        if (not Magic.ItemReadable(it))
           and (it^.special < $80)
           and (it^.equipped <> 0)
           and (effect > 0) then begin
          { item effects 80.. are spell rows 57.. }
          if effect > 56 then effect := effect - 23;
          if CombatAi.DecideCastSpell(cr, effect, lowPri) then chosen := it;
        end;
        it := it^.next;
      end;
      Dec(lowPri);
    end;
  if chosen <> nil then begin
    ViewChar.UseItem(chosen, used);
    SelectItemToUse := True;
  end;
end;

{ For a monster, or in quick or demo mode, try up to a d7 of rounds of three random memorized spells, each round
  accepting a lower priority, and cast the first DecideCastSpell accepts.
  @param(cr The creature.)
  @returns(True when a spell was cast or begun.) }
function SelectSpellToCast(cr: Types.PWork): Boolean;
var
  list: array[0..79] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellTarget: array[0..3] of Byte;
  lowPri: Byte;
  roll: Byte;
  ext: Boolean;
  tries: Byte;
  inner: Byte;
  count: Byte;
  k: Byte;
  spell: Byte;
  chosen: Byte;
begin
  if cr^.combatAddr^.spellCast > 0 then begin
    SelectSpellToCast := False;
    Exit;
  end;
  count := 0;
  if cr^.combatAddr^.castAllowed <> 0 then
    for k := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
      if cr^.memorizedSpells[k] in [1..100] then begin
        list[count] := cr^.memorizedSpells[k];
        Inc(count);
      end;
  chosen := 0;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  tries := 1;
  if count > 0 then
    if (cr^.npc > C_Npc.MORALE_MASK) or GDVars.quickMagic or GDVars.demoMode then
      if GDVars.teamCount[ShortInt(CharHlp.NotHostile(cr))] > 0 then
        while (tries <= roll) and (chosen = 0) do begin
          inner := 1;
          while (inner < 4) and (chosen = 0) do begin
            k := FxEngine.RollDice(1, count) - 1;
            spell := list[k];
            if CombatAi.DecideCastSpell(cr, spell, lowPri) then chosen := spell;
            Inc(inner);
          end;
          Dec(lowPri);
          Inc(tries);
        end;
  if chosen > 0 then
    CbtActs.CastSpellCombat(chosen, 1, ext)
  else
    ext := False;
  SelectSpellToCast := ext;
end;

{ Whether cr can afford a step toward (baseDir + its stance's offset for attempt) mod 8. A step off the map sets edge;
  impassable terrain or another creature blocks it. A stinking cloud in the cell makes the step unaffordable unless cr
  is immune, turned or saves; a cloudkill, unless cr is immune, turned or of level 7 or more (caLevelHighest).
  @param(cr The creature.)
  @param(attempt Which of the stance's offsets, 1..5.)
  @param(baseDir The direction aimed at.)
  @param(edge Set when the step would leave the map.)
  @returns(True when the step can be taken.) }
function AiCanStep(cr: Types.PWork; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  eff: Types.PEffectRec;
  dirAdj: Byte;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
  hasStinkCloud: Byte;
  hasCloudkill: Byte;
  canStep: Boolean;
begin
  edge := False;
  canStep := False;
  dirAdj := GDConsts.aiDirOffsets[cr^.combatAddr^.aiStance, attempt];
  dir := (baseDir + dirAdj) mod 8;
  CbtMap.ProbeDirection(cr, dir, crIdx, terrIdx, hasStinkCloud, hasCloudkill);
  if terrIdx = 0 then
    edge := True
  else begin
    if GDConsts.terrainInfo[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE then begin
      AiCanStep := False;
      Exit;
    end;
    if Odd(dir) then
      stepCost := GDConsts.terrainInfo[terrIdx].cost * 3
    else
      stepCost := GDConsts.terrainInfo[terrIdx].cost * 2;
    if crIdx = 0 then
      if stepCost < cr^.combatAddr^.movement then begin
        if hasStinkCloud <> 0 then
          if (not CharHlp.HasEffect(cr, C_Effect.ANIMATE_DEAD, eff))
             and (not CharHlp.HasEffect(cr, C_Effect.STINKING_COUGH, eff))
             and (not CharHlp.HasEffect(cr, C_Effect.IMMUNE_PARALYSIS_POISON, eff))
             and (not CharHlp.HasEffect(cr, C_Effect.IMMUNE_CHARM_POISON, eff))
             and (not CharHlp.HasEffect(cr, 129, eff))
             and (not CharHlp.HasEffect(cr, 63, eff))
             and (cr^.combatAddr^.turned = 0)
             and (not FxEngine.RollSavingThrow(cr, 0, 0)) then
            stepCost := cr^.combatAddr^.movement + 1;
        if hasCloudkill <> 0 then
          if (cr^.caLevelHighest < 7)
             and (not CharHlp.HasEffect(cr, 129, eff))
             and (not CharHlp.HasEffect(cr, C_Effect.IMMUNE_PARALYSIS_POISON, eff))
             and (not CharHlp.HasEffect(cr, 133, eff))
             and (cr^.combatAddr^.turned = 0)
             and (not CharHlp.HasEffect(cr, C_Effect.IMMUNE_CHARM_POISON, eff)) then
            stepCost := cr^.combatAddr^.movement + 1;
        if cr^.combatAddr^.movement >= stepCost then canStep := True;
      end;
  end;
  AiCanStep := canStep;
end;

{ One step, while cr has movement and initiative left and (for an NPC) passes its morale roll: toward the target -- an
  unarmored magic-user 2 or 3 cells away steps away instead, and one closer ends its round -- or, when fleeing, a way
  set by the party's facing, leaving the field at the map's edge (AttemptFlee); the stance's five offsets are tried in
  turn. A step that reverses the last one, or none possible, is a stall and moves to the next stance; the second stall
  drops the target, the third ends the move. A step draws opportunity attacks and the terrain's effects.
  @param(cr The creature.) }
procedure AiMoveStep(cr: Types.PWork);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  steps: array[0..3] of Byte;
begin
  TextRend.DisplayString(0, 24, LightGreen, Black,
                         'Move/Attack, Move Left = ' + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2) + ' ');
  if CombatAi.CheckKeystroke(cr) then Exit;
  if (cr^.combatAddr^.movement div 2 > 0) and (cr^.combatAddr^.initiative > 0) and
      ((cr^.npc < C_Npc.NON_PLAYER) or
       ((cr^.npc > C_Npc.MORALE_MASK) and
        (GDVars.hostileCreatureHit <= GDVars.currentMorale + FxEngine.RollDice(1, 100))) or
      (cr^.hostile = 1)) then begin
    done := False;
    if cr^.combatAddr^.fleeing = 0 then begin
      dir := CbtActs.DirTowardTarget(cr, cr^.combatAddr^.other);
      if (cr^.equipped[C_Equip.ARMOR] = nil) and (cr^.caCharClass = CombatAi.CLASS_MAGE) then
        case CharHlp.CalcDistance(Pointer(cr), Pointer(cr^.combatAddr^.other)) of
          2, 3: dir := (dir + 4) mod 8;
          0, 1:
            begin
              done := CombatAi.FinishRound(cr);
              Exit;
            end;
        end;
    end else begin
      cr^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      dir := GDVars.partyPos.facing - (((GDVars.partyPos.facing + 2) mod 4) div 2);
      if cr^.hostile = 0 then dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    attempt := 1;
    while (attempt < 6) and (not done)
          and (not CombatAi.AiCanStep(cr, attempt, dir, edge)) do
      if (cr^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(cr, dir)
      else
        Inc(attempt);
    if done then begin
      cr^.combatAddr^.movement := 0;
      cr^.combatAddr^.fleeing := 0;
      done := CharHlp.ClearGuard(cr);
    end else begin
      adjDir := (dir + GDConsts.aiDirOffsets[cr^.combatAddr^.aiStance, attempt]) mod 8;
      if (attempt = 6) or (GDVars.lastMoveDir = (adjDir + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        cr^.combatAddr^.aiStance := cr^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          cr^.combatAddr^.other := nil;
          if GDVars.stuckCount > 2 then begin
            cr^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(cr, 255, 1, 0) then
            done := CombatAi.FinishRound(cr);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjDir
      else
        done := True;
    end;
    if not done then begin
      GDVars.combatMapVisible := Ord(GDVars.targetInRange or CbtMap.CombatIconVisible(cr, 0) or
                                       (cr^.hostile = 0));
      CbtMap.SetCreatureFacing(cr, adjDir, 0, 0);
      CbtActs.AttacksOfOpportunity(cr, cr^.combatAddr^.direction);
      if cr^.enabled = 0 then
        done := CharHlp.ClearGuard(cr)
      else begin
        if cr^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(cr, cr^.combatAddr^.direction);
        if cr^.enabled = 0 then done := CharHlp.ClearGuard(cr);
        FxEngine.ConsiderTerrainEffects(cr, 1);
      end;
    end;
  end else
    done := CombatAi.FinishRound(cr);
end;

{ Runs the AI's move/attack loop (the 21st pass finishes the round): fires condition-14 effects, lets a party member
  bandage a dying teammate (ending its turn), moves a fleeing creature away, then attacks the locked target if it is a
  hostile in weapon range and in sight (a locked party-side target is dropped, so hostile creatures never use theirs
  here), or a random enemy in range, or moves toward a target. A ranged weapon that cannot fire with an enemy adjacent
  makes it re-equip and stop. Attacks try a sweep first. Note: the locked target is read before it is checked for nil,
  and the pass that finishes the round for the pass limit still goes on to seek and attack a target.
  @param(cr The acting creature.)
  @returns(True when the creature can no longer act.) }
function AiMoveAttack(cr: Types.PWork): Boolean;
var
  done: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  weapon: Pointer;
  target: Types.PWork;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  enemy: array[0..3] of Byte;
begin
  GDVars.lastMoveDir := C_Dir.CENTER;
  GDVars.stuckCount := 0;
  GDVars.aiMoveState := 0;
  loopCount := 0;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MONSTER_SPECIAL, cr);
  if (cr^.hostile = 0) and CharHlp.BandageDying(True) then
    cr^.combatAddr^.initiative := 0;
  if cr^.combatAddr^.initiative = 0 then canAct := False;
  while (not done) and canAct do begin
    if cr^.combatAddr^.fleeing <> 0 then
      while (cr^.combatAddr^.movement > 0)
            and (cr^.combatAddr^.initiative > 0)
            and (cr^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(cr);
    if (cr^.combatAddr^.initiative = 0)
       or (cr^.combatAddr^.initiative = 20) then
      canAct := False
    else
      done := False;
    if (not done) and canAct then begin
      Inc(loopCount);
      if loopCount > 20 then begin
        done := True;
        canAct := CombatAi.FinishRound(cr) = False;
      end;
      GDVars.targetInRange := False;
      weaponRange := 1;
      if cr^.equipped[C_Equip.WEAPON] <> nil then
        weaponRange := GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then weaponRange := 1;
      target := cr^.combatAddr^.other;
      if (target^.enabled = 0) or (target^.hostile = 0) then target := nil;
      if target <> nil then
        if CbtActs.CanTarget(cr, target) then begin
          tx := CbtMap.CombatCellX(target);
          ty := CbtMap.CombatCellY(target);
          range := weaponRange;
          GDVars.combatArenaPtr^.distMode := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                              tx, ty, range, GDVars.combatArenaPtr) then
            if range div 2 <= weaponRange then GDVars.targetInRange := True;
        end;
      if not GDVars.targetInRange then begin
        cnt := CharHlp.CountTargets(Pointer(cr), weaponRange);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(cr, 255, 0, 0) then
            CombatAi.AiMoveStep(cr)
          else
            done := CombatAi.FinishRound(cr);
        end else begin
          pick := FxEngine.RollDice(1, cnt);
          target := GDVars.creaturePtr[GDVars.potentialTargetCreature[pick]];
          if CharHlp.HasRangedWeapon(cr) and (not CharHlp.HasThrowableWeapon(cr))
             and (CharHlp.CountTargets(Pointer(cr), 1) > 0) then begin
            CombatAi.EquipWeaponAndArmor(cr);
            done := True;
          end else if (CharHlp.CalcDistance(Pointer(cr), Pointer(target)) = 1)
                  or CbtActs.CanTarget(cr, target) then
            GDVars.targetInRange := True;
        end;
      end;
      if GDVars.targetInRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 2,
                          CbtActs.DirTowardTarget(cr, target));
      if GDVars.targetInRange then begin
        if CbtActs.SweepAttack(cr, target) then
          done := CharHlp.ClearGuard(cr)
        else begin
          CbtActs.NoteAttackDirection(cr, target);
          weapon := nil;
          if CharHlp.HasRangedWeapon(cr) then begin
            GDVars.targetInRange := CharHlp.FindDamagingRangedWeapon(cr, weapon);
            if CharHlp.HasThrowableWeapon(cr) then
              if CharHlp.CalcDistance(Pointer(cr), Pointer(target)) = 1 then weapon := nil;
          end;
          CbtActs.MakeAttack(cr, target, False, Types.PItemRec(weapon), done);
          if done then
            canAct := False
          else if target^.enabled = 0 then
            done := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := canAct = False;
end;

{ Ends the creature's round: a helpless, ranged-armed or out-of-initiative creature just ends its actions; others guard.
  @param(cr The creature.)
  @returns(What ending the actions or guarding returns.) }
function FinishRound(cr: Types.PWork): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(cr)
     or CharHlp.HasRangedWeapon(cr)
     or (cr^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.ClearGuard(cr)
  else
    FinishRound := CharHlp.Guard(cr);
end;

{ Handles a key pressed during an AI turn: Alt-M toggles quick magic, space returns each creature that is neither a
  non-player character nor animated to manual control, and Alt-X tries the victory cheat. Pending keys are discarded
  afterwards. Note: the key is tested whether or not the extended-key prefix came first, so an unprefixed 2 also toggles
  quick magic and an unprefixed hyphen also tries the cheat.
  @param(cr The creature.)
  @returns(True when space put the creature itself back under manual control, which marks it to act again at once.) }
function CheckKeystroke(cr: Types.PWork): Boolean;
var
  p: Types.PWork;
  ch: Char;
begin
  CheckKeystroke := False;
  if GameIo.InputPending then begin
    ch := GameIo.ReadGameKey;
    { an extended key: ReadGameKey returns its scan code next }
    if ch = #0 then ch := GameIo.ReadGameKey;
    case ch of
      { Alt-M }
      #50:
        begin
          GDVars.quickMagic := GDVars.quickMagic = False;
          if GDVars.quickMagic then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      ' ':
        begin
          p := GDVars.creatureList;
          while p <> nil do begin
            if (p^.npc < C_Npc.NON_PLAYER) and (p^.status <> C_Status.ANIMATED) then
              p^.quickfight := 0;
            p := p^.nextCharAddr;
          end;
          if cr^.quickfight = 0 then begin
            cr^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      { Alt-X }
      #45:
        if CbtActs.VictoryCheat then begin end;
    end;
  end;
  GameIo.DrainKeys;
end;

{ A turned creature flees. A monster whose morale fails against its own hit points and then its side's flees if it can
  outrun its enemies and has Intelligence 3 or more, else surrenders with Intelligence above 5.
  @param(cr The creature.)
  @returns(True when it surrenders.) }
function CheckMorale(cr: Types.PWork): Boolean;
var
  enemyMove: Byte;
  { Unused in this version; see the other implementations of this routine. }
  moraleSave: Byte;
begin
  CheckMorale := False;
  cr^.combatAddr^.fleeing := 0;
  if cr^.combatAddr^.turned <> 0 then begin
    cr^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(cr, 'is forced to flee', C_Msg.MESSAGE_ROW, True);
    FxEngine.RemoveAiEffects(cr);
    Exit;
  end;
  if cr^.npc <= C_Npc.MORALE_MASK then Exit;
  GDVars.currentMorale := (cr^.npc and C_Npc.MORALE_MASK) * 2;
  if GDVars.currentMorale > 102 then GDVars.currentMorale := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
  if (GDVars.currentMorale >= 100 - cr^.hpCur * 100 div cr^.caHpMax) and (GDVars.currentMorale <> 0) then Exit;
  moraleSave := GDVars.currentMorale;
  GDVars.currentMorale := GDVars.hostileCreatureHit;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
  if (GDVars.currentMorale >= 100 - GDVars.gbvmZone1Ptr^[C_Gbvm.MORALE_THRESHOLD])
     and (GDVars.currentMorale <> 0)
     and (cr^.hostile <> 0) then Exit;
  enemyMove := CbtActs.HighestEnemyMovement(cr);
  if (enemyMove <= CbtActs.CalcCreatureMovement(cr) div 2)
     and (cr^.intCur >= 3) then begin
    cr^.combatAddr^.fleeing := 1;
    FxEngine.RemoveEffect(cr, 74, nil);
    FxEngine.RemoveEffect(cr, 75, nil);
    FxEngine.RemoveAiEffects(cr);
  end else if cr^.intCur > 5 then begin
    if cr^.hostile = 1 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] := GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] + 1;
    FxEngine.PutOutOfPlayWithStatus(cr, C_Status.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.ClearGuard(cr);
  end;
end;

{ Scores a weapon for EquipWeaponAndArmor: damage dice product, +8 per plus, +2 per damage bonus (holy water scores 8
  against an undead target), +2 per extra shot for a launcher, +3 one-handed. The score is zero when it would need more
  than 3 hands, for an aligned weapon of another alignment, for the Javelin of Lightning, and when cursed.
  @param(cr The creature that would wield the weapon.)
  @param(it The weapon.)
  @returns(The score.) }
function CalcWeaponPriority(cr: Types.PWork; it: Types.PItemRec): Byte;
var
  pri: Byte;
  base: Types.TBaseItemRec;
begin
  base := GDVars.baseItems[it^.itemType];
  pri := base.dmgSmDice * base.dmgSmRolls;
  if it^.plus > 0 then pri := pri + it^.plus * 8;
  if base.dmgSmMod > 0 then pri := pri + base.dmgSmMod * 2;
  if (it^.itemType = C_Item.HOLY_WATER_VIAL)
     and (cr^.combatAddr^.other <> nil)
     and (cr^.combatAddr^.other^.levelUndead > 0) then
    pri := 8;
  if (base.props and C_Item.FIRES_AMMO) > 0 then
    pri := pri + (base.rateOfFire - 1) * 2;
  if base.hands <= 1 then pri := pri + 3;
  if base.hands + cr^.handsEquipped > 3 then pri := 0;
  { an aligned weapon }
  if it^.special = 132 then
    if (it^.effect and $F) <> cr^.caAlignment then pri := 0;
  if it^.effect = 83 then pri := 0;
  if it^.cursed <> 0 then pri := 0;
  CalcWeaponPriority := pri;
end;

{ Whether cr can shoot or throw w: sel is w itself when thrown, or the arrows or quarrels it fires.
  @param(cr The creature.)
  @param(w The weapon, or nil.)
  @param(sel Receives the missile, or nil.)
  @returns(True when a missile was found or the weapon's properties are exactly 10.) }
function FindMissile(cr: Types.PWork; w: Types.PItemRec; var sel: Types.PItemRec): Boolean;
var
  props: Byte;
begin
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := GDVars.baseItems[w^.itemType].props;
    if (props and C_Item.THROWN) <> 0 then
      sel := w;
    if (props and C_Item.FIRES_AMMO) <> 0 then begin
      if (props and C_Item.USES_ARROWS) <> 0 then
        sel := cr^.equipped[C_Equip.ARROW];
      if (props and C_Item.USES_QUARRELS) <> 0 then
        sel := cr^.equipped[C_Equip.BOLT];
    end;
  end;
  if (sel <> nil) or (props = 10) then
    FindMissile := True
  else
    FindMissile := False;
end;

{ Ready cr's best weapon, ranged when it outvalues half the best melee weapon, has ammunition and can be thrown at range
  or no enemy is adjacent (never underwater), and its best shield when a hand is free; a cursed item stays.
  @param(cr The creature.) }
procedure EquipWeaponAndArmor(cr: Types.PWork);
var
  bestRanged: Types.PItemRec;
  bestMelee: Types.PItemRec;
  bestShield: Types.PItemRec;
  it: Types.PItemRec;
  ammo: Types.PItemRec;
  bestRangedPri: Byte;
  bestMeleePri: Byte;
  bestShieldPri: Byte;
  pri: Byte;
  itType: Byte;
  { Unused in this version; see the other implementations of this routine. }
  props: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hands: Byte;
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  hasAmmo: Boolean;
begin
  if cr^.equipped[C_Equip.WEAPON] <> nil then
    cr^.handsEquipped := cr^.handsEquipped
        - GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].hands;
  if cr^.equipped[CombatAi.EQUIP_SHIELD] <> nil then
    cr^.handsEquipped := cr^.handsEquipped
        - GDVars.baseItems[cr^.equipped[CombatAi.EQUIP_SHIELD]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPri := 1;
  bestMeleePri := cr^.unarmedDiceA1 * cr^.unarmedRollsA1;
  if cr^.unarmedModA1 > 0 then
    bestMeleePri := bestMeleePri + cr^.unarmedModA1 * 2;
  bestShieldPri := 0;
  it := cr^.itemsAddr;
  while it <> nil do begin
    itType := it^.itemType;
    if GDVars.baseItems[itType].slot = C_Equip.WEAPON then
      if (GDVars.baseItems[itType].classMask and cr^.itemLimits) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(cr, it);
        if ((GDVars.baseItems[itType].props and C_Item.FIRES_AMMO) <> 0)
           or ((GDVars.baseItems[itType].props and C_Item.THROWN) <> 0) then
          if pri > bestRangedPri then
            if CombatAi.FindMissile(cr, it, ammo) then begin
              bestRanged := it;
              bestRangedPri := pri;
            end;
        if (GDVars.baseItems[itType].props and C_Item.FIRES_AMMO) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := it;
            bestMeleePri := pri;
          end;
      end;
    if GDVars.baseItems[itType].slot = CombatAi.EQUIP_SHIELD then
      if (GDVars.baseItems[itType].classMask and cr^.itemLimits) > 0 then begin
        if it^.plus >= 0 then pri := it^.plus + 1 else pri := 0;
        if pri > bestShieldPri then begin
          bestShield := it;
          bestShieldPri := pri;
        end;
      end;
    it := it^.next;
  end;
  if (bestRanged <> nil)
     and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and ((GDVars.baseItems[bestRanged^.itemType].props and C_Item.THROWABLE) = C_Item.THROWABLE) then
    trueRanged := True
  else
    trueRanged := False;
  hasAmmo := CombatAi.FindMissile(cr, bestRanged, ammo);
  if (bestRanged <> nil)
     and (GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CharHlp.CountTargets(Pointer(cr), 1) = 0)) then
    it := bestRanged
  else
    it := bestMelee;
  changed := False;
  needSwap := True;
  if cr^.equipped[C_Equip.WEAPON] <> nil then
    if (cr^.equipped[C_Equip.WEAPON] = it) or (cr^.equipped[C_Equip.WEAPON]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if cr^.equipped[C_Equip.WEAPON] <> nil then
      ViewChar.ToggleReadyItem(cr^.equipped[C_Equip.WEAPON]);
    CharHlp.RecalcStats(cr);
    if cr^.equipped[CombatAi.EQUIP_SHIELD] <> nil then
      if cr^.equipped[CombatAi.EQUIP_SHIELD]^.cursed = 0 then
        cr^.handsEquipped := cr^.handsEquipped
            - GDVars.baseItems[cr^.equipped[CombatAi.EQUIP_SHIELD]^.itemType].hands;
    if it <> nil then ViewChar.ToggleReadyItem(it);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  CbtActs.RecalcAttacksLeft(cr);
  needSwap := True;
  if cr^.equipped[CombatAi.EQUIP_SHIELD] <> nil then
    if (cr^.equipped[CombatAi.EQUIP_SHIELD] = bestShield) or (cr^.equipped[CombatAi.EQUIP_SHIELD]^.cursed <> 0) then
      needSwap := False;
  if cr^.handsEquipped > 2 then begin
    if (cr^.equipped[CombatAi.EQUIP_SHIELD] = nil) or (cr^.equipped[CombatAi.EQUIP_SHIELD]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(it);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(cr^.equipped[CombatAi.EQUIP_SHIELD]);
      changed := True;
    end;
  end else if (cr^.handsEquipped < 2) and needSwap then begin
    if cr^.equipped[CombatAi.EQUIP_SHIELD] <> nil then
      ViewChar.ToggleReadyItem(cr^.equipped[CombatAi.EQUIP_SHIELD]);
    CharHlp.RecalcStats(cr);
    if bestShield <> nil then
      ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  if changed then CharHlp.CombatPrintCreatureInfo(cr);
end;

begin
end.
