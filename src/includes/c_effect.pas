{ Effect ids: the id of a TEffectRec node and the index into EffHndlr's handler table. }
unit C_Effect;

interface

const
  { harassed by snakes, fighting them instead of acting }
  SNAKES = 3;
  { protection from evil: CharGen grants it to a paladin }
  PROTECTION_FROM_EVIL = 8;
  CHARM = 11;
  ENLARGE = 12;
  { swallowed whole: the victim suffocates when its count runs out }
  SUFFOCATING = 13;
  { Slow Poison's hourly damage }
  SLOW_POISON_HIT = 15;
  { racial: CharGen grants it to a gnome }
  GNOME_THAC0 = 18;
  { Slow Poison wearing off: a creature still poisoned dies }
  SLOW_POISON_END = 22;
  SPIRITUAL_HAMMER = 23;
  INVISIBLE = 25;
  { racial: CharGen grants it to a dwarf }
  DWARF_THAC0 = 26;
  { clumsy, on a failed save against SpellFumble }
  CLUMSY = 27;
  MIRROR_IMAGE = 28;
  { coughing in a stinking cloud after a saved throw }
  STINKING_COUGH = 30;
  { nausea from a stinking cloud, and the end of a disease }
  HELPLESS = 31;
  ANIMATE_DEAD = 32;
  BLIND = 33;
  DISEASED = 34;
  { Note: CharHlp's effect-name table shows it as blinded. }
  CONFUSED = 35;
  BESTOW_CURSE = 36;
  STRENGTH = 38;
  HASTED = 39;
  SLOWED = 42;
  { a disease that weakens an ability score, and one that takes hit points }
  DISEASE_STRENGTH = 43;
  DISEASE_HIT_POINTS = 44;
  { racial: CharGen grants these to dwarves and gnomes }
  DWARF_ARMOR_CLASS_VS_GIANTS = 47;
  GNOME_ARMOR_CLASS_BONUS = 48;
  { paralyzed }
  HELD = 52;
  SLEEP = 53;
  POISONED = 55;
  { no movement }
  IMMOBILE = 58;
  { racial: CharGen grants these for the race }
  CONSTITUTION_SAVE_BONUS = 97;
  ELF_RESISTANCE = 107;
  { immune to a stinking cloud's effects }
  IMMUNE_PARALYSIS_POISON = 111;
  { racial: CharGen grants it to a half-elf }
  HALF_ELF_RESISTANCE = 124;
  { immune to a cloudkill's effects }
  IMMUNE_CHARM_POISON = 125;
  { no movement: the Entangle spell's effect }
  ENTANGLED = 136;
  { a monster's hold on its victim: swallowing it }
  SWALLOWING = 139;
  { fleeing in fear }
  AFRAID = 142;
  { a monster's holds on its victim: hugging it, draining its blood and constricting it }
  HUGGING = 144;
  DRAINING_BLOOD = 150;
  CONSTRICTING = 156;

implementation

end.
