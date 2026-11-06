{ Spell values: the spell lists, the pending flag and id mask of a spell byte, a character's memorized-spell slots, and
  the spell ids more than one unit names. }
unit C_Spell;

interface

const
  { the spell list a spell belongs to (TSpellTabRec.castClass), also the first index of a character's spell slots }
  CLERIC_LIST = 0;
  DRUID_LIST = 1;
  MAGIC_USER_LIST = 2;
  { A spell byte holds the spell id in bits 0..6; bit 7 marks a pending memorization or scribing. }
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { a character's memorized-spell slots, 0..80 }
  MEMORIZED_SPELL_SLOTS = 81;
  { the spells a new magic-user knows: Detect Magic, Enlarge, Read Magic and Sleep }
  DETECT_MAGIC_MAGE = 11;
  ENLARGE = 12;
  READ_MAGIC = 18;
  SLEEP = 21;
  { the cure spells: Camp's Fix rolls them, and CbtActs aims them at the wounded }
  CURE_LIGHT_WOUNDS = 3;
  CURE_SERIOUS_WOUNDS = 58;
  CURE_CRITICAL_WOUNDS = 71;

implementation

end.
