{ Effect trigger conditions: the points in combat at which FxEngine.TriggerEffectsWithCondition runs effect handlers. }
unit C_Cond;

interface

const
  { Combat's CreatureAction, before the initiative test }
  TURN_START = 7;
  COMBAT_START = 8;
  { CombatAi's AiMoveAttack, as it starts }
  MONSTER_SPECIAL = 14;
  { CreatureAction, before the creature acts }
  ACTION_START = 15;
  MORALE_CHECK = 17;
  ROUND_END = 19;

implementation

end.
