{ Creature status values: TWork.status, in statusNames order. Status 2 has no name: no code sets or tests it. }
unit C_Status;

interface

const
  OKAY = 0;
  ANIMATED = 1;
  { fled combat }
  RUNNING = 3;
  UNCONSCIOUS = 4;
  DYING = 5;
  DEAD_STATUS = 6;
  { petrified }
  STONED = 7;
  { removed from play: disintegrated or dispelled }
  GONE = 8;

implementation

end.
