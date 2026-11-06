{ The effects engine: effect handler dispatch, adding, removing and triggering effects, attack rolls, saving throws,
  dice, damage that is not from a weapon with its element's message, Strength effects, healing and revival, and the
  clouds' effects on the creatures in them. KillCreature handles death and going out of play, and RecalcAbility
  recomputes an ability when an effect or item changes it. The unit works on the in-memory work record (Types.TWork),
  not the saved TCharRecord, through its case 8 names.

  CallEffectHandler calls GDVars.effectHandlers[effId], the handler of an effect id, or, while GDVars.overrideEffectFlag
  is set, effect 147's handler for every call. EffHndlr.InitEffectHandlers fills the table. }
{$O+,F+,S+}
{$A+}
unit FxEngine;

interface

uses Types, C_Status, C_Effect, C_Class, C_Cond, C_Dir, C_Ifc, C_Msg, C_Npc, C_Stat, GDConsts, GDVars,
  CbtMap, Pathing, Raster, TextRend, CharHlp, C_Gbvm;

{ Show msg under the creature and, unless it is already dead, stoned or gone, kill it: give it status, disable it with
  no hit points, remove its 0-hit-point effects, run its condition-13 effects and put its body down if it stays down,
  recount the teams and pause; when the last enemy falls in combat mode 1, say that none remain. Outside combat the
  party roster is redrawn.
  @param(cr The creature.)
  @param(status The status it dies with.)
  @param(msg The message.) }
procedure KillCreature(cr: Types.PWork; status: Byte; msg: Types.TStr40);

{ Run an effect's handler from GDVars.effectHandlers; while GDVars.overrideEffectFlag is set, effect 147's handler runs
  instead.
  @param(effId The effect.)
  @param(cr The creature.)
  @param(p The effect node or item passed to the handler.)
  @param(removed True when the effect is being removed.) }
procedure CallEffectHandler(effId: Byte; cr: Types.PWork; p: Pointer; removed: Boolean);

{ Remove an effect from a creature: run its handler for the removal when its onRemove flag is set, unlink and free it,
  and while effects are locked remove every other copy of it. Removing effect 14 recomputes charisma; enlarge, strength
  or effect 146 recompute strength.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(eff The effect node, or nil for the first with effId.) }
procedure RemoveEffect(cr: Types.PWork; effId: Byte; eff: Pointer);

{ Run the handlers of the creature's effects listed for a trigger condition (TriggerEffect), such as the attack, damage
  and saving-throw adjustments and the starts and ends of turns, rounds and fights.
  @param(cond The condition, 1..23; 0 runs nothing.)
  @param(cr The creature.) }
procedure TriggerEffectsWithCondition(cond: Byte; cr: Types.PWork);

{ Apply the clouds in the creature's cells. When it has just moved (flag), a stinking cloud makes it save or be helpless
  for 1d4+1 ('chokes and gags from nausea'), a save still leaving it coughing; a creature of script flag 8, helpless,
  animated or immune to poison is spared, and the cloud's caster is the current character meanwhile. A cloudkill kills a
  creature of terrType 0..4, and one of 5 or 6 that fails its save at -4 or at 0; script flag 8 spares it too.
  @param(cr The creature.)
  @param(flag Nonzero after a step.) }
procedure ConsiderTerrainEffects(cr: Types.PWork; flag: Byte);

{ Rolls an attack that has no attacking creature: a d20, where 1 always misses and 20 counts as 100, adjusted by the
  defender's condition-16 effects.
  @param(defender Creature attacked.)
  @param(sixtyMinusThac0 The attack's to-hit value, 60 minus its THAC0.)
  @returns(True when the adjusted roll is not negative and the roll plus the to-hit value exceeds the defender's armor
    class.) }
function AttackRollNoAttacker(defender: Types.PWork; sixtyMinusThac0: Byte): Boolean;

{ Roll an attack: the attacker turns visible, 1d20 is rolled (a 1 misses, a 20 counts 100) and the attacker's
  condition-10 and the defender's condition-16 effects run; it hits when the roll plus the attacker's THAC0 and the
  zone's modifier (the party's, adjusted for the difficulty, or the monsters') reaches sixtyMinusAc.
  @param(attacker The attacker.)
  @param(defender The creature attacked.)
  @param(sixtyMinusAc 60 less the defender's armor class.)
  @returns(True on a hit.) }
function AttackRoll(attacker, defender: Types.PWork; sixtyMinusAc: Byte): Boolean;

{ Roll a saving throw on 1d20: a 1 fails and a 20 succeeds; otherwise the roll plus the creature's save bonus and the
  modifier, after its condition-12 effects, must reach its save of saveType. The result is kept in
  GDVars.isSavingThrowMade too.
  @param(cr The creature.)
  @param(saveType The save, 0..4.)
  @param(modifier Added to the roll.)
  @returns(True when the save is made.) }
function RollSavingThrow(cr: Types.PWork; saveType, modifier: ShortInt): Boolean;

{ Rolls a number of dice and adds them up.
  @param(n Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(n, sides: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(n Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(n, sides: Byte): Byte;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(cr: Types.PWork; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(cr The creature.)
  @param(status Its new status.)
  @param(msg The message.) }
procedure PutOutOfPlayWithStatus(cr: Types.PWork; status: Byte; msg: Types.TStr40);

{ Removes each invisibility effect from a creature.
  @param(cr The creature.) }
procedure RemoveInvisibility(cr: Types.PWork);

{ Remove the effects that end at 0 hit points (GDConsts.hpZeroEffects); a berserk party member returns to the party's
  side.
  @param(cr The creature.) }
procedure RemoveEffectsHp0(cr: Types.PWork);

{ Remove the effects that put a creature under computer control (GDConsts.aiEffects).
  @param(cr The creature.) }
procedure RemoveAiEffects(cr: Types.PWork);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(cr The creature.)
  @param(effId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(cr: Types.PWork; effId: Byte): Boolean;

{ Tells whether a strength would be higher than a creature's natural strength.
  @param(cr The creature.)
  @param(baseStr The strength score.)
  @param(excStr Its exceptional strength.)
  @param(effStrength Receives the strength packed as StrengthModifier packs it, when it is higher.)
  @returns(True when it is higher.) }
function AdjustForNewStrength(cr: Types.PWork; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Deal damage that is not from a weapon: the creature's condition-6 effects adjust it, a save takes none or half, and
  without a save its condition-20 effects run. The damage is reported with its element and inflicted; in combat it stops
  a spell being cast, and a creature put down is reported.
  @param(cr The creature.)
  @param(damage The damage.)
  @param(saveReduction 1 for none on a save, 2 for half.)
  @param(saved True when the creature saved.) }
procedure InflictNonWeaponDamage(cr: Types.PWork; damage, saveReduction: Byte; saved: Boolean);

{ Gives a creature an effect, announcing it. Effects that block it react first (condition 9) and may cancel it; the
  effect also fails when the creature saved and a save negates it. Either way the creature is reported unaffected.
  Otherwise the effect is added, replacing an instance that still has time to run, and the message, if any, is shown.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration.)
  @param(strength Its strength.)
  @param(onRemove Set to have its handler called when it is removed.)
  @param(saveNegates Set when a successful save stops the effect.)
  @param(saved Set when the creature saved.)
  @param(msg The announcement, or empty.) }
procedure AddEffectWithMessage(cr: Types.PWork; effId: Byte; minutes: Word; strength: Byte; onRemove, saveNegates,
                               saved: Boolean; msg: Types.TStr40);

{ Heal a creature that is okay, animated, unconscious or dying, up to its maximum; with bypassRot only one below its
  maximum. A dying creature becomes unconscious, and outside combat an unconscious one runs effect 78's revival.
  @param(cr The creature.)
  @param(hp Hit points to heal.)
  @param(bypassRot True to heal only a wounded creature.)
  @returns(True when it healed.) }
function RestoreHitPoints(cr: Types.PWork; hp: Byte; bypassRot: Boolean): Boolean;

{ Bring a creature back up with hp hit points where it stands or can be placed: 'stands up and grins' for a hostile one,
  else 'gets back up'.
  @param(cr The creature.)
  @param(hp Its hit points.)
  @returns(True when it was revived.) }
function ReviveDeadCreature(cr: Types.PWork; hp: Byte): Boolean;

{ Recomputes the current value of one ability of a creature from its permanent value, its equipped magic items and its
  effects. Items can raise or lower an ability or force it to 3 or 7. Strength keeps the best of the items, effect 146,
  Enlarge and the Strength effect, which adds its decoded Strength to a creature at 18/99 or less and turns each point
  above 18 into 10 exceptional points for a fighter, paladin or ranger (18 for other classes). Constitution recomputes
  the maximum hit points from the rolled hit points and the Constitution bonus of the class levels, moves the current
  hit points by the change, and keeps effect 62 on while it is 20 or more. Intelligence and Wisdom drop to 3 under
  Feeblemind unless an item forces 7 or 3, and Charisma adds the strength of effect 14.
  @param(cr Creature recalculated.)
  @param(mode Ability, a C_Stat index from STRENGTH to CHARISMA.) }
procedure RecalcAbility(cr: Types.PWork; mode: ShortInt);

implementation

type
  TZoneBytes = array[0..2047] of Byte;
  PZoneBytes = ^TZoneBytes;

  PDirs = ^TDirs;
  TDirs = array[0..255] of Byte;

var
  zone1PtrV: PZoneBytes absolute GDVars.gbvmZone1Ptr;

procedure KillCreature(cr: Types.PWork; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(cr, msg, C_Msg.MESSAGE_ROW, False);
  { already dead, stoned or gone: skip }
  case cr^.status of
    C_Status.STONED, C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
    cr^.status := status;
    cr^.enabled := 0;
    cr^.hpCur := 0;
    FxEngine.RemoveEffectsHp0(cr);
    FxEngine.TriggerEffectsWithCondition(13, cr);
    if cr^.enabled = 0 then
      CbtMap.CreatureDowned(cr);
    CbtMap.CountTeams;
    if (cr^.fxHostile = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT)
       and (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1)
       and (GDVars.teamCount[1] = 0) then begin
      GDVars.displayStatusLineProc('No enemies remain here.');
      TextRend.PauseOnly;
      GDVars.displayStatusLineProc('');
    end else
      TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    { outside combat the party sheet is on screen -- refresh it for the current creature. }
    if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
      CharHlp.DisplayParty(GDVars.curChar);
  end;
  end;
end;

procedure CallEffectHandler(effId: Byte; cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if GDVars.overrideEffectFlag <> 0 then
    GDVars.effectHandlers[147](cr, p, removed)
  else
    GDVars.effectHandlers[effId](cr, p, removed);
end;

{ Remove every copy of an effect from a creature, without running its handler.
  @param(cr The creature.)
  @param(effId The effect.) }
procedure RemoveAllEffects(cr: Types.PWork; effId: Byte);
var
  next: Types.PEffectRec;
  prev: Types.PEffectRec;
  cur: Types.PEffectRec;
begin
  cur := Types.PEffectRec(cr^.effects);
  while cur <> nil do begin
    next := cur^.next;
    if cur^.id = effId then begin
      if Types.PEffectRec(cr^.effects) = cur then
        cr^.effects := Types.PEffectRec(cur^.next)
      else begin
        prev := Types.PEffectRec(cr^.effects);
        while (prev <> nil) and (prev^.next <> cur) do
          prev := prev^.next;
        if prev <> nil then
          prev^.next := cur^.next;
      end;
      FreeMem(cur, SizeOf(Types.TEffectRec));
    end;
    cur := next;
  end;
end;

procedure RemoveEffect(cr: Types.PWork; effId: Byte; eff: Pointer);
var
  prev: Types.PEffectRec;
  p: Types.PEffectRec;
begin
  p := eff;
  if p = nil then begin
    p := Types.PEffectRec(cr^.effects);
    while (p <> nil) and (p^.id <> effId) do
      p := p^.next;
  end;
  if p = nil then Exit;
  if p^.onRemove then
    FxEngine.CallEffectHandler(effId, cr, p, True);
  prev := Types.PEffectRec(cr^.effects);
  while (prev <> nil) and (prev <> p) do
    prev := prev^.next;
  if prev <> nil then begin
    if Types.PEffectRec(cr^.effects) = p then
      cr^.effects := Types.PEffectRec(p^.next)
    else begin
      prev := Types.PEffectRec(cr^.effects);
      while (prev <> nil) and (prev^.next <> p) do
        prev := prev^.next;
      prev^.next := p^.next;
    end;
    FreeMem(p, SizeOf(Types.TEffectRec));
  end;
  if GDVars.effectLockFlag <> 0 then
    FxEngine.RemoveAllEffects(cr, effId);
  if effId = 14 then
    FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
  if (effId = C_Effect.ENLARGE) or (effId = C_Effect.STRENGTH) or (effId = 146) then
    FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
end;

{ Fires one effect on a creature: calls its handler when the creature has the effect, or, for the aura effects Silence
  15', Protection from Evil 10', Protection from Good 10' and Prayer, when a creature carrying it has this one in range
  (6 cells for Prayer, else 1; outside combat any carrier counts). The handler gets the node found: the creature's own,
  or the carrier's for an aura. The range test builds a target list, and the caller's target list is kept around it.
  @param(cr The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(cr: Types.PWork; effId: Byte);
var
  { the caller's target list }
  savedList: array[1..72] of Types.TCombatTarget;
  p: Types.PWork;
  eff: Types.PEffectRec;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.creatureList;
  if CharHlp.HasEffect(cr, effId, eff) then
    found := True
  else if effId in [21, 45, 46, 49] then begin
    Move(GDVars.combatTargetData[1], savedList, SizeOf(savedList));
    while (p <> nil) and not found do begin
      if CharHlp.HasEffect(p, effId, eff) then begin
        if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
          if effId = 49 then range := 6 else range := 1;
          Pathing.buildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p),
                                  range, 255, CbtMap.GetIconSize(p), GDVars.combatArenaPtr);
          for i := 1 to GDVars.targetCount do
            if GDVars.combatTargetData[i].idx = CbtMap.CombatSlot(cr) then
              found := True;
        end else
          found := True;
      end;
      p := p^.next;
    end;
    Move(savedList, GDVars.combatTargetData[1], SizeOf(savedList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, cr, eff, False);
end;

procedure TriggerEffectsWithCondition(cond: Byte; cr: Types.PWork);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  case cond of
    0: ;
    1: begin
          FxEngine.TriggerEffect(cr, 37);
          FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
          FxEngine.TriggerEffect(cr, 71);
          FxEngine.TriggerEffect(cr, 69);
        end;
    2: begin
          FxEngine.TriggerEffect(cr, 79);
          FxEngine.TriggerEffect(cr, 80);
          FxEngine.TriggerEffect(cr, 145);
          FxEngine.TriggerEffect(cr, 57);
          FxEngine.TriggerEffect(cr, 96);
          FxEngine.TriggerEffect(cr, 122);
          FxEngine.TriggerEffect(cr, 123);
          FxEngine.TriggerEffect(cr, 149);
          FxEngine.TriggerEffect(cr, 154);
          FxEngine.TriggerEffect(cr, 155);
          FxEngine.TriggerEffect(cr, 64);
          FxEngine.TriggerEffect(cr, 67);
          FxEngine.TriggerEffect(cr, 159);
        end;
    3: begin
          FxEngine.TriggerEffect(cr, 65);
          FxEngine.TriggerEffect(cr, 66);
          FxEngine.TriggerEffect(cr, 67);
          FxEngine.TriggerEffect(cr, 70);
          FxEngine.TriggerEffect(cr, 79);
          FxEngine.TriggerEffect(cr, 87);
        end;
    4: begin
          FxEngine.TriggerEffect(cr, 29);
          FxEngine.TriggerEffect(cr, 6);
          FxEngine.TriggerEffect(cr, 157);
          FxEngine.TriggerEffect(cr, 103);
          FxEngine.TriggerEffect(cr, 75);
          FxEngine.TriggerEffect(cr, 76);
          FxEngine.TriggerEffect(cr, 134);
          FxEngine.TriggerEffect(cr, 152);
        end;
    5: begin
          FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
          FxEngine.TriggerEffect(cr, 41);
          FxEngine.TriggerEffect(cr, 104);
          FxEngine.TriggerEffect(cr, 120);
          FxEngine.TriggerEffect(cr, 101);
          FxEngine.TriggerEffect(cr, 115);
          FxEngine.TriggerEffect(cr, 116);
          FxEngine.TriggerEffect(cr, 119);
          FxEngine.TriggerEffect(cr, 94);
          FxEngine.TriggerEffect(cr, 117);
          FxEngine.TriggerEffect(cr, 60);
          FxEngine.TriggerEffect(cr, 81);
          FxEngine.TriggerEffect(cr, 82);
          FxEngine.TriggerEffect(cr, 85);
          FxEngine.TriggerEffect(cr, 130);
          FxEngine.TriggerEffect(cr, 143);
          FxEngine.TriggerEffect(cr, 151);
          FxEngine.TriggerEffect(cr, 153);
        end;
    6: begin
          FxEngine.TriggerEffect(cr, 113);
          FxEngine.TriggerEffect(cr, 61);
          FxEngine.TriggerEffect(cr, 10);
          FxEngine.TriggerEffect(cr, 20);
          FxEngine.TriggerEffect(cr, 105);
          FxEngine.TriggerEffect(cr, 106);
          FxEngine.TriggerEffect(cr, 112);
          FxEngine.TriggerEffect(cr, 114);
          FxEngine.TriggerEffect(cr, 118);
          FxEngine.TriggerEffect(cr, 17);
          FxEngine.TriggerEffect(cr, 93);
          FxEngine.TriggerEffect(cr, 101);
          FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
          FxEngine.TriggerEffect(cr, 110);
          FxEngine.TriggerEffect(cr, 73);
          FxEngine.TriggerEffect(cr, 82);
          FxEngine.TriggerEffect(cr, 84);
          FxEngine.TriggerEffect(cr, 129);
          FxEngine.TriggerEffect(cr, 133);
          FxEngine.TriggerEffect(cr, 135);
          FxEngine.TriggerEffect(cr, 63);
          FxEngine.TriggerEffect(cr, 148);
        end;
    C_Cond.TURN_START: begin
          FxEngine.TriggerEffect(cr, 51);
          FxEngine.TriggerEffect(cr, C_Effect.HELD);
          FxEngine.TriggerEffect(cr, C_Effect.SLEEP);
          FxEngine.TriggerEffect(cr, C_Effect.HELPLESS);
          FxEngine.TriggerEffect(cr, C_Effect.SNAKES);
          FxEngine.TriggerEffect(cr, C_Effect.CLUMSY);
          FxEngine.TriggerEffect(cr, C_Effect.ENTANGLED);
        end;
    C_Cond.COMBAT_START: begin
          FxEngine.TriggerEffect(cr, 89);
          FxEngine.TriggerEffect(cr, 72);
          FxEngine.TriggerEffect(cr, C_Effect.POISONED);
        end;
    9: begin
          FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
          FxEngine.TriggerEffect(cr, 105);
          FxEngine.TriggerEffect(cr, 106);
          FxEngine.TriggerEffect(cr, C_Effect.ELF_RESISTANCE);
          FxEngine.TriggerEffect(cr, 108);
          FxEngine.TriggerEffect(cr, 109);
          FxEngine.TriggerEffect(cr, 110);
          FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_PARALYSIS_POISON);
          FxEngine.TriggerEffect(cr, 112);
          FxEngine.TriggerEffect(cr, C_Effect.HALF_ELF_RESISTANCE);
          FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_CHARM_POISON);
          FxEngine.TriggerEffect(cr, 63);
          FxEngine.TriggerEffect(cr, 129);
          FxEngine.TriggerEffect(cr, 148);
        end;
    10: begin
          FxEngine.TriggerEffect(cr, 1);
          FxEngine.TriggerEffect(cr, 2);
          FxEngine.TriggerEffect(cr, C_Effect.BLIND);
          FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
          FxEngine.TriggerEffect(cr, 49);
          FxEngine.TriggerEffect(cr, 6);
          FxEngine.TriggerEffect(cr, 157);
          FxEngine.TriggerEffect(cr, C_Effect.GNOME_THAC0);
          FxEngine.TriggerEffect(cr, C_Effect.DWARF_THAC0);
          FxEngine.TriggerEffect(cr, 75);
          FxEngine.TriggerEffect(cr, 76);
        end;
    11: begin
          FxEngine.TriggerEffect(cr, C_Effect.BLIND);
          FxEngine.TriggerEffect(cr, 17);
          FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
          FxEngine.TriggerEffect(cr, 9);
          FxEngine.TriggerEffect(cr, 45);
          FxEngine.TriggerEffect(cr, 46);
          FxEngine.TriggerEffect(cr, C_Effect.STINKING_COUGH);
          FxEngine.TriggerEffect(cr, 7);
        end;
    12: begin
          FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
          FxEngine.TriggerEffect(cr, 9);
          FxEngine.TriggerEffect(cr, 10);
          FxEngine.TriggerEffect(cr, 17);
          FxEngine.TriggerEffect(cr, 20);
          FxEngine.TriggerEffect(cr, C_Effect.BLIND);
          FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
          FxEngine.TriggerEffect(cr, 45);
          FxEngine.TriggerEffect(cr, 46);
          FxEngine.TriggerEffect(cr, 49);
          FxEngine.TriggerEffect(cr, 61);
          FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_PARALYSIS_POISON);
          FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_CHARM_POISON);
          FxEngine.TriggerEffect(cr, C_Effect.CONSTITUTION_SAVE_BONUS);
          FxEngine.TriggerEffect(cr, 50);
          FxEngine.TriggerEffect(cr, 54);
          FxEngine.TriggerEffect(cr, 148);
        end;
    13: begin
          FxEngine.TriggerEffect(cr, 99);
          FxEngine.TriggerEffect(cr, 100);
        end;
    C_Cond.MONSTER_SPECIAL: begin
          FxEngine.TriggerEffect(cr, 83);
          FxEngine.TriggerEffect(cr, 88);
          FxEngine.TriggerEffect(cr, 121);
          FxEngine.TriggerEffect(cr, 86);
          FxEngine.TriggerEffect(cr, 87);
          FxEngine.TriggerEffect(cr, 90);
          FxEngine.TriggerEffect(cr, 126);
          FxEngine.TriggerEffect(cr, 128);
          FxEngine.TriggerEffect(cr, 131);
          FxEngine.TriggerEffect(cr, 132);
          FxEngine.TriggerEffect(cr, C_Effect.SWALLOWING);
          FxEngine.TriggerEffect(cr, C_Effect.HUGGING);
          FxEngine.TriggerEffect(cr, C_Effect.DRAINING_BLOOD);
        end;
    C_Cond.ACTION_START: begin
          FxEngine.TriggerEffect(cr, 21);
          FxEngine.TriggerEffect(cr, C_Effect.STINKING_COUGH);
          FxEngine.TriggerEffect(cr, C_Effect.CHARM);
          FxEngine.TriggerEffect(cr, C_Effect.SUFFOCATING);
          FxEngine.TriggerEffect(cr, 77);
          FxEngine.TriggerEffect(cr, C_Effect.IMMOBILE);
        end;
    16: begin
          FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
          FxEngine.TriggerEffect(cr, 71);
          FxEngine.TriggerEffect(cr, 37);
          FxEngine.TriggerEffect(cr, C_Effect.DWARF_ARMOR_CLASS_VS_GIANTS);
          FxEngine.TriggerEffect(cr, C_Effect.GNOME_ARMOR_CLASS_BONUS);
          FxEngine.TriggerEffect(cr, 89);
          FxEngine.TriggerEffect(cr, 4);
        end;
    C_Cond.MORALE_CHECK: begin
          FxEngine.TriggerEffect(cr, 1);
          FxEngine.TriggerEffect(cr, 2);
          FxEngine.TriggerEffect(cr, C_Effect.CHARM);
          FxEngine.TriggerEffect(cr, 158);
        end;
    18: begin
          FxEngine.TriggerEffect(cr, C_Effect.HASTED);
          FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
        end;
    C_Cond.ROUND_END: begin
          FxEngine.TriggerEffect(cr, 98);
          FxEngine.TriggerEffect(cr, C_Effect.SPIRITUAL_HAMMER);
          FxEngine.TriggerEffect(cr, 72);
          FxEngine.TriggerEffect(cr, 56);
          FxEngine.TriggerEffect(cr, C_Effect.CHARM);
        end;
    20: begin
          FxEngine.TriggerEffect(cr, 50);
          FxEngine.TriggerEffect(cr, 54);
          FxEngine.TriggerEffect(cr, 148);
        end;
    21: begin
          FxEngine.TriggerEffect(cr, C_Effect.CONFUSED);
        end;
    22: begin
          FxEngine.TriggerEffect(cr, 138);
        end;
    23: begin
          FxEngine.TriggerEffect(cr, 74);
        end;
  end;
end;

{ Find the creature whose cloud covers an arena cell.
  @param(x Arena column.)
  @param(y Arena row.)
  @param(start The first cloud.)
  @param(count Cells in each cloud.)
  @param(tbl The directions of the cloud's cells.)
  @returns(The cloud's owner, or the first creature when no cloud covers it.) }
function FindCreatureAtCell(x, y: ShortInt; start: Types.PArenaNode; count: Byte; tbl: PDirs): Types.PWork;
var
  p: Types.PArenaNode;
  found: Boolean;
  i: Byte;
begin
  p := start;
  found := False;
  while (p <> nil) and not found do begin
    for i := 1 to count do
      if p^.cellLive[i] <> 0 then
        if (p^.cellX + GDConsts.dirDX[tbl^[i]] = x) and (p^.cellY + GDConsts.dirDY[tbl^[i]] = y) then
          found := True;
    if not found then
      p := p^.next;
  end;
  if found then
    FindCreatureAtCell := p^.data
  else
    FindCreatureAtCell := GDVars.creatureList;
end;

procedure ConsiderTerrainEffects(cr: Types.PWork; flag: Byte);
var
  { ProbeDirection outputs }
  cellTerr: Byte;
  cellCr: Byte;
  eff: Types.PEffectRec;
  { HasEffect's result for the coughing effect, cleared first }
  eff2: Types.PEffectRec;
  saved: Boolean;
  { ProbeDirection outputs }
  hasStinkCloud: Byte;
  hasCloudkill: Byte;
  { the current character, while the cloud's caster stands in for it }
  savedTargets: Types.PWork;
begin
  if cr^.enabled = 0 then Exit;
  CbtMap.ProbeDirection(cr, C_Dir.CENTER, cellCr, cellTerr, hasStinkCloud, hasCloudkill);
  if hasStinkCloud <> 0 then
    if flag <> 0 then
      if (cr^.scriptFlags[0] and 8) = 0 then
      if not CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff) then
        if not CharHlp.HasEffect(cr, C_Effect.ANIMATE_DEAD, eff) then
          if not CharHlp.HasEffect(cr, C_Effect.IMMUNE_PARALYSIS_POISON, eff) then
            if not CharHlp.HasEffect(cr, C_Effect.IMMUNE_CHARM_POISON, eff) then begin
              saved := FxEngine.RollSavingThrow(cr, 0, 0);
              if saved then begin
                savedTargets := GDVars.curChar;
                GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(cr),
                                                  CbtMap.CombatCellY(cr),
                                                  GDVars.linkedListStinkingPtr, 4, @GDConsts.cloudCells);
                FxEngine.AddEffectWithMessage(cr, C_Effect.STINKING_COUGH, 1, 255, False, False, saved,
                                              'starts to cough');
                eff2 := nil;
                if CharHlp.HasEffect(cr, C_Effect.STINKING_COUGH, eff2) then
                  FxEngine.CallEffectHandler(C_Effect.STINKING_COUGH, cr, eff, False);
                GDVars.curChar := savedTargets;
              end else begin
                savedTargets := GDVars.curChar;
                GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(cr),
                                                  CbtMap.CombatCellY(cr),
                                                  GDVars.linkedListStinkingPtr, 4, @GDConsts.cloudCells);
                FxEngine.AddEffectWithMessage(cr, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, 255, False, False,
                                              saved, 'chokes and gags from nausea');
                if CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff) then
                  FxEngine.CallEffectHandler(C_Effect.HELPLESS, cr, eff, False);
                GDVars.curChar := savedTargets;
              end;
            end;
  if hasCloudkill <> 0 then
    if (cr^.scriptFlags[0] and 8) = 0 then
    if cr^.enabled <> 0 then
      case cr^.terrType of
        0..4: begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', C_Msg.MESSAGE_ROW, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
              end;
        5: if not FxEngine.RollSavingThrow(cr, 0, -4) then begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', C_Msg.MESSAGE_ROW, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
              end;
        6: if not FxEngine.RollSavingThrow(cr, 0, 0) then begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', C_Msg.MESSAGE_ROW, False);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
              end;
      end;
end;

function AttackRollNoAttacker(defender: Types.PWork; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.currentAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.currentAttackRoll > 1 then begin
    if GDVars.currentAttackRoll = 20 then
      GDVars.currentAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if (GDVars.currentAttackRoll >= 0) and (GDVars.currentAttackRoll + sixtyMinusThac0 > defender^.acCur) then
      AttackRollNoAttacker := True;
  end;
end;

function AttackRoll(attacker, defender: Types.PWork; sixtyMinusAc: Byte): Boolean;
var
  zoneAttackMod: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.currentAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.currentAttackRoll > 1 then begin
    if GDVars.currentAttackRoll = 20 then
      GDVars.currentAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(10, attacker);
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if attacker^.fxHostile = 0 then begin
      zoneAttackMod := zone1PtrV^[$6E2];
      case GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] of
        0: Inc(zoneAttackMod, 2);
        1: Inc(zoneAttackMod);
        3: Dec(zoneAttackMod);
        4: Dec(zoneAttackMod, 2);
      end;
    end else
      zoneAttackMod := zone1PtrV^[$6E0];
    if (GDVars.currentAttackRoll >= 0) and
        (GDVars.currentAttackRoll + attacker^.thac0Cur + zoneAttackMod >= sixtyMinusAc) then
      AttackRoll := True;
  end;
end;

function RollSavingThrow(cr: Types.PWork; saveType, modifier: ShortInt): Boolean;
begin
  GDVars.isSavingThrowMade := True;
  GDVars.gSaveRoll := FxEngine.RollDice(1, 20);
  case GDVars.gSaveRoll of
    1: GDVars.isSavingThrowMade := False;
    20: GDVars.isSavingThrowMade := True;
  else begin
    GDVars.gSaveRoll := GDVars.gSaveRoll + cr^.saveBonus + modifier;
    GDVars.currentSavingThrow2 := saveType;
    FxEngine.TriggerEffectsWithCondition(12, cr);
    if cr^.fxSaves[saveType] <= GDVars.gSaveRoll then
      GDVars.isSavingThrowMade := True
    else
      GDVars.isSavingThrowMade := False;
  end;
  end;
  RollSavingThrow := GDVars.isSavingThrowMade;
end;

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Byte;
begin
  GDVars.currentDamageDice := n;
  RollDamageDice := FxEngine.RollDice(n, sides);
end;

procedure AddEffect(cr: Types.PWork; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  p: Types.PEffectRec;
  q: Types.PEffectRec;
begin
  GetMem(p, SizeOf(Types.TEffectRec));
  if cr^.effects = nil then
    cr^.effects := p
  else begin
    q := Types.PEffectRec(cr^.effects);
    while q^.next <> nil do
      q := q^.next;
    q^.next := p;
  end;
  p^.next := nil;
  p^.id := effId;
  p^.duration := minutes;
  p^.onRemove := onRemove;
  p^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(cr: Types.PWork; status: Byte; msg: Types.TStr40);
var
  slot: Byte;
begin
  if cr^.enabled = 0 then Exit;
  slot := CbtMap.CombatSlot(cr);
  CbtMap.DisplayMapViewCentered(cr, 3, False);
  CharHlp.PrintCreatureMessage(cr, msg, C_Msg.MESSAGE_ROW, True);
  cr^.enabled := 0;
  cr^.status := status;
  if cr^.status <> C_Status.RUNNING then
    cr^.hpCur := 0;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  Raster.FlushView;
  GDVars.combatArenaLocation[slot].size := 0;
  CbtMap.BuildArenaArrays;
  if CharHlp.ClearGuard(cr) then
    FxEngine.RemoveEffectsHp0(cr);
end;

procedure RemoveInvisibility(cr: Types.PWork);
var
  eff: Types.PEffectRec;
begin
  while CharHlp.HasEffect(cr, C_Effect.INVISIBLE, eff) do
    FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, eff);
end;

procedure RemoveEffectsHp0(cr: Types.PWork);
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  for i := 1 to 21 do
    FxEngine.RemoveEffect(cr, GDConsts.hpZeroEffects[i], nil);
  if CharHlp.HasEffect(cr, 77, eff) then
    if cr^.npc = C_Npc.ANIMATED_PLAYER then
      cr^.fxHostile := 0;
end;

procedure RemoveAiEffects(cr: Types.PWork);
var
  i: Byte;
begin
  for i := 1 to 5 do
    FxEngine.RemoveEffect(cr, GDConsts.aiEffects[i], nil);
end;

function RemoveEffectWithMessage(cr: Types.PWork; effId: Byte): Boolean;
var
  eff: Types.PEffectRec;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(cr, effId, eff) then begin
    CharHlp.PrintCreatureMessage(cr, 'is Cured', C_Msg.MESSAGE_ROW, True);
    FxEngine.RemoveEffect(cr, effId, eff);
    RemoveEffectWithMessage := True;
  end;
end;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(eff The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(eff: Types.PEffectRec; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := eff^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(cr: Types.PWork; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldBase: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
  { Unused in this version; see the other implementations of this routine. }
  enc: Byte;
begin
  if (baseStr > cr^.fxStats[C_Stat.STRENGTH].permanent) or ((baseStr = 18) and (excStr > cr^.exStrBase)) then begin
    AdjustForNewStrength := True;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr);
  end else
    AdjustForNewStrength := False;
end;

procedure RecalcAbility(cr: Types.PWork; mode: ShortInt);
var
  statVal: Byte;
  baseStr: Byte;
  strExc: Byte;
  excStr: Byte;
  eff: Types.PEffectRec;
  hpSave: Byte;
  accum: Byte;
  tmp: Byte;
  i: ShortInt;
  p: Types.PItemRec;
  statOverride: Byte;
  enc: Byte;
  count: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (baseStr > statVal) or ((baseStr = 18) and (excStr > strExc)) then begin
      statVal := baseStr;
      strExc := excStr;
    end;
  end;

  { Add a class's constitution hit-point bonus for b levels into accum. }
  procedure StatBonus(a: ShortInt; b: Byte);
  begin
    if GDConsts.maxClassLevels[a] <= b then
      b := GDConsts.maxClassLevels[a] - 1;
    if a = C_Class.RANGER_LEVEL then
      if (cr^.fxLevelAtChange = 0) or (cr^.fxClassB[C_Class.RANGER_LEVEL] = cr^.fxLevelAtChange) then
        Inc(b);
    if (a = C_Class.FIGHTER_LEVEL) or (a = C_Class.RANGER_LEVEL) or (a = C_Class.PALADIN_LEVEL) then begin
      case statVal of
        15..19: Inc(accum, (statVal - 14) * b);
        20: Inc(accum, b * 5);
        21..23: Inc(accum, b * 6);
        24..25: Inc(accum, b * 7);
      end;
    end else begin
      if statVal > 15 then
        Inc(accum, b * 2)
      else if statVal = 15 then
        Inc(accum, b);
    end;
  end;

begin
  accum := 0;
  baseStr := 0;
  excStr := 0;
  statOverride := 255;
  p := Types.PItemRec(cr^.items);
  statVal := cr^.fxStats[mode].permanent;
  strExc := cr^.exStrBase;
  { ---- phase 1: scan the item list, accumulate stat modifiers ---- }
  while p <> nil do begin
    if (p^.special > $80) and (p^.equipped <> 0) then begin
      enc := p^.special and $7F;
      case mode of
        C_Stat.STRENGTH: begin
             case enc of
               5: case p^.effect of
                    0: begin baseStr := 18; excStr := 100; end;
                    1: baseStr := 19;
                    2: baseStr := 20;
                    3: baseStr := 21;
                    4: baseStr := 22;
                    5: baseStr := 23;
                    6: baseStr := 24;
                  end;
               8: if (cr^.fxStats[C_Stat.STRENGTH].permanent < 18) and (p^.effect = 0) then begin
                    baseStr := cr^.fxStats[C_Stat.STRENGTH].permanent + 1;
                    excStr := 0;
                  end;
               13: statOverride := 3;
             end;
             StrClamp;
           end;
        C_Stat.CONSTITUTION: begin
             if enc = 6 then Inc(statVal)
             else if enc = 8 then
               if (cr^.fxStats[C_Stat.CONSTITUTION].permanent < 18) and (p^.effect = 4) then Inc(statVal);
           end;
        C_Stat.INTELLIGENCE: begin
             case enc of
               8: if (cr^.fxStats[C_Stat.INTELLIGENCE].permanent < 18) and (p^.effect = 1) then Inc(statVal);
               12: statOverride := 7;
               13: statOverride := 3;
             end;
           end;
        C_Stat.WISDOM: if enc = 8 then
             if (p^.effect = 2) and (cr^.fxStats[C_Stat.WISDOM].permanent < 18) then Inc(statVal);
        C_Stat.DEXTERITY: begin
             case enc of
               2: case cr^.fxStats[C_Stat.DEXTERITY].permanent of
                    0..6: Inc(statVal, 4);
                    7..13: Inc(statVal, 2);
                  else Inc(statVal);
                  end;
               8: if (cr^.fxStats[C_Stat.DEXTERITY].permanent < 18) and (p^.effect = 3) then Inc(statVal);
               10: Dec(statVal, 2);
             end;
           end;
        C_Stat.CHARISMA: begin
             case enc of
               6: Dec(statVal);
               8: if (cr^.fxStats[C_Stat.CHARISMA].permanent < 18) and (p^.effect = 5) then Inc(statVal);
             end;
           end;
      end;
    end;
    p := p^.next;
  end;
  { ---- phase 2: write back the recomputed stat ---- }
  case mode of
    C_Stat.STRENGTH: begin
         if CharHlp.HasEffect(cr, C_Effect.STRENGTH, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           if (statVal <= 18) and (strExc < 100) then begin
             baseStr := statVal + baseStr;
             if baseStr > 18 then begin
               if (ShortInt(cr^.fxClassA[C_Class.FIGHTER_LEVEL]) > 0) or
                   (ShortInt(cr^.fxClassB[C_Class.FIGHTER_LEVEL]) > 0) or
                   (ShortInt(cr^.fxClassA[C_Class.PALADIN_LEVEL]) > 0) or
                       (ShortInt(cr^.fxClassB[C_Class.PALADIN_LEVEL]) > 0) or
                   (ShortInt(cr^.fxClassA[C_Class.RANGER_LEVEL]) > 0) or
                       (ShortInt(cr^.fxClassB[C_Class.RANGER_LEVEL]) > 0) then begin
                 excStr := cr^.exStrCur + (baseStr - 18) * 10;
                 if excStr > 100 then excStr := 100;
                 baseStr := 18;
               end else
                 baseStr := 18;
             end;
           end;
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, 146, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, C_Effect.ENLARGE, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if statOverride <> 255 then begin
           cr^.fxStats[C_Stat.STRENGTH].current := statOverride;
           cr^.exStrCur := 0;
         end else begin
           cr^.fxStats[C_Stat.STRENGTH].current := statVal;
           cr^.exStrCur := strExc;
         end;
       end;
    C_Stat.CONSTITUTION: begin
         count := 0;
         hpSave := cr^.fxHpMax;
         cr^.fxHpMax := cr^.pcHpRolled;
         for i := 0 to 7 do begin
           tmp := cr^.fxClassB[i];
           if tmp > 0 then StatBonus(i, tmp);
           tmp := cr^.fxClassA[i];
           if tmp > 0 then Inc(count);
           if GDConsts.maxClassLevels[i] < tmp then
             tmp := GDConsts.maxClassLevels[i];
           if tmp > cr^.fxLevelAtChange then begin
             Dec(tmp, cr^.fxLevelAtChange);
             StatBonus(i, tmp);
           end;
         end;
         accum := accum div count;
         Inc(cr^.fxHpMax, accum);
         if cr^.fxHpMax > hpSave then
           Inc(cr^.hpCur, cr^.fxHpMax - hpSave);
         if cr^.fxHpMax < hpSave then begin
           if cr^.hpCur > hpSave - cr^.fxHpMax then
             Dec(cr^.hpCur, hpSave - cr^.fxHpMax)
           else
             cr^.hpCur := 0;
         end;
         cr^.fxStats[C_Stat.CONSTITUTION].current := statVal;
         if cr^.fxStats[C_Stat.CONSTITUTION].current >= 20 then begin
           if not CharHlp.HasEffect(cr, 62, eff) then
             FxEngine.AddEffect(cr, 62, 60, 255, True);
         end else
           FxEngine.RemoveEffect(cr, 62, nil);
       end;
    C_Stat.INTELLIGENCE: begin
         if CharHlp.HasEffect(cr, 68, eff) then
           if statOverride > 7 then statOverride := 3;
         if statOverride <> 255 then
           cr^.fxStats[C_Stat.INTELLIGENCE].current := statOverride
         else
           cr^.fxStats[C_Stat.INTELLIGENCE].current := statVal;
       end;
    C_Stat.WISDOM: begin
         if CharHlp.HasEffect(cr, 68, eff) then
           if statOverride > 7 then statOverride := 3;
         if statOverride <> 255 then
           cr^.fxStats[C_Stat.WISDOM].current := statOverride
         else
           cr^.fxStats[C_Stat.WISDOM].current := statVal;
       end;
    C_Stat.DEXTERITY: if statOverride <> 255 then
         cr^.fxStats[C_Stat.DEXTERITY].current := statOverride
       else
         cr^.fxStats[C_Stat.DEXTERITY].current := statVal;
    C_Stat.CHARISMA: begin
         if CharHlp.HasEffect(cr, 14, eff) then
           Inc(statVal, eff^.strength);
         cr^.fxStats[C_Stat.CHARISMA].current := statVal;
       end;
  end;
end;

procedure InflictNonWeaponDamage(cr: Types.PWork; damage, saveReduction: Byte; saved: Boolean);
var
  s: String;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(6, cr);
  if saved then
    case saveReduction of
      1: GDVars.pendingDamage := 0;
      2: GDVars.pendingDamage := GDVars.pendingDamage div 2;
    end else
    FxEngine.TriggerEffectsWithCondition(20, cr);
  if GDVars.pendingDamage > 0 then begin
    if GDVars.pendingDamage <> 1 then
      s := 'takes ' + CharHlp.Uint8Str(GDVars.pendingDamage) + ' points of damage '
    else
      s := 'takes 1 point of damage ';
    case GDVars.elementMask and $F7 of
      1: s := s + 'from Fire';
      2: s := s + 'from Cold';
      4: s := s + 'from Electricity';
      16: s := s + 'from Acid';
    end;
    if (GDVars.elementMask and 8) = GDVars.elementMask then
      s := s + 'from Magic';
    CharHlp.PrintNameStringAnim(cr, False, s);
    CharHlp.InflictDamage(cr, GDVars.pendingDamage);
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      cr^.combatAddr^.castAllowed := 0;
      if cr^.combatAddr^.spellCast > 0 then begin
        CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
        CharHlp.RemoveSpell(cr, cr^.combatAddr^.spellCast);
        cr^.combatAddr^.spellCast := 0;
      end;
    end;
    if cr^.enabled = 0 then begin
      s := 'Goes Down';
      if (cr^.status = C_Status.DYING) and (cr^.levelUndead = 0) then
        s := s + ', and is Dying';
      if cr^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
        s := 'is killed';
      CharHlp.PrintCreatureMessage(cr, s, GDVars.curRow + 1, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveEffectsHp0(cr);
        FxEngine.TriggerEffectsWithCondition(13, cr);
        if cr^.enabled = 0 then
          CbtMap.CreatureDowned(cr)
        else
          TextRend.PauseOnly;
      end;
    end;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure AddEffectWithMessage(cr: Types.PWork; effId: Byte; minutes: Word; strength: Byte; onRemove, saveNegates,
                               saved: Boolean; msg: Types.TStr40);
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.gEffectCheck := effId;
  FxEngine.TriggerEffectsWithCondition(9, cr);
  if (GDVars.gEffectCheck = 0) or (saved and (saveNegates = True)) then
    CharHlp.PrintCreatureMessage(cr, 'is Unaffected', C_Msg.MESSAGE_ROW, True)
  else begin
    if CharHlp.HasEffect(cr, effId, eff) then
      if eff^.duration > 0 then
        FxEngine.RemoveEffect(cr, effId, eff);
    FxEngine.AddEffect(cr, effId, minutes, strength, onRemove);
    if msg[0] <> #0 then begin
      {$V-} CharHlp.PrintNameStringAnim(cr, True, msg); {$V+}
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(cr: Types.PWork; hp: Byte; bypassRot: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  RestoreHitPoints := False;
  if not (cr^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                         C_Status.DYING]) then Exit;
  if ((cr^.hpCur < cr^.fxHpMax) and bypassRot) or (not bypassRot) then begin
    cr^.hpCur := cr^.hpCur + hp;
    if cr^.hpCur > cr^.fxHpMax then
      cr^.hpCur := cr^.fxHpMax;
    if cr^.enabled = 0 then begin
      if cr^.status = C_Status.DYING then cr^.status := C_Status.UNCONSCIOUS;
      if (cr^.status = C_Status.UNCONSCIOUS) and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
        FxEngine.CallEffectHandler(78, cr, nil, True);
    end;
    RestoreHitPoints := True;
  end;
end;

function ReviveDeadCreature(cr: Types.PWork; hp: Byte): Boolean;
var
  s: Types.TStr40;
  valid: Boolean;
  slot: Byte;
begin
  valid := False;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    slot := CbtMap.CombatSlot(cr);
    if slot <> 0 then
      if GDVars.combatArenaLocation[slot].size <> 0 then
        valid := True;
  end;
  if valid or
      CbtMap.IsValidCreatureLoc(cr, CbtMap.CombatCellX(cr),
                                CbtMap.CombatCellY(cr), True) then begin
    cr^.status := C_Status.OKAY;
    cr^.enabled := 1;
    cr^.hpCur := hp;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      CbtMap.DisplayMapViewCentered(cr, 3, False);
    if cr^.fxHostile = 1 then
      s := 'stands up and grins'
    else
      s := 'gets back up';
    CharHlp.PrintCreatureMessage(cr, s, C_Msg.MESSAGE_ROW, True);
    CbtMap.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

begin
end.
