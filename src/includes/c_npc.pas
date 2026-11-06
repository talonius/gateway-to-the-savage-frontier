{ TWork.npc values: bit 7 marks a creature outside the party; bits 0..6 hold its morale. }
unit C_Npc;

interface

const
  NON_PLAYER = $80;
  MORALE_MASK = $7F;
  { a creature outside the party that an effect puts under the computer's control: a monster animated or gone berserk,
    or the mirror-duel copy }
  ANIMATED_NON_PLAYER = $B2;
  { a party member under the computer's control: charmed, berserk, afraid or animated. Money still counts it with the
    party, and the effect's end gives it back to the player (npc 0) }
  ANIMATED_PLAYER = $B3;

implementation

end.
