{ Script-visible game-memory addresses, used as indices into the zone banks. }
unit C_Gbvm;

interface

const
  { zone 0: the 3D map block LOAD FILES loaded, reloaded with a saved game }
  GEO_MAP_ID = $4BC5;
  { zone 0: the game clock's hour }
  CLOCK_HOURS = $4BC9;
  { zone 0: the area's anti-magic flag }
  ANTI_MAGIC = $4BE5;
  { zone 0: nonzero while the party is in a dungeon, zero on the overland }
  IN_DUNGEON = $4BE6;
  { zone 0: the party's cell before its last step }
  PREV_X = $4BF0;
  PREV_Y = $4BF1;
  { zone 0: the script that ran before the last NEWECL }
  PREV_SCRIPT = $4BF2;
  { zone 0: nonzero where the area has no automap and the party's coordinates are hidden }
  NO_AUTOMAP = $4BFB;
  { zone 0: the camp's ring and statues, which the camp menu offers }
  CAMP_RING = $4C21;
  CAMP_STATUES = $4C27;
  { zone 0: the difficulty level, which scales monster hit points and to-hit rolls }
  DIFFICULTY = $4CF4;
  { zone 0: nonzero for a fight underwater: combat changes color 8, missiles cannot be used and some spells fail }
  UNDERWATER = $4CF7;
  { zone 0: the direction the party fled in }
  FLEE_DIRECTION = $4CF9;
  { zone 0: while set, pictures draw recolored through the view, and MenuCore's menu animation steps a frame on every
    pass of its loop }
  PICTURE_FADE = $4CFF;
  { zone 0: 1 when the party may leave a combat by any map edge }
  COMBAT_MODE = $4D01;
  { zone 0: the count of hostiles that surrendered or got away }
  ESCAPED_HOSTILES = $4D03;

  { zone 1: the classes the training hall here trains, as a bitmask; 0 outside a hall }
  TRAIN_MASK = $7EA8;
  { zone 1: the distance between the party and the monsters, at most the requested one }
  MONSTER_DIST = $7EC1;
  { zone 1: added to a creature's morale check }
  MORALE_THRESHOLD = $7EC6;
  { zone 1: how the last combat ended }
  COMBAT_RESULT = $7EC7;
  { zone 1: $FF or more blocks the party's next step; cleared when a map loads }
  MOVE_LOCK = $7EC9;
  { zone 1: search and look mode flags }
  SEARCH_FLAGS = $7ECA;
  { zone 1: the sides taken by surprise (1 the party, 2 the hostiles) }
  SURPRISE = $7ECB;
  { zone 1: the rest ticks between the rolls for an interruption, and the percent chance of each }
  REST_SAFE_TIME = $7ED2;
  REST_INTERRUPT_PERCENT = $7ED3;
  { zone 1: set when the party's step leaves the map }
  LEAVE_MAP = $7ED5;
  { zone 1: the portrait head shown for PICTURE and close-ups; 255 for none }
  PORTRAIT_HEAD = $7EE1;
  { zone 1: nonzero for a duel against the party's mirror images; afterward dying and unconscious members recover }
  MIRROR_DUEL = $7EE6;
  { zone 1: set to 1 when the party attacks an ally }
  ATTACKED_ALLIES = $7F33;
  { zone 1: the number of characters in the party }
  PARTY_SIZE = $7F3E;
  { zone 1: added to the party's movement in combat }
  PARTY_MOVE_MODIFIER = $7F72;

implementation

end.
