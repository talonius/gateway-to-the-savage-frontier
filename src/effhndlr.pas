{ The per-effect handlers, and InitEffectHandlers, which fills the effect-handler table GDVars.effectHandlers, indexed
  by effect id. GameInit.InitializeGame calls InitEffectHandlers, and FxEngine.CallEffectHandler dispatches every effect
  through the table.

  Nine effect ids go to handlers in CbtActs, which InitEffectHandlers installs from there: 57 AttackEngulf, 87
  AttackEyeRays, 96 AttackHug, 149 AttackDrainBlood, 155 AttackConstrict, and BiteAndHold for the four holds:
  swallowing, hugging, draining blood and constricting.

  Every handler takes the creature, the effect node or item, and whether the effect is being removed. }
{$O+,F+,R-,S+,I-,V-,B-,A+}
unit EffHndlr;

interface

uses Types, C_Status, C_Effect, C_Class, C_Equip, C_Ifc, C_Item, C_Msg, C_Npc, C_Race, C_Terr, FxEngine, ViewChar,
  CbtMap, Pathing, CharHlp, ClassCal, TextRend, GDConsts, GDVars, CbtActs, C_Gbvm;

{ Fill GDVars.effectHandlers with this unit's handlers, and with CbtActs' for the monsters' special attacks and holds. }
procedure InitEffectHandlers;

{ End the creature's turn: clear its initiative, cast spell, guard and movement.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffClearGuard(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies the bless effect: adds 5 to morale and 1 to the attack roll.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBless(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies the curse effect: takes 5 from morale (not below 0) and 1 from the attack roll.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCurse(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies sticks to snakes: the snakes use up the creature's attacks this round, taking them off the effect's strength
  (the effect ends when it runs out); the creature is shown fighting with snakes and its actions end.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies Dispel Evil: takes 7 from the attack roll when the current creature has creature-type flag bit 0.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDispelEvil(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Flame Tongue weapon: against its target adds 1 to the attack roll and damage of a regenerating creature, 2 of a
  cold-based or avian one and 3 of an undead one, and makes the damage magical fire.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFlameTongue(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies Faerie Fire: raises the creature's two armor class values by 2; values from 58 up become 60, including any
  above 60. Note: a higher stored armor class value is a better armor class, so the outlined creature becomes harder to
  hit, not easier.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFaerieFire(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies protection from evil: against an evil attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtEvil(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies protection from good: against a good attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtGood(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies resist cold: halves cold damage and adds 3 to the saving throw against it.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffResistCold(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Charm: the first time, move the creature to the charmer's side, keeping its own side in the effect's strength, clear
  its target and recount the teams; its morale is held at 100. On removal its own side returns. A creature on the
  hostile side fights under computer control, and a party member back on the party's side is the player's again.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffEnlargeStrength(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Engulfed: each call counts the strength down by 1, and a call that finds it already 0 kills the creature, which
  suffocates.
  @param(cr The creature that carries the effect.)
  @param(p The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffEngulfed(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFriends(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies the poison that slow poison holds back: every ten minutes, unless the effect lock is set, renews itself and
  costs the creature 1 hit point while it has more than 1, redrawing the party display outside combat.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSlowPoisonHit(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies shield: raises the creature's armor class value to at least 57 (armor class 3), adds 1 to the saving throw,
  and stops Magic Missile.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffShield(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Gnome's to-hit bonus: raise the attack roll by 1 against a target whose creature-type flags have bit 1 set.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGnomeHitBonus(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies resist fire: halves fire damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies silence: the creature can neither use items nor cast this round, and says it is silenced the first time.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSilence(cr: Types.PWork; p: Pointer; removed: Boolean);

{ End of slow poison: unless effects are locked, a creature still poisoned dies, and the slow-poison effect is removed
  with effects locked.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSlowPoisonEnd(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Spiritual hammer: on removal take the hammer out of the creature's items; otherwise, when it has no hammer and room in
  its pack, give it a +1 spiritual hammer, readied, and show 'Gains an item'. The armor class is recomputed after.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies invisibility: unless the current character can see invisible, it may not target the creature and takes 4 from
  its attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Dwarf's to-hit bonus: raise the attack roll by 1 against a target whose creature-type flags have bit 2 set.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDwarfHitBonus(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies mirror image: unless the dice pick the creature itself (1 in images + 1), an attack or single-target offensive
  spell is canceled and an image is lost; losing the last ends the effect. The image count is the high nibble of the
  effect's strength. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffMirrorImage(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies ray of enfeeblement: the damage loses a quarter, rounded down.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffEnfeeble(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Coughing effect: shows 'is coughing' the first time, stops the creature casting and using items, lowers its rear armor
  class value by 2, to no less than 50, and copies it to the armor class.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCoughing(cr: Types.PWork; p: Pointer; removed: Boolean);

{ End of animate dead: the creature collapses dead unless effects are locked, and returns to its side with its fighting
  level, movement 12 and creature type 0 restored.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffAnimateDead(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies blindness: the attack roll, armor class, armor class from behind and saving throw each lose 4.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlind(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies disease: runs the handlers of the strength-loss and hit-point-loss diseases.
  @param(cr The creature carrying the effect.)
  @param(p Passed on to the handlers.)
  @param(removed Passed on to the handlers.) }
procedure EffDiseased(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Confusion, rolled on 1d100 each round: 1..10 the creature flees in fear under computer control, 11..60 it stands
  confused and loses its turn, 61..80 it goes berserk, 81..100 it is enraged. Then a saving throw ends the confusion.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffConfusion(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies bestow curse: takes 4 from the attack roll and the saving throw.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBestowCurse(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Blinking: in combat, while the creature has no initiative left, it cannot be targeted and attacks on it miss.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlinking(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Haste effect: the creature ages a year the first time (bit 4 of the strength marks that), and its movement or attacks
  double.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffHasted(cr: Types.PWork; p: Pointer; removed: Boolean);

{ End of stinking cloud: find the creature's cloud by the effect's strength, show that the air (or water) clears,
  restore the terrain of its cells (a corpse where a body lies), unlink and free it, and redraw the remaining clouds.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffClearStinkingCloud(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Protection from Normal Missiles effect: a missile without a plus is always avoided.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffProtNormalMissiles(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies Slow: halves the movement or attacks.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSlowed(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Strength disease: unless effects are locked, renews itself for 60 more minutes and lowers the Strength by 1 ('is
  weakened') while it is above 3; at 3 the creature becomes helpless.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffDiseaseStrength(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Hit-point disease: unless the effect lock is on, it re-arms for 10 minutes and deals 1 damage, or at 1 hit point the
  creature becomes helpless.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDiseaseHitPoints(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Dwarf's defense against giants: lower the attack roll by 4 against a large attacker of creature type 2 or 10.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDwarfGiantDefense(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies the gnome's defensive bonus: takes 4 from the attack roll when the current creature is of creature type 1 with
  icon size 2.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGnomeBugDefense(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies prayer: gives the side named by strength bit 4 a 1 bonus to saving throws and attack rolls and the other side
  a 1 penalty.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Passed on to the bonus routine.) }
procedure EffPrayer(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A creature of cold: raise the save roll by 2 against cold, and double fire damage it fails to save against.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffColdNature(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A creature of fire: raise the save roll by 2 against fire, and double cold damage. Note: the doubling tests
  GDVars.recentlySavedGameFlag where EffColdNature tests the saving throw.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireNature(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Ring of Invisibility effect: renews invisibility for a minute.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRenewInvisibility(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Immobile: no movement and no casting.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmobile(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A troll's regeneration starting: adds lasting regeneration (effect 98).
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollRegen(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Hit only by magic: a weapon without a plus does no damage and one below +3 half; holy water is unaffected.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRequirePlusThreeWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Strong fire resistance: against fire, take 2 off each damage die (each die doing at least 1), raise the save roll by
  4, and cancel fire that is not magical.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrongFireResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Constitution regeneration, for Constitution 20 and over: unless the effect lock is set, renews itself for an hour and
  heals a hit point.
  @param(cr Creature with the effect.)
  @param(p The effect record.)
  @param(removed Unused.) }
procedure EffConRegeneration(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Minor globe of invulnerability: cancel spells below level 4.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMinorGlobe(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Makes a hit poisonous: the target saves against poison or dies.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Makes a hit weakly poisonous: the target saves against poison, at +4, or dies.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeakPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Makes a hit mildly poisonous: the target saves against poison, at +2, or dies.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMildPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Paralyzing-hit effect: the target saves or is paralyzed for 2d8 minutes.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffParalyzingHit(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies Feeblemind: sets Intelligence and Wisdom to 7 ("is stupid"); in combat the creature can no longer cast and
  loses the spell it was casting.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFeeblemind(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies Invisible to Animals: an attacker of creature type 19 takes 4 from its attack roll and, without See Invisible,
  cannot attack the creature.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffInvisibleToAnimals(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Makes a hit strongly poisonous: the target saves against poison, at -2, or dies.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrongPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Concealed: the creature cannot be targeted and attacks on it drop by 4.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffConcealed(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Camouflage and the Cloak of Elvenkind: 95 percent of the time, invisibility for a minute.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCamouflage(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies breath immunity: cancels the effect and the damage of attacks with damage-type bit $20 ("is unaffected").
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneBreath(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDistracted(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Dragon slayer: against a dragon (creature type 3) the damage becomes 1d12 times 3, plus 4 and the strength bonus, and
  the attack roll rises by 2.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonSlayer(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Against creature type 8, add 3 to the attack roll and the damage.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBonusVsTypeEight(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies berserk: makes the creature a quick fighter with NPC value $B3 ($B2 for an NPC above $7F other than $B3). In
  combat it also targets the first other creature in its target list, joins the opposing team, stops casting and "goes
  berzerk". On removal $B3 is cleared and it returns to team 0.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Revival effect: the creature revives with its current hit points, or the effect re-arms to try again in a minute.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDelayedRevival(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Fire on a hit: 2d10 magical fire damage to the target.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Acid-touch effect: a hit deals 1d4 acid damage to the target.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffAcidTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halves the damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDamage(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Resistance to fire and cold: against either, a saving throw (type 4) negates the damage when the current spell allows
  a save, and otherwise the damage is halved.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireColdResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Petrifying gaze: gaze at the target when it is in line of sight, unless it is invisible or concealed (or invisible to
  animals, for a gazer of creature type 19). With effect 127 a target with a mirror item (name part 118) reflects the
  gaze back. The one gazed at saves or is stoned.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPetrifyingGaze(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Absorbs electricity: the effect and damage are canceled and the creature gains 8 hit points, with no limit. Note: a d8
  is rolled and its result discarded.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffAbsorbElectricity(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Makes weapons of weapon class 1 deal 1 damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffResistPiercing(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies displacement: the first attack on the creature misses; the mark in strength bit 4 is cleared only in round 0
  on a zero attack roll.
  @param(cr Unused.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffDisplaced(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Ends the caster's Cloudkill: finds the creature's cloud, numbered by its strength div 16, in the Cloudkill list. If
  found, restores its nine cells (the downed-body tile $1F where a body lies, else the saved tile), unlinks and frees
  it, and draws the cloud tile $1C on the cells of the remaining clouds.
  @param(cr The creature that carries the effect.)
  @param(p The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffClearCloudkill(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halves fire damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfFire(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halves damage from weapons whose weapon class has bit 0 or bit 7 set.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfPierceBash(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Fighting on at 0 hit points: when it runs out, a creature still fighting falls dead.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffFightOn(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Constitution save bonus: adds 1 at Constitution 4..6, up to 5 at 18..20, to saving throws against spells and wands.
  Note: a Constitution outside 4..20 adds an unset value.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffConSpellSave(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Regeneration: heal 3 hit points, up to the maximum.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRegeneration(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Being able to fight on: a dying creature less than 6 below 0, or an unconscious one, revives and fights on under the
  fighting-on effect for 1d4+1 minutes, and this effect goes.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffCanFightOn(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A troll's vulnerability to fire and acid: damage of any other kind starts its return in 3d6 minutes.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollBurn(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A troll's regeneration: unless it already regenerates, regeneration starts in 3 minutes.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffTrollHeal(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A troll coming back: it revives at full hit points, or tries again in a minute.
  @param(cr The creature with the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffTrollReturn(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Adds 1d6 fire damage against a target without effects 20, 54 and 61.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireDamageBonus(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Missile-dodging effect: a 60 percent chance to avoid a missile.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDodgeMissiles(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Gives magic resistance of 50, which rises against casters below level 11.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrongMagicResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Gives magic resistance of 15, which rises against casters below level 11.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeakMagicResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Elven resistance: a 90 percent chance to resist sleep and charm.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffElfResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Immunity to sleep and charm: charm and sleep have no effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneSleepCharm(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Immunity to paralysis: paralysis has no effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysis(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies cold immunity: cancels the effect and the damage of cold attacks.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneCold(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Immunity to poison and paralysis: poison and paralysis have no effect, and saving throws of type 0 always succeed.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysisPoison(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies fire immunity: cancels the effect and the damage of fire attacks.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneFire(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Against fire, take 1 off each damage die, each doing at least 1.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeakFireResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halve electric damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfElectric(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halve the damage of weapons of class 0 or 1.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDamageFromWeaponClass(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halves the damage of a weapon with a plus.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfMagicWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies vulnerability to holy water: an attacker (the current character) wielding a holy water vial does 1d6 + 1
  damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHolyWater(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halves cold damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfCold(cr: Types.PWork; p: Pointer; removed: Boolean);

{ A weapon without a plus does no damage when its wielder is a monster or its terrType is below 4.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWeaponResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Boulder-dodging effect: a 50 percent chance to avoid a thrown boulder.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDodgeBoulders(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Spit acid: on 1..25 of 1d100 at a target within 3 cells, end the turn and spit 8d4 acid damage, a save for half, then
  end this effect and effect 80.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffSpitAcid(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Paralyzing touch: the target saves or is held ('is paralyzed').
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffParalyzingTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Deals 2d8 magical cold damage to the creature's target.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffColdTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Half-elven resistance: a 30 percent chance to resist sleep and charm.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfElfResistance(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Immunity to charm, sleep, paralysis and poison: those effects are canceled, and saves against paralysis and poison
  succeed.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneCharmSleepParalysisPoison(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Paralyzing gaze: gaze at the target, which saves or is held ('is paralyzed').
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffParalyzingGaze(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Cancel an attack that carries an effect or magical damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMagicImmunity(cr: Types.PWork; p: Pointer; removed: Boolean);

{ An attack with quarrels (item type $1C) of name part 135 removes the creature outright (gone), removes its effects
  that end at 0 hit points, triggers its condition-13 effects and marks it downed if it is still disabled. Note: the
  item's type is read before the item is checked for nil.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBanishByWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);

{ An item's effect: add the effect the item carries to the creature, running its handler outside combat; on removal
  remove it.
  @param(cr The creature the effect is on.)
  @param(p The item that carries the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrantItemEffect(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Cancels fear, effects 29 and 68, and attacks with damage-type bit $40.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneDebilitation(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Ranger's damage bonus: add the ranger level to the damage against a target whose creature-type flags have bit 3 set.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRangerDamageBonus(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Cancel electric damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneElectric(cr: Types.PWork; p: Pointer; removed: Boolean);

{ No movement.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoMovement(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies berserk from confusion: the creature fights under AI control (NPC value $B3, or $B2 for an NPC above $7F other
  than $B3), takes the second creature of a full target list as its target and joins the side opposed to it. On removal
  a $B3 creature's NPC value is cleared and its side comes from the effect's strength.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies lasting invisibility: makes the creature invisible, with duration and strength $FF.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffLastingInvisibility(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Applies the recent-cure effect: on removal, sets the paladin's cures left to (paladin level - 1) div 5 + 1.
  @param(cr The creature that carries the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecentCure(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Fear: drop the creature's AI effects; on removal a party member is the player's again and the creature stops fleeing.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Zaps an adjacent attacker (the current character): it 'gets zapped' for twice the pending damage, as magic.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffZapAttacker(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Dispel evil's touch: an evil target that fails its save is dispelled and the attacker loses dispel evil (effects 4 and
  145); otherwise 'resists dispel evil'.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDispelEvilTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Add 1d6 to fire damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireVulnerable(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Double the damage of a weapon with name part 144.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffVulnerableToIcewindDale(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Halve the damage when the target wears armor with name part 137.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGlacierArmor(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Double the damage of a weapon with name part 250.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffVulnerableToStonecutting(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Charming gaze: a target not charmed already saves or is charmed to the gazer's side ('is charmed'), its charm handler
  run and its turn ended.
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffCharmGaze(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Against a dragon (creature type 3), add 2 to the attack roll and the damage and make it magical fire.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFlameVsDragons(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Surrender: a creature below 20 hit points that is the last of its side surrenders ('Surrenders'); a hostile one counts
  as escaped.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSurrender(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Disease touch: unless the effect is being removed, the target saves or is diseased ('is diseased').
  @param(cr The creature the effect is on.)
  @param(p The effect node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseaseTouch(cr: Types.PWork; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNone(cr: Types.PWork; p: Pointer; removed: Boolean);

implementation

const
  { the See Invisible spell's effect }
  SEE_INVISIBLE = 24;
  { fighting on: a creature EffCanFightOn revives, which falls dead when the effect ends }
  FIGHT_ON = 95;
  { gone berserk, on Confusion's roll }
  CONFUSED_BERSERK = 137;

type
  { a 16-bit count that is never negative }
  TNN16 = 0..32767;

{ Cancels the pending effect and the damage when the given effect is 0 or is the effect being applied.
  @param(x The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(x: Byte);
begin
  if (x = 0) or (GDVars.gEffectCheck = x) then
  begin GDVars.pendingDamage := 0; GDVars.gEffectCheck := 0; end;
end;

{ Adds an effect, removed through its handler, unless the effect lock is set.
  @param(cr The creature given the effect.)
  @param(effId The effect.)
  @param(strength Its strength.)
  @param(minutes Its duration in minutes.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(cr: Types.PWork; effId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectLockFlag <> 0 then AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(cr, effId, minutes, strength, True);
  end;
end;

procedure EffClearGuard(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if Byte(CharHlp.ClearGuard(cr)) <> 0 then;
end;

{ Raise the save roll and the attack roll by 1.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure SaveAttackBonus(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.gSaveRoll);
  Inc(GDVars.currentAttackRoll);
end;

procedure EffBless(cr: Types.PWork; p: Pointer; removed: Boolean);
begin Inc(GDVars.currentMorale, 5); Inc(GDVars.currentAttackRoll); end;

procedure EffCurse(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if GDVars.currentMorale < 5 then GDVars.currentMorale := 0 else Dec(GDVars.currentMorale, 5);
  Dec(GDVars.currentAttackRoll);
end;

procedure EffSticksToSnakes(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  t: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ended: Boolean;
begin
  t := cr^.curAttacks[1] + cr^.curAttacks[2];
  if Types.PEffectRec(p)^.strength > t then
    Dec(Types.PEffectRec(p)^.strength, t)
  else
    FxEngine.RemoveEffect(cr, C_Effect.SNAKES, nil);
  CharHlp.PrintNameStringAnim(cr, True, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  ended := CharHlp.ClearGuard(cr);
end;

procedure EffDispelEvil(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.creatureTypeFlags and 1) <> 0 then Dec(GDVars.currentAttackRoll, 7);
end;

procedure EffFlameTongue(cr: Types.PWork; p: Pointer; removed: Boolean);
var t: Byte;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  case GDVars.otherCreatureCurrentPtr^.charType of
    10: t := 1;
    9, 12: t := 2;
    4: t := 3;
  else
    t := 0;
  end;
  Inc(GDVars.currentAttackRoll, t);
  Inc(GDVars.pendingDamage, t);
  GDVars.elementMask := 9;
end;

procedure EffFaerieFire(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if cr^.acCur < 58 then Inc(cr^.acCur, 2) else cr^.acCur := 60;
  if cr^.acBehind < 58 then Inc(cr^.acBehind, 2) else cr^.acBehind := 60;
end;

procedure EffProtEvil(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.caAlignment = 2) or (GDVars.curChar^.caAlignment = 5) or
      (GDVars.curChar^.caAlignment = 8) then
  begin Inc(GDVars.gSaveRoll, 2); Dec(GDVars.currentAttackRoll, 2); end;
end;

procedure EffProtGood(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.caAlignment = 0) or (GDVars.curChar^.caAlignment = 3) or
      (GDVars.curChar^.caAlignment = 6) then
  begin Inc(GDVars.gSaveRoll, 2); Dec(GDVars.currentAttackRoll, 2); end;
end;

procedure EffResistCold(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then
  begin GDVars.pendingDamage := GDVars.pendingDamage shr 1; Inc(GDVars.gSaveRoll, 3); end;
end;

procedure EffCharm(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if removed then
    cr^.fxHostile := (Types.PEffectRec(p)^.strength and $40) div $40
  else begin
    if (Types.PEffectRec(p)^.strength and $20) = 0 then begin
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $20 + ShortInt(cr^.fxHostile) * $40;
      cr^.fxHostile := Types.PEffectRec(p)^.strength div $80;
      cr^.combatAddr^.other := nil;
      CbtMap.CountTeams;
    end;
    GDVars.currentMorale := 100;
  end;
  if cr^.fxHostile = 1 then begin
    cr^.quickfight := 1;
    if cr^.npc <= C_Npc.MORALE_MASK then cr^.npc := C_Npc.ANIMATED_PLAYER;
  end else if cr^.npc = C_Npc.ANIMATED_PLAYER then begin
    cr^.quickfight := 0;
    cr^.npc := 0;
  end;
end;

procedure EffEnlargeStrength(cr: Types.PWork; p: Pointer; removed: Boolean);
begin end;

procedure EffEngulfed(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength = 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'Suffocates')
  else
    Dec(Types.PEffectRec(p)^.strength);
end;

procedure EffFriends(cr: Types.PWork; p: Pointer; removed: Boolean);
begin end;

procedure EffSlowPoisonHit(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if GDVars.effectLockFlag <> 0 then
  else if EffHndlr.AddEffectIfNoLock(cr, C_Effect.SLOW_POISON_HIT, Types.PEffectRec(p)^.strength, 10) then
    if cr^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar);
    end;
end;

procedure EffReadMagic(cr: Types.PWork; p: Pointer; removed: Boolean);
begin end;

procedure EffShield(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if cr^.acCur < 57 then cr^.acCur := 57;
  Inc(GDVars.gSaveRoll);
  if GDVars.currentSpellBeing = 15 then GDVars.pendingDamage := 0;
end;

procedure EffGnomeHitBonus(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if (GDVars.otherCreatureCurrentPtr^.creatureTypeFlags and 2) <> 0 then Inc(GDVars.currentAttackRoll);
end;

procedure EffResistFire(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (not removed) and ((GDVars.elementMask and 1) <> 0) then
  begin GDVars.pendingDamage := GDVars.pendingDamage shr 1; Inc(GDVars.gSaveRoll, 3); end;
end;

procedure EffSilence(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(cr, 'is silenced', C_Msg.MESSAGE_ROW, True);
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
end;

procedure EffSlowPoisonEnd(cr: Types.PWork; p: Pointer; removed: Boolean);
var buf: Pointer;
begin
  if GDVars.effectLockFlag <> 0 then
  else begin
    if CharHlp.HasEffect(cr, C_Effect.POISONED, Types.PEffectRec(buf)) then
      FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'dies from poison');
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLockFlag := 0;
  end;
end;

procedure EffSpiritualHammer(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  allocated: Types.PItemRec;
  it: Types.PItemRec;
  found: Byte;
begin
  it := cr^.itemsAddr;
  found := 0;
  while (it <> nil) and (found = 0) do
    if (it^.itemType = C_Item.HAMMER) and (it^.nameIds[3] = C_Item.SPIRITUAL_COMPONENT) then
      found := 1
    else
      it := it^.next;
  if removed and (it <> nil) then
    CharHlp.RemoveItem(cr, it);
  if (not removed) and (found = 0) and (cr^.numberOfItems < C_Item.MAX_CARRIED_ITEMS) then begin
    it := New(Types.PItemRec);
    allocated := it;
    FillChar(it^, SizeOf(it^), 0);
    it^.itemType := C_Item.HAMMER;
    it^.nameIds[2] := C_Item.HAMMER_COMPONENT;
    it^.nameIds[3] := C_Item.SPIRITUAL_COMPONENT;
    it^.plus := 1;
    it^.effect := C_Effect.SPIRITUAL_HAMMER;
    it^.special := $A0;
    CharHlp.AddItemCopyVar(cr, it);
    ViewChar.ToggleReadyItem(it);
    Dispose(allocated);
    CharHlp.PrintCreatureMessage(cr, 'Gains an item', C_Msg.MESSAGE_ROW, True);
  end;
  CharHlp.RecalcStats(Types.PWork(cr));
end;

procedure EffInvisible(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  if not removed then
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE, Types.PEffectRec(loc)) then begin
      GDVars.currentSuppressTargetingFlag := 1;
      Dec(GDVars.currentAttackRoll, 4);
    end;
end;

procedure EffDwarfHitBonus(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if (GDVars.otherCreatureCurrentPtr^.creatureTypeFlags and 4) <> 0 then Inc(GDVars.currentAttackRoll);
end;

procedure EffMirrorImage(cr: Types.PWork; p: Pointer; removed: Boolean);
var images: Byte;
begin
  if (not removed) and (FxEngine.RollDice(1, (Types.PEffectRec(p)^.strength div 16) + 1) > 1) and
      ((GDVars.currentSpellBeing <= 0) or
       ((GDVars.currentSpellAffectsFlag = 0) and
        (GDConsts.spellTable[GDVars.currentSpellBeing].offensive <> 0))) then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(cr, 'lost an image', C_Msg.MESSAGE_ROW, True);
    images := Types.PEffectRec(p)^.strength shr 4;
    Dec(images);
    if images = 0 then
      FxEngine.RemoveEffect(cr, C_Effect.MIRROR_IMAGE, nil)
    else begin
      images := images shl 4;
      Types.PEffectRec(p)^.strength := (Types.PEffectRec(p)^.strength and $F) or images;
    end;
  end;
end;

procedure EffEnfeeble(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

procedure EffCoughing(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(cr, 'is coughing', C_Msg.MESSAGE_ROW, True);
  cr^.combatAddr^.itemUseAllowed := 0;
  cr^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(Types.PWork(cr));
  if cr^.acBehind > 52 then Dec(cr^.acBehind, 2)
  else cr^.acBehind := 50;
  cr^.acCur := cr^.acBehind;
  if cr = GDVars.curChar then
    CharHlp.CombatPrintCreatureInfo(cr);
end;

procedure EffAnimateDead(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if GDVars.effectLockFlag = 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'collapses');
  cr^.fxHostile := Types.PEffectRec(p)^.strength div 16;
  cr^.quickfight := 1;
  cr^.thiefSkills[$E9] := 0;
  cr^.attackLevel := ClassCal.EarlierClassActive(Types.PWork(cr)) * cr^.classLevels2[C_Class.FIGHTER_LEVEL] +
    cr^.classLevels[C_Class.FIGHTER_LEVEL];
  cr^.moveRate := 12;
  if cr^.npc = C_Npc.ANIMATED_PLAYER then cr^.npc := 0;
  cr^.charType := 0;
end;

procedure EffBlind(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  Dec(GDVars.currentAttackRoll, 4);
  Dec(cr^.acCur, 4);
  Dec(cr^.acBehind, 4);
  Dec(GDVars.gSaveRoll, 4);
end;

procedure EffDiseased(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(C_Effect.DISEASE_STRENGTH, cr, p, removed);
  FxEngine.CallEffectHandler(C_Effect.DISEASE_HIT_POINTS, cr, p, removed);
end;

procedure EffConfusion(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Boolean;
begin
  roll := FxEngine.RollDice(1, 100);
  case roll of
    1..10:
      begin
        FxEngine.RemoveEffect(cr, C_Effect.CONFUSED, nil);
        cr^.combatAddr^.turned := 1;
        cr^.quickfight := 1;
        if cr^.npc <= C_Npc.MORALE_MASK then cr^.npc := C_Npc.ANIMATED_PLAYER;
        cr^.combatAddr^.other := nil;
        FxEngine.AddEffectWithMessage(cr, C_Effect.AFRAID, 10, 0, True, True, False, 'runs away');
        FxEngine.RemoveAiEffects(Types.PWork(cr));
      end;
    11..60:
      begin
        CharHlp.PrintNameStringAnim(cr, True, 'is confused');
        CharHlp.ClearMessageWindow;
        EffHndlr.EffClearGuard(cr, p, False);
      end;
    61..80:
      begin
        FxEngine.AddEffectWithMessage(cr, EffHndlr.CONFUSED_BERSERK, 1, cr^.fxHostile, True, True, False,
                                      'goes berserk');
        FxEngine.CallEffectHandler(EffHndlr.CONFUSED_BERSERK, cr, nil, False);
      end;
    81..100:
      begin
        CharHlp.PrintNameStringAnim(cr, True, 'is enraged');
        CharHlp.ClearMessageWindow;
      end;
  end;
  saved := FxEngine.RollSavingThrow(cr, 4, -2);
  if saved then
    FxEngine.RemoveEffect(cr, C_Effect.CONFUSED, nil);
end;

procedure EffBestowCurse(cr: Types.PWork; p: Pointer; removed: Boolean);
begin Dec(GDVars.currentAttackRoll, 4); Dec(GDVars.gSaveRoll, 4); end;

procedure EffBlinking(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
  else if cr^.combatAddr^.initiative = 0 then
  begin GDVars.currentSuppressTargetingFlag := 1; GDVars.currentAttackRoll := -1; end;
end;

procedure EffHasted(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (Types.PEffectRec(p)^.strength and $10) = 0 then begin
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $10;
    CharHlp.PrintCreatureMessage(cr, 'ages', C_Msg.MESSAGE_ROW, True);
    Inc(cr^.age);
  end;
  GDVars.currentAttackCurrent := GDVars.currentAttackCurrent shl 1;
end;

{ Show that the air clears, or the water underwater. }
procedure PrintCloudClearMessage;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0 then
    CharHlp.PrintBottomLine('The air clears a little...')
  else
    CharHlp.PrintBottomLine('The water clears a little...');
end;

procedure EffClearStinkingCloud(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  cloud: Types.PArenaNode;
  node: Types.PArenaNode;
  found: Boolean;
  k: Byte;
  i: Byte;
  col: Byte;
  row: Byte;
begin
  k := Types.PEffectRec(p)^.strength div 16;
  found := False;
  node := GDVars.linkedListStinkingPtr;
  while (node <> nil) and not found do
    if (node^.owner = cr) and (node^.hi = k) then
      found := True
    else
      node := node^.next;
  if not found then Exit;
  EffHndlr.PrintCloudClearMessage;
  for i := 1 to SizeOf(GDConsts.cloudCells) do
    if node^.active[i] <> 0 then begin
      col := node^.baseCol + GDConsts.dirDX[GDConsts.cloudCells[i]];
      row := node^.baseRow + GDConsts.dirDY[GDConsts.cloudCells[i]];
      found := False;
      for k := 1 to GDVars.downedCount do
        if (GDVars.combatDownedCharacter[k].cr <> nil) and (GDVars.combatDownedCharacter[k].x = col)
           and (GDVars.combatDownedCharacter[k].y = row) then
          found := True;
      if found then
        GDVars.combatArenaPtr^.cells[row, col] := C_Terr.TERRAIN_CORPSE
      else
        GDVars.combatArenaPtr^.cells[row, col] := node^.saved[i];
    end;
  cloud := GDVars.linkedListStinkingPtr;
  if cloud = node then
    GDVars.linkedListStinkingPtr := cloud^.next
  else
    while cloud^.next <> node do
      cloud := cloud^.next;
  cloud^.next := node^.next;
  FreeMem(node, SizeOf(Types.TArenaNode));
  cloud := GDVars.linkedListStinkingPtr;
  while cloud <> nil do begin
    for i := 1 to SizeOf(GDConsts.cloudCells) do
      if cloud^.active[i] <> 0 then
        GDVars.combatArenaPtr^.cells[cloud^.baseRow + GDConsts.dirDY[GDConsts.cloudCells[i]],
                               cloud^.baseCol + GDConsts.dirDX[GDConsts.cloudCells[i]]] := C_Terr.TERRAIN_STINK_CLOUD;
    cloud := cloud^.next;
  end;
end;

{ Lets a creature avoid a missile: when the current character has a readied weapon and stands more than one cell away, a
  d100 roll within the chance cancels the damage, makes the attack miss and takes the hit back, with 'Avoids it'.
  @param(w The creature attacked.)
  @param(chance The chance in percent.) }
procedure AvoidMissile(w: Types.PWork; chance: Byte);
begin
  if GDVars.curChar^.equipped[C_Equip.WEAPON] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, w) > 1 then
      if FxEngine.RollDice(1, 100) <= chance then begin
        CharHlp.PrintCreatureMessage(w, 'Avoids it', C_Msg.MESSAGE_ROW, True);
        GDVars.pendingDamage := 0;
        GDVars.currentAttackRoll := -1;
        Dec(GDVars.currentNumberHits[1]);
      end;
end;

{ Finds the item a creature attacks with: the missile its readied weapon fires or throws, else the readied weapon.
  @param(w The creature.)
  @returns(The item, or nil with no weapon readied.) }
function FindDamagingWeapon(w: Types.PWork): Pointer;
var res: Pointer; flag: Byte;
begin
  res := nil;
  if w^.equipped[C_Equip.WEAPON] <> nil then begin
    flag := Byte(CharHlp.FindDamagingRangedWeapon(w, res));
    if (flag = 0) or (res = nil) then res := w^.equipped[C_Equip.WEAPON];
  end;
  FindDamagingWeapon := res;
end;

procedure EffProtNormalMissiles(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar))^.plus = 0 then
      EffHndlr.AvoidMissile(cr, 100);
end;

procedure EffSlowed(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.currentAttackCurrent := GDVars.currentAttackCurrent shr 1;
end;

procedure EffDiseaseStrength(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_STRENGTH, Types.PEffectRec(p)^.strength, 60) then begin
    if cr^.statCells[$11] > 3 then begin
      CharHlp.PrintCreatureMessage(cr, 'is weakened', C_Msg.MESSAGE_ROW, True);
      Dec(cr^.statCells[$11]);
    end else
      if not CharHlp.HasEffect(cr, C_Effect.HELPLESS, Types.PEffectRec(loc)) then
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, False);
  end;
end;

procedure EffDiseaseHitPoints(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(cr, C_Effect.DISEASE_HIT_POINTS, Types.PEffectRec(p)^.strength, 10) then begin
    if cr^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar);
    end else
      if not CharHlp.HasEffect(cr, C_Effect.HELPLESS, Types.PEffectRec(loc)) then
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, False);
  end;
end;

procedure EffDwarfGiantDefense(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if (GDVars.curChar^.charType = 2) or (GDVars.curChar^.charType = 10) then
    if (GDVars.curChar^.iconDim and $7F) = 2 then Dec(GDVars.currentAttackRoll, 4);
end;

procedure EffGnomeBugDefense(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if GDVars.curChar^.charType = 1 then
    if (GDVars.curChar^.iconDim and $7F) = 2 then Dec(GDVars.currentAttackRoll, 4);
end;

procedure EffPrayer(cr: Types.PWork; p: Pointer; removed: Boolean);
var t: Byte;
begin
  t := (Types.PEffectRec(p)^.strength and $10) div 16;
  if cr^.fxHostile = t then EffHndlr.SaveAttackBonus(cr, p, removed)
  else begin Dec(GDVars.currentAttackRoll); Dec(GDVars.gSaveRoll); end;
end;

procedure EffColdNature(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then Inc(GDVars.gSaveRoll, 2)
  else if (GDVars.elementMask and 1) <> 0 then
    if not GDVars.isSavingThrowMade then GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffFireNature(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then Inc(GDVars.gSaveRoll, 2)
  else if (GDVars.elementMask and 2) <> 0 then
    if GDVars.recentlySavedGameFlag = 0 then GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffPoisoned(cr: Types.PWork; p: Pointer; removed: Boolean);
begin end;

procedure EffRenewInvisibility(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffImmobile(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  cr^.combatAddr^.movement := 0;
  cr^.combatAddr^.castAllowed := 0;
end;

procedure EffTrollRegen(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, 98, 0, 255, False);
end;

procedure EffRequirePlusThreeWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if (r <> nil) and (r^.itemType = C_Item.HOLY_WATER_VIAL) then
  else if (r = nil) or (r^.plus = 0) then GDVars.pendingDamage := 0
  else if (r <> nil) and (r^.plus < 3) then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffStrongFireResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
var i: Byte;
begin
  if (GDVars.elementMask and 1) <> 0 then begin
    for i := 1 to GDVars.currentDamageDice do begin
      Dec(GDVars.pendingDamage, 2);
      if GDVars.pendingDamage < GDVars.currentDamageDice then GDVars.pendingDamage := GDVars.currentDamageDice;
    end;
    Inc(GDVars.gSaveRoll, 4);
    if (GDVars.elementMask and 8) = 0 then EffHndlr.NullifyAttack(0);
  end;
end;

procedure EffConRegeneration(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(cr, 62, Types.PEffectRec(p)^.strength, 60) then
    if FxEngine.RestoreHitPoints(cr, 1, True) then
      CharHlp.AnnounceHealStatus(cr);
end;

procedure EffMinorGlobe(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.currentSpellBeing > 0) and
      (GDConsts.spellTable[GDVars.currentSpellBeing].levelS < 4) then EffHndlr.NullifyAttack(0);
end;

{ The creature's target saves against poison with modifier x or is poisoned and killed ('is Poisoned', 'is killed').
  @param(cr The attacker.)
  @param(x The save modifier, read as a ShortInt.) }
procedure PoisonTarget(cr: Types.PWork; x: Byte);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 0, ShortInt(x)) then begin
    CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'is Poisoned', C_Msg.MESSAGE_ROW, False);
    TextRend.PauseOnly;
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.POISONED, 0, 255, False);
    FxEngine.KillCreature(GDVars.otherCreatureCurrentPtr, C_Status.DEAD_STATUS, 'is killed');
  end;
end;

{ The creature's target saves or is held for dmg ('is Paralyzed').
  @param(cr The attacker.)
  @param(dmg The hold's duration.)
  @param(flag Unused.) }
procedure ParalyzeTarget(cr: Types.PWork; dmg: Word; flag: Byte);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 0, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.otherCreatureCurrentPtr, True, 'is Paralyzed');
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.HELD, dmg, 12, False);
  end;
end;

procedure EffPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 0);
end;

procedure EffWeakPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 4);
end;

procedure EffMildPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 2);
end;

procedure EffParalyzingHit(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalyzeTarget(cr, FxEngine.RollDice(2, 8), 0);
end;

procedure EffFeeblemind(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  cr^.statCells[$13] := 7;
  cr^.statCells[$15] := 7;
  CharHlp.PrintCreatureMessage(cr, 'is stupid', C_Msg.MESSAGE_ROW, True);
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    cr^.combatAddr^.castAllowed := 0;
    if cr^.combatAddr^.spellCast > 0 then begin
      CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(cr, cr^.combatAddr^.spellCast);
      cr^.combatAddr^.spellCast := 0;
    end;
  end;
end;

procedure EffInvisibleToAnimals(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  if GDVars.curChar^.charType = 19 then begin
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE,
                             Types.PEffectRec(loc)) then GDVars.currentSuppressTargetingFlag := 1;
    Dec(GDVars.currentAttackRoll, 4);
  end;
end;

procedure EffStrongPoisonAttack(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(cr, 254);
end;

procedure EffConcealed(cr: Types.PWork; p: Pointer; removed: Boolean);
begin GDVars.currentSuppressTargetingFlag := 1; Dec(GDVars.currentAttackRoll, 4); end;

procedure EffCamouflage(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 95 then FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, False);
end;

procedure EffImmuneBreath(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $20) > 0 then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(cr, 'is unaffected', C_Msg.MESSAGE_ROW, True);
  end;
end;

procedure EffDistracted(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Integer;
begin
end;

procedure EffDragonSlayer(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if GDVars.otherCreatureCurrentPtr^.charType = 3 then begin
    GDVars.pendingDamage := FxEngine.RollDice(1, 12) * 3 + 4 + CharHlp.StrDamageAdjust(cr);
    Inc(GDVars.currentAttackRoll, 2);
  end;
end;

procedure EffBonusVsTypeEight(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if GDVars.otherCreatureCurrentPtr^.charType = 8 then
  begin Inc(GDVars.currentAttackRoll, 3); Inc(GDVars.pendingDamage, 3); end;
end;

procedure EffBerserk(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= C_Npc.MORALE_MASK) or (cr^.npc = C_Npc.ANIMATED_PLAYER) then cr^.npc := C_Npc.ANIMATED_PLAYER
    else cr^.npc := C_Npc.ANIMATED_NON_PLAYER;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      cr^.combatAddr^.other := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                              255, 255, CbtMap.GetIconSize(cr), GDVars.combatArenaPtr);
      cr^.combatAddr^.other := GDVars.creaturePtr[GDVars.combatTargetData[2].idx];
      cr^.combatAddr^.castAllowed := 0;
      cr^.fxHostile := cr^.combatAddr^.other^.fxHostile xor 1;
      CharHlp.PrintCreatureMessage(cr, 'goes berzerk', C_Msg.MESSAGE_ROW, True);
    end;
  end else begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then cr^.npc := 0;
    cr^.fxHostile := 0;
  end;
end;

procedure EffDelayedRevival(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(cr, cr^.hpCur) then
    repeated := EffHndlr.AddEffectIfNoLock(cr, 78, Types.PEffectRec(p)^.strength, 1);
end;

procedure EffFireTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := 9;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(2, 10), 0, False);
end;

procedure EffAcidTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $10;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(1, 4), 0, False);
end;

procedure EffHalfDamage(cr: Types.PWork; p: Pointer; removed: Boolean);
begin GDVars.pendingDamage := GDVars.pendingDamage shr 1; end;

procedure EffFireColdResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if ((GDVars.elementMask and 1) <> 0) or ((GDVars.elementMask and 2) <> 0) then
    if FxEngine.RollSavingThrow(cr, 4, 0) and (GDConsts.spellTable[GDVars.currentSpellBeing].saveResult <> 0) then
      GDVars.pendingDamage := 0
    else
      GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffPetrifyingGaze(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
  reflected: Boolean;
  eff: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
  dist: Word;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_Effect.INVISIBLE, eff) or
      CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, 71, eff) or
      ((cr^.charType = 19) and CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, 69, eff)) then Exit;
  x := CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr);
  y := CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr);
  dist := 20;
  if not Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), x, y,
                          dist, GDVars.combatArenaPtr) then Exit;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', C_Msg.MESSAGE_ROW, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr),
                                  CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 4, 45);
  if CharHlp.HasEffect(cr, 127, eff) then begin
    reflected := False;
    it := GDVars.otherCreatureCurrentPtr^.itemsAddr;
    while (it <> nil) and (not reflected) do begin
      if it^.equipped <> 0 then
        if (it^.nameIds[1] = 118) or (it^.nameIds[2] = 118) or (it^.nameIds[3] = 118) then begin
          CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'reflects it!', 12, False);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                          CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr),
                                          CbtMap.CombatCellX(cr),
                                          CbtMap.CombatCellY(cr), 4, 45);
          reflected := True;
          GDVars.otherCreatureCurrentPtr := cr;
        end;
      it := it^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 1, 0) then
    FxEngine.KillCreature(GDVars.otherCreatureCurrentPtr, C_Status.STONED, 'is Stoned');
end;

procedure EffAbsorbElectricity(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
begin
  if (GDVars.elementMask and 4) <> 0 then begin
    EffHndlr.NullifyAttack(0);
    roll := FxEngine.RollDice(1, 8);
    Inc(cr^.hpCur, 8);
  end;
end;

procedure EffResistPiercing(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if GDVars.baseItems[r^.itemType].wpnClass = 1 then GDVars.pendingDamage := 1;
end;

procedure EffDisplaced(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.combatRoundCounterCount = 0) and (GDVars.currentAttackRoll = 0) then
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength and $F
  else if (Types.PEffectRec(p)^.strength and $10) = 0 then begin
    GDVars.currentAttackRoll := -1;
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength or $10;
  end;
end;

procedure EffClearCloudkill(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  ptr2: Types.PArenaNode;
  node: Types.PArenaNode;
  found: Boolean;
  j: Byte;
  i: Byte;
  cellX: Byte;
  cellY: Byte;
begin
  j := Types.PEffectRec(p)^.strength div 16;
  found := False;
  node := GDVars.cloudkillList;
  while (node <> nil) and not found do
    if (node^.caster = cr) and (node^.idx = j) then
      found := True
    else
      node := node^.next;
  if not found then Exit;
  EffHndlr.PrintCloudClearMessage;
  for i := 1 to SizeOf(GDConsts.cloudCells9) do
    if node^.exists[i] <> 0 then begin
      cellX := node^.ulX + GDConsts.dirDX[GDConsts.cloudCells9[i]];
      cellY := node^.ulY + GDConsts.dirDY[GDConsts.cloudCells9[i]];
      found := False;
      for j := 1 to GDVars.downedCount do
        if (GDVars.combatDownedCharacter[j].cr <> nil) and (GDVars.combatDownedCharacter[j].x = cellX) and
            (GDVars.combatDownedCharacter[j].y = cellY) then
          found := True;
      if found then
        GDVars.combatArenaPtr^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE
      else
        GDVars.combatArenaPtr^.cells[cellY, cellX] := node^.under[i];
    end;
  ptr2 := GDVars.cloudkillList;
  if ptr2 = node then
    GDVars.cloudkillList := ptr2^.next
  else
    while ptr2^.next <> node do
      ptr2 := ptr2^.next;
  ptr2^.next := node^.next;
  Dispose(node);
  ptr2 := GDVars.cloudkillList;
  while ptr2 <> nil do begin
    for i := 1 to SizeOf(GDConsts.cloudCells9) do
      if ptr2^.exists[i] <> 0 then
        GDVars.combatArenaPtr^.cells[ptr2^.ulY + GDConsts.dirDY[GDConsts.cloudCells9[i]],
                               ptr2^.ulX + GDConsts.dirDX[GDConsts.cloudCells9[i]]] := C_Terr.TERRAIN_CLOUDKILL;
    ptr2 := ptr2^.next;
  end;
end;

procedure EffHalfFire(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffHalfPierceBash(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if (GDVars.baseItems[r^.itemType].wpnClass and $81) <> 0 then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffFightOn(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if cr^.enabled <> 0 then
    FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'Falls dead');
end;

procedure EffConSpellSave(cr: Types.PWork; p: Pointer; removed: Boolean);
var t: Byte;
begin
  if (GDVars.currentSavingThrow2 = 4) or (GDVars.currentSavingThrow2 = 2) then begin
    case cr^.statCells[$19] of
      4..6: t := 1;
      7..10: t := 2;
      11..13: t := 3;
      14..17: t := 4;
      18..20: t := 5;
    end;
    GDVars.gSaveRoll := GDVars.gSaveRoll + t;
  end;
end;

procedure EffRegeneration(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  Inc(cr^.hpCur, 3);
  if cr^.hpCur > cr^.evMaxHp then cr^.hpCur := cr^.evMaxHp;
end;

procedure EffCanFightOn(cr: Types.PWork; p: Pointer; removed: Boolean);
var hp: Byte;
begin
  hp := 0;
  if (cr^.status = C_Status.DYING) and (cr^.combatAddr^.overkill < 6) then
    hp := 6 - cr^.combatAddr^.overkill;
  if cr^.status = C_Status.UNCONSCIOUS then hp := 6;
  if (hp > 0) and FxEngine.ReviveDeadCreature(cr, hp) then begin
    FxEngine.AddEffect(cr, EffHndlr.FIGHT_ON, FxEngine.RollDice(1, 4) + 1, 255, True);
    Types.PEffectRec(p)^.onRemove := False;
    FxEngine.RemoveEffect(cr, 99, p);
  end;
end;

procedure EffTrollBurn(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if ((GDVars.elementMask and 1) = 0) and ((GDVars.elementMask and $10) = 0) then
    FxEngine.AddEffect(cr, 102, FxEngine.RollDice(3, 6), 255, True);
end;

procedure EffTrollHeal(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  if (not CharHlp.HasEffect(cr, 98, Types.PEffectRec(loc)))
     and (not CharHlp.HasEffect(cr, 59, Types.PEffectRec(loc))) then
    FxEngine.AddEffect(cr, 59, 3, 255, True);
end;

procedure EffTrollReturn(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  repeated: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(cr, cr^.evMaxHp) then
    repeated := EffHndlr.AddEffectIfNoLock(cr, 102, Types.PEffectRec(p)^.strength, 1);
end;

procedure EffFireDamageBonus(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if (not CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, 20, Types.PEffectRec(loc)))
     and (not CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, 54, Types.PEffectRec(loc)))
     and (not CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, 61, Types.PEffectRec(loc))) then
    Inc(GDVars.pendingDamage, FxEngine.RollDice(1, 6));
end;

procedure EffDodgeMissiles(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidMissile(cr, 60);
end;

{ Magic resistance: an attack carrying an effect or magical damage is canceled on a percentile roll of x, plus 5 for
  each caster level below 11.
  @param(x The base chance.) }
procedure MagicResistance(x: Byte);
var
  r: Byte;
  thr: Byte;
begin
  r := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  thr := x + (11 - r) * 5;
  if (GDVars.gEffectCheck = 0) and ((GDVars.elementMask and 8) = 0) then
  else
    if FxEngine.RollDice(1, 100) <= thr then EffHndlr.NullifyAttack(0);
end;

procedure EffStrongMagicResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(50);
end;

procedure EffWeakMagicResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(15);
end;

procedure EffElfResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
    EffHndlr.NullifyAttack(C_Effect.CHARM);
  end;
end;

procedure EffImmuneSleepCharm(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
end;

procedure EffImmuneParalysis(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.HELD);
end;

procedure EffImmuneCold(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffImmuneParalysisPoison(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(C_Effect.HELD);
  if GDVars.currentSavingThrow2 = 0 then GDVars.gSaveRoll := 100;
end;

procedure EffImmuneFire(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffWeakFireResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
var i: Byte;
begin
  if (GDVars.elementMask and 1) <> 0 then
    for i := 1 to GDVars.currentDamageDice do begin
      Dec(GDVars.pendingDamage);
      if GDVars.pendingDamage < GDVars.currentDamageDice then GDVars.pendingDamage := GDVars.currentDamageDice;
    end;
end;

procedure EffHalfElectric(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 4) <> 0 then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffHalfDamageFromWeaponClass(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if (GDVars.baseItems[r^.itemType].wpnClass = 0) or
        (Byte(GDVars.baseItems[r^.itemType].wpnClass = 1) <> 0) then
      GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffHalfMagicWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if r^.plus > 0 then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffHolyWater(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if r <> nil then
    if r^.itemType = C_Item.HOLY_WATER_VIAL then
      GDVars.pendingDamage := FxEngine.RollDamageDice(1, 6) + 1;
end;

procedure EffHalfCold(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 2) <> 0 then GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffWeaponResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if (r = nil) or (r^.plus = 0) then
    if (GDVars.curChar^.race > C_Race.MONSTER) or (GDVars.curChar^.terrType < 4) then GDVars.pendingDamage := 0;
end;

procedure EffDodgeBoulders(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if r <> nil then
    if (r^.itemType = C_Item.VH_BOULDER) or (r^.itemType = C_Item.LT_BOULDER) then
      EffHndlr.AvoidMissile(cr, 50);
end;

procedure EffSpitAcid(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  ended: Boolean;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if (FxEngine.RollDice(1, 100) <= 25) and (CharHlp.CalcDistance(cr, GDVars.otherCreatureCurrentPtr) < 4) then begin
    ended := CharHlp.ClearGuard(cr);
    CharHlp.PrintCreatureMessage(cr, 'Spits Acid', C_Msg.MESSAGE_ROW, True);
    CharHlp.BuildIconFacings(23);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr),
                                    CbtMap.CombatCellY(cr),
                                    CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                    CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 1, 30);
    FxEngine.InflictNonWeaponDamage(GDVars.otherCreatureCurrentPtr, FxEngine.RollDamageDice(8, 4), 2,
                           FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 3, 0));
    FxEngine.RemoveEffect(cr, 121, p);
    FxEngine.RemoveEffect(cr, 80, nil);
  end;
end;

procedure EffParalyzingTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
var saved: Boolean;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else begin
    saved := FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 0, 0);
    if not saved then begin
      FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.HELD, 0, 255, False);
      CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'is paralyzed', C_Msg.MESSAGE_ROW, True);
    end;
  end;
end;

procedure EffColdTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $A;
  FxEngine.InflictNonWeaponDamage(cr^.combatAddr^.other, FxEngine.RollDamageDice(2, 8), 0, False);
end;

procedure EffHalfElfResistance(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
  end;
end;

procedure EffImmuneCharmSleepParalysisPoison(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
  EffHndlr.NullifyAttack(C_Effect.HELD);
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  if GDVars.currentSavingThrow2 = 0 then GDVars.gSaveRoll := 100;
end;

procedure EffParalyzingGaze(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', C_Msg.MESSAGE_ROW, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr),
                                  CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 4, 45);
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 1, 0) then begin
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.HELD, 0, 255, False);
    CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'is paralyzed', C_Msg.MESSAGE_ROW, False);
  end;
end;

procedure EffMagicImmunity(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.gEffectCheck = 0) and ((GDVars.elementMask and 8) = 0) then
  else EffHndlr.NullifyAttack(0);
end;

procedure EffBanishByWeapon(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Pointer;
begin
  loc := nil;
  if Byte(CharHlp.FindDamagingRangedWeapon(GDVars.curChar, loc)) <> 0 then
    if Types.PItemRec(loc)^.itemType = C_Item.QUARRELS then
      if loc <> nil then
        if Types.PItemRec(loc)^.nameIds[3] = 135 then begin
          cr^.status := C_Status.GONE;
          cr^.enabled := 0;
          cr^.hpCur := 0;
          FxEngine.RemoveEffectsHp0(cr);
          FxEngine.TriggerEffectsWithCondition(13, cr);
          if cr^.enabled = 0 then CbtMap.CreatureDowned(cr);
        end;
end;

procedure EffGrantItemEffect(cr: Types.PWork; p: Pointer; removed: Boolean);
var loc: Types.PItemRec;
begin
  GDVars.overrideEffectFlag := 0;
  loc := p;
  if removed then
    FxEngine.RemoveEffect(cr, loc^.effect, nil)
  else begin
    FxEngine.AddEffect(cr, loc^.effect, 0, 255, True);
    if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
      FxEngine.CallEffectHandler(loc^.effect, cr, nil, False);
  end;
end;

procedure EffImmuneDebilitation(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.AFRAID);
  EffHndlr.NullifyAttack(29);
  EffHndlr.NullifyAttack(68);
  if (GDVars.elementMask and $40) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffRangerDamageBonus(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
  else if (GDVars.otherCreatureCurrentPtr^.creatureTypeFlags and 8) <> 0 then
    Inc(GDVars.pendingDamage, cr^.fxClassA[C_Class.RANGER_LEVEL]);
end;

procedure EffImmuneElectric(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 4) <> 0 then EffHndlr.NullifyAttack(0);
end;

procedure EffNoMovement(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  cr^.combatAddr^.movement := 0;
end;

procedure EffConfusedBerserk(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= C_Npc.MORALE_MASK) or (cr^.npc = C_Npc.ANIMATED_PLAYER) then cr^.npc := C_Npc.ANIMATED_PLAYER
    else cr^.npc := C_Npc.ANIMATED_NON_PLAYER;
    cr^.combatAddr^.other := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255,
                            255, CbtMap.GetIconSize(cr), GDVars.combatArenaPtr);
    cr^.combatAddr^.other := GDVars.creaturePtr[GDVars.combatTargetData[2].idx];
    cr^.fxHostile := cr^.combatAddr^.other^.fxHostile xor 1;
  end else begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then cr^.npc := 0;
    cr^.fxHostile := Types.PEffectRec(p)^.strength;
  end;
end;

procedure EffLastingInvisibility(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 255, 255, False);
end;

procedure EffRecentCure(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if removed then
    cr^.diseaseCount := TNN16(ClassCal.EarlierClassActive(Types.PWork(cr)) *
                              cr^.classLevels2[C_Class.PALADIN_LEVEL] + cr^.classLevels[C_Class.PALADIN_LEVEL] -
                              1) div 5 + 1;
end;

procedure EffFear(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if cr^.npc = C_Npc.ANIMATED_PLAYER then
    begin cr^.npc := 0; cr^.quickfight := 0; end;
    cr^.combatAddr^.turned := 0;
  end else
    FxEngine.RemoveAiEffects(Types.PWork(cr));
end;

procedure EffZapAttacker(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  savedAe: Byte;
  savedAf: Byte;
begin
  if CharHlp.CalcDistance(GDVars.curChar, cr) < 2 then begin
    savedAe := GDVars.pendingDamage;
    GDVars.pendingDamage := GDVars.pendingDamage shl 1;
    savedAf := GDVars.elementMask;
    GDVars.elementMask := 8;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'gets zapped', C_Msg.MESSAGE_ROW, True);
    FxEngine.InflictNonWeaponDamage(GDVars.curChar, GDVars.pendingDamage, 0, False);
    GDVars.pendingDamage := savedAe;
    GDVars.elementMask := savedAf;
  end;
end;

procedure EffDispelEvilTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if ((GDVars.otherCreatureCurrentPtr^.creatureTypeFlags and 1) <> 0) and
      (not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 4, 0)) then begin
    FxEngine.KillCreature(GDVars.otherCreatureCurrentPtr, C_Status.GONE, 'is dispelled');
    FxEngine.RemoveEffect(GDVars.curChar, 4, nil);
    FxEngine.RemoveEffect(GDVars.curChar, 145, nil);
  end else
    CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'resists dispel evil', C_Msg.MESSAGE_ROW, True);
end;

procedure EffFireVulnerable(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1) <> 0 then
    Inc(GDVars.pendingDamage, FxEngine.RollDice(1, 6));
end;

procedure EffVulnerableToIcewindDale(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if (r^.nameIds[1] = 144) or (r^.nameIds[2] = 144) or (r^.nameIds[3] = 144) then
      GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffGlacierArmor(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  r := GDVars.otherCreatureCurrentPtr^.equipped[C_Equip.ARMOR];
  if r <> nil then
    if (r^.nameIds[1] = 137) or (r^.nameIds[2] = 137) or (r^.nameIds[3] = 137) then
      GDVars.pendingDamage := GDVars.pendingDamage shr 1;
end;

procedure EffVulnerableToStonecutting(cr: Types.PWork; p: Pointer; removed: Boolean);
var r: Types.PItemRec;
begin
  r := Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if r <> nil then
    if (r^.nameIds[1] = 250) or (r^.nameIds[2] = 250) or (r^.nameIds[3] = 250) then
      GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffCharmGaze(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  guardRes: Boolean;
  saved: Boolean;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_Effect.CHARM, Types.PEffectRec(p)) then Exit;
  saved := FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 4, 0);
  if saved then Exit;
  FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_Effect.CHARM, 0, ShortInt(cr^.fxHostile) * $80 + 3, True);
  CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'is charmed', C_Msg.MESSAGE_ROW, True);
  if CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_Effect.CHARM, Types.PEffectRec(p)) then
    FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.otherCreatureCurrentPtr, p, False);
  guardRes := CharHlp.ClearGuard(GDVars.otherCreatureCurrentPtr);
end;

procedure EffFlameVsDragons(cr: Types.PWork; p: Pointer; removed: Boolean);
var t: Byte;
begin
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if GDVars.otherCreatureCurrentPtr^.charType = 3 then t := 2 else t := 0;
  if t <> 0 then begin
    Inc(GDVars.currentAttackRoll, t);
    Inc(GDVars.pendingDamage, t);
    GDVars.elementMask := 9;
  end;
end;

procedure EffSurrender(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if (cr^.enabled <> 0) and (cr^.hpCur < 20) and (GDVars.teamCount[ShortInt(cr^.fxHostile)] <= 1) then begin
    FxEngine.PutOutOfPlayWithStatus(cr, C_Status.UNCONSCIOUS, 'Surrenders');
    if cr^.fxHostile = 1 then
      GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] := GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] + 1;
  end;
end;

procedure EffDiseaseTouch(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.otherCreatureCurrentPtr := cr^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then Exit;
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, 0, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.otherCreatureCurrentPtr, True, 'is diseased');
    FxEngine.CallEffectHandler(C_Effect.DISEASED, GDVars.otherCreatureCurrentPtr, p, removed);
  end;
end;

procedure EffNone(cr: Types.PWork; p: Pointer; removed: Boolean);
begin end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[1] := EffHndlr.EffBless;
  GDVars.effectHandlers[2] := EffHndlr.EffCurse;
  GDVars.effectHandlers[3] := EffHndlr.EffSticksToSnakes;
  GDVars.effectHandlers[4] := EffHndlr.EffDispelEvil;
  GDVars.effectHandlers[5] := EffHndlr.EffNone;
  GDVars.effectHandlers[6] := EffHndlr.EffFlameTongue;
  GDVars.effectHandlers[7] := EffHndlr.EffFaerieFire;
  GDVars.effectHandlers[8] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[9] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[10] := EffHndlr.EffResistCold;
  GDVars.effectHandlers[11] := EffHndlr.EffCharm;
  GDVars.effectHandlers[12] := EffHndlr.EffEnlargeStrength;
  GDVars.effectHandlers[13] := EffHndlr.EffEngulfed;
  GDVars.effectHandlers[14] := EffHndlr.EffFriends;
  GDVars.effectHandlers[15] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectHandlers[16] := EffHndlr.EffReadMagic;
  GDVars.effectHandlers[17] := EffHndlr.EffShield;
  GDVars.effectHandlers[18] := EffHndlr.EffGnomeHitBonus;
  GDVars.effectHandlers[19] := EffHndlr.EffNone;
  GDVars.effectHandlers[20] := EffHndlr.EffResistFire;
  GDVars.effectHandlers[21] := EffHndlr.EffSilence;
  GDVars.effectHandlers[22] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectHandlers[23] := EffHndlr.EffSpiritualHammer;
  GDVars.effectHandlers[24] := EffHndlr.EffNone;
  GDVars.effectHandlers[25] := EffHndlr.EffInvisible;
  GDVars.effectHandlers[26] := EffHndlr.EffDwarfHitBonus;
  GDVars.effectHandlers[27] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[28] := EffHndlr.EffMirrorImage;
  GDVars.effectHandlers[29] := EffHndlr.EffEnfeeble;
  GDVars.effectHandlers[30] := EffHndlr.EffCoughing;
  GDVars.effectHandlers[31] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[32] := EffHndlr.EffAnimateDead;
  GDVars.effectHandlers[33] := EffHndlr.EffBlind;
  GDVars.effectHandlers[34] := EffHndlr.EffDiseased;
  GDVars.effectHandlers[35] := EffHndlr.EffConfusion;
  GDVars.effectHandlers[36] := EffHndlr.EffBestowCurse;
  GDVars.effectHandlers[37] := EffHndlr.EffBlinking;
  GDVars.effectHandlers[38] := EffHndlr.EffEnlargeStrength;
  GDVars.effectHandlers[39] := EffHndlr.EffHasted;
  GDVars.effectHandlers[40] := EffHndlr.EffClearStinkingCloud;
  GDVars.effectHandlers[41] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectHandlers[42] := EffHndlr.EffSlowed;
  GDVars.effectHandlers[43] := EffHndlr.EffDiseaseStrength;
  GDVars.effectHandlers[44] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectHandlers[45] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[46] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[47] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectHandlers[48] := EffHndlr.EffGnomeBugDefense;
  GDVars.effectHandlers[49] := EffHndlr.EffPrayer;
  GDVars.effectHandlers[50] := EffHndlr.EffColdNature;
  GDVars.effectHandlers[51] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[52] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[53] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[54] := EffHndlr.EffFireNature;
  GDVars.effectHandlers[55] := EffHndlr.EffPoisoned;
  GDVars.effectHandlers[56] := EffHndlr.EffRenewInvisibility;
  @GDVars.effectHandlers[57] := @CbtActs.AttackEngulf;
  GDVars.effectHandlers[58] := EffHndlr.EffImmobile;
  GDVars.effectHandlers[59] := EffHndlr.EffTrollRegen;
  GDVars.effectHandlers[60] := EffHndlr.EffRequirePlusThreeWeapon;
  GDVars.effectHandlers[61] := EffHndlr.EffStrongFireResistance;
  GDVars.effectHandlers[62] := EffHndlr.EffConRegeneration;
  GDVars.effectHandlers[63] := EffHndlr.EffMinorGlobe;
  GDVars.effectHandlers[64] := EffHndlr.EffPoisonAttack;
  GDVars.effectHandlers[65] := EffHndlr.EffWeakPoisonAttack;
  GDVars.effectHandlers[66] := EffHndlr.EffMildPoisonAttack;
  GDVars.effectHandlers[67] := EffHndlr.EffParalyzingHit;
  GDVars.effectHandlers[68] := EffHndlr.EffFeeblemind;
  GDVars.effectHandlers[69] := EffHndlr.EffInvisibleToAnimals;
  GDVars.effectHandlers[70] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectHandlers[71] := EffHndlr.EffConcealed;
  GDVars.effectHandlers[72] := EffHndlr.EffCamouflage;
  GDVars.effectHandlers[73] := EffHndlr.EffImmuneBreath;
  GDVars.effectHandlers[74] := EffHndlr.EffDistracted;
  GDVars.effectHandlers[75] := EffHndlr.EffDragonSlayer;
  GDVars.effectHandlers[76] := EffHndlr.EffBonusVsTypeEight;
  GDVars.effectHandlers[77] := EffHndlr.EffBerserk;
  GDVars.effectHandlers[78] := EffHndlr.EffDelayedRevival;
  GDVars.effectHandlers[79] := EffHndlr.EffFireTouch;
  GDVars.effectHandlers[80] := EffHndlr.EffAcidTouch;
  GDVars.effectHandlers[81] := EffHndlr.EffHalfDamage;
  GDVars.effectHandlers[82] := EffHndlr.EffFireColdResistance;
  GDVars.effectHandlers[83] := EffHndlr.EffPetrifyingGaze;
  GDVars.effectHandlers[84] := EffHndlr.EffAbsorbElectricity;
  GDVars.effectHandlers[85] := EffHndlr.EffResistPiercing;
  @GDVars.effectHandlers[87] := @CbtActs.AttackEyeRays;
  GDVars.effectHandlers[89] := EffHndlr.EffDisplaced;
  GDVars.effectHandlers[91] := EffHndlr.EffClearCloudkill;
  GDVars.effectHandlers[92] := EffHndlr.EffNone;
  GDVars.effectHandlers[93] := EffHndlr.EffHalfFire;
  GDVars.effectHandlers[94] := EffHndlr.EffHalfPierceBash;
  GDVars.effectHandlers[95] := EffHndlr.EffFightOn;
  @GDVars.effectHandlers[96] := @CbtActs.AttackHug;
  GDVars.effectHandlers[97] := EffHndlr.EffConSpellSave;
  GDVars.effectHandlers[98] := EffHndlr.EffRegeneration;
  GDVars.effectHandlers[99] := EffHndlr.EffCanFightOn;
  GDVars.effectHandlers[100] := EffHndlr.EffTrollBurn;
  GDVars.effectHandlers[101] := EffHndlr.EffTrollHeal;
  GDVars.effectHandlers[102] := EffHndlr.EffTrollReturn;
  GDVars.effectHandlers[103] := EffHndlr.EffFireDamageBonus;
  GDVars.effectHandlers[104] := EffHndlr.EffDodgeMissiles;
  GDVars.effectHandlers[105] := EffHndlr.EffStrongMagicResistance;
  GDVars.effectHandlers[106] := EffHndlr.EffWeakMagicResistance;
  GDVars.effectHandlers[107] := EffHndlr.EffElfResistance;
  GDVars.effectHandlers[108] := EffHndlr.EffImmuneSleepCharm;
  GDVars.effectHandlers[109] := EffHndlr.EffImmuneParalysis;
  GDVars.effectHandlers[110] := EffHndlr.EffImmuneCold;
  GDVars.effectHandlers[111] := EffHndlr.EffImmuneParalysisPoison;
  GDVars.effectHandlers[112] := EffHndlr.EffImmuneFire;
  GDVars.effectHandlers[113] := EffHndlr.EffWeakFireResistance;
  GDVars.effectHandlers[114] := EffHndlr.EffHalfElectric;
  GDVars.effectHandlers[115] := EffHndlr.EffHalfDamageFromWeaponClass;
  GDVars.effectHandlers[116] := EffHndlr.EffHalfMagicWeapon;
  GDVars.effectHandlers[117] := EffHndlr.EffHolyWater;
  GDVars.effectHandlers[118] := EffHndlr.EffHalfCold;
  GDVars.effectHandlers[119] := EffHndlr.EffWeaponResistance;
  GDVars.effectHandlers[120] := EffHndlr.EffDodgeBoulders;
  GDVars.effectHandlers[121] := EffHndlr.EffSpitAcid;
  GDVars.effectHandlers[122] := EffHndlr.EffParalyzingTouch;
  GDVars.effectHandlers[123] := EffHndlr.EffColdTouch;
  GDVars.effectHandlers[124] := EffHndlr.EffHalfElfResistance;
  GDVars.effectHandlers[125] := EffHndlr.EffImmuneCharmSleepParalysisPoison;
  GDVars.effectHandlers[126] := EffHndlr.EffParalyzingGaze;
  GDVars.effectHandlers[127] := EffHndlr.EffNone;
  GDVars.effectHandlers[129] := EffHndlr.EffMagicImmunity;
  GDVars.effectHandlers[130] := EffHndlr.EffBanishByWeapon;
  GDVars.effectHandlers[133] := EffHndlr.EffImmuneDebilitation;
  GDVars.effectHandlers[134] := EffHndlr.EffRangerDamageBonus;
  GDVars.effectHandlers[135] := EffHndlr.EffImmuneElectric;
  GDVars.effectHandlers[136] := EffHndlr.EffNoMovement;
  GDVars.effectHandlers[137] := EffHndlr.EffConfusedBerserk;
  GDVars.effectHandlers[138] := EffHndlr.EffLastingInvisibility;
  @GDVars.effectHandlers[C_Effect.SWALLOWING] := @CbtActs.BiteAndHold;
  GDVars.effectHandlers[140] := EffHndlr.EffNone;
  GDVars.effectHandlers[141] := EffHndlr.EffRecentCure;
  GDVars.effectHandlers[142] := EffHndlr.EffFear;
  GDVars.effectHandlers[143] := EffHndlr.EffZapAttacker;
  @GDVars.effectHandlers[C_Effect.HUGGING] := @CbtActs.BiteAndHold;
  GDVars.effectHandlers[145] := EffHndlr.EffDispelEvilTouch;
  GDVars.effectHandlers[146] := EffHndlr.EffNone;
  GDVars.effectHandlers[147] := EffHndlr.EffGrantItemEffect;
  GDVars.effectHandlers[148] := EffHndlr.EffFireVulnerable;
  @GDVars.effectHandlers[149] := @CbtActs.AttackDrainBlood;
  @GDVars.effectHandlers[C_Effect.DRAINING_BLOOD] := @CbtActs.BiteAndHold;
  GDVars.effectHandlers[151] := EffHndlr.EffVulnerableToIcewindDale;
  GDVars.effectHandlers[152] := EffHndlr.EffGlacierArmor;
  GDVars.effectHandlers[153] := EffHndlr.EffVulnerableToStonecutting;
  GDVars.effectHandlers[154] := EffHndlr.EffCharmGaze;
  @GDVars.effectHandlers[155] := @CbtActs.AttackConstrict;
  @GDVars.effectHandlers[C_Effect.CONSTRICTING] := @CbtActs.BiteAndHold;
  GDVars.effectHandlers[157] := EffHndlr.EffFlameVsDragons;
  GDVars.effectHandlers[158] := EffHndlr.EffSurrender;
  GDVars.effectHandlers[159] := EffHndlr.EffDiseaseTouch;
end;

begin
end.
