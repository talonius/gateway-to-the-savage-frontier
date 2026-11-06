{ The weapon-property bits of TBaseItemRec.props, the item types and name components the code singles out, the most
  items a character carries, and the weight carried past its allowance. }
unit C_Item;

interface

const
  { TBaseItemRec.props bits }
  USES_ARROWS = $01;
  STRENGTH_BONUS = $04;
  FIRES_AMMO = $08;
  { the weapon itself is the missile }
  THROWN = $10;
  USES_QUARRELS = $80;
  THROWABLE = C_Item.THROWN or C_Item.STRENGTH_BONUS;
  { item types: the hammer, the Spiritual Hammer spell's weapon too, quarrels, arrows and the holy water vial }
  HAMMER = 20;
  QUARRELS = 28;
  ARROWS = 73;
  HOLY_WATER_VIAL = 85;
  { monster weapons that never drop and are not thrown back: itemTypeNames' vhboulder, ltboulder, HyBoulder and
    manttail }
  VH_BOULDER = 87;
  LT_BOULDER = 88;
  HY_BOULDER = 89;
  MANT_TAIL = 98;
  { itemNameComponents' Hammer and Spiritual, the Spiritual Hammer's name }
  HAMMER_COMPONENT = 20;
  SPIRITUAL_COMPONENT = 243;
  { the most items a character carries }
  MAX_CARRIED_ITEMS = 16;
  { the encumbrance a character may carry past its weight allowance }
  CARRY_ALLOWANCE = 1500;

implementation

end.
