{ Combat attack resolution. It owns the to-hit and damage arithmetic, backstab, sweep, guarding and opportunity attacks,
  the flee check, turn undead, both aiming UIs (the target ring and the free cursor), the in-combat spell-target picker,
  and the monsters' special attacks: engulf, constrict, eye rays, hug, blood drain and the hold that follows them.

  It draws nothing of its own: the arena and the scrolling view come from CbtMap, the combat text lines and the creature
  panel from CharHlp, effects from FxEngine, menus from MenuCore. It owns no storage: its state is in GDConsts, GDVars
  and the combatants' work records. }
{$O+,F+}
{$A+}
{$R-}
{$S+}
unit CbtActs;

interface

uses Types, C_Status, C_Effect, C_Class, C_Dir, C_Item, C_Msg, C_Npc, C_Spell, C_Terr, GDConsts, GDVars, C_Keys, Crt,
  SoundDrv, CbtMap, FxEngine, CharHlp, Pathing, TextRend, ViewChar, ClassCal, GameIo, MenuCore, Border, Magic, C_Gbvm;

{ Start a combatant's round: clear its cast spell and attack flag, allow casting and item use unless its cell holds a
  stinking cloud or a cloudkill, set its attacks and sweeps, run its condition-18 effects, roll its initiative and set
  its movement. Initiative is 1d6 + CharHlp.DexMissileAdjust, at least 1 and 6 less when its side is surprised; it is 0
  for a disabled combatant or one outside 0..20.
  @param(creature The combatant.) }
procedure BeginRound(creature: Types.PWork);

{ Computes a creature's movement in half-steps: its current movement plus, for the party, the zone's movement modifier
  (a result outside 1..96 becomes 1), doubled and then adjusted by its condition-18 effects, which run with the movement
  flag set.
  @param(creature The creature whose movement is computed.)
  @returns(The movement in half-steps.) }
function CalcCreatureMovement(creature: Types.PWork): Byte;

{ Moves a creature one cell in a direction. The step costs the terrain cost times 2 half-steps, times 3 on a diagonal;
  with too few left, movement drops to 0 but the step is still taken. The view follows the mover (faster in quick
  fight). The step plays the step sound, resets the creature's flanking counts and lets guarding enemies attack, and a
  mover left out of play or helpless loses the rest of its movement.
  @param(creature The creature moving.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure CombatMoveCreature(creature: Types.PWork; direction: Byte);

{ Gives each enemy adjacent to a creature before a step, but not after it, one free attack on the mover, made as from
  behind, while the mover stays up. Helpless enemies, enemies an effect forbids to attack, and enemies draining blood or
  holding with a bite are skipped. An enemy with no initiative left that has already been attacked this round needs the
  mover in the five directions in front of it. The attack uses the enemy's highest phase with attacks left, granting one
  attack when that phase has no attacks left, and the enemy's own target is kept.
  @param(creature The creature about to move.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure AttacksOfOpportunity(creature: Types.PWork; direction: Byte);

{ Try to flee in the given direction: it works with no enemy on the field, when the fastest enemy's movement is below
  the combatant's own, or on 1d2 = 1 when they tie. A fleeing party member records its exit side, combat mode 1 ends the
  fight, the combatant leaves play 'Got Away', and an escaping hostile is counted; otherwise 'Escape is blocked'.
  @param(creature The combatant fleeing.)
  @param(direction Direction of the flight.)
  @returns(ClearGuard's result for the combatant.) }
function AttemptFlee(creature: Types.PWork; direction: Byte): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made, the result replaces the
  current attacks when it is below the previous count (in melee, below twice it). Note: otherwise the current attacks
  keep the base attacks value, in half-attacks, rather than the previous count.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Types.PWork);

{ Sweeps level-0 enemies. When the defender is an adjacent level-0 enemy, the attacker's sweep budget exceeds its
  current attacks, and more adjacent level-0 enemies stand around it than it has current attacks, the attacker makes one
  attack on each of up to its sweep budget of them, the defender first.
  @param(att The creature attacking.)
  @param(def The enemy chosen to attack.)
  @returns(True if the attacker swept.) }
function SweepAttack(att, def: Types.PWork): Boolean;

{ Checks whether effects let one creature attack another. True when the target is the attacker itself, False when the
  target is nil. Otherwise the target's condition-1 effects run, then, unless they vetoed, the attacker's condition-0
  effects with the target as its temporary target; an effect vetoes by setting the targeting veto flag.
  @param(attacker The creature that would attack.)
  @param(target The creature it would attack, or nil.)
  @returns(True when the attack is allowed.) }
function CanTarget(attacker, target: Types.PWork): Boolean;

{ Turn undead: roll the number of undead affected (1d12) and one check roll (1d20), and take the table column from the
  turner's cleric level, or its paladin level less 2 if higher, dual-class levels folded in (0 does nothing, 9..13 count
  as 9, more as 10). Then, weakest undead first, each one's threshold is GDConsts.turnTable[levelUndead, tableColumn]
  (signed): a roll at or above its absolute value turns it (positive) or destroys it (negative), and the first failure
  ends the turning. While fewer than six have been affected, destroying the last of the budget adds one more. 'Nothing
  Happens...' if none was affected; the turner's guard is cleared.
  @param(creature The turning combatant.) }
procedure CombatTurnUndead(creature: Types.PWork);

{ Finds the lowest-level unturned undead in the target list (any range); equal levels keep the earlier one, and undead
  of level 13 or more are never picked.
  @param(creature The creature turning undead.)
  @param(target Receives the undead found, or nil.)
  @returns(True if a target was found.) }
function FindTurnUndeadTarget(creature: Types.PWork; var target: Pointer): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Types.PWork);

{ Turn defender toward attacker (unless it is attacked from behind or has been attacked twice) and attacker toward
  defender, animate the missile when weapon is given and for a wielded weapon of type 47 or 101, and run RollAttacks if
  attacker has attacks left. A fired weapon then loses attacker's first-phase attack count of its quantity; used up, a
  throwable weapon drops to the treasure list unless it is special 137 or a boulder or manticore tail, and the rest are
  removed. The attacker's icon is redrawn. Note: the wielded weapon's type is read without a nil check.
  @param(attacker The attacker.)
  @param(defender The creature attacked.)
  @param(fromBehind True for an attack from behind, which leaves the defender's facing alone.)
  @param(weapon The missile or thrown weapon used, or nil.)
  @param(done Set, through ClearGuard, when the attacker's attacks are over.) }
procedure MakeAttack(attacker, defender: Types.PWork; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);

{ Pick the target of a cure spell in cr's cell and the eight around it; any other spell targets cr. The pick is the
  wounded ally with the fewest hit points, cr itself also when below half its maximum; but when a downed body that is
  not dead lies on a corpse cell and no wounded ally is below 8 hit points, the body.
  @param(spellId The spell being cast.)
  @param(cr The caster.)
  @param(tgt Receives the target, nil when none is found.)
  @returns(True when a target is found.) }
function FindCureTarget(spellId: Byte; cr: Types.PWork; var tgt: Types.PWork): Boolean;

{ Pick the targets of spellId into GDVars.targetCreaturePtr by the spell's target type, the low nibble of its touch
  field: 0 the caster, 3 every combatant on the caster's side, 5 a run of picks until their weight (by level, or by size
  for spell 79) passes a budget of 2d4 (the caster's level for spell 79), 15 one pick, or the creatures around the
  picked cell when it holds no creature, 8..14 the creatures within touch and 7 cells of the picked cell, and anything
  else up to (touch and 3) + 1 separate picks. Each pick goes through SelectSpellTarget; a repeated pick is refused
  ('Already been targeted') or, for an AI caster, uses up a pick. Note: type 15's radius, (touch and $F) shr 4, is
  always 0.
  @param(spellId The spell being cast.)
  @param(dir 0 for a player's aim, else the AI's picks.)
  @param(done Cleared when a single pick fails or no separate pick is made.) }
procedure SelectCombatTargets(spellId, dir: Byte; var done: Boolean);

{ Cast a spell in combat. spellId 0 asks with the spell menu; a camp-only spell is refused. silent = 0 redraws the
  combat interface and centers the caster first. A spell whose casting time (drainLevels div 3) is 0 is cast at once; a
  slower one is begun ('Begins Casting'), its time taken off the caster's initiative (to no less than 1), and when
  silent its targets are picked now.
  @param(spellId The spell, or 0 to choose one.)
  @param(silent Nonzero for an AI caster: no redraw, and the targets picked for it.)
  @param(done Set when the spell was cast or begun.) }
procedure CastSpellCombat(spellId, silent: Byte; var done: Boolean);

{ Confirms an attack on an ally; enemies and quick-fighting attackers pass unasked. Yes sets the attacked-allies flags,
  each okay NPC turns hostile and drops its target, and the teams are recounted.
  @param(attacker The attacker.)
  @param(defender The defender.)
  @returns(True when the attack goes ahead.) }
function CheckAttackAlly(attacker, defender: Types.PWork): Boolean;

{ The aiming menu: build a list of the targets around cr, start on the first one not on cr's side, and step the
  highlight between the targets (N/P, wrapping) with a moving cursor; M or an arrow key drops to ManualAimCursor, T
  takes the aim through ConfirmAttackTarget and C recenters. With GDVars.extFlag set only the arrow keys are read.
  @param(cr The aiming combatant.)
  @param(range The reach; 255 takes the ready weapon's range less 1, or 1 with none.)
  @param(weaponMode 1 for a weapon attack, 0 for a spell.)
  @param(groundOk Nonzero when an empty cell can be aimed at.)
  @param(flag4 Nonzero when a creature can be aimed at.)
  @param(done Set when an aim is taken.)
  @param(tgt The caller's target record: the creature and its cell.) }
procedure CombatAimMenu(cr: Types.PWork; range, weaponMode, groundOk, flag4: Byte; var done: Boolean;
                        var tgt);

{ Finds the direction from one creature to another, using eight sectors whose slope thresholds are 106/256 and 618/256;
  the same cell gives 0.
  @param(creature The creature looking.)
  @param(other The creature looked at.)
  @returns(The direction, 0..7 clockwise from north.) }
function DirTowardTarget(creature, other: Types.PWork): Byte;

{ Sets the hostiles' hit-point percentage: the enabled hostiles' current hit points as a percentage of the hostiles'
  combined maximum hit points, disabled ones included, rounded down to a multiple of five; it is left unchanged when
  there are no hostiles. Note: the totals are Words multiplied by 20, so above 3276 hit points the percentage wraps. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Types.PWork): Byte;

{ Makes sure a creature has a locked target. A lock is kept, without a range check, unless `forceNew` is set or the
  target is now an ally, disabled or forbidden by CanTarget. Otherwise it makes up to 20 random picks among the enemies
  in range, dropping forbidden ones; when that fails a second pass repeats it, with terrain no longer blocking unless
  `forceNew` is set, and there `relaxed` accepts a pick without CanTarget.
  @param(cr The creature.)
  @param(range The range in cells.)
  @param(relaxed Nonzero to accept a second-pass pick without CanTarget.)
  @param(forceNew Nonzero to drop the lock and keep terrain blocking.)
  @returns(True when the creature has a target.) }
function AcquireTarget(cr: Types.PWork; range, relaxed, forceNew: Byte): Boolean;

{ Engulf, an effect handler: on 1..4 of 1d10, unless the target is down, immobile or suffocating, or cr is already
  swallowing a victim, print '<cr> engulfs <target>', make the target immobile and suffocating for 2d4, and give cr the
  swallowing hold on the target's slot.
  @param(cr The engulfing creature; its target is the victim.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure AttackEngulf(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Fires up to four eye rays, starting with a fresh target. Each eye fires the first unused ray whose range covers the
  target: disintegrate (distance 2 or less), stone (3), death (4), each allowing a saving throw, or a 2d8+1 wound (5);
  when no ray applies it casts the first unused of spells $54, $37 and $15. After each ray AcquireTarget checks the
  target again, keeping it while it is still a valid enemy. Note: the line-of-sight result is never tested, so rays also
  fire at targets out of sight.
  @param(cr The creature with the eyes.)
  @param(deadCombat Unused.)
  @param(deadFlag Unused.) }
procedure AttackEyeRays(cr: Types.PWork; deadCombat: Types.PCombatRec; deadFlag: Byte);

{ Constrict, an effect handler: on 1..4 of 1d10, with the target and cr up, cr not already constricting and the target
  not immobile, print '<cr> constricts <target>', make the target immobile and give cr the constricting hold on the
  target's slot.
  @param(cr The constricting creature; its target is the victim.)
  @param(combat Unused.)
  @param(secondary Unused.) }
procedure AttackConstrict(cr: Types.PWork; combat: Types.PCombatRec; secondary: Byte);

{ Hug, an effect handler: with a target, cr not already hugging, the target not immobile and GDVars.currentAttackRoll at
  least 18, print '<cr> hugs <target>', make the target immobile and give cr the hugging hold on the target's slot. The
  target is left in GDVars.otherCreatureCurrentPtr.
  @param(cr The hugging creature; its target is the victim.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure AttackHug(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A hold's round, the handler of cr's hold effect, whose id is combat^.spellCast (swallowing, constricting, draining
  blood, else hugging) and whose victim is the creature in slot combat^.initiative. When secondary is nonzero or either
  is down, the victim is freed (no longer immobile, and no longer suffocating from a swallow) and, unless secondary, the
  hold ends. Otherwise cr makes two attacks with the hold's damage, 1d2 constricting, 1d4 draining blood, 2d8 swallowing
  or holding, and the hold ends if the victim goes down.
  @param(cr The holding creature.)
  @param(combat The hold effect's record.)
  @param(secondary Nonzero frees the victim without ending the hold.) }
procedure BiteAndHold(cr: Types.PWork; combat: Types.PCombatRec; secondary: Byte);

{ Blood drain, an effect handler: on 1..4 of 1d10, with the target up, cr not already draining and the target not
  immobile, print '<cr> drains blood from <target>', make the target immobile and give cr the blood-draining hold on the
  target's slot.
  @param(cr The draining creature; its target is the victim.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure AttackDrainBlood(cr: Types.PWork; p: Pointer; removed: Boolean);

{ The editor's instant win: while GDVars.superMode is nonzero, print 'The Gods intervene!', kill every hostile, clear
  every combatant's guard and recenter the view.
  @returns(True.) }
function VictoryCheat: Boolean;

{ Return a class's level plus, when the dual-class abilities are restored, the level in that class before the change.
  @param(cr The character.)
  @param(cls The class, a C_Class level index.)
  @returns(The combined level.) }
function TotalClassLevel(cr: Types.PWork; cls: ShortInt): ShortInt;

implementation

type
  { One acquired-target slot as filled by SelectSpellTarget: the creature and its arena cell x/y. SelectCombatTargets's
    res and the unused bytes after it form this record. }
  PTgtRec = ^TTgtRec;
  TTgtRec = record
    cr: Types.PWork;
    cellX: Byte;
    cellY: Byte;
    cellYTail: Byte;
  end;

procedure CalcWeaponDamage(attacker, defender: Types.PWork; phase: Byte); forward;

procedure ProcessAttackResult(attacker, defender: Types.PWork; manner, damage, shownDamage: Byte;
                              isHit: Boolean); forward;

procedure GuardersAttack(creature: Types.PWork); forward;

function AttacksFromRate(rate: Byte): Byte; forward;

function IsBackstab(attacker, defender: Types.PWork): Boolean; forward;

procedure RollAttacks(att, def: Types.PWork; fromBehind: Boolean; var done: Boolean; other: Types.PItemRec); forward;

procedure AnimateMissile(attacker, defender: Types.PWork; weapon: Types.PItemRec); forward;

procedure ApplyRangePenalty(attacker, defender: Types.PWork; var armorClass: Byte); forward;

function SelectSpellTarget(spellId, aiControlled, groundOk: Byte; var target: Types.PWork): Boolean; forward;

procedure BeginRound(creature: Types.PWork);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  cellIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  specialTerrain: Byte;
  inStinkingCloud: Byte;
  inCloudkill: Byte;
begin
  with Types.PWork(creature)^.combatAddr^ do begin
    spellCast := 0;
    CbtMap.ProbeDirection(creature, C_Dir.CENTER,
                          cellIndex, cellIndex, inStinkingCloud, inCloudkill);
    castAllowed := Ord((inStinkingCloud = 0) and (inCloudkill = 0));
    itemUseAllowed := Ord((inStinkingCloud = 0) and (inCloudkill = 0));
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.currentAttackCurrent := Types.PWork(creature)^.attacks2;
    GDVars.currentCreatureCalculatingFlag := 0;
    FxEngine.TriggerEffectsWithCondition(18, Types.PWork(creature));
    Types.PWork(creature)^.curAtt[2] := CbtActs.AttacksFromRate(GDVars.currentAttackCurrent);
    sweepCount := Types.PWork(creature)^.cbAttackLevel;
    if Types.PWork(creature)^.enabled <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(Types.PWork(creature));
      if initiative < 1 then
        initiative := 1;
      if Byte((Types.PWork(creature)^.hostile + 1) and Integer(GDVars.gbvmZone1Ptr^[C_Gbvm.SURPRISE])) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  Types.PWork(creature)^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

function CalcCreatureMovement(creature: Types.PWork): Byte;
var
  movement: Byte;
begin
  movement := Types.PWork(creature)^.movementCur;
  if Types.PWork(creature)^.hostile = 0 then
    movement := movement + GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_MOVE_MODIFIER];
  GDVars.currentCreatureCalculatingFlag := 1;
  if (movement < 1) or (movement > 96) then
    movement := 1;
  GDVars.currentAttackCurrent := movement * 2;
  FxEngine.TriggerEffectsWithCondition(18, Types.PWork(creature));
  GDVars.currentCreatureCalculatingFlag := 0;
  CalcCreatureMovement := GDVars.currentAttackCurrent;
end;

{ Roll the damage of attack phase 1 or 2 into GDVars.pendingDamage: its dice plus its bonus, at least 0, multiplied for
  a backstab by (thief level + restored dual-class thief level - 1) div 4 + 2. GDVars.elementMask is 1 for a weapon of
  item type 86. Then the attacker's condition-4 and the defender's condition-5 effects run.
  @param(attacker The attacker.)
  @param(defender The creature hit.)
  @param(phase Attack phase, 1 or 2.) }
procedure CalcWeaponDamage(attacker, defender: Types.PWork; phase: Byte);
begin
  GDVars.pendingDamage := FxEngine.RollDamageDice(attacker^.curRollsA[phase], attacker^.curDiceA[phase])
      + attacker^.curModA[phase];
  if GDVars.pendingDamage < 0 then
    GDVars.pendingDamage := 0;
  if CbtActs.IsBackstab(attacker, defender) then
    GDVars.pendingDamage := GDVars.pendingDamage *
      (Word(attacker^.classLevels[C_Class.THIEF_LEVEL] +
            attacker^.cbOldThiefLevel * ClassCal.EarlierClassActive(Types.PWork(attacker)) - 1) div 4 + 2);
  GDVars.elementMask := 0;
  if attacker^.cbWeapon <> nil then
    if attacker^.cbWeapon^.itemType = 86 then
      GDVars.elementMask := 1;
  FxEngine.TriggerEffectsWithCondition(4, Types.PWork(attacker));
  FxEngine.TriggerEffectsWithCondition(5, Types.PWork(defender));
end;

{ Report an attack and apply it: the attacker's verb ('-Backstabs-' for manner 2, 'slays helpless' for 3, else
  'Attacks'), the defender, '(from behind) ' for manner 1, and the hit and its damage or the miss. A damaged defender
  may cast no more this round and loses a spell it was casting; a defender put down is reported ('goes down', 'and is
  Dying', 'is killed'), its 0-hit-point effects removed, its condition-13 effects run and, if still down, its body
  placed.
  @param(attacker The attacker.)
  @param(defender The creature attacked.)
  @param(manner 0 a plain attack, 1 from behind, 2 a backstab, 3 a helpless defender slain.)
  @param(damage Damage inflicted.)
  @param(shownDamage Damage reported.)
  @param(isHit True for a hit.) }
procedure ProcessAttackResult(attacker, defender: Types.PWork; manner, damage, shownDamage: Byte; isHit: Boolean);
var
  row: Byte;
  message: String[80];
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(Types.PWork(attacker), message, C_Msg.MESSAGE_ROW, False);
  row := 12;
  CharHlp.DisplayCreatureName(Types.PWork(defender), 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.Uint8Str(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(Types.PWork(defender), damage);
  end else
    message := message + 'and Misses';
  if defender^.status <> C_Status.GONE then
    TextRend.DisplayMessageWindow(23, row, 38, row + 3, LightGreen, Black, True, message);
  row := GDVars.curRow + 1;
  if damage > 0 then begin
    defender^.combatAddr^.castAllowed := 0;
    if defender^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(Types.PWork(defender), 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender, defender^.combatAddr^.spellCast);
      defender^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if defender^.enabled = 0 then begin
    CharHlp.PrintCreatureMessage(Types.PWork(defender), 'goes down', row, False);
    Inc(row, 2);
    if (defender^.status = C_Status.DYING) and (defender^.thiefSkills[$E9] = 0) then
      TextRend.DisplayString(23, row, LightGreen, Black, 'and is Dying');
    if defender^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
      CharHlp.PrintCreatureMessage(Types.PWork(defender), 'is killed', row, False);
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(Types.PWork(defender));
    FxEngine.TriggerEffectsWithCondition(13, Types.PWork(defender));
    if defender^.enabled = 0 then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Types.PWork);
var
  count: Byte;
  index: Byte;
  guarder: Types.PWork;
  done: Boolean;
begin
  count := CharHlp.CountTargets(Types.PWork(creature), 1);
  for index := 1 to count do
    if creature^.enabled <> 0 then begin
      guarder := GDVars.creaturePtr[GDVars.potentialTargetCreature[index]];
      if (guarder^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(Types.PWork(guarder))) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature),
                          CbtMap.CombatCellY(creature), 2, C_Dir.CENTER);
        guarder^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(guarder, creature);
        CbtActs.MakeAttack(guarder, creature, False, nil, done);
      end;
    end;
end;

procedure CombatMoveCreature(creature: Types.PWork; direction: Byte);
var
  moveCost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  slot := CbtMap.CombatSlot(creature);
  x := GDVars.combatArenaLocation[slot].x;
  y := GDVars.combatArenaLocation[slot].y;
  nx := x + GDConsts.dirDX[direction];
  ny := y + GDConsts.dirDY[direction];
  if Odd(direction) then
    moveCost := GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[ny, nx]].cost * 3
  else
    moveCost := GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[ny, nx]].cost * 2;
  if moveCost > Types.PWork(creature)^.combatAddr^.movement then
    Types.PWork(creature)^.combatAddr^.movement := 0
  else
    Dec(Types.PWork(creature)^.combatAddr^.movement, moveCost);
  moveCost := 1;
  if Types.PWork(creature)^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.combatArenaPtr^.ox, ny - GDVars.combatArenaPtr^.oy) then
      if GDVars.combatMapVisible <> 0 then
        CbtMap.ScrollView(x, y, 2, C_Dir.CENTER);
  end;
  if GDVars.combatMapVisible <> 0 then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.combatArenaLocation[slot].x := nx;
  GDVars.combatArenaLocation[slot].y := ny;
  CbtMap.BuildArenaArrays;
  if GDVars.combatMapVisible <> 0 then
    CbtMap.ScrollView(nx, ny, moveCost, C_Dir.CENTER);
  Types.PWork(creature)^.combatAddr^.attackerCount := 0;
  Types.PWork(creature)^.combatAddr^.flankTotal := 0;
  SoundDrv.SoundCommand(10);
  CbtActs.GuardersAttack(creature);
  if (Types.PWork(creature)^.enabled = 0) or CharHlp.IsHelpless(Types.PWork(creature)) then
    Types.PWork(creature)^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Types.PWork; direction: Byte);
var
  candidates: array[1..12] of Byte;
  effect: Types.PEffectRec;
  stillAdjacent: Boolean;
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  candidateCount: Byte;
  countAfter: Byte;
  scanPos: Byte;
  index: Byte;
  phasePos: Byte;
  phase: Byte;
  facingScan: Byte;
  attacker: Types.PWork;
  savedTarget: Pointer;
begin
  FillChar(candidates, SizeOf(candidates), 0);
  slot := CbtMap.CombatSlot(creature);
  candidateCount := CharHlp.CountTargets(Types.PWork(creature), 1);
  if candidateCount = 0 then
    Exit;
  for index := 1 to candidateCount do
    candidates[index] := GDVars.potentialTargetCreature[index];
  Inc(GDVars.combatArenaLocation[slot].x, GDConsts.dirDX[direction]);
  Inc(GDVars.combatArenaLocation[slot].y, GDConsts.dirDY[direction]);
  countAfter := CharHlp.CountTargets(Types.PWork(creature), 1);
  Dec(GDVars.combatArenaLocation[slot].x, GDConsts.dirDX[direction]);
  Dec(GDVars.combatArenaLocation[slot].y, GDConsts.dirDY[direction]);
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.potentialTargetCreature[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if Types.PWork(creature)^.enabled <> 0 then begin
        GDVars.combatRedraw := 1;
        GDVars.combatMapVisible := 1;
        attacked := False;
        attacker := GDVars.creaturePtr[candidates[index]];
        if not CharHlp.IsHelpless(Types.PWork(attacker)) then
          if CbtActs.CanTarget(attacker, creature) then
            if not CharHlp.HasEffect(Types.PWork(attacker), 75, effect) then
              if not CharHlp.HasEffect(Types.PWork(attacker), 74, effect) then
                for facingScan := attacker^.combatAddr^.direction + 6
                    to attacker^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (attacker^.combatAddr^.initiative > 0)
                       or (attacker^.combatAddr^.attackerCount = 0)
                       or
                          Pathing.IsDirToward(CbtMap.CombatCellX(attacker),
                                              CbtMap.CombatCellY(attacker),
                                              CbtMap.CombatCellX(creature),
                                              CbtMap.CombatCellY(creature), facingScan mod 8)
                    then begin
                      phase := 1;
                      if attacker^.attacks = 0 then
                        phase := 2;
                      for phasePos := 1 to SizeOf(attacker^.curAtt) do
                        if attacker^.curAtt[phasePos] > 0 then
                          phase := phasePos;
                      if attacker^.curAtt[phase] = 0 then
                        attacker^.curAtt[phase] := 1;
                      attacker^.combatAddr^.attackPhase := phase;
                      savedTarget := attacker^.combatAddr^.other;
                      CbtActs.MakeAttack(attacker, creature, True, nil, GDVars.doneRoundFlag);
                      attacked := True;
                      attacker^.combatAddr^.other := savedTarget;
                      if Types.PWork(creature)^.enabled <> 0 then begin
                        GDVars.combatRedraw := 1;
                        CharHlp.CombatPrintCreatureInfo(Types.PWork(creature));
                      end;
                    end;
      end;
end;

{ Return the side a fleeing party member leaves by: an orthogonal dir is itself; a diagonal turns counter-clockwise (dir
  and 6), or clockwise for north-east off the top row, south-east left of column 48, south-west on column 0 and
  north-west on row 0. Slot 0 always turns counter-clockwise.
  @param(dir Direction of the flight.)
  @param(cr The fleeing combatant.)
  @returns(The exit side, a direction.) }
function FleeDirection(dir: Byte; cr: Types.PWork): Byte;
var
  slot: Byte;
begin
  FleeDirection := dir and 6;
  if (dir = C_Dir.NORTH) or (dir = C_Dir.EAST) or (dir = C_Dir.SOUTH) or (dir = C_Dir.WEST) then
    Exit;
  slot := CbtMap.CombatSlot(cr);
  if slot = 0 then
    Exit;
  if dir = C_Dir.NORTHEAST then
    if GDVars.combatArenaLocation[slot].y <> 0 then begin
      FleeDirection := C_Dir.EAST;
      Exit;
    end;
  if dir = C_Dir.SOUTHEAST then
    if GDVars.combatArenaLocation[slot].x < 48 then begin
      FleeDirection := C_Dir.SOUTH;
      Exit;
    end;
  if dir = C_Dir.SOUTHWEST then
    if GDVars.combatArenaLocation[slot].x = 0 then begin
      FleeDirection := C_Dir.WEST;
      Exit;
    end;
  if dir = C_Dir.NORTHWEST then
    if GDVars.combatArenaLocation[slot].y = 0 then
      FleeDirection := C_Dir.NORTH;
end;

function AttemptFlee(creature: Types.PWork; direction: Byte): Boolean;
var
  hasEscaped: Boolean;
  enemyMove: Byte;
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then begin
    if creature^.hostile = 0 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.FLEE_DIRECTION] := CbtActs.FleeDirection(direction, creature);
    if GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1 then
      GDVars.combatTransition := 1;
    FxEngine.PutOutOfPlayWithStatus(Types.PWork(creature), C_Status.RUNNING, 'Got Away');
    if creature^.hostile = 1 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] := GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] + 1;
  end else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.ClearGuard(Types.PWork(creature));
end;

procedure RecalcAttacksLeft(creature: Types.PWork);
var
  attacks: Byte;
  previous: Byte;
  ammoLimit: Byte;
  rate: Byte;
  ranged: Boolean;
  weapon: Types.PItemRec;
begin
  ranged := False;
  previous := Types.PWork(creature)^.curAtt[1];
  Types.PWork(creature)^.curAtt[1] := Types.PWork(creature)^.attacks;
  if CharHlp.HasRangedWeapon(Types.PWork(creature)) and
      CharHlp.FindDamagingRangedWeapon(Types.PWork(creature), Pointer(weapon)) then begin
    ranged := True;
    rate := GDVars.baseItems[Types.PWork(creature)^.cbWeapon^.itemType].rateOfFire;
    if rate < 2 then
      rate := 2;
    GDVars.currentAttackCurrent := rate;
  end else
    GDVars.currentAttackCurrent := Types.PWork(creature)^.curAtt[1];
  GDVars.currentCreatureCalculatingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(18, Types.PWork(creature));
  attacks := CbtActs.AttacksFromRate(GDVars.currentAttackCurrent);
  if ranged then
    if weapon <> nil then begin
      ammoLimit := 1;
      if weapon <> nil then
        if weapon^.quantity > ammoLimit then
          ammoLimit := weapon^.quantity;
      if ammoLimit < attacks then
        if weapon^.quantity > 0 then
          attacks := ammoLimit;
    end;
  if (Types.PWork(creature)^.combatAddr^.madeAttack = 0) or (attacks < previous)
     or ((Types.PWork(creature)^.combatAddr^.madeAttack <> 0) and (attacks < previous * 2) and (not ranged)) then
    Types.PWork(creature)^.curAtt[1] := attacks;
end;

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.combatRoundCounterCount) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function SweepAttack(att, def: Types.PWork): Boolean;
var
  cntBefore: Byte;
  inRange: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PWork;
begin
  SweepAttack := False;
  if Types.PWork(att)^.curAtt[1] < Types.PWork(att)^.combatAddr^.sweepCount then
    if Types.PWork(def)^.cbLevelHighest = 0 then
      if CharHlp.CalcDistance(Types.PWork(att), Types.PWork(def)) = 1 then begin
        cntBefore := CharHlp.CountTargets(Types.PWork(att), 1);
        inRange := 0;
        for i := 1 to cntBefore do begin
          p := GDVars.creaturePtr[GDVars.potentialTargetCreature[i]];
          if p = def then
            defIdx := i;
          if p^.cbLevelHighest = 0 then
            Inc(inRange);
        end;
        if inRange > Types.PWork(att)^.curAtt[1] then begin
          if inRange > Types.PWork(att)^.combatAddr^.sweepCount then
            inRange := Types.PWork(att)^.combatAddr^.sweepCount;
          CharHlp.PrintCreatureMessage(Types.PWork(att), 'sweeps', C_Msg.MESSAGE_ROW, True);
          p := GDVars.creaturePtr[GDVars.potentialTargetCreature[1]];
          if p <> def then begin
            GDVars.potentialTargetCreature[defIdx] := GDVars.potentialTargetCreature[1];
            GDVars.potentialTargetCreature[1] := CbtMap.CombatSlot(def);
          end;
          for i := 1 to cntBefore do
            if inRange > 0 then
              if GDVars.creaturePtr[GDVars.potentialTargetCreature[i]]^.cbLevelHighest = 0 then begin
                p := GDVars.creaturePtr[GDVars.potentialTargetCreature[i]];
                CbtActs.NoteAttackDirection(att, p);
                Types.PWork(att)^.curAtt[1] := 1;
                CbtActs.MakeAttack(att, p, False, nil, GDVars.doneRoundFlag);
                Dec(inRange);
              end;
          SweepAttack := True;
        end;
      end;
end;

function CanTarget(attacker, target: Types.PWork): Boolean;
var
  savedTarget: Pointer;
begin
  CanTarget := False;
  if target <> nil then
    if attacker = target then
      CanTarget := True
    else begin
      GDVars.currentSuppressTargetingFlag := 0;
      FxEngine.TriggerEffectsWithCondition(1, Types.PWork(target));
      if GDVars.currentSuppressTargetingFlag = 0 then begin
        savedTarget := Types.PWork(attacker)^.combatAddr^.other;
        Types.PWork(attacker)^.combatAddr^.other := Types.PWork(target);
        FxEngine.TriggerEffectsWithCondition(0, Types.PWork(attacker));
        Types.PWork(attacker)^.combatAddr^.other := savedTarget;
      end;
      CanTarget := GDVars.currentSuppressTargetingFlag = 0;
    end;
end;

function TotalClassLevel(cr: Types.PWork; cls: ShortInt): ShortInt;
begin
  TotalClassLevel :=
    cr^.classLevels2[cls] * ClassCal.EarlierClassActive(Types.PWork(cr)) +
    cr^.classLevels[cls];
end;

procedure CombatTurnUndead(creature: Types.PWork);
var
  { 1d20 check roll }
  roll: Byte;
  { 1d12 budget of undead }
  affectedLeft: Byte;
  minimumLeft: Byte;
  { signed table threshold }
  needed: ShortInt;
  turnedAny: Boolean;
  stop: Boolean;
  { the undead being turned }
  target: Pointer;
  tableColumn: ShortInt;
begin
  CharHlp.PrintCreatureMessage(Types.PWork(creature), 'turns undead...', C_Msg.MESSAGE_ROW, False);
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  turnedAny := False;
  stop := False;
  Types.PWork(creature)^.combatAddr^.usedTurnUndead := 1;
  minimumLeft := 6;
  affectedLeft := FxEngine.RollDice(1, 12);
  roll := FxEngine.RollDice(1, 20);
  tableColumn := CbtActs.TotalClassLevel(creature, C_Class.CLERIC_LEVEL);
  if tableColumn + 2 < CbtActs.TotalClassLevel(creature, C_Class.PALADIN_LEVEL) then
    tableColumn := CbtActs.TotalClassLevel(creature, C_Class.PALADIN_LEVEL) - 2;
  case tableColumn of
    0: stop := True;
    1..8: tableColumn := tableColumn;
    9..13: tableColumn := 9;
  else
    tableColumn := 10;
  end;
  while CbtActs.FindTurnUndeadTarget(creature, target) and (affectedLeft > 0) and (not stop) do begin
    needed := GDConsts.turnTable[Types.PWork(target)^.levelUndead, tableColumn];
    if roll >= Abs(needed) then begin
      turnedAny := True;
      CbtMap.DisplayMapViewCentered(target, 3, False);
      GDVars.combatRedraw := 1;
      CharHlp.CombatPrintCreatureInfo(Types.PWork(target));
      if needed > 0 then begin
        FxEngine.PutOutOfPlayWithStatus(Types.PWork(target), C_Status.GONE, 'is turned');
      end else begin
        CharHlp.PrintCreatureMessage(Types.PWork(target), 'Is destroyed', C_Msg.MESSAGE_ROW, False);
        CbtMap.CreatureDowned(target);
        Types.PWork(target)^.status := C_Status.GONE;
        Types.PWork(target)^.enabled := 0;
      end;
      if minimumLeft > 0 then
        Dec(minimumLeft);
      Dec(affectedLeft);
      if (affectedLeft = 0) and (minimumLeft > 0) and (needed < 0) then
        Inc(affectedLeft);
      CharHlp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not turnedAny then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CbtMap.CountTeams;
  GDVars.doneRoundFlag := CharHlp.ClearGuard(Types.PWork(creature));
  CharHlp.ClearMessageWindow;
end;

function FindTurnUndeadTarget(creature: Types.PWork; var target: Pointer): Boolean;
var
  count: Byte;
  index: Byte;
  bestLevel: ShortInt;
  candidate: Types.PWork;
begin
  bestLevel := 13;
  target := nil;
  count := CharHlp.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for index := 1 to count do begin
    candidate := GDVars.creaturePtr[GDVars.potentialTargetCreature[index]];
    if (candidate^.combatAddr^.turned = 0) and (candidate^.levelUndead > 0)
       and (candidate^.levelUndead < bestLevel) then begin
      bestLevel := candidate^.levelUndead;
      target := candidate;
      FindTurnUndeadTarget := True;
    end;
  end;
end;

{ Resolves an attacker's remaining attacks on a defender. A helpless defender is slain with one blow (its hit points
  plus 5) and the attacks are spent. Otherwise the attacker uses its weapon's large-target dice against a large
  defender, and the defense is the rear armor class less 4 on a backstab, the rear armor class from behind (when asked,
  or when the defender was attacked more than once with the attacker at its back and a flank spread above 4), else the
  front armor class, plus range penalties. The attacks are rolled from the current attack phase down to 1 until the
  defender drops; a miss is reported when no attack hits, a used-up missile of type 100 ends the attacks, and the sweep
  budget is spent. Note: an attacker that goes down during its attacks loses the rest of that phase's attacks but still
  makes the next phase's.
  @param(att The creature attacking.)
  @param(def The creature attacked.)
  @param(fromBehind True to attack as from behind.)
  @param(done Set True when the attacker has no attacks left or is down; its actions then end.)
  @param(other The missile or thrown item, or nil.) }
procedure RollAttacks(att, def: Types.PWork; fromBehind: Boolean; var done: Boolean; other: Types.PItemRec);
var
  weaponRec: Types.TBaseItemRec;
  attackMade: Boolean;
  defDown: Boolean;
  backstab: Byte;
  ac: Byte;
  k: Byte;
  phase: Byte;
  atkType: Byte;
  { acCurArr's index: 1 for the rear armor class }
  bsFlag: ShortInt;
begin
  backstab := Byte(fromBehind);
  done := False;
  GDVars.currentNumberHits[1] := 0;
  GDVars.currentNumberHits[2] := 0;
  GDVars.attacksMade[1] := 0;
  GDVars.attacksMade[2] := 0;
  attackMade := False;
  defDown := False;
  GDVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(Types.PWork(def)) then begin
    SoundDrv.SoundCommand(7);
    while att^.curAtt[att^.combatAddr^.attackPhase] = 0 do
      Dec(att^.combatAddr^.attackPhase);
    Inc(GDVars.attacksMade[att^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, def^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(Types.PWork(att));
    for k := 1 to SizeOf(att^.curAtt) do
      att^.curAtt[k] := 0;
    attackMade := True;
    done := True;
  end else begin
    if att^.cbWeapon <> nil then
      if (def^.iconDim > $80) or ((def^.iconDim and 7) > 1) then begin
        weaponRec := GDVars.baseItems[att^.cbWeapon^.itemType];
        att^.curRollsA[1] := weaponRec.dmgLgRolls;
        att^.curDiceA[1] := weaponRec.dmgLgDice;
        att^.curModA[1] := att^.curModA[1] - weaponRec.dmgSmMod
            + weaponRec.dmgLgMod;
      end;
    CharHlp.RecalcStats(Types.PWork(def));
    FxEngine.TriggerEffectsWithCondition(11, Types.PWork(def));
    bsFlag := 0;
    if CbtActs.IsBackstab(att, def) then
      ac := def^.acCurArr[1] - 4
    else begin
      if def^.combatAddr^.attackerCount > 1 then
        if CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction then
          if def^.combatAddr^.flankTotal > 4 then
            backstab := 1;
      if backstab <> 0 then
        bsFlag := 1;
      ac := def^.acCurArr[bsFlag];
    end;
    CbtActs.ApplyRangePenalty(att, def, ac);
    atkType := 0;
    if backstab <> 0 then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    phase := att^.combatAddr^.attackPhase;
    for k := phase downto 1 do
      while (att^.curAtt[k] > 0) and (not defDown) do begin
        Dec(att^.curAtt[k]);
        att^.combatAddr^.attackPhase := k;
        Inc(GDVars.attacksMade[k]);
        if FxEngine.AttackRoll(Types.PWork(att), Types.PWork(def), ac)
           or CharHlp.IsHelpless(Types.PWork(def)) then begin
          Inc(GDVars.currentNumberHits[k]);
          SoundDrv.SoundCommand(7);
          attackMade := True;
          CbtActs.CalcWeaponDamage(att, def, k);
          CbtActs.ProcessAttackResult(att, def, atkType, GDVars.pendingDamage, GDVars.pendingDamage, True);
          if def^.enabled <> 0 then
            FxEngine.TriggerEffectsWithCondition(k + 1, Types.PWork(att));
          if def^.enabled = 0 then
            defDown := True;
          if att^.enabled = 0 then begin
            phase := 0;
            att^.curAtt[k] := 0;
          end;
        end;
      end;
    if (other <> nil) and (other^.quantity = 0) and (other^.itemType = 100) then
      for k := 1 to SizeOf(att^.curAtt) do
        att^.curAtt[k] := 0;
    if not attackMade then begin
      SoundDrv.SoundCommand(9);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    { not for a helpless defender }
    done := True;
    for k := 1 to SizeOf(att^.curAtt) do
      if att^.curAtt[k] > 0 then
        done := False;
    att^.combatAddr^.sweepCount := 0;
  end;
  if att^.enabled = 0 then
    done := True;
  if done then
    done := CharHlp.ClearGuard(Types.PWork(att));
end;

procedure NoteAttackDirection(attacker, defender: Types.PWork);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(defender^.combatAddr^.attackerCount);
  attackDirection := CbtActs.DirTowardTarget(defender, attacker);
  angle := (attackDirection - defender^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  defender^.combatAddr^.flankTotal := (defender^.combatAddr^.flankTotal + angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Types.PWork; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);
var
  thrownCopy: Types.PItemRec;
  savedCharacter: Types.PWork;
  direction: Byte;
begin
  GDVars.combatMapVisible := 1;
  GDVars.combatRedraw := 1;
  GDVars.roundLimit := GDVars.combatRoundCounterCount + 15;
  direction := defender^.combatAddr^.direction;
  if (defender^.combatAddr^.attackerCount < 2) and (fromBehind = False) then
    direction := CbtActs.DirTowardTarget(defender, attacker);
  defender^.combatAddr^.direction := 255;
  CbtMap.SetCreatureFacing(defender, direction, 0, 0);
  direction := CbtActs.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(Types.PWork(attacker));
  CbtMap.SetCreatureFacing(attacker, direction, 1, 0);
  attacker^.combatAddr^.other := defender;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  if (attacker^.cbWeapon^.itemType = 47) or (attacker^.cbWeapon^.itemType = 101) then
    CbtActs.AnimateMissile(attacker, defender, attacker^.cbWeapon);
  done := True;
  if (attacker^.curAtt[1] > 0) or (attacker^.curAtt[2] > 0) then begin
    savedCharacter := GDVars.curChar;
    GDVars.curChar := attacker;
    CbtActs.RollAttacks(attacker, defender, fromBehind, done, weapon);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, GDVars.attacksMade[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(Types.PWork(attacker)) and (weapon^.special <> 137) and
            not (weapon^.itemType in
                 [C_Item.VH_BOULDER, C_Item.LT_BOULDER, C_Item.HY_BOULDER, C_Item.MANT_TAIL]) then begin
          New(thrownCopy);
          Move(weapon^, thrownCopy^, SizeOf(thrownCopy^));
          thrownCopy^.next := GDVars.treasureItems;
          GDVars.treasureItems := thrownCopy;
          thrownCopy^.equipped := 0;
          CharHlp.RemoveItem(Types.PWork(attacker), weapon);
          GDVars.lastMissileItem := thrownCopy;
        end else
          CharHlp.RemoveItem(Types.PWork(attacker), weapon);
    end;
    CharHlp.RecalcStats(Types.PWork(attacker));
    GDVars.curChar := savedCharacter;
  end;
  if done then
    done := CharHlp.ClearGuard(Types.PWork(attacker));
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 0, 0);
  end;
end;

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Types.PWork; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(Types.PWork(attacker), Types.PWork(defender));
  if CharHlp.HasRangedWeapon(Types.PWork(attacker)) then
    band := (GDVars.baseItems[attacker^.cbWeapon^.itemType].range - 1) div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 3;
  end;
end;

function FindCureTarget(spellId: Byte; cr: Types.PWork; var tgt: Types.PWork): Boolean;
var
  best: Types.PWork;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  if not (spellId in [C_Spell.CURE_LIGHT_WOUNDS, C_Spell.CURE_SERIOUS_WOUNDS, C_Spell.CURE_CRITICAL_WOUNDS]) then begin
    tgt := cr;
    FindCureTarget := True;
    Exit;
  end;
  best := nil;
  downIdx := 0;
  bestHp := 255;
  for d := C_Dir.NORTH to C_Dir.CENTER do begin
    nx := CbtMap.CombatCellX(cr) + GDConsts.dirDX[d];
    ny := CbtMap.CombatCellY(cr) + GDConsts.dirDY[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      tgt := GDVars.creaturePtr[crIdx];
      if tgt^.hostile = cr^.hostile then
        if tgt^.hpCur < tgt^.cbHpMax then
          if (tgt^.hpCur < bestHp)
             or ((tgt = cr) and (tgt^.hpCur < tgt^.cbHpMax div 2)) then begin
            best := tgt;
            bestHp := tgt^.hpCur;
          end;
    end else if terrIdx = C_Terr.TERRAIN_CORPSE then
      for j := 1 to GDVars.downedCount do
        if GDVars.combatDownedCharacter[j].cr <> nil then
          if not (GDVars.combatDownedCharacter[j].cr^.status in
                  [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE]) then
            if GDVars.combatDownedCharacter[j].x = nx then
              if GDVars.combatDownedCharacter[j].y = ny then
                downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GDVars.combatDownedCharacter[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Picks one spell target. For the player the aim goes through CombatAimMenu (one spell may aim at cells but not at
  creatures), which also locks the target. Otherwise a spell that does not target enemies goes to the caster, or for
  Cure Light Wounds to FindCureTarget's pick; an offensive spell takes one AcquireTarget pick, rejected when the target
  is helpless and the spell's effect is a helpless status. On success the target's cell becomes the spell's target cell;
  on failure the target is cleared.
  @param(spellId The spell being aimed.)
  @param(aiControlled 0 for the player's aim menu; nonzero for computer-controlled targeting.)
  @param(groundOk Passed to CombatAimMenu: nonzero lets the player pick a bare cell.)
  @param(target Receives the target: a creature pointer followed by its arena cell.)
  @returns(True if a target was found.) }
function SelectSpellTarget(spellId, aiControlled, groundOk: Byte; var target: Types.PWork): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Types.PWork;
  i: Byte;
  tries: Byte;
  creatureOk: Byte;
begin
  found := False;
  if aiControlled = 0 then begin
    creatureOk := Byte(spellId <> 83);
    CbtActs.CombatAimMenu(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, groundOk, creatureOk, found, target);
    GDVars.curChar^.combatAddr^.other := target;
  end else if GDConsts.spellTable[spellId].offensive = 0 then begin
    target := GDVars.curChar;
    if CbtActs.FindCureTarget(spellId, GDVars.curChar, Types.PWork(target)) then begin
      PTgtRec(@target)^.cellX := CbtMap.CombatCellX(target);
      PTgtRec(@target)^.cellY := CbtMap.CombatCellY(target);
      found := True;
    end;
  end else begin
    tries := 1;
    while (tries > 0) and not found do begin
      acceptable := True;
      if CbtActs.AcquireTarget(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, 1) then begin
        candidate := GDVars.curChar^.combatAddr^.other;
        if CharHlp.IsHelpless(Types.PWork(candidate)) then
          for i := 1 to SizeOf(GDConsts.helplessFx) do
            if GDConsts.spellTable[spellId].effectId = GDConsts.helplessFx[i] then
              acceptable := False;
        if acceptable then begin
          target := GDVars.curChar^.combatAddr^.other;
          PTgtRec(@target)^.cellX := CbtMap.CombatCellX(target);
          PTgtRec(@target)^.cellY := CbtMap.CombatCellY(target);
          found := True;
        end;
      end;
      Dec(tries);
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.gTargetX := PTgtRec(@target)^.cellX;
    GDVars.gTargetY := PTgtRec(@target)^.cellY;
  end else begin
    SelectSpellTarget := False;
    FillChar(PTgtRec(@target)^, SizeOf(TTgtRec), 0);
  end;
end;

procedure SelectCombatTargets(spellId, dir: Byte; var done: Boolean);
var
  { the separate picks left }
  menuCnt: Byte;
  { the targets taken }
  found: Byte;
  j: Byte;
  { type 5's weight budget }
  rng: Byte;
  { type 5's weight so far }
  vote: Byte;
  { Unused in this version; see the other implementations of this routine. }
  candidateSlots: array[0..2] of Byte;
  { the acquired target; the cell x/y follow it and are reached through PTgtRec(@res)^ }
  res: Types.PWork;
  { the pick is already a target }
  dupFlag: Boolean;
  { ends type 5's picks }
  resFlag: Boolean;
  { type 3's walk of the combatants }
  p: Types.PWork;
begin
  done := True;
  GDVars.numberTargetedCreatures := 0;
  GDVars.currentSpellAffectsFlag := 0;
  GDVars.gTargetX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.gTargetY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellTable[spellId].touch and $0F of
    0:
      begin
        GDVars.targetCreaturePtr[1] := GDVars.curChar;
        GDVars.numberTargetedCreatures := 1;
      end;
    3:
      begin
        p := GDVars.creatureList;
        while p <> nil do begin
          if p^.hostile = GDVars.curChar^.hostile then begin
            Inc(GDVars.numberTargetedCreatures);
            GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures] := p;
          end;
          p := p^.nextCharAddr;
        end;
      end;
    5:
      begin
        vote := 0;
        found := 0;
        if spellId = 79 then
          rng := CharHlp.GetCasterLevel(79)
        else
          rng := FxEngine.RollDice(2, 4);
        resFlag := False;
        repeat
          if CbtActs.SelectSpellTarget(spellId, dir, 0, res) then begin
            dupFlag := False;
            for j := 1 to found do
              if GDVars.targetCreaturePtr[j] = res then
                dupFlag := True;
            if not dupFlag then begin
              Inc(found);
              GDVars.targetCreaturePtr[found] := res;
              GDVars.gTargetX := CbtMap.CombatCellX(res);
              GDVars.gTargetY := CbtMap.CombatCellY(res);
              Inc(GDVars.numberTargetedCreatures);
              if spellId <> 79 then begin
                case GDVars.targetCreaturePtr[found]^.cbLevelHighest of
                  0, 1: Inc(vote);
                  2: Inc(vote, 2);
                  3: Inc(vote, 4);
                else
                  Inc(vote, 8);
                end;
              end else begin
                case GDVars.targetCreaturePtr[found]^.iconDim of
                  1: Inc(vote);
                  2, 3: Inc(vote, 2);
                  4: Inc(vote, 4);
                end;
              end;
              if (found > 1) and (vote > rng) then
                resFlag := True;
            end else begin
              if dir <> 0 then
                Dec(rng)
              else
                CharHlp.PrintBottomLine('Already been targeted');
            end;
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(res),
                                   CbtMap.CombatCellY(res));
          end else
            resFlag := True;
        until resFlag or (rng = 0);
      end;
    15:
      begin
        if CbtActs.SelectSpellTarget(spellId, dir, 0, res) then begin
          if GDVars.curChar^.combatAddr^.other <> nil then begin
            GDVars.targetCreaturePtr[1] := GDVars.curChar^.combatAddr^.other;
            GDVars.numberTargetedCreatures := 1;
          end else begin
            Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY,
                                    (GDConsts.spellTable[spellId].touch and $F) shr 4, 255, 1, GDVars.combatArenaPtr);
            for found := 1 to GDVars.targetCount do
              GDVars.targetCreaturePtr[found] := GDVars.creaturePtr[GDVars.combatTargetData[found].idx];
            GDVars.numberTargetedCreatures := GDVars.targetCount;
            GDVars.currentSpellAffectsFlag := 1;
          end;
        end else
          done := False;
      end;
    8..14:
      begin
        if CbtActs.SelectSpellTarget(spellId, dir, 1, res) then begin
          Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, GDConsts.spellTable[spellId].touch and $7, 255, 1,
                                  GDVars.combatArenaPtr);
          for found := 1 to GDVars.targetCount do
            GDVars.targetCreaturePtr[found] := GDVars.creaturePtr[GDVars.combatTargetData[found].idx];
          GDVars.numberTargetedCreatures := GDVars.targetCount;
          GDVars.currentSpellAffectsFlag := 1;
        end else
          done := False;
      end;
  else begin
      menuCnt := (GDConsts.spellTable[spellId].touch and $3) + 1;
      found := 0;
      while menuCnt > 0 do begin
        if CbtActs.SelectSpellTarget(spellId, dir, 0, res) then begin
          dupFlag := False;
          for j := 1 to found do
            if GDVars.targetCreaturePtr[j] = res then
              dupFlag := True;
          if not dupFlag then begin
            Inc(found);
            GDVars.targetCreaturePtr[found] := res;
            Dec(menuCnt);
            GDVars.gTargetX := CbtMap.CombatCellX(res);
            GDVars.gTargetY := CbtMap.CombatCellY(res);
          end else begin
            if dir = 0 then
              CharHlp.PrintBottomLine('Already been targeted')
            else
              Dec(menuCnt);
          end;
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(res),
                                 CbtMap.CombatCellY(res));
        end else
          menuCnt := 0;
      end;
      GDVars.numberTargetedCreatures := found;
      if found = 0 then
        done := False;
      GDVars.gTargetX := CbtMap.CombatCellX(GDVars.targetCreaturePtr[found]);
      GDVars.gTargetY := CbtMap.CombatCellY(GDVars.targetCreaturePtr[found]);
    end;
  end;
end;

procedure CastSpellCombat(spellId, silent: Byte; var done: Boolean);
var
  { the spell cast: spellId, or the spell menu's pick }
  sp: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  { the casting time, taken off the caster's initiative }
  levelDrain: Byte;
  { the spell menu's position }
  idx: Integer;
  { a slow spell's targets are picked }
  targetOk: Boolean;
  { the spell menu found spells }
  notEmpty: Boolean;
  { the caster }
  savedCr: Types.PWork;
begin
  savedCr := GDVars.curChar;
  notEmpty := True;
  idx := -1;
  done := False;
  sp := spellId;
  if sp = 0 then
    sp := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if sp > 0 then
    if GDConsts.spellTable[sp].combatOk = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      sp := 0;
    end;
  if silent = 0 then begin
    CharHlp.DisplayCombatInterface;
    GDVars.combatMapVisible := 1;
    GDVars.combatRedraw := 1;
    CbtMap.DisplayMapViewCentered(savedCr, 3, True);
    CharHlp.CombatPrintCreatureInfo(Types.PWork(savedCr));
  end;
  if sp > 0 then begin
    levelDrain := GDConsts.spellTable[sp].drainLevels div 3;
    if levelDrain = 0 then begin
      Magic.CastSpell(sp, Boolean(silent), True, done);
      if silent = 0 then
        done := CharHlp.ClearGuard(Types.PWork(savedCr));
    end else begin
      if silent <> 0 then
        CbtActs.SelectCombatTargets(sp, 1, targetOk)
      else
        targetOk := True;
      if targetOk then begin
        done := True;
        CharHlp.PrintCreatureMessage(Types.PWork(savedCr), 'Begins Casting', C_Msg.MESSAGE_ROW, True);
        savedCr^.combatAddr^.spellCast := sp;
        if savedCr^.combatAddr^.initiative > levelDrain then
          Dec(savedCr^.combatAddr^.initiative, levelDrain)
        else
          savedCr^.combatAddr^.initiative := 1;
      end;
    end;
  end;
end;

{ Checks for a backstab: the attacker must be a thief (or have thief levels from an earlier class that is active), with
  no weapon or one of item types 7, 8, 35..37 or 97; the defender must be small, have been attacked more than once this
  round, and face away from the attacker.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Types.PWork): Boolean;
var
  weapon: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  armor: Types.PItemRec;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := attacker^.cbWeapon;
  if weapon <> nil then
    weaponType := weapon^.itemType;
  armor := attacker^.cbArmor;
  if (attacker^.classLevels[C_Class.THIEF_LEVEL] > 0)
     or ((attacker^.cbOldThiefLevel > 0) and (ClassCal.EarlierClassActive(Types.PWork(attacker)) <> 0)) then
    if (weapon = nil) or (weaponType = 97) or (weaponType = 7) or (weaponType = 8)
       or ((weaponType > 34) and (weaponType < 38)) then
      canBackstab := True;
  if canBackstab and (defender^.combatAddr^.attackerCount > 1)
     and ((defender^.iconDim and $7F) <= 1)
     and (CbtActs.DirTowardTarget(attacker, defender) = defender^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

function DirTowardTarget(creature, other: Types.PWork): Byte;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  deltaX := Abs(x2 - x1);
  deltaY := Abs(y2 - y1);
  dir := C_Dir.NORTH;
  found := False;
  while not found do begin
    case dir of
      C_Dir.NORTH: found := (y2 <= y1) and ((618 * deltaX) div 256 <= deltaY);
      C_Dir.EAST: found := (x2 >= x1) and ((106 * deltaX) div 256 >= deltaY);
      C_Dir.SOUTH: found := (y2 >= y1) and ((618 * deltaX) div 256 <= deltaY);
      C_Dir.WEST: found := (x2 <= x1) and ((106 * deltaX) div 256 >= deltaY);
      C_Dir.NORTHEAST: found := (y2 <= y1) and (x2 >= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      C_Dir.SOUTHEAST: found := (y2 >= y1) and (x2 >= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      C_Dir.SOUTHWEST: found := (y2 >= y1) and (x2 <= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
      C_Dir.NORTHWEST: found := (y2 <= y1) and (x2 <= x1)
             and ((618 * deltaX) div 256 >= deltaY) and ((106 * deltaX) div 256 <= deltaY);
    end;
    if not found then
      Inc(dir);
  end;
  DirTowardTarget := dir;
end;

{ Animate a missile from attacker to defender, its picture, frame count, pace and sound chosen by weapon's type: a
  directional arrow, a tumbling four-frame picture or a two-frame one.
  @param(attacker The attacker.)
  @param(defender The creature attacked.)
  @param(weapon The missile or thrown weapon.) }
procedure AnimateMissile(attacker, defender: Types.PWork; weapon: Types.PItemRec);
var
  missileCellBase: Byte;
  frames: Byte;
  direction: Byte;
  pace: Byte;
  { Unused in this version; see the other implementations of this routine. }
  imageSize: Word;
begin
  direction := CbtActs.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  missileCellBase := 13;
  imageSize := GDVars.moveIconSheet^.frameSize;
  case weapon^.itemType of
    9, 21, 100, C_Item.QUARRELS, 31, C_Item.ARROWS:
      begin
        if Odd(direction) then begin
          if (direction = C_Dir.SOUTHEAST) or (direction = C_Dir.SOUTHWEST) then
            CharHlp.CopyIconFacing(missileCellBase + 1, 1, 0, Ord(direction = C_Dir.SOUTHWEST))
          else
            CharHlp.CopyIconFacing(missileCellBase + 1, 0, 0, Ord(direction = C_Dir.NORTHWEST));
        end else
          CharHlp.CopyIconFacing(missileCellBase + direction mod 4, direction div 4, 0, 0);
        SoundDrv.SoundCommand(12);
      end;
    2, 7, C_Item.HAMMER:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 3);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(9);
      end;
    C_Item.HOLY_WATER_VIAL, 86:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 4);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(6);
      end;
    101, 47, C_Item.MANT_TAIL:
      begin
        Inc(missileCellBase);
        CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, 0);
        CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, 0);
        frames := 2;
        pace := 10;
        SoundDrv.SoundCommand(6);
      end;
  else
    CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, 0);
    CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, 0);
    frames := 2;
    pace := 20;
    SoundDrv.SoundCommand(9);
  end;
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(attacker),
                                  CbtMap.CombatCellY(attacker),
                                  CbtMap.CombatCellX(defender),
                                  CbtMap.CombatCellY(defender), frames, pace);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Types.PWork;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if combatant^.hostile = 1 then begin
      if combatant^.enabled <> 0 then
        hitPointTotal := hitPointTotal + combatant^.hpCur;
      maximumTotal := maximumTotal + combatant^.cbHpMax;
    end;
    combatant := combatant^.nextCharAddr;
  end;
  if maximumTotal > 0 then
    GDVars.hostileCreatureHit := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Types.PWork): Byte;
var
  highest: Byte;
  movement: Byte;
  combatant: Types.PWork;
begin
  highest := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if (ShortInt(CharHlp.NotHostile(Types.PWork(creature))) = combatant^.hostile) and
        (combatant^.enabled <> 0) then begin
      movement := CbtActs.CalcCreatureMovement(combatant) div 2;
      if movement > highest then
        highest := movement;
    end;
    combatant := combatant^.nextCharAddr;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Types.PWork): Boolean;
var
  combatant: Types.PWork;
begin
  if (ShortInt(CharHlp.NotHostile(defender)) = attacker^.hostile) or (attacker^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenuClear('Attack Ally: ', LightMagenta, LightGreen, White) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.attackedAllies := 1;
    GDVars.gbvmZone1Ptr^[C_Gbvm.ATTACKED_ALLIES] := 1;
    combatant := GDVars.creatureList;
    while combatant <> nil do begin
      if (combatant^.status = C_Status.OKAY) and (combatant^.npc > C_Npc.MORALE_MASK) then begin
        combatant^.hostile := 1;
        combatant^.combatAddr^.other := nil;
      end;
      combatant := combatant^.nextCharAddr;
    end;
    CbtMap.CountTeams;
  end;
end;

{ Shows one aim-menu round on the target: centers the view on it, shows the range in weapon mode, and offers Target when
  the target is in range (spell mode: when creatures may be targeted; weapon mode: when the target is another creature
  and the attacker either has no ranged weapon, or has ammunition for it and no adjacent enemy or a throwable weapon),
  then Next, Prev, Manual, Center and Exit.
  @param(cr The creature aiming.)
  @param(p The creature under the aim.)
  @param(effRange The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell.)
  @param(gr3 Unused.)
  @param(gr4 Nonzero when a spell may target a creature.)
  @returns(The key chosen.) }
function AimTargetMenu(cr, p: Types.PWork; effRange, weaponMode, gr3, gr4: Byte): Char;
var
  { the menu's options }
  line: String[40];
  ext: Boolean;
  { receives FindDamagingRangedWeapon's weapon }
  it: Pointer;
  { the distance to the target }
  dist: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dir: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedDistMode: array[0..3] of Byte;
begin
  line := '';
  dist := CharHlp.CalcDistance(Types.PWork(cr), Types.PWork(p));
  dir := CbtActs.DirTowardTarget(cr, p);
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, Black, 'Range = ' + CharHlp.Uint8Str(dist) + '  ');
  if dist <= effRange then begin
    if weaponMode = 0 then begin
      if gr4 <> 0 then
        line := 'Target '
      else
        line := '';
    end else if cr <> p then begin
      if not CharHlp.HasRangedWeapon(Types.PWork(cr)) then
        line := 'Target '
      else if CharHlp.FindDamagingRangedWeapon(Types.PWork(cr), it) then
        if (CharHlp.CountTargets(Types.PWork(cr), 1) = 0)
           or CharHlp.HasThrowableWeapon(Types.PWork(cr)) then
          line := 'Target ';
    end;
  end;
  line := 'Next Prev Manual ' + line + 'Center Exit';
  CbtMap.DisplayMapViewCentered(p, 3, True);
  GDVars.combatRedraw := 1;
  CharHlp.CombatPrintCreatureInfo(Types.PWork(p));
  GDVars.joyClickB := 1;
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', line, LightMagenta, LightGreen, White, True, False, ext);
  GDVars.joyClickB := 0;
end;

{ Confirms an aim selection: weapon mode 1 makes a weapon attack, anything else selects a spell target. A weapon attack
  on an ally needs CheckAttackAlly's consent, otherwise the selection is cleared and the done flag is False. The attack
  tries a sweep first; a throwable ranged weapon used at distance 1 strikes as melee.
  @param(cr The creature aiming.)
  @param(p The creature chosen.)
  @param(weaponMode 1 for a weapon attack.)
  @param(done False when the attack was declined; otherwise True or the attack's result.)
  @param(tgt Receives the target and its cell; cleared when declined.) }
procedure ConfirmAttackTarget(cr, p: Types.PWork; weaponMode: Byte; var done: Boolean; var tgt);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  rangedWpn: Types.PItemRec;
begin
  rangedWpn := nil;
  done := True;
  if (weaponMode = 1) and (not CbtActs.CheckAttackAlly(cr, p)) then
    done := False;
  if done then begin
    PTgtRec(@tgt)^.cr := p;
    PTgtRec(@tgt)^.cellX := CbtMap.CombatCellX(p);
    PTgtRec(@tgt)^.cellY := CbtMap.CombatCellY(p);
    GDVars.combatArenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GDVars.combatArenaPtr^.ox + 3, GDVars.combatArenaPtr^.oy + 3, 3, C_Dir.CENTER);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttack(cr, p) then
        done := CharHlp.ClearGuard(Types.PWork(cr))
      else begin
        CbtActs.NoteAttackDirection(cr, p);
        if CharHlp.HasRangedWeapon(Types.PWork(cr))
           and CharHlp.FindDamagingRangedWeapon(Types.PWork(cr), Pointer(rangedWpn))
           and CharHlp.HasThrowableWeapon(Types.PWork(cr))
           and (CharHlp.CalcDistance(Types.PWork(cr), Types.PWork(p)) = 1) then
          rangedWpn := nil;
        CbtActs.MakeAttack(cr, p, False, rangedWpn, done);
      end;
    end;
  end else
    FillChar(PTgtRec(@tgt)^, SizeOf(TTgtRec), 0);
end;

{ CombatAimMenu's free cursor: move a cell cursor about the arena with the arrow keys, showing the range to it for a
  weapon and the information of a creature or downed body under it, under '(Use Cursor keys) ' with 'Target' when the
  cell can be aimed at, else 'Exit'. Enter or T takes the aim (through ConfirmAttackTarget for an attack), C or 5
  recenters, and no choice or E cancels.
  @param(cr The aiming combatant.)
  @param(p The target the cursor starts on.)
  @param(effRange The reach of the attack or spell.)
  @param(weaponMode 1 for a weapon attack, 0 for a spell.)
  @param(gr3 Nonzero when an empty cell can be aimed at.)
  @param(gr4 Nonzero when a creature can be aimed at.)
  @param(done Set when an aim is taken.)
  @param(tgt The caller's target record: the creature, or nil, and the cell; cleared when nothing is taken.) }
procedure ManualAimCursor(cr, p: Types.PWork; effRange, weaponMode, gr3, gr4: Byte; var done: Boolean; var tgt);
var
  { the menu's options }
  line: String[40];
  ch: Char;
  { receives FindDamagingRangedWeapon's weapon }
  it: Pointer;
  { the cursor's next step: a direction, or CENTER for none }
  dir: Byte;
  idx: Byte;
  { the cursor's cell, which WalkLine overwrites with where the line stops }
  savedX: ShortInt;
  savedY: ShortInt;
  cursorX: ShortInt;
  cursorY: ShortInt;
  { GetArenaContents' creature index }
  crIdx: Byte;
  { GetArenaContents' terrain index }
  terrIdx: Byte;
  { WalkLine's distance }
  rangeWork: Word;
  { 1 while the cell under the cursor can be aimed at }
  inRange: Byte;
begin
  GDVars.manualAimActive := 1;
  FillChar(PTgtRec(@tgt)^, SizeOf(TTgtRec), 0);
  cursorX := CbtMap.CombatCellX(p);
  cursorY := CbtMap.CombatCellY(p);
  ch := ' ';
  dir := C_Dir.CENTER;
  done := False;
  GDVars.combatArenaPtr^.cursorOn := True;
  GDVars.combatArenaPtr^.cursorSize := 1;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cursorX, cursorY, 3, dir);
    Inc(cursorX, GDConsts.dirDX[dir]);
    Inc(cursorY, GDConsts.dirDY[dir]);
    if cursorX < 0 then cursorX := 0;
    if cursorY < 0 then cursorY := 0;
    if cursorX >
        SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then cursorX := SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1;
    if cursorY > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
      cursorY := SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1;
    CbtMap.GetArenaContents(cursorX, cursorY, crIdx, terrIdx);
    GameIo.DrainKeys;
    inRange := 0;
    rangeWork := 255;
    savedX := cursorX;
    savedY := cursorY;
    if Byte(Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                             savedX, savedY, rangeWork, GDVars.combatArenaPtr)) <> 0 then begin
      inRange := 1;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, Black, 'Range = ' + CharHlp.Uint16Str(rangeWork shr 1) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    rangeWork := rangeWork shr 1;
    p := nil;
    if inRange <> 0 then
      if crIdx > 0 then
        p := GDVars.creaturePtr[crIdx]
      else if terrIdx = C_Terr.TERRAIN_CORPSE then
        for idx := 1 to GDVars.downedCount do
          if (GDVars.combatDownedCharacter[idx].x = cursorX) and (GDVars.combatDownedCharacter[idx].y = cursorY) then
            p := GDVars.combatDownedCharacter[idx].cr;
    if p <> nil then begin
      GDVars.combatRedraw := 1;
      CharHlp.CombatPrintCreatureInfo(Types.PWork(p));
    end else
      Border.ClearBox(23, 1, 38, 21);
    if (effRange < rangeWork) or (GDConsts.terrainInfo[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE) then
      inRange := 0;
    if p <> nil then begin
      if (not CbtActs.CanTarget(cr, p)) or (gr4 = 0) then
        inRange := 0;
      if weaponMode = 1 then begin
        if (cr = p) or ((crIdx = 0) and (terrIdx = C_Terr.TERRAIN_CORPSE)) then
          inRange := 0
        else if CharHlp.HasRangedWeapon(Types.PWork(cr)) then
          if (not CharHlp.FindDamagingRangedWeapon(Types.PWork(cr), it))
             or
               ((CharHlp.CountTargets(Types.PWork(cr), 1) > 0) and
                (not CharHlp.HasThrowableWeapon(Types.PWork(cr)))) then
            inRange := 0;
      end;
    end else if gr3 = 0 then
      inRange := 0;
    line := 'Exit';
    if GDVars.currentAttackCurrent <> 0 then
      if inRange <> 0 then
        line := 'Target';
    if GDConsts.isArenaClickPending then begin
      CbtMap.RedrawArenaCell(cursorX, cursorY);
      GDConsts.isArenaClickPending := False;
      if GDConsts.isArenaClickOutside then
        GDVars.menuKey := '5'
      else
        GDVars.menuKey := '!';
    end else begin
      GDVars.arenaMouseX := cursorX;
      GDVars.arenaMouseY := cursorY;
      ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', line, LightMagenta, LightGreen, White, True, False,
                                    GDVars.doneRoundFlag);
    end;
    cursorX := GDVars.arenaMouseX;
    cursorY := GDVars.arenaMouseY;
    case ch of
      C_Keys.ENTER, 'T':
        begin
          GDVars.combatArenaPtr^.cursorOn := False;
          if inRange <> 0 then begin
            PTgtRec(@tgt)^.cellX := cursorX;
            PTgtRec(@tgt)^.cellY := cursorY;
            if p <> nil then
              PTgtRec(@tgt)^.cr := p
            else
              PTgtRec(@tgt)^.cr := nil;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cr, PTgtRec(@tgt)^.cr, weaponMode, done, tgt)
            else
              done := True;
          end;
          if (inRange = 0) or (not done) then begin
            CbtMap.RedrawArenaCell(cursorX, cursorY);
            done := False;
            FillChar(PTgtRec(@tgt)^, SizeOf(TTgtRec), 0);
          end;
        end;
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
      C_Keys.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cursorX, cursorY);
          FillChar(PTgtRec(@tgt)^, SizeOf(TTgtRec), 0);
          done := False;
        end;
      '5', 'C':
        begin
          CbtMap.ScrollView(cursorX, cursorY, 0, C_Dir.CENTER);
          dir := C_Dir.CENTER;
        end;
    else
      dir := C_Dir.CENTER;
    end;
  end;
  GDVars.manualAimActive := 0;
end;

procedure CombatAimMenu(cr: Types.PWork; range, weaponMode, groundOk, flag4: Byte; var done: Boolean; var tgt);
var
  targets: array[1..72] of Types.TCombatTarget;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  skipStep: ShortInt;
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  p: Types.PWork;
  ch: Char;

  { Fill targets from Pathing's target list around c. }
  procedure BuildAimTargets(c: Types.PWork);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127,
                            255, CbtMap.GetIconSize(c), GDVars.combatArenaPtr);
    tgtCount := GDVars.targetCount;
    for i := 1 to tgtCount do
      targets[i] := GDVars.combatTargetData[i];
  end;

  { Step the highlight by step targets, wrapping, animating the cursor when animate; return the new target. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PWork;
  var
    { Unused in this version; see the other implementations of this routine. }
    previousTarget: array[0..3] of Byte;
  begin
    if animate then begin
      curX := GDVars.combatArenaLocation[targets[curIdx].idx].x;
      curY := GDVars.combatArenaLocation[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GDVars.creaturePtr[targets[curIdx].idx];
    nextX := GDVars.combatArenaLocation[targets[curIdx].idx].x;
    nextY := GDVars.combatArenaLocation[targets[curIdx].idx].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
  FillChar(tgt, SizeOf(TTgtRec), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if Types.PWork(cr)^.cbWeapon <> nil then
      effRange := GDVars.baseItems[Types.PWork(cr)^.cbWeapon^.itemType].range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(cr);
  curIdx := 1;
  skipStep := 0;
  while (GDVars.creaturePtr[targets[curIdx + skipStep].idx] <> nil)
        and (GDVars.creaturePtr[targets[curIdx + skipStep].idx]^.hostile = cr^.hostile) do
    Inc(skipStep);
  if GDVars.creaturePtr[targets[curIdx + skipStep].idx] = nil then
    skipStep := 0;
  p := AdvanceAimTarget(skipStep, True);
  skipStep := 1;
  ch := ' ';
  while (done = False) and (not (ch in [C_Keys.NONE, 'E'])) do
  begin
    if not CbtActs.CanTarget(cr, p) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      if GDConsts.isArenaClickPending then begin
        ch := 'M';
        GDVars.extFlag := False;
      end else
        ch := CbtActs.AimTargetMenu(cr, p, effRange, weaponMode, groundOk, flag4);
      if not GDVars.extFlag then begin
        case ch of
          'N':
            begin
              skipStep := 1;
              menuStep := 1;
            end;
          'P':
            begin
              skipStep := -1;
              menuStep := -1;
            end;
          'M':
            begin
              CbtActs.ManualAimCursor(cr, p, effRange, weaponMode, groundOk, flag4, done, tgt);
              CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
              BuildAimTargets(cr);
              menuStep := 0;
            end;
          'T':
            begin
              CbtActs.ConfirmAttackTarget(cr, p, weaponMode, done, tgt);
              CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
              BuildAimTargets(cr);
              menuStep := 0;
            end;
          'C':
            begin
              CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0,
                                C_Dir.CENTER);
              menuStep := 0;
            end;
        end;
      end else begin
        if ch in [C_Keys.HOME, C_Keys.UP, C_Keys.PAGE_UP, C_Keys.LEFT, C_Keys.RIGHT, C_Keys.END_KEY,
                  C_Keys.DOWN, C_Keys.PAGE_DOWN] then begin
          CbtActs.ManualAimCursor(cr, p, effRange, weaponMode, groundOk, flag4, done, tgt);
          CharHlp.CopyIconFacing(25, 0, 0, Byte(False));
          BuildAimTargets(cr);
          menuStep := 0;
        end;
      end;
      GDConsts.isArenaClickPending := False;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_Keys.NONE, 'E'])));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(cr: Types.PWork; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PWork;
begin
  pass := False;
  found := False;
  second := False;
  p := cr^.combatAddr^.other;
  if (forceNew <> 0) or
      ((p <> nil) and ((p^.hostile = cr^.hostile) or (p^.enabled = 0) or (not CbtActs.CanTarget(cr, p)))) then
    cr^.combatAddr^.other := nil;
  if cr^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.combatArenaPtr^.distMode := 1;
    tries := 20;
    cnt := CharHlp.CountTargets(Types.PWork(cr), range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := FxEngine.RollDice(1, cnt);
      if GDVars.potentialTargetCreature[pick] > 0 then begin
        p := GDVars.creaturePtr[GDVars.potentialTargetCreature[pick]];
        if ((relaxed <> 0) and (GDVars.combatArenaPtr^.distMode <> 0))
           or CbtActs.CanTarget(cr, p) then begin
          found := True;
          cr^.combatAddr^.other := p;
        end else begin
          GDVars.potentialTargetCreature[pick] := 0;
          for pick := 1 to cnt do
            if GDVars.potentialTargetCreature[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.combatArenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

procedure AttackEngulf(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  defenderSlot: Byte;
  eff: Types.PEffectRec;
  def: Types.PWork;
begin
  def := cr^.combatAddr^.other;
  if FxEngine.RollDice(1, 10) > 4 then
    Exit;
  if def^.enabled = 0 then
    Exit;
  if CharHlp.HasEffect(Types.PWork(def), C_Effect.IMMOBILE, eff) then
    Exit;
  if CharHlp.HasEffect(Types.PWork(def), C_Effect.SUFFOCATING, eff) then
    Exit;
  if CharHlp.HasEffect(Types.PWork(cr), C_Effect.SWALLOWING, eff) then
    Exit;
  def := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(Types.PWork(cr), 'engulfs ' + def^.name, 12, True);
  FxEngine.AddEffect(Types.PWork(def), C_Effect.IMMOBILE, 0, CbtMap.CombatSlot(def), False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, Types.PWork(def), nil, False);
  FxEngine.AddEffect(Types.PWork(def), C_Effect.SUFFOCATING, 0, FxEngine.RollDice(2, 4), False);
  FxEngine.AddEffect(Types.PWork(cr), C_Effect.SWALLOWING, 0, CbtMap.CombatSlot(def), True);
end;

procedure AttackConstrict(cr: Types.PWork; combat: Types.PCombatRec; secondary: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  targetSlot: array[0..1] of Byte;
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  if FxEngine.RollDice(1, 10) <= 4 then begin
    tgt := cr^.combatAddr^.other;
    if tgt^.enabled <> 0 then
      if cr^.enabled <> 0 then
        if not CharHlp.HasEffect(Types.PWork(cr), C_Effect.CONSTRICTING, eff) then
          if not CharHlp.HasEffect(Types.PWork(tgt), C_Effect.IMMOBILE, eff) then begin
            CharHlp.PrintCreatureMessage(Types.PWork(cr), 'constricts ' + tgt^.name, 12, True);
            FxEngine.AddEffect(Types.PWork(tgt), C_Effect.IMMOBILE, 0, CbtMap.CombatSlot(tgt),
                               False);
            FxEngine.CallEffectHandler(C_Effect.IMMOBILE, Types.PWork(tgt), nil, False);
            FxEngine.AddEffect(Types.PWork(cr), C_Effect.CONSTRICTING, 0,
                               CbtMap.CombatSlot(tgt), True);
          end;
  end;
end;

procedure AttackEyeRays(cr: Types.PWork; deadCombat: Types.PCombatRec; deadFlag: Byte);
var
  eyesLeft: Byte;
  rayType: Word;
  usedMask: Byte;
  castDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  saved: Byte;
  target: Pointer;

  { Fire ray picture b from cr toward target. }
  procedure RayBeam(b: Byte);
  begin
    CharHlp.BuildIconFacings(b + 13);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr),
                                    CbtMap.CombatCellY(cr),
                                    CbtMap.CombatCellX(target),
                                    CbtMap.CombatCellY(target), 1, 30);
  end;

  { Pick a target (a new one when b is 1) and clear castDone when it is in line of sight. }
  procedure LosTrace(b: Byte);
  var
    { the target's cell, which WalkLine overwrites }
    targetX: ShortInt;
    targetY: ShortInt;
  begin
    castDone := True;
    if CbtActs.AcquireTarget(cr, 255, 0, b) then begin
      targetX := CbtMap.CombatCellX(cr^.combatAddr^.other);
      targetY := CbtMap.CombatCellY(cr^.combatAddr^.other);
      if Byte(Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                               targetX, targetY, rayType, GDVars.combatArenaPtr)) <> 0 then
        castDone := False;
    end;
  end;

begin
  usedMask := 0;
  eyesLeft := 4;
  castDone := False;
  cr^.combatAddr^.other := nil;
  LosTrace(1);
  repeat
    target := cr^.combatAddr^.other;
    rayType := CharHlp.CalcDistance(Types.PWork(cr), Types.PWork(target));
    Dec(eyesLeft);
    if target <> nil then begin
      if (rayType <= 2) and ((usedMask and 1) = 0) then begin
        usedMask := usedMask or 1;
        CharHlp.PrintCreatureMessage(Types.PWork(cr), 'fires a disintegrate ray', C_Msg.MESSAGE_ROW, True);
        RayBeam(5);
        if not FxEngine.RollSavingThrow(Types.PWork(target), 3, 0) then
          FxEngine.KillCreature(Types.PWork(target), C_Status.GONE, 'is disintergrated');
        LosTrace(0);
      end else if (rayType <= 3) and ((usedMask and 2) = 0) then begin
        usedMask := usedMask or 2;
        CharHlp.PrintCreatureMessage(Types.PWork(cr), 'fires a flesh to stone ray', C_Msg.MESSAGE_ROW, True);
        RayBeam(10);
        if not FxEngine.RollSavingThrow(Types.PWork(target), 1, 0) then
          FxEngine.KillCreature(Types.PWork(target), C_Status.STONED, 'is Stoned');
        LosTrace(0);
      end else if (rayType <= 4) and ((usedMask and 4) = 0) then begin
        usedMask := usedMask or 4;
        CharHlp.PrintCreatureMessage(Types.PWork(cr), 'fires a death ray', C_Msg.MESSAGE_ROW, True);
        RayBeam(5);
        if not FxEngine.RollSavingThrow(Types.PWork(target), 0, 0) then
          FxEngine.KillCreature(Types.PWork(target), C_Status.DEAD_STATUS, 'is killed');
        LosTrace(0);
      end else if (rayType <= 5) and ((usedMask and 8) = 0) then begin
        usedMask := usedMask or 8;
        CharHlp.PrintCreatureMessage(Types.PWork(cr), 'wounds you', C_Msg.MESSAGE_ROW, True);
        RayBeam(5);
        FxEngine.InflictNonWeaponDamage(Types.PWork(target), FxEngine.RollDamageDice(2, 8) + 1, 0, False);
        LosTrace(0);
      end else begin
        if (usedMask and $10) = 0 then begin
          Magic.CastSpell(84, True, True, castDone);
          usedMask := usedMask or $10;
        end else if (usedMask and $20) = 0 then begin
          Magic.CastSpell(55, True, True, castDone);
          usedMask := usedMask or $20;
        end else if (usedMask and $40) = 0 then begin
          Magic.CastSpell(21, True, True, castDone);
          usedMask := usedMask or $40;
        end;
      end;
    end;
  until (eyesLeft <= 0) or (cr^.combatAddr^.other = nil);
end;

procedure BiteAndHold(cr: Types.PWork; combat: Types.PCombatRec; secondary: Byte);
var
  done: Boolean;
begin
  GDVars.otherCreatureCurrentPtr := GDVars.creaturePtr[Byte(combat^.initiative)];
  if (secondary <> 0) or (cr^.enabled = 0) or (GDVars.otherCreatureCurrentPtr^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.otherCreatureCurrentPtr, C_Effect.IMMOBILE, nil);
    if combat^.spellCast = C_Effect.SWALLOWING then
      FxEngine.RemoveEffect(GDVars.otherCreatureCurrentPtr, C_Effect.SUFFOCATING, nil);
    if secondary = 0 then begin
      combat^.attackPhase := 0;
      FxEngine.RemoveEffect(Types.PWork(cr), combat^.spellCast, combat);
    end;
  end else begin
    cr^.curAtt[1] := 2;
    cr^.curAtt[2] := 0;
    if combat^.spellCast = C_Effect.CONSTRICTING then begin
      cr^.curRollsA[1] := 1;
      cr^.curDiceA[1] := 2;
      CharHlp.PrintCreatureMessage(Types.PWork(cr), 'constricts ' + GDVars.otherCreatureCurrentPtr^.name, 12, True);
    end else if combat^.spellCast = C_Effect.DRAINING_BLOOD then begin
      cr^.curRollsA[1] := 1;
      cr^.curDiceA[1] := 4;
      CharHlp.PrintCreatureMessage(Types.PWork(cr), 'sucks blood from ' + GDVars.otherCreatureCurrentPtr^.name, 12,
                                   True);
    end else if combat^.spellCast = C_Effect.SWALLOWING then begin
      CharHlp.PrintCreatureMessage(Types.PWork(cr), 'is swallowing ' + GDVars.otherCreatureCurrentPtr^.name, 12, True);
      cr^.curRollsA[1] := 2;
      cr^.curDiceA[1] := 8;
    end else begin
      CharHlp.PrintCreatureMessage(Types.PWork(cr), 'is holding ' + GDVars.otherCreatureCurrentPtr^.name, 12, True);
      cr^.curRollsA[1] := 2;
      cr^.curDiceA[1] := 8;
    end;
    CbtActs.MakeAttack(cr, GDVars.otherCreatureCurrentPtr, False, nil, done);
    done := CharHlp.ClearGuard(Types.PWork(cr));
    if GDVars.otherCreatureCurrentPtr^.enabled = 0 then begin
      FxEngine.RemoveEffect(Types.PWork(cr), combat^.spellCast, nil);
      FxEngine.RemoveEffect(GDVars.otherCreatureCurrentPtr, C_Effect.IMMOBILE, nil);
      if combat^.spellCast = C_Effect.SWALLOWING then
        FxEngine.RemoveEffect(GDVars.otherCreatureCurrentPtr, C_Effect.SUFFOCATING, nil);
    end;
  end;
end;

procedure AttackDrainBlood(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  tgt := cr^.combatAddr^.other;
  if FxEngine.RollDice(1, 10) <= 4 then
    if tgt^.enabled <> 0 then
      if not CharHlp.HasEffect(Types.PWork(cr), C_Effect.DRAINING_BLOOD, eff) then
        if not CharHlp.HasEffect(Types.PWork(tgt), C_Effect.IMMOBILE, eff) then begin
          tgt := cr^.combatAddr^.other;
          CharHlp.PrintCreatureMessage(Types.PWork(cr), 'drains blood from ' + tgt^.name, 12, True);
          FxEngine.AddEffect(Types.PWork(tgt), C_Effect.IMMOBILE, 0, CbtMap.CombatSlot(tgt),
                             False);
          FxEngine.CallEffectHandler(C_Effect.IMMOBILE, Types.PWork(tgt), nil, False);
          FxEngine.AddEffect(Types.PWork(cr), C_Effect.DRAINING_BLOOD, 0,
                             CbtMap.CombatSlot(tgt), True);
        end;
end;

procedure AttackHug(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  targetSlot: array[0..1] of Byte;
  eff: Types.PEffectRec;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  if CharHlp.HasEffect(Types.PWork(cr), C_Effect.HUGGING, eff) then
    Exit;
  if CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_Effect.IMMOBILE, eff) then
    Exit;
  if GDVars.currentAttackRoll < 18 then
    Exit;
  CharHlp.PrintCreatureMessage(Types.PWork(cr), 'hugs ' + GDVars.otherCreatureCurrentPtr^.name, 12, True);
  FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.IMMOBILE, 0,
                     CbtMap.CombatSlot(GDVars.otherCreatureCurrentPtr), False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.otherCreatureCurrentPtr, nil, False);
  FxEngine.AddEffect(Types.PWork(cr), C_Effect.HUGGING, 0,
                     CbtMap.CombatSlot(GDVars.otherCreatureCurrentPtr), True);
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  p: Types.PWork;
begin
  VictoryCheat := True;
  if GDVars.superMode <> 0 then begin
    CharHlp.PrintBottomLine('The Gods intervene!');
    p := GDVars.creatureList;
    while p <> nil do begin
      if p^.hostile = 1 then begin
        p^.enabled := 0;
        p^.status := C_Status.DEAD_STATUS;
        GDVars.combatArenaLocation[CbtMap.CombatSlot(p)].size := 0;
      end;
      done := CharHlp.ClearGuard(Types.PWork(p));
      p := p^.nextCharAddr;
    end;
    CbtMap.ScrollView(GDVars.combatArenaPtr^.ox + 3, GDVars.combatArenaPtr^.oy + 3, 255, C_Dir.CENTER);
  end;
end;

begin
end.
