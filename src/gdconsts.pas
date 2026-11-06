{ Initialized data: every typed constant in the data segment, grouped by the subsystem that owns them and kept in
  address order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Keys, C_Effect;

{ Copy protection: the verdict. }
const
  { CopyProt.CopyProtection's verdict: True when the player typed the journal word. CopyProt writes it; nothing reads
    it. }
  hasPassedCopyProtection: Boolean = False;

{ Copy protection: the journal word lookup. }
const
  { the first prompt line; CopyProt prints each with its challenge number appended }
  wordPrompt: String[17] = ' what is word #';
  { the second prompt line }
  linePrompt: String[21] = ' on line #';
  { the third prompt line }
  pagePrompt: String[17] = ' from page #';
  { The 30 journal answer words, stored down the columns: row r holds letter r of every word, word n in column n, and a
    space ends a word (CopyProt's DecodeWord). }
  journalAnswerGrid: array[1..9] of String[30] = (
    'SCAYACGAUBCTITSACHAMITCTWHBRSH',
    'AIRO LRRNOHRNHOROENANHRHIUYECA',
    'VTEU EEMDTAACEMEM YG EOECG ARS',
    'AYA  RAOEHRIR E B  I  SIKE DOT',
    'G    ITRA ANE   A  C  SRE   LE',
    'E    CE D CIA   T       D   L ',
    '     SR   TNS                ',
    '          EGE',
    '          R  ');

{ Copy protection's challenges, the temple, post-combat cleanup, the GBVM class map, combat AI and placement, turning
  undead and the movement menus. }
const
  { The journal lookups CopyProt draws from: challenge n asks for grid word n, which stands at this page, line and word
    of the journal. }
  journalChallenges: array[1..30] of Types.TJournalChallenge = (
    (pageNum: 2; lineNum: 2; wordNum: 3), (pageNum: 3; lineNum: 6; wordNum: 5),
    (pageNum: 3; lineNum: 5; wordNum: 5), (pageNum: 4; lineNum: 2; wordNum: 1),
    (pageNum: 4; lineNum: 6; wordNum: 2), (pageNum: 5; lineNum: 2; wordNum: 3),
    (pageNum: 5; lineNum: 4; wordNum: 6), (pageNum: 6; lineNum: 1; wordNum: 6),
    (pageNum: 6; lineNum: 3; wordNum: 5), (pageNum: 7; lineNum: 5; wordNum: 1),
    (pageNum: 7; lineNum: 6; wordNum: 5), (pageNum: 8; lineNum: 2; wordNum: 7),
    (pageNum: 8; lineNum: 4; wordNum: 1), (pageNum: 9; lineNum: 4; wordNum: 1),
    (pageNum: 9; lineNum: 5; wordNum: 2), (pageNum: 10; lineNum: 2; wordNum: 2),
    (pageNum: 10; lineNum: 5; wordNum: 2), (pageNum: 11; lineNum: 1; wordNum: 4),
    (pageNum: 11; lineNum: 4; wordNum: 1), (pageNum: 12; lineNum: 2; wordNum: 1),
    (pageNum: 12; lineNum: 8; wordNum: 2), (pageNum: 14; lineNum: 3; wordNum: 1),
    (pageNum: 14; lineNum: 7; wordNum: 3), (pageNum: 15; lineNum: 3; wordNum: 2),
    (pageNum: 15; lineNum: 5; wordNum: 3), (pageNum: 16; lineNum: 1; wordNum: 4),
    (pageNum: 16; lineNum: 3; wordNum: 3), (pageNum: 18; lineNum: 1; wordNum: 1),
    (pageNum: 18; lineNum: 3; wordNum: 4), (pageNum: 19; lineNum: 6; wordNum: 3));
  { Temple: the effect ids Cure Disease and Heal remove }
  cureDiseaseEffects: array[1..6] of Byte = (
    C_Effect.HELPLESS, C_Effect.DISEASED, C_Effect.DISEASE_STRENGTH, C_Effect.DISEASE_HIT_POINTS, 50, 57);
  { the temple's healing menu }
  templeSpells: array[1..11] of String[40] = (
    'Cure Blindness', 'Cure Disease', 'Cure Light Wounds', 'Cure Serious Wounds',
    'Cure Critical Wounds', 'Heal', 'Neutralize Poison', 'Raise Dead', 'Remove Curse',
    'Stone to Flesh', 'Exit');
  { The effect ids PostCbt strips from each party member after a fight. It reads [1..20]; element 0 is never read. }
  clearEffects: array[0..20] of Byte = (
    0, C_Effect.SNAKES, C_Effect.CHARM, C_Effect.SUFFOCATING, 21, C_Effect.SPIRITUAL_HAMMER,
    C_Effect.CLUMSY, C_Effect.CONFUSED, 40, 51, C_Effect.HELD, C_Effect.SLEEP, C_Effect.IMMOBILE,
    91, C_Effect.ENTANGLED, 137, C_Effect.SWALLOWING, C_Effect.AFRAID, C_Effect.HUGGING,
    C_Effect.HELPLESS, C_Effect.DRAINING_BLOOD);
  { The class index whose levels EclMenu.SpecialReadZ1 reports for each GBVM zone-1 class-level cell. }
  gbClassMap: array[$C9..$D0] of Byte = (5, 0, 6, 2, 7, 1, 3, 4);
  { The direction offsets, in eighths of a turn with 8 straight ahead, that each combat AI stance tries in order
    (CombatAi). }
  aiDirOffsets: array[1..6, 1..5] of Byte = (
    (8, 7, 6, 1, 2), (8, 1, 2, 7, 6), (7, 1, 8, 6, 2),
    (1, 7, 8, 2, 6), (8, 7, 6, 5, 4), (8, 1, 2, 3, 4));
  { Combat placement (CombatSt), by team direction and ring: the ring's direction }
  ringDirTbl: array[0..3, 0..3] of Byte = (
    (8, 4, 6, 2), (8, 6, 4, 0), (8, 0, 6, 2), (8, 2, 0, 4));
  { by team direction and ring: the ring's start quadrant }
  ringStart: array[0..3, 0..3] of Byte = (
    (0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6, 4, 0));
  { each quadrant's direction }
  quadDir: array[0..3] of Byte = (7, 2, 3, 6);
  { the quadrant start columns, for the first ring and the outer rings }
  startQX: array[Boolean, 0..3] of ShortInt = ((5, 4, 5, 6), (3, 8, 7, 2));
  { the quadrant start rows, for the first ring and the outer rings }
  startQY: array[Boolean, 0..3] of ShortInt = ((3, 2, 2, 3), (0, 2, 5, 3));
  { each placement direction's valid columns per row }
  rowBand: array[0..4, 0..5] of Types.TBandRec = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)));
  { the column steps to the four orthogonal neighbors CombatSt spreads a terrain feature to }
  featDX: array[1..4] of ShortInt = (0, 1, 0, -1);
  { and the row steps }
  featDY: array[1..4] of ShortInt = (-1, 0, 1, 0);
  { Feature-class bits for each wilderness terrain char (CombatSt.TerrainClassOf). }
  terrainClass: array[0..31] of Byte = (
    $00, $18, $11, $15, $01, $01, $60, $14, $08, $01, $00, $21, $71, $09, $06, $04,
    $01, $09, $09, $08, $59, $00, $11, $11, $00, $00, $01, $11, $00, $00, $20, $80);
  { Turning undead (CbtActs.CombatTurnUndead), by undead level and cleric level bucket. A d20 roll of at least the
    value's magnitude succeeds: a positive value turns the undead, zero or negative destroys it, and 99 is out of
    reach. }
  turnTable: array[1..10, 1..10] of ShortInt = (
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
  { The 3D movement menus (Explore.MapMainMenu): [1] and [2] with and without Area, [3] the Move prompt's, and [4] and
    [5] the first two with the developer menu's G. }
  movementMenus: array[1..5] of String[40] = (
    'Move Area Cast View Encamp Search Look',
    'Move Cast View Encamp Search Look',
    'Exit',
    'Move Area Cast View Encamp Srch Look G',
    'Move Cast View Encamp Search Look G');

{ Developer menu: the item editor's cursor columns. }
const
  { the text column of the '>' cursor on each of the item editor's 15 fields }
  itemFieldX: array[0..14] of Byte = (1, 2, 3, 4, 5, 1, 1, 20, 1, 20, 1, 20, 1, 2, 3);

{ Developer menu: the item editor's cursor rows. }
const
  { the text row of the '>' cursor on each field }
  itemFieldY: array[0..14] of Byte = (17, 17, 17, 17, 17, 18, 19, 19, 20, 20, 21, 21, 22, 22, 22);

{ Developer menu's item names and wealth editor, and the map editor's start. }
const
  { The short name DevMenu's item editor shows for each item type, the base-item index; unnamed types carry their own
    number. }
  itemTypeNames: array[1..128] of String[10] = (
    'battleaxe', 'handaxe', 'Bardiche', 'BecDeCor', 'BillGuisa', 'BoStick', 'club', 'dagger',
    'dart', 'Fauchard', 'FauchardF', 'Flail', 'militaryf', 'glaiveguii', 'GlaiveGui',
    'Guisarme', 'Guisarmev', 'Halberd', 'LucernHam', 'hammer', 'javelin', 'JoStick', 'Mace',
    'MornStar', 'Partisan', 'Pick', 'AwlPike', 'quarrel', 'Ranseur', 'Scimitar', 'spear',
    'Spetum', 'QtrStaff', 'bstsword', 'broadsword', 'lngsword', 'shtsword', '2hdsword',
    'Trident', 'Voulge', 'CompLBow', 'CompSBow', 'LongBow', 'ShortBow', 'FineBow', 'LightXbow',
    'sling', 'StfSling1', 'Arrow1', 'LthrArmr', 'PaddeArmr', 'studdarmr', 'ringmail',
    'scalmail', 'chanmail', 'SplntMail', 'BndArmor', 'platmail', 'shield', 'ProtScrll',
    'muscroll', 'clerscrll', 'guantlet', 'Hat', 'Belt', 'Robe', 'cloak', 'Boots', 'Ring',
    '0hands', '1hands', '2hands', 'arrow', '74', '75', '76', 'bracers', 'muwand', 'otherwand',
    '80', '81', '82', '83', 'potgtstr', 'holywater', 'flask', 'vhboulder', 'ltboulder',
    'HyBoulder', '90', '91', 'cloakdisp', 'ringprot', 'DrowMace', 'ElvnChain', 'DrowChain',
    'drawlsword', 'manttail', 'RingWizrd', 'dartshnes', 'slnstaff', 'Hoopak', 'Sol Plate',
    'Dragnlnce', 'Flail', 'Halberd', '107', '108', '109', '110', '111', '112', '113', '114',
    '115', '116', '117', '118', '119', '120', '121', '122', '123', '124', '125', '126', '127',
    '128');
  { DevMenu's wealth editor: the '>' cursor's column on each of its 12 fields, the seven combat stats, experience,
    current and maximum HP, stat code and ring }
  wealthFieldX: array[0..11] of Byte = (1, 20, 1, 20, 1, 20, 1, 1, 1, 20, 20, 20);
  { and its row on each field }
  wealthFieldY: array[0..11] of Byte = (17, 17, 18, 18, 19, 19, 20, 21, 22, 22, 20, 21);
  { GeoEdit: GeoEditor sets it on its first entry }
  isGeoEditorInitialized: Boolean = False;

{ Map editor: saved maps and the options menu. }
const
  { the word a saved map starts with, before the map block }
  geoFileHeader: Word = $0400;
  { the file a map is saved to; the map number goes in its last two characters }
  geoSaveName: String[5] = 'GEO00';
  { the file a map is loaded from, numbered the same way }
  geoLoadName: String[5] = 'GEO00';
  { GeoEdit's map options menu }
  mapOptionsMenu: String[40] = 'Map 1 2 3 Dir Walls Lo Sa Out Ind Ex';

{ Map editor: the main menu. }
const
  { GeoEdit's main menu }
  geoEditorMenu: String[40] = 'Wall Spc Blk Loc Dir Clr Files Mov Ext';

{ Map editor's barrier names and the camp menus. }
const
  { What GeoEditor shows after 'block=', by View3D.GetBarrierType's 0..3. }
  barrierNames: array[0..3] of String[20] = ('Blocked', 'Clear', 'Locked Door', 'Magic Lock');
  { Camp.CampMainMenu's menu }
  campMenu: String[40] = 'Save View Magic Rest Alter Fix Exit';
  { CampMagicMenu's menu }
  magicMenu: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { CampAlterMenu's menu }
  alterMenu: String[40] = 'Order Drop Speed Icon Level Exit';

{ Camp: the order and difficulty menus. }
const
  { the party-order menus, by selection state }
  orderMenus: array[0..1] of String[40] = ('Select Exit', 'Place Exit');
  { the difficulty menu of the alter menu's Level item }
  difficultyMenu: String[40] = 'Novice Squire Veteran Adept Champion';

{ Save files: names and name offsets. }
const
  { SaveLoad's character-file scan: the spaces that pad a name to 15 characters }
  nameBlanks: String[15] = '               ';
  { where the name sits in the file, by save mode }
  saveNameOffsets: array[0..2] of Byte = (0, 0, 4);

{ Save files: sizes and imports, and the character generator's menus. }
const
  { where the second name sits in the file, by save mode }
  saveName2Offsets: array[0..2] of Word = (247, 132, 19);
  { the file size, by save mode }
  saveFileSizes: array[0..2] of Word = (SizeOf(Types.TWork), SizeOf(Types.TCharRecord), SizeOf(Types.THillsfarRec));
  { CHEAD/CBODY file suffix by icon size }
  iconHeightSuffix: array[1..2] of Char = ('S', 'T');
  { The class id SaveLoad gives an imported character, by its class nibble. }
  importClassIds: array[0..15] of Byte = (17, 6, 2, 14, 5, 16, 13, 15, 0, 12, 8, 17, 11, 17, 9, 17);
  { CharGen.MainMenu's commands and whether each is offered; MainMenu rewrites the flags from the roster and party
    state. }
  menuItems: array[0..13] of Types.TMenuItem = (
    (name: 'Create New Character'; enabled: 1), (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0), (name: 'Icon Select'; enabled: 0),
    (name: 'Train Character'; enabled: 0), (name: 'Human Change Classes'; enabled: 0),
    (name: 'View Character'; enabled: 0), (name: 'Add Character to Party'; enabled: 1),
    (name: 'Remove Character from Party'; enabled: 0), (name: 'Load Saved Game'; enabled: 1),
    (name: 'Save Current Game'; enabled: 0), (name: 'Begin Adventuring'; enabled: 0),
    (name: 'initialize JoyStick/Mouse'; enabled: 1), (name: 'Exit to DOS'; enabled: 1));
  { CharGen's icon editor menus by editor state; CharGen puts Hair or Face over xxxx and Small or Large before ' Keep
    Exit'. }
  iconMenus: array[1..5] of String[40] = (
    'Parts 1st-color 2nd-color Size Exit', 'Head Weapon Exit',
    'Weapon Body xxxx Shield Arm Leg Exit', ' Keep Exit', 'Next Prev Keep Exit');

{ Character generator's hit dice, the disease cures and memorization. }
const
  { CharGen: each class's starting hit dice count }
  hpDice: array[0..7] of Byte = (1, 1, 1, 1, 2, 1, 1, 2);
  { and their sides }
  hpSides: array[0..7] of Byte = (8, 8, 10, 10, 8, 4, 6, 4);
  { The disease effect ids ViewChar's Cure action looks for and removes. }
  diseaseEffects: array[1..6] of Byte = (31, 34, 43, 44, 50, 57);
  { Camp sets it in its main and memorize menus and clears it for Fix's rest and on leaving camp; GameTime completes a
    memorization only while it is set }
  isMemorizeActive: Boolean = False;

{ The rest clock. }
const
  { GameTime copies CheckRestingHeal's showTime into it and, while it is set, redraws the rest clock before a
    memorization notice }
  isRestTimeShown: Boolean = False;

{ Money, random magic items and the spell-list headings. }
const
  { Money.ConvertMoney: how many coins of each type make one of the next; it reads [0..3]. }
  exchangeValue: array[0..4] of Word = (10, 10, 2, 5, 50);
  { unused }
  spareBeforeRandomItems: Word = 8;
  { The magic items Money.GenerateRandomItem makes. Money reads them as one word array, template n from word 8n-7. }
  randomItemTemplates: array[1..7] of Types.TRandomItemTemplate = (
    (nameIds: (185, 187, 64); weight: 1; value: 800; properties: (3, 99, 0)),
    (nameIds: (239, 167, 64); weight: 1; value: 1100; properties: (1, 59, 0)),
    (nameIds: (185, 167, 64); weight: 1; value: 400; properties: (1, 3, 0)),
    (nameIds: (173, 167, 64); weight: 1; value: 450; properties: (1, 48, 0)),
    (nameIds: (206, 167, 69); weight: 1; value: 11000; properties: (30, 15, 0)),
    (nameIds: (226, 167, 100); weight: 10; value: 15000; properties: (0, 38, 131)),
    (nameIds: (157, 167, 21); weight: 20; value: 3000; properties: (1, 51, 0)));
  { Magic's spell-list headings: the level }
  spellLevelNames: array[1..9] of String[40] = (
    '1st Level', '2nd Level', '3rd Level', '4th Level', '5th Level', '6th Level', '7th Level',
    '8th Level', '9th Level');

{ Spell lists, multi-ray spells and the effects cleared at 0 HP. }
const
  { the casting class before 'spells' in Magic's spell-list headings; the fourth is empty }
  spellClassNames: array[0..3] of String[11] = ('Clerical ', 'Druidical ', 'Magic-User ', '');
  { Magic: the first side ray's column offset from a multi-ray spell's target cell, by the center ray's direction }
  sideRayDX1: array[0..7] of ShortInt = (-1, 0, 0, 1, 1, 0, 0, -1);
  { the first side ray's row offset }
  sideRayDY1: array[0..7] of ShortInt = (0, -1, -1, 0, 0, 1, 1, 0);
  { the second side ray's column offset }
  sideRayDX2: array[0..7] of ShortInt = (1, 1, 0, 0, -1, -1, 0, 0);
  { the second side ray's row offset }
  sideRayDY2: array[0..7] of ShortInt = (0, 0, 1, 1, 0, 0, -1, -1);
  { The effect ids FxEngine removes from a combatant at 0 HP (RemoveEffectsHp0). }
  hpZeroEffects: array[1..21] of Byte = (
    7, C_Effect.CHARM, C_Effect.SUFFOCATING, 21, C_Effect.SPIRITUAL_HAMMER, C_Effect.STINKING_COUGH,
    C_Effect.HELPLESS, C_Effect.ANIMATE_DEAD, 51, C_Effect.HELD, C_Effect.SLEEP, C_Effect.IMMOBILE,
    59, 95, 98, C_Effect.ENTANGLED, 137, C_Effect.SWALLOWING, C_Effect.HUGGING, C_Effect.DRAINING_BLOOD,
    C_Effect.CONSTRICTING);

{ The effects removed with the AI. }
const
  { the effect ids FxEngine.RemoveAiEffects removes }
  aiEffects: array[1..5] of Byte = (C_Effect.SUFFOCATING, C_Effect.IMMOBILE, C_Effect.SWALLOWING,
    C_Effect.HUGGING, C_Effect.DRAINING_BLOOD);

{ Character display: effect names. }
const
  { CharHlp: the effect names it shows in parentheses for a character's first named effect }
  effectNames: array[1..31] of String[14] = (
    'snake charmed', 'held', 'asleep', 'nauseous', 'draining blood', 'afraid', 'entangled',
    'berserk', 'hugging', 'swallowing', 'immobile', 'charmed', 'blinded', 'cursed', 'snaked',
    'silenced', 'clumsy', 'blinded', 'slow', 'blessed', 'fighting on', 'invisible', 'duplicated',
    'blinking', 'weakened', 'hastened', 'prot. vs. good', 'prot. vs. evil', 'resist cold',
    'enlarged', 'displaced');

{ Character display: the effects named. }
const
  { the effect id each effectNames entry names }
  effectNameIds: array[1..31] of Byte = (
    51, C_Effect.HELD, C_Effect.SLEEP, C_Effect.HELPLESS, C_Effect.DRAINING_BLOOD, C_Effect.AFRAID,
    C_Effect.ENTANGLED, 137, C_Effect.HUGGING, C_Effect.SWALLOWING, C_Effect.IMMOBILE,
    C_Effect.CHARM, C_Effect.BLIND, 2, C_Effect.SNAKES, 21, C_Effect.CLUMSY, C_Effect.CONFUSED,
    C_Effect.SLOWED, 1, 95, C_Effect.INVISIBLE, C_Effect.MIRROR_IMAGE, 37, 29, C_Effect.HASTED, 9,
    C_Effect.PROTECTION_FROM_EVIL, 10, C_Effect.ENLARGE, 89);

{ Level caps, menu keys, view colors, color remaps, the view slots and Border's frame symbols. }
const
  { ClassCal.AtClassLevelCap: the level at which each base class stops advancing. }
  levelCaps: array[0..7] of ShortInt = (6, 6, 8, 8, 7, 6, 8, 8);
  { MenuCore: the extended scan code a combat-arena click answers with, by the direction from the reference cell to the
    clicked cell (DirectionBetween), clockwise from up }
  directionKeys: array[0..7] of Char = (C_Keys.UP, C_Keys.PAGE_UP, C_Keys.RIGHT, C_Keys.PAGE_DOWN,
                                        C_Keys.DOWN, C_Keys.END_KEY, C_Keys.LEFT, C_Keys.HOME);
  { the menu text YesNoMenu and YesNoMenuClear show }
  yesNoText: String[7] = 'Yes No';
  { MapView: the color for each sky and ceiling selector. }
  skyCeilingColors: array[0..15] of Byte = (0, 15, 4, 11, 13, 2, 9, 14, 0, 15, 4, 11, 13, 2, 9, 14);
  { Portrait's color remap DisplayImageBuf uses while its view is active: the source colors }
  viewPicRemapFrom: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { and their replacements }
  viewPicRemapTo: Types.TColorTab = (12, 12, 12, 12, 4, 5, 6, 7, 12, 12, 10, 12, 12, 12, 14, 12);
  { the color remap for a transparent animation frame: the source colors }
  animRemapFrom: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { and their replacements }
  animRemapTo: Types.TColorTab = (13, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15);
  { View3D: the ten view slots' rectangles over a WALLDEF slice. }
  viewSlotGeom: Types.TViewSlotGeom = (
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
    cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
    xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
    yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { MapTiles' color remap LoadRemappedPic applies to every loaded frame, which swaps Black and DarkGray: the source
    colors }
  iconLoadRemapFrom: Types.TColorTab = (0, 8, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15);
  { and their replacements }
  iconLoadRemapTo: Types.TColorTab = (8, 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15);
  { LoadIconAnim's source colors }
  iconColorIdentity: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { LoadIconAnim's targets for other sprites, each color to itself }
  iconColorKeptTo: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { LoadIconAnim's targets for ICON }
  iconColorPinkToBlack: Types.TColorTab = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15);
  { Border's frame symbols, one per screen column or row, each added to its symbol base: the main frame's top edge }
  borderTop: array[0..39] of Byte = (
    0, 13, 13, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 8, 8, 8, 8, 8, 8, 8,
    8, 8, 8, 8, 8, 8, 8, 11, 12, 8, 8, 8, 8, 10, 8, 8, 8, 13, 13, 1);
  { the main frame's bottom edge }
  borderBottom: array[0..39] of Byte = (
    1, 13, 13, 8, 10, 8, 8, 8, 9, 8, 8, 9, 8, 8, 8, 8, 8, 11, 8, 9,
    12, 8, 8, 12, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 10, 8, 13, 13, 0);
  { the horizontal rule }
  borderRule: array[0..39] of Byte = (
    0, 13, 13, 8, 8, 11, 8, 8, 8, 8, 8, 8, 8, 8, 10, 9, 8, 8, 9, 8,
    9, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 10, 8, 8, 8, 8, 8, 13, 13, 1);
  { the main frame's left edge }
  borderLeft: array[0..23] of Byte = (
    0, 7, 7, 5, 2, 6, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 7, 7, 1);
  { DrawViewFrame's divider column, one symbol per row }
  borderVertical: array[0..16] of Byte = (0, 7, 7, 2, 2, 5, 2, 2, 4, 2, 2, 2, 3, 2, 7, 7, 1);

{ Frame symbols: the right edge and the combat frame's left column. }
const
  { the main frame's right edge }
  borderRight: array[0..23] of Byte = (
    1, 7, 7, 2, 4, 2, 2, 4, 2, 2, 2, 2, 6, 5, 2, 2, 2, 2, 2, 2, 2, 7, 7, 0);
  { DrawCombatFrame's left column }
  borderCombatLeft: array[0..22] of Byte = (
    0, 7, 7, 2, 2, 2, 2, 6, 2, 2, 2, 2, 2, 2, 4, 2, 2, 6, 2, 2, 7, 7, 1);

{ Frame symbols: the combat frame's middle column. }
const
  { DrawCombatFrame's middle column }
  borderCombatMid: array[0..22] of Byte = (
    0, 7, 7, 2, 5, 6, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 7, 7, 1);

{ Frame symbols: the combat frame's right column. }
const
  { DrawCombatFrame's right column }
  borderCombatRight: array[0..22] of Byte = (
    0, 7, 7, 5, 2, 2, 2, 5, 2, 2, 2, 2, 4, 2, 2, 6, 2, 2, 3, 2, 7, 7, 1);

{ Frame symbols: the view's inner box, left edge. }
const
  { DrawViewFrame's inner box left edge, by screen row }
  borderInnerLeft: array[2..14] of Byte = (14, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 15);

{ Frame symbols: the inner box's right edge. }
const
  { DrawViewFrame's inner box right edge, by screen row }
  borderInnerRight: array[2..14] of Byte = (16, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 17);

{ Frame symbols: the inner box's top edge. }
const
  { DrawViewFrame's inner box top edge, by screen column }
  borderInnerTop: array[2..14] of Byte = (14, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 16);

{ Frame symbols: the inner box's bottom edge. }
const
  { DrawViewFrame's inner box bottom edge, by screen column }
  borderInnerBottom: array[2..14] of Byte = (15, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 17);

{ Frame symbols: the character sheet's divider. }
const
  { DrawSheetFrame's divider column, by screen row }
  borderMenuVertical: array[8..20] of Byte = (0, 2, 2, 2, 4, 2, 2, 2, 1, 2, 7, 7, 1);

{ Frame symbols: the ending frame's left edge. }
const
  { DrawEndingFrame's left edge }
  borderCustomLeft: array[0..24] of Byte = (
    0, 7, 7, 5, 2, 6, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 7, 7, 7, 1);

{ Frame symbols: the ending frame's right edge. }
const
  { DrawEndingFrame's right edge }
  borderCustomRight: array[0..24] of Byte = (
    1, 7, 7, 2, 4, 2, 2, 4, 2, 2, 2, 2, 6, 5, 2, 2, 2, 2, 2, 2, 2, 7, 7, 7, 0);

{ Picture color tables, file names and the keyboard queue. }
const
  { Blit: the packed CGA fill byte for each CGA color }
  cgaColorFill: array[0..3] of Byte = ($00, $55, $AA, $FF);
  { the packed Tandy fill byte for each color }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { the CGA color of each color as packed nibbles, which FillPicRect fills through }
  compositeMap: Types.TPalette24 = (
    $00, $11, $22, $12, $01, $21, $30, $33, $00, $11, $22, $12, $01, $21, $30, $33,
    $00, $00, $00, $00, $00, $00, $00, $00);
  { the color RgbToColor16 gives a gray, by its intensity quarter }
  paletteLevelMap: array[0..3] of Byte = (0, 8, 7, 15);
  { a picture's default map from its 32 colors to CGA colors }
  cgaMap: array[0..31] of Byte = (
    0, 0, 1, 1, 2, 2, 1, 2, 0, 1, 2, 1, 3, 0, 3, 3,
    0, 0, 1, 1, 2, 2, 1, 2, 0, 1, 2, 1, 3, 0, 3, 3);
  { and to EGA or Tandy colors }
  egaMap: array[0..31] of Byte = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { The characters DaxIo.SanitizeFileName strips from a file name. }
  invalidFileChars: array[1..10] of Char = (' ', '.', '*', ',', '?', '/', '\', ':', ';', '|');
  { GameIo: how many of its two buffered key bytes are waiting }
  queuedKeyCount: Byte = 0;

{ Joystick keys, sound rates and the heap. }
const
  { the extended scan code GameIo returns for each joystick direction zone, clockwise from up }
  joystickDirectionKeys: array[0..7] of Char = (C_Keys.UP, C_Keys.PAGE_UP, C_Keys.RIGHT, C_Keys.PAGE_DOWN,
                                                C_Keys.DOWN, C_Keys.END_KEY, C_Keys.LEFT, C_Keys.HOME);
  { Each sound id's playback rate in Hz, which SoundDrv.SoundCommand passes the driver as driverCommand.sampleRate. It
    plays ids 2..12 but plays 3 and 6 as 9, so entries 1, 3 and 6 are never read. }
  soundSampleRates: array[1..12] of Word = (
    32, 4000, 0, 7075, 9000, 0, 8200, 8000, 8101, 8107, 7546, 7075);
  { GameBoot sets it when it lowers HeapEnd by 16 KB for a Tandy; AdjustHeap gives the memory back and clears it. }
  isHeapEndLowered: Boolean = False;

{ Coin values and the class, race and alignment names. }
const
  { each coin's worth in copper, copper through platinum; Money and ViewChar divide by [3] to count in gold }
  coinValues: array[0..4] of LongInt = (1, 10, 100, 200, 1000);
  { the class names a character sheet shows; class 17 is the one SaveLoad gives an imported character whose class it
    cannot map }
  classNames: array[0..17] of String[26] = (
    'Cleric', 'Druid', 'Fighter', 'Paladin', 'Ranger', 'Magic-User', 'Thief', 'Monk',
    'Cleric/Fighter', 'Cleric/Fighter/Magic-User', 'Cleric/Ranger', 'Cleric/Magic-User',
    'Cleric/Thief', 'Fighter/Magic-User', 'Fighter/Thief', 'Fighter/Magic-User/Thief',
    'Magic-User/Thief', 'OK buddy, who are you?');
  { the race names a character sheet shows }
  raceNames: array[0..7] of String[9] = (
    'Monster', 'Dwarf', 'Elf', 'Gnome', 'Half-Elf', 'Halfling', 'Half-Orc', 'Human');
  { the alignment names }
  alignNames: array[0..8] of String[16] = (
    'Lawful Good', 'Lawful Neutral', 'Lawful Evil', 'Neutral Good', 'True Neutral',
    'Neutral Evil', 'Chaotic Good', 'Chaotic Neutral', 'Chaotic Evil');

{ Gender and money names. }
const
  { the gender names }
  genderNames: array[0..1] of String[6] = ('Male', 'Female');
  { the coin type names }
  moneyNames: array[0..6] of String[10] = (
    'Copper', 'Silver', 'Electrum', 'Gold', 'Platinum', 'Gems', 'Jewelry');

{ Status names. }
const
  { the status names a character sheet shows }
  statusNames: array[0..8] of String[12] = (
    'Okay', 'Animated', 'tempgone', 'Running', 'Unconscious', 'Dying', 'Dead', 'Stoned', 'Gone');

{ Item name components. }
const
  { The item-name components: CharHlp's item-name builder appends the entry each of an item's nameIds selects, and
    ModeInit copies entry 252 at start-up. }
  itemNameComponents: array[1..255] of String[20] = (
    'Battle Axe', 'Hand Axe', 'Bardiche', 'Bec De Corbin', 'Bill-Guisarme', 'Bo Stick', 'Club',
    'Dagger', 'Dart', 'Fauchard', 'Fauchard-Fork', 'Flail', 'Military Fork', 'Glaive',
    'Glaive-Guisarme', 'Guisarme', 'Guisarme-Voulge', 'Halberd', 'Lucern Hammer', 'Hammer',
    'Javelin', 'Jo Stick', 'Mace', 'Morning Star', 'Partisan', 'Military Pick', 'Awl Pike',
    'Quarrel', 'Ranseur', 'Scimitar', 'Spear', 'Spetum', 'Quarter Staff', 'Bastard Sword',
    'Broad Sword', 'Long Sword', 'Short Sword', 'Two-Handed Sword', 'Trident', 'Voulge',
    'Composite Long Bow', 'Composite Short Bow', 'Long Bow', 'Short Bow', 'Heavy Crossbow',
    'Light Crossbow', 'Sling', 'Mail', 'Armor', 'Leather', 'Padded', 'Studded', 'Ring', 'Scale',
    'Chain', 'Splint', 'Banded', 'Plate', 'Shield', 'Woods', 'Arrow', 'Banite', 'Robes', 'Potion',
    'Scroll', 'Ring', 'Rod', 'Stave', 'Wand', 'Jug', 'Amulet', 'Dragon Breath', 'Bag',
    'Defoliation', 'Ice Storm', 'Book', 'Boots', 'Hornets Nest', 'Bracers', 'Piercing', 'Brooch',
    'Elfin Chain', 'Wizardry', 'ac10', 'Dexterity', 'Fumbling', 'Chime', 'Cloak', 'Crystal', 'Cube',
    'Cubic', 'Dwarven', 'Decanter', 'Gloves', 'Drums', 'Dust', 'Thievery', 'Hat', 'Flask',
    'Gauntlets', 'Gem', 'Girdle', 'Helm', 'Horn', 'Stupidity', 'Incense', 'Stone', 'Ioun Stone',
    'Javelin', 'Jewel', 'Ointment', 'Scrawled Note', 'Scarlet And', 'Manual', 'Incandescent',
    'Deep Red', 'Pink', 'Mirror', 'Necklace', 'And Green', 'Blue', 'Pearl', 'Powerlessness',
    'Vermin', 'Pipes', 'Hole', 'Dragon Slayer', 'Robe', 'Rope', 'Frost Brand', 'Berserker',
    'Scarab', 'Spade', 'Sphere', 'Blessed', 'Talisman', 'of the Glacier', 'Trident', 'stunning',
    'Well', 'Wings', 'Vial', 'Lantern', 'of Icewind Dale', 'Flask of Oil', '10 ft. Pole',
    '50 ft. Rope', 'Iron', 'Thf Prickly Tools', 'Iron Rations', 'Standard Rations', 'Holy Symbol',
    'Holy Water vial', 'Unholy Water vial', 'Barding', 'Dragon', 'Lightning', 'Saddle', 'Staff',
    'Drow', 'Wagon', '+1', '+2', '+3', '+4', '+5', 'of', 'Vulnerability', 'Cloak', 'Displacement',
    'Torches', 'Oil', 'Speed', 'Tapestry', 'Spine', 'Copper', 'Silver', 'Electrum', 'Gold',
    'Platinum', 'Ointment', 'Button', 'Sheet', 'Strength', 'Healing', 'Holding', 'Extra',
    'Gaseous Form', 'Slipperiness', 'Jewelled', 'Flying', 'Treasure Finding', 'Fear',
    'Disappearance', 'Statuette', 'Fungus', 'Chain', 'Pendant', 'Broach', 'Of Striking', '-1', '-2',
    '-3', 'Lightning Bolt', 'Fire Resistance', 'Magic Missiles', 'Save', 'Clrc Scroll', 'MU Scroll',
    'With 1 Spell', 'With 2 Spells', 'With 3 Spells', 'Prot. Scroll', 'Jewelry', 'Fine', 'Huge',
    'Bone', 'Brass', 'Key', 'AC 2', 'AC 6', 'AC 4', 'AC 3', 'Of Prot.', 'Paralyzation', 'Map',
    'Invisibility', 'Missiles', 'Elven', 'Rotting', 'Covered', 'Efreeti', 'Bottle',
    'Missile Attractor', 'Letter', 'Secr Door & Trap Det', 'with Squid emblem', 'Feather Falling',
    'Giant Strength', 'Restoring Level(s)', 'Flame Tongue', 'Fireballs', 'Spiritual', 'Boulder',
    'Diamond', 'Emerald', 'Opal', 'Saphire', 'Sword', 'of stonecutting', 'Meteorite Ore', 'Wooden',
    '+2 vs Undead', 'Pass', 'Cursed');

{ Debug switch. }
const
  { GameIo's Ctrl-D toggles debugOn, opening its debug log as it sets it and closing the log as it clears it. While it
    is set, GameIo's Ctrl-Z walks creatureList through DumpWhoList, whose body is empty; EclVm traces each ECL opcode to
    the log and CharHlp marks the area status line with '*'. GameInit clears it. }
  debugOn: Byte = 0;

{ Compass names and direction lookup. }
const
  { The eight facing names, clockwise from north; CharHlp shows the party's. }
  dirNames: array[0..7] of String[2] = ('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
  { Pathing's step direction for a one-cell move, by [dy + 1, dx + 1]; the center, 8, is no move. }
  dirByDelta: array[0..2, 0..2] of Byte = ((7, 0, 1), (6, 8, 2), (5, 4, 3));

{ Video tables of TextRend, Border, DaxIo, Blit and Raster; disk prompts; symbol-set ranges; the column steps. }
const
  { unused }
  egaPlaneMask: array[0..3] of Byte = ($08, $04, $02, $01);
  { a CGA color's fill word }
  cgaColorPat: array[0..3] of Word = ($0000, $5555, $AAAA, $FFFF);
  { a color's 2-bit CGA pixel }
  attrTable: array[0..15] of Byte = (0, 0, 0, 1, 2, 2, 2, 3, 0, 1, 1, 1, 2, 2, 3, 3);
  { a pixel pair, high pair first }
  cgaPositionBitmask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);
  { each EGA plane's bit }
  egaPlaneBit: array[0..3] of Byte = ($01, $02, $04, $08);
  { a CGA color's 2-bit pixel at each of the four positions in a byte }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00), ($40, $10, $04, $01), ($80, $20, $08, $02), ($C0, $30, $0C, $03));
  { The disk prompts DaxIo, GameInit and SaveLoad index from 0. }
  insertDiskDrive: array[0..6] of String[29] = (
    'Insert disk 2 in drive ', 'Insert disk 1 in drive ', 'Insert disk 3 in drive ',
    'Insert disk 4 in drive ', 'Insert disk 5 in drive ', 'Insert disk 6 in drive ',
    'Insert disk 7 in drive ');
  { View3D: the first symbol of each wall-symbol set }
  symSetFirst: array[0..4] of Word = (1, 46, 116, 186, 256);
  { and its last }
  symSetLast: array[0..4] of Word = (45, 115, 185, 255, 295);
  { The column step for each direction, clockwise from north, 8 being no step. }
  dirDX: array[0..8] of ShortInt = (0, 1, 1, 1, 0, -1, -1, -1, 0);

{ Direction row steps. }
const
  { the row step for each direction, clockwise from north, 8 being no step }
  dirDY: array[0..8] of ShortInt = (-1, -1, 0, 1, 1, 1, 0, -1, 0);

{ Combat terrain, icon footprints, helpless effects and the keypad. }
const
  { Each combat terrain id's movement and line-walk rules and its icon. }
  terrainInfo: array[1..65] of Types.TTerrainEntry = (
    (cost: 255; clearance: 1; blocking: 2; tileId: 0), (cost: 255; clearance: 1; blocking: 2; tileId: 1),
    (cost: 255; clearance: 1; blocking: 2; tileId: 2), (cost: 255; clearance: 1; blocking: 2; tileId: 3),
    (cost: 1; clearance: 1; blocking: 0; tileId: 4), (cost: 255; clearance: 1; blocking: 2; tileId: 5),
    (cost: 255; clearance: 1; blocking: 2; tileId: 6), (cost: 255; clearance: 1; blocking: 2; tileId: 7),
    (cost: 1; clearance: 1; blocking: 0; tileId: 8), (cost: 255; clearance: 1; blocking: 2; tileId: 9),
    (cost: 1; clearance: 1; blocking: 0; tileId: 10), (cost: 255; clearance: 1; blocking: 2; tileId: 11),
    (cost: 1; clearance: 1; blocking: 0; tileId: 12), (cost: 255; clearance: 1; blocking: 2; tileId: 13),
    (cost: 1; clearance: 1; blocking: 0; tileId: 14), (cost: 255; clearance: 1; blocking: 2; tileId: 15),
    (cost: 1; clearance: 1; blocking: 0; tileId: 16), (cost: 255; clearance: 1; blocking: 2; tileId: 17),
    (cost: 255; clearance: 1; blocking: 2; tileId: 18), (cost: 255; clearance: 1; blocking: 2; tileId: 19),
    (cost: 255; clearance: 1; blocking: 2; tileId: 20), (cost: 255; clearance: 1; blocking: 2; tileId: 21),
    (cost: 1; clearance: 1; blocking: 0; tileId: 22), (cost: 1; clearance: 1; blocking: 0; tileId: 23),
    (cost: 255; clearance: 1; blocking: 2; tileId: 24), (cost: 2; clearance: 2; blocking: 0; tileId: 34),
    (cost: 1; clearance: 1; blocking: 0; tileId: 35), (cost: 1; clearance: 1; blocking: 0; tileId: 36),
    (cost: 1; clearance: 1; blocking: 0; tileId: 37), (cost: 1; clearance: 1; blocking: 0; tileId: 38),
    (cost: 1; clearance: 1; blocking: 0; tileId: 39), (cost: 255; clearance: 1; blocking: 2; tileId: 0),
    (cost: 255; clearance: 1; blocking: 2; tileId: 1), (cost: 255; clearance: 1; blocking: 2; tileId: 2),
    (cost: 255; clearance: 1; blocking: 2; tileId: 3), (cost: 255; clearance: 1; blocking: 2; tileId: 4),
    (cost: 1; clearance: 1; blocking: 0; tileId: 5), (cost: 1; clearance: 1; blocking: 0; tileId: 6),
    (cost: 1; clearance: 1; blocking: 0; tileId: 7), (cost: 1; clearance: 1; blocking: 0; tileId: 8),
    (cost: 1; clearance: 1; blocking: 0; tileId: 9), (cost: 255; clearance: 1; blocking: 2; tileId: 10),
    (cost: 255; clearance: 1; blocking: 2; tileId: 11), (cost: 1; clearance: 1; blocking: 0; tileId: 12),
    (cost: 1; clearance: 1; blocking: 0; tileId: 13), (cost: 1; clearance: 1; blocking: 0; tileId: 14),
    (cost: 1; clearance: 1; blocking: 0; tileId: 15), (cost: 2; clearance: 1; blocking: 0; tileId: 16),
    (cost: 2; clearance: 1; blocking: 0; tileId: 17), (cost: 2; clearance: 1; blocking: 0; tileId: 18),
    (cost: 2; clearance: 1; blocking: 0; tileId: 19), (cost: 2; clearance: 1; blocking: 0; tileId: 20),
    (cost: 2; clearance: 1; blocking: 0; tileId: 21), (cost: 1; clearance: 1; blocking: 0; tileId: 22),
    (cost: 1; clearance: 1; blocking: 0; tileId: 23), (cost: 1; clearance: 1; blocking: 0; tileId: 24),
    (cost: 1; clearance: 1; blocking: 0; tileId: 25), (cost: 2; clearance: 1; blocking: 0; tileId: 26),
    (cost: 2; clearance: 1; blocking: 0; tileId: 27), (cost: 4; clearance: 0; blocking: 0; tileId: 28),
    (cost: 4; clearance: 0; blocking: 0; tileId: 29), (cost: 4; clearance: 0; blocking: 0; tileId: 30),
    (cost: 4; clearance: 0; blocking: 0; tileId: 31), (cost: 1; clearance: 1; blocking: 0; tileId: 32),
    (cost: 1; clearance: 1; blocking: 0; tileId: 33));
  { CbtMap: the cell offsets of a combatant's icon cells, by icon size. }
  iconDelta: array[1..4, 0..3] of Types.TIconDelta = (
    ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1), (dx: 1; dy: 1)));
  { The effect ids that leave a combatant helpless: CharHlp tests a character for each and CbtActs compares a spell's
    effect with them. }
  helplessFx: array[1..4] of Byte = (51, 52, 53, 31);
  { MenuCore's scan codes: the keypad key for each digit 1..9 }
  keypadScan: array[0..8] of Byte = ($4F, $50, $51, $4B, $20, $4D, $47, $48, $49);

{ Menu clicks on the 3D view. }
const
  { the arrow key a click on the 3D view answers with, by the clicked text row and column, 3..13 each }
  vectorScan: array[3..13, 3..13] of Byte = (
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $4B, $48, $48, $48, $48, $48, $48, $48, $4D, $4D),
    ($4B, $50, $50, $50, $50, $50, $50, $50, $50, $50, $4D),
    ($50, $50, $50, $50, $50, $50, $50, $50, $50, $50, $50));

{ Cloud shapes. }
const
  { The directions from a 2-by-2 Stinking Cloud's cell to the cells it fills, 8 being the cell itself. }
  cloudCells: array[1..4] of Byte = (8, 2, 3, 4);
  { and from a 3-by-3 Cloudkill's }
  cloudCells9: array[1..9] of Byte = (8, 0, 1, 2, 3, 4, 5, 6, 7);

{ Spells, the clock and the class rules. }
const
  { Each spell id's name. }
  spellNames: array[1..100] of String[40] = (
    'Bless', 'Curse', 'Cure Light Wounds', 'Cause Light Wounds', 'Detect Magic',
    'Protection From Evil', 'Protection from Good', 'Resist Cold', 'Burning Hands', 'Charm Person',
    'Detect Magic', 'Enlarge', 'Reduce', 'Friends', 'Magic Missile', 'Protection From Evil',
    'Protection From Good', 'Read Magic', 'Shield', 'Shocking Grasp', 'Sleep', 'Find Traps',
    'Hold Person', 'Resist Fire', 'Silence, 15'' Radius', 'Slow Poison', 'Snake Charm',
    'Spiritual Hammer', 'Detect Invisibility', 'Invisibility', 'Knock', 'Mirror Image',
    'Ray of Enfeeblement', 'Stinking Cloud', 'Strength', 'Animate Dead', 'Cure Blindness',
    'Cause Blindness', 'Cure Disease', 'Cause Disease', 'Dispel Magic', 'Prayer', 'Remove Curse',
    'Bestow Curse', 'Blink', 'Dispel Magic', 'Fireball', 'Haste', 'Hold Person',
    'Invisibility, 10'' Radius', 'Lightning Bolt', 'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius', 'Protection From Normal Missiles', 'Slow', 'Restoration', '',
    'Cure Serious Wounds', '', '', '', '', '', '', '', 'Cause Serious Wounds', 'Neutralize Poison',
    'Poison', 'Protection Evil, 10'' Radius', 'Sticks to Snakes', 'Cure Critical Wounds',
    'Cause Critical Wounds', 'Dispel Evil', 'Flame Strike', 'Raise Dead', 'Slay Living',
    'Detect Magic', 'Entangle', 'Faerie Fire', 'Invisibility to Animals', 'Charm Monsters',
    'Confusion', 'Dimension Door', 'Fear', 'Fire Shield', 'Fumble', 'Ice Storm',
    'Minor Globe Of Invulnerability', 'Remove Curse', 'Animate Dead', 'Cloud Kill', 'Cone of Cold',
    'Feeblemind', 'Hold Monsters', '', '', '', '', '', 'Bestow Curse');
  { Each spell id's row of the spell table. }
  spellTable: array[1..100] of Types.TSpellTabRec = (
    { 1 Bless }
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; touch: 10; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 1; combatOk: 2; drainLevels: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 2 Curse }
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; touch: 10; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 2; combatOk: 1; drainLevels: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 3 Cure Light Wounds }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 4 Cause Light Wounds }
    (castClass: 0; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 5; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 5 Detect Magic }
    (castClass: 0; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 10; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 6 Protection From Evil }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 8; combatOk: 2; drainLevels: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 7 Protection from Good }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 9; combatOk: 2; drainLevels: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 8 Resist Cold }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 10; combatOk: 2; drainLevels: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 9 Burning Hands }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 10 Charm Person }
    (castClass: 2; level: 1; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 11; combatOk: 1; drainLevels: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 11 Detect Magic }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 12 Enlarge }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 12; combatOk: 2; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 13 Reduce }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 1; saveType: 4; effectId: 13; combatOk: 2; drainLevels: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 14 Friends }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 14; combatOk: 0; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 15 Magic Missile }
    (castClass: 2; level: 1; rangeBase: 6; rangePerLevel: 4; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 16 Protection From Evil }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 8; combatOk: 2; drainLevels: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 17 Protection From Good }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 9; combatOk: 2; drainLevels: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 18 Read Magic }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 16; combatOk: 0; drainLevels: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 19 Shield }
    (castClass: 2; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 5; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 17; combatOk: 2; drainLevels: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 20 Shocking Grasp }
    (castClass: 2; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 21 Sleep }
    (castClass: 2; level: 1; rangeBase: 3; rangePerLevel: 4; durBase: 0; durPerLevel: 5; touch: 9; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 53; combatOk: 1; drainLevels: 1; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 22 Find Traps }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 30; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 19; combatOk: 0; drainLevels: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 23 Hold Person }
    (castClass: 0; level: 2; rangeBase: 6; rangePerLevel: 0; durBase: 4; durPerLevel: 1; touch: 6; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; drainLevels: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 24 Resist Fire }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 20; combatOk: 2; drainLevels: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 25 Silence, 15' Radius }
    (castClass: 0; level: 2; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 31; targeting: 0;
     saveResult: 3; saveType: 4; effectId: 21; combatOk: 1; drainLevels: 5; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 26 Slow Poison }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 22; combatOk: 2; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 27 Snake Charm }
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 240; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 51; combatOk: 1; drainLevels: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 28 Spiritual Hammer }
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 23; combatOk: 2; drainLevels: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 29 Detect Invisibility }
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 5; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 24; combatOk: 2; drainLevels: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 30 Invisibility }
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; drainLevels: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 31 Knock }
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; drainLevels: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 32 Mirror Image }
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 28; combatOk: 2; drainLevels: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 33 Ray of Enfeeblement }
    (castClass: 2; level: 2; rangeBase: 1; rangePerLevel: 1; durBase: 0; durPerLevel: 1; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 29; combatOk: 1; drainLevels: 2; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 34 Stinking Cloud }
    (castClass: 2; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 9; targeting: 0;
     saveResult: 3; saveType: 0; effectId: 30; combatOk: 1; drainLevels: 2; aiPriority: 5; offensive: 1; aiRadius: 1),
    { 35 Strength }
    (castClass: 2; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; touch: 0; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 38; combatOk: 2; drainLevels: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 36 Animate Dead }
    (castClass: 3; level: 7; rangeBase: 4; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 8; targeting: 4;
     saveResult: 1; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 37 Cure Blindness }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 38 Cause Blindness }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 33; combatOk: 1; drainLevels: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 39 Cure Disease }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; drainLevels: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 40 Cause Disease }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 34; combatOk: 1; drainLevels: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 41 Dispel Magic }
    (castClass: 0; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 9; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 4; aiPriority: 3; offensive: 1; aiRadius: 1),
    { 42 Prayer }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 3; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 49; combatOk: 2; drainLevels: 6; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 43 Remove Curse }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 44 Bestow Curse }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 36; combatOk: 1; drainLevels: 6; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 45 Blink }
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 37; combatOk: 2; drainLevels: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 46 Dispel Magic }
    (castClass: 2; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 9; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 3; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 47 Fireball }
    (castClass: 2; level: 3; rangeBase: 10; rangePerLevel: 1; durBase: 0; durPerLevel: 0; touch: 11; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 48 Haste }
    (castClass: 2; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 3; durPerLevel: 1; touch: 10; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; drainLevels: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 49 Hold Person }
    (castClass: 2; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 7; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; drainLevels: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 50 Invisibility, 10' Radius }
    (castClass: 2; level: 3; rangeBase: 1; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 14; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; drainLevels: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 51 Lightning Bolt }
    (castClass: 2; level: 3; rangeBase: 4; rangePerLevel: 1; durBase: 0; durPerLevel: 0; touch: 8; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 52 Protection From Evil, 10' Radius }
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 45; combatOk: 2; drainLevels: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 53 Protection From Good, 10' Radius }
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 46; combatOk: 2; drainLevels: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 54 Protection From Normal Missiles }
    (castClass: 2; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 41; combatOk: 2; drainLevels: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 55 Slow }
    (castClass: 2; level: 3; rangeBase: 9; rangePerLevel: 1; durBase: 3; durPerLevel: 1; touch: 10; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 42; combatOk: 1; drainLevels: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 56 Restoration }
    (castClass: 0; level: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 57 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; drainLevels: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 58 Cure Serious Wounds }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 7; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 59 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 38; combatOk: 2; drainLevels: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 60 }
    (castClass: 3; level: 6; rangeBase: 4; rangePerLevel: 4; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 61 }
    (castClass: 3; level: 6; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 0; effectId: 52; combatOk: 1; drainLevels: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 62 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 39; combatOk: 2; drainLevels: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 63 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 7; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 71; combatOk: 2; drainLevels: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 64 }
    (castClass: 3; level: 6; rangeBase: 7; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 11; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 65 }
    (castClass: 3; level: 6; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 66 Cause Serious Wounds }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 7; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 67 Neutralize Poison }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; drainLevels: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 68 Poison }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 0; effectId: 0; combatOk: 1; drainLevels: 7; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 69 Protection Evil, 10' Radius }
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 45; combatOk: 2; drainLevels: 7; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 70 Sticks to Snakes }
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 2; touch: 4; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 3; combatOk: 1; drainLevels: 7; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 71 Cure Critical Wounds }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 8; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 72 Cause Critical Wounds }
    (castClass: 0; level: 5; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 73 Dispel Evil }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 0; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 145; combatOk: 1; drainLevels: 8; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 74 Flame Strike }
    (castClass: 0; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 75 Raise Dead }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 0; drainLevels: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 76 Slay Living }
    (castClass: 0; level: 5; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 10; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 77 Detect Magic }
    (castClass: 1; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 12; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 5; combatOk: 2; drainLevels: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 78 Entangle }
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 10; durPerLevel: 0; touch: 11; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 136; combatOk: 1; drainLevels: 3; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 79 Faerie Fire }
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 0; durPerLevel: 4; touch: 5; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 7; combatOk: 1; drainLevels: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 80 Invisibility to Animals }
    (castClass: 1; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 10; durPerLevel: 1; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 69; combatOk: 2; drainLevels: 4; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 81 Charm Monsters }
    (castClass: 2; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 5; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 11; combatOk: 1; drainLevels: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 82 Confusion }
    (castClass: 2; level: 4; rangeBase: 12; rangePerLevel: 0; durBase: 2; durPerLevel: 1; touch: 11; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 35; combatOk: 1; drainLevels: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 83 Dimension Door }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 3; durBase: 0; durPerLevel: 0; touch: 8; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 84 Fear }
    (castClass: 2; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 8; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 142; combatOk: 1; drainLevels: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 85 Fire Shield }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 2; durPerLevel: 1; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 4; aiPriority: 8; offensive: 0; aiRadius: 0),
    { 86 Fumble }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 27; combatOk: 1; drainLevels: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 87 Ice Storm }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; touch: 10; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 88 Minor Globe Of Invulnerability }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 63; combatOk: 2; drainLevels: 4; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 89 Remove Curse }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 2;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 4; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 90 Animate Dead }
    (castClass: 3; level: 5; rangeBase: 1; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 240; targeting: 4;
     saveResult: 0; saveType: 4; effectId: 32; combatOk: 2; drainLevels: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 91 Cloud Kill }
    (castClass: 2; level: 5; rangeBase: 2; rangePerLevel: 0; durBase: 0; durPerLevel: 1; touch: 9; targeting: 0;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 92 Cone of Cold }
    (castClass: 2; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 8; targeting: 0;
     saveResult: 2; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 93 Feeblemind }
    (castClass: 2; level: 5; rangeBase: 16; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 68; combatOk: 1; drainLevels: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 94 Hold Monsters }
    (castClass: 2; level: 5; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; touch: 7; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 52; combatOk: 1; drainLevels: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 95 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 73; combatOk: 2; drainLevels: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 96 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 109; combatOk: 2; drainLevels: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 97 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 25; combatOk: 2; drainLevels: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 98 }
    (castClass: 3; level: 6; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 11; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 0; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 99 }
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; touch: 0; targeting: 1;
     saveResult: 0; saveType: 4; effectId: 0; combatOk: 2; drainLevels: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 100 Bestow Curse }
    (castClass: 2; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; touch: 4; targeting: 0;
     saveResult: 1; saveType: 4; effectId: 0; combatOk: 1; drainLevels: 4; aiPriority: 4; offensive: 1; aiRadius: 0));
  { GameTime's clock: the size of each clock unit, segment to year. }
  unitScale: array[0..6] of Word = (10, 10, 6, 24, 30, 12, 256);
  { 60 - THAC0, by class and level }
  thac0Tbl: array[0..7, 0..12] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46),
    (39, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (39, 39, 39, 39, 39, 39, 41, 41, 41, 41, 41, 43, 43),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46));
  { the class bits ClassCal and CharGen add up for a character, by class }
  createClassBits: array[0..7] of Byte = ($02, $10, $08, $40, $40, $01, $04, $20);
  { the class bits CharGen tests, by class }
  classBits: array[0..7] of Byte = ($02, $02, $08, $10, $20, $01, $04, $04);
  { unused }
  classBitsTail: array[0..8] of Byte = (
    $10, $10, $10, $20, $20, $20, $40, $40, $40);

{ Class levels, icon colors and thief skills. }
const
  { the level at which each class's hit dice stop }
  maxClassLevels: array[0..7] of Byte = (10, 15, 10, 10, 11, 12, 11, 19);
  { the icon colors CharGen and SaveLoad seed }
  defIconCol: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
  { the thief skills, by thief level }
  thiefBase: array[1..12, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0),
    (35, 29, 25, 21, 15, 10, 86, 0),
    (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20),
    (50, 42, 40, 40, 31, 20, 90, 25),
    (55, 47, 45, 47, 37, 20, 92, 30),
    (60, 52, 50, 55, 43, 25, 94, 35),
    (65, 57, 55, 62, 49, 25, 96, 40),
    (70, 62, 60, 70, 56, 30, 98, 45),
    (80, 67, 65, 78, 63, 30, 99, 50),
    (90, 72, 70, 86, 70, 35, 99, 60),
    (100, 77, 75, 94, 77, 35, 99, 65));
  { the thief skill adjustments, by race }
  raceAdj: array[1..7, 1..8] of ShortInt = (
    (0, 10, 15, 0, 0, 0, -10, -5),
    (5, -5, 0, 5, 10, 5, 0, 0),
    (0, 5, 10, 5, 5, 10, -15, 0),
    (10, 0, 0, 0, 5, 0, 0, 0),
    (5, 5, 5, 10, 15, 5, -15, -5),
    (-5, 5, 5, 0, 0, 5, 5, -10),
    (0, 0, 0, 0, 0, 0, 0, 0));
  { the thief skill adjustments, by dexterity 9..19 }
  dexAdj: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10),
    (-19, -5, -10, -15, -5),
    (-5, 0, -5, -10, 0),
    (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, -5, 0, 0, 0),
    (5, 10, 0, 5, 5),
    (10, 15, 5, 10, 10),
    (15, 20, 10, 12, 12));

{ Experience past level 12 and the race and class rules. }
const
  { a level past 12, by class }
  xpPerExtraLevel: array[0..6] of LongInt = (
    225000, 750000, 250000, 350000, 325000, 375000, 220000);
  { the attribute limits, by race }
  raceLim: array[1..7] of Types.TRaceLim = (
    (strMin: (8, 8); strMax: (18, 17); exStrMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (3, 3); strMax: (18, 16); exStrMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 15); exStrMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); exStrMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); exStrMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 18); exStrMax: (99, 75); intMin: 3; intMax: 17;
     wisMin: 3; wisMax: 14; dexMin: 3; dexMax: 17; conMin: 13; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (3, 3); strMax: (18, 18); exStrMax: (100, 50); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { the classes each race may take, a count then the class ids }
  classesByRace: array[1..7, 0..13] of ShortInt = (
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (7, 2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (13, 0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0));
  { the starting age by race and class, a base and the dice added to it }
  startingAge: array[1..7, 0..6] of Types.TRuleAge = (
    ((base: 250; num: 2; sides: 20), (base: 0; num: 0; sides: 0), (base: 40; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 75; num: 3; sides: 6)),
    ((base: 650; num: 10; sides: 10), (base: 0; num: 0; sides: 0), (base: 130; num: 5; sides: 6),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 150; num: 5; sides: 6),
     (base: 100; num: 5; sides: 6)),
    ((base: 300; num: 3; sides: 12), (base: 0; num: 0; sides: 0), (base: 60; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 100; num: 2; sides: 12),
     (base: 80; num: 5; sides: 4)),
    ((base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 26; num: 3; sides: 8), (base: 30; num: 2; sides: 8),
     (base: 22; num: 3; sides: 8)),
    ((base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 20; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 40; num: 2; sides: 4)),
    ((base: 20; num: 1; sides: 4), (base: 0; num: 0; sides: 0), (base: 13; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 20; num: 2; sides: 4)),
    ((base: 18; num: 1; sides: 4), (base: 18; num: 1; sides: 4), (base: 15; num: 1; sides: 4),
     (base: 17; num: 1; sides: 4), (base: 20; num: 1; sides: 4), (base: 24; num: 2; sides: 4),
     (base: 18; num: 1; sides: 4)));
  { the age at which each of a race's five age categories starts, of which CharGen reads the first four }
  ageCategoryRace: array[1..7, 1..5] of Word = (
    (50, 150, 250, 350, 450),
    (175, 550, 875, 1200, 1600),
    (90, 300, 450, 600, 750),
    (40, 100, 175, 250, 325),
    (33, 68, 101, 144, 199),
    (15, 30, 45, 60, 80),
    (20, 40, 60, 90, 120));
  { the minimum abilities for each of the 17 class ids with the multi-classes }
  minimumStatisticsClass: array[0..16, 0..5] of Byte = (
    (6, 6, 9, 0, 0, 0), (0, 0, 12, 0, 0, 15), (9, 0, 6, 6, 7, 0), (12, 9, 13, 0, 9, 17),
    (13, 13, 14, 0, 14, 0), (0, 9, 6, 6, 0, 0), (6, 6, 0, 9, 0, 0), (15, 0, 15, 15, 11, 0),
    (9, 0, 9, 0, 0, 0), (9, 9, 9, 0, 0, 0), (0, 13, 14, 0, 14, 0), (0, 9, 9, 0, 0, 0),
    (0, 0, 9, 9, 0, 0), (9, 9, 0, 0, 0, 0), (9, 0, 0, 9, 0, 0), (9, 9, 0, 9, 0, 0),
    (0, 9, 0, 9, 0, 0));
  { the alignments each class id allows, a count then the alignment ids }
  alignmentsAllowedClass: array[0..16, 0..9] of ShortInt = (
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (5, 1, 3, 4, 5, 7, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (1, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (3, 0, 3, 6, 0, 0, 0, 0, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (3, 0, 3, 6, 0, 0, 0, 0, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0));
  { CharGen's hit-point bonus by constitution. }
  conBonusTbl: array[3..25] of ShortInt = (-2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);

{ Experience, starting gold, saving throws and the input, picture and click state. }
const
  { Each class's experience for levels 2..12, -1 where the class cannot reach the level, and the spell slots each of
    those levels adds, by spell level. CharGen and Magic read xpNeeded, and ClassCal adds the slot gains for clerics,
    paladins from level 9, rangers from level 8 (druid spells, then magic-user spells in columns 4 and 5) and
    magic-users; ViewChar rebuilds a magic-user's slots from the same row. }
  experienceSpellsClass: Types.TXpTable = (
    (xpNeeded: (1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001, 450001, -1, -1);
     slotGains: ((1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (1, 1, 0, 0, 0), (0, 1, 1, 0, 0), (0, 0, 1, 0, 0), (0, 0, 0, 1, 0),
                 (0, 0, 1, 1, 0), (1, 1, 0, 0, 1), (0, 0, 0, 1, 1), (1, 0, 1, 0, 0), (1, 1, 1, 0, 0))),
    (xpNeeded: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xpNeeded: (2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001, 500001, 750001, 1000001);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xpNeeded: (2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001, 700001, 1050001, -1);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (0, 0, 0, 0, 0), (1, 0, 0, 0, 0), (1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (0, 1, 0, 0, 0))),
    (xpNeeded: (2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001, 325001, 650001, -1);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (1, 0, 0, 0, 0), (0, 0, 0, 1, 0), (1, 0, 0, 0, 0), (0, 0, 0, 1, 0), (0, 1, 0, 0, 0))),
    (xpNeeded: (2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001, 250001, 375001, -1);
     slotGains: ((1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (1, 1, 0, 0, 0), (1, 0, 1, 0, 0), (0, 0, 1, 0, 0), (0, 1, 0, 1, 0),
                 (0, 0, 1, 1, 0), (0, 0, 0, 0, 1), (0, 1, 0, 0, 1), (0, 0, 1, 1, 1), (0, 0, 0, 1, 1))),
    (xpNeeded: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, 160001, 220001, 440001);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xpNeeded: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     slotGains: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
                 (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))));
  { Each class's starting-gold dice. CharGen rolls a new character's classes' dice into a total it never reads, then
    gives the character 35 platinum. }
  startingGoldClass: array[0..7] of Types.TRuleGold = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 5; sides: 4), (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));
  { The saving throws by class, level 1..12 and save 0..4; ClassCal takes each save's lowest over the character's
    classes and never reads level 0. Note: the paladin's level 8 and the monk's level 10 are out of step with their
    neighbors. }
  savingThrow: array[0..7, 1..12, 0..4] of Byte = (
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11)),
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14),
     (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11), (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10)),
    ((12, 13, 14, 15, 15), (12, 13, 14, 15, 15), (11, 12, 13, 14, 14), (11, 12, 13, 14, 14), (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12),
     (8, 9, 10, 10, 11), (9, 9, 10, 10, 11), (6, 7, 8, 7, 9), (6, 7, 8, 7, 9), (5, 6, 7, 6, 8), (5, 6, 7, 6, 8)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14),
     (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11), (7, 8, 9, 8, 10),
     (7, 8, 9, 8, 10)),
    ((14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10),
     (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8)),
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11), (11, 10, 10, 14, 11), (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11)),
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11), (13, 11, 9, 13, 10), (11, 9, 7, 11, 8),
     (11, 9, 7, 11, 8)));
  { FixMain skips the introduction when the first command-line parameter is this key. }
  stingKey: String[5] = 'STING';
  { the mouse cursor GameInit installs outside CGA }
  cursorMaskEga: Types.TMouseCursor = (
    screenMask: ($3FFF, $1FFF, $0FFF, $07FF, $03FF, $01FF, $00FF, $007F,
                 $003F, $003F, $01FF, $00FF, $10FF, $F87F, $F87F, $FC7F);
    cursorMask: ($0000, $4000, $6000, $7000, $7800, $7C00, $7E00, $7F00,
                 $7F80, $7C00, $6C00, $4600, $0600, $0300, $0300, $0000));
  { the mouse cursor GameInit installs in CGA }
  cursorMaskCga: Types.TMouseCursor = (
    screenMask: ($0FFF, $03FF, $00FF, $003F, $000F, $0003, $0000, $0003,
                 $0003, $3F03, $FF00, $FF00, $FFC3, $FFFF, $FFFF, $FFFF);
    cursorMask: ($0000, $3000, $3C00, $3F00, $3FC0, $3FF0, $3FFC, $3FC0,
                 $3CF0, $00F0, $003C, $003C, $0000, $0000, $0000, $0000));
  { Joystick's direction for each band of the stick's row and column, clockwise from north with 8 centered. }
  joystickZoneMap: array[0..5, 0..5] of Byte = (
    (7, 7, 0, 0, 1, 1), (7, 8, 8, 8, 8, 1), (6, 8, 8, 8, 8, 2),
    (6, 8, 8, 8, 8, 2), (5, 8, 8, 8, 8, 3), (5, 5, 4, 4, 3, 3));
  { the keypad digit for each direction, which nothing reads }
  joystickZoneKeys: array[0..9] of Char = ('8', '9', '6', '3', '2', '1', '4', '7', ' ', C_Keys.NONE);
  { the COMSPR picture GameInit loads, which CharHlp's combat interface draws at the screen's top left in VGA }
  combatFramePic: Types.PImgBuf = nil;
  { the COMSPR picture View3D draws at the screen's top left in VGA }
  viewFramePic: Types.PImgBuf = nil;
  { GeoEdit's I command toggles it; View3D then marks each cell's event. }
  areEventsShown: Boolean = False;
  { Camp, Shop, Temple, Vault and PostCbt set it around their menus; while it is set, MenuCore turns a click on the
    current character into the View command. }
  canClickToView: Boolean = False;
  { EclMenu sets it around its horizontal menus; MenuCore then accepts a mouse click on a one-option menu at once. }
  isEclMenuActive: Boolean = False;
  { MenuCore sets it when a mouse click on the combat arena becomes an A or M command; CbtActs then redraws the cell }
  isArenaClickPending: Boolean = False;
  { MenuCore sets it when an arena click falls outside the inner 5-by-5 cells of the view; CbtActs takes its aim key
    from it }
  isArenaClickOutside: Boolean = False;

{ The sound driver vector and the font. }
const
  { GameBoot reads the INT 66h vector here; GameInit loads the sound effects and Config picks its sound mode by whether
    it is nil. }
  int66Vector: Pointer = nil;
  { TextRend sets it once the game font is loaded; HeapErr reports an error in the game's interface only then. }
  isFontLoaded: Boolean = False;

implementation

end.
