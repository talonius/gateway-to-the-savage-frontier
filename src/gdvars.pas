{ Global variables: every variable in the data segment, grouped by the subsystem that owns them and kept in address
  order. A new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ Main menu and configuration file. }
var
  { the key FixMain's main menu returned }
  menuResult: Char;
  { set by MenuHorizontal when the key was an extended one }
  menuExt: Boolean;
  { unused }
  spareBeforeConfigVars: array[0..1] of Byte;
  { Config's GAME.CFG file and the I/O result of its last open }
  configVars: Types.TConfigVars;

{ Exit chain and title cards. }
var
  { the ExitProc HeapErr chains to and puts back }
  savedExitProc: Pointer;
  { Intro: set when a key cut a title card short }
  introInterrupted: Boolean;

{ Title card timing and the ECL script state. }
var
  { the tick at which Intro's title-card wait started }
  introStartTicks: LongInt;
  { set by EclVm to end CallEclScript's loop }
  eclStop: Byte;
  { set when EclVm must put savedChar back as the current character }
  restoreChar: Byte;
  { the LOAD FILES latch; the ECL loop skips the reload while it is set }
  filesLoaded: Byte;
  { the LOAD PIECES latch, set and cleared, never read }
  piecesLoaded: Byte;
  { the map latch, set and cleared, never read }
  mapLoaded: Byte;
  { the monsters LOAD MONSTER has added, capped at 63; CLEARMONSTERS resets it }
  creatureCnt: Byte;
  { the current character EclVm backed up, a Types.PWork }
  savedChar: Pointer;
  { PostCbt: set when the loot sweep meets a hostile neither Okay nor Running, or cleanup removes a combatant outside
    the party }
  monstersKilled: Byte;
  { PostCbt: set when the party escaped the fight }
  partyFled: Byte;
  { Shop: seeded True before its buy loop and passed as MenuVertical's redraw }
  shopMenuRedraw: Boolean;

{ Combat AI movement. }
var
  { the AI's last step direction, 8 for none }
  lastMoveDir: Byte;
  { how often the AI has reversed or failed to find a step }
  stuckCount: Byte;
  { only zeroed }
  aiMoveState: Byte;

{ Combat set-up: the arena and team placement. }
var
  { CombatSt: the party's map column its arena is built around }
  combatPartyX: ShortInt;
  { and the map row }
  combatPartyY: ShortInt;
  { the quad occupancy grid, [team, ring, row, column], 1 where a cell is free }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { each team's placement origin column }
  placeX: array[0..1] of ShortInt;
  { each team's placement origin row }
  placeY: array[0..1] of ShortInt;
  { the rows each team is placed over }
  teamRows: array[0..1] of ShortInt;
  { the direction each team faces as it is placed }
  teamDir: array[0..1] of ShortInt;
  { the dungeon arena builder's column offset from the party, -6..6 }
  dungeonCellDX: ShortInt;
  { its row offset, -2..2 }
  dungeonCellDY: ShortInt;
  { that cell's north wall: 0 open, 1 solid, 3 door }
  wallN: Byte;
  { its west wall, coded the same way }
  wallW: Byte;
  { its east wall }
  wallE: Byte;
  { its south wall }
  wallS: Byte;
  { the team being placed, 0 the party }
  team: ShortInt;

{ Combat set-up: terrain and decoration. }
var
  { the wilderness terrain under the party }
  terrainChar: Byte;
  { set when the dungeon cell's map event is $80, which lets CombatSt decorate it }
  isDecorationAllowed: Boolean;
  { set when the cell's walls enclose it }
  isCellEnclosed: Boolean;

{ Game start-up loop. }
var
  { unused }
  spareBeforeGi2: array[0..3] of Byte;
  { GameInit's loop index }
  gi2: Byte;

{ Game start-up: the items file. }
var
  { unused }
  spareBeforeItemsOk: array[0..1] of Byte;
  { whether GameInit opened ITEMS.1 }
  itemsOk: Boolean;

{ Game start-up: the mouse probe, ITEMS.1 and the item editor. }
var
  { unused }
  spareBeforeMouseProbe: array[0..43] of Byte;
  { the buttons GameInit reads once at start-up to decide mouse scaling }
  mouseProbeButtons: Integer;
  { and the mouse's column then }
  mouseProbeX: Integer;
  { and its row }
  mouseProbeY: Integer;
  { GameInit's ITEMS.1 }
  itemsFile: file;
  { unused }
  spareBeforeItemEditorField: array[0..1] of Byte;
  { DevMenu's item editor field 0..14 }
  itemEditorField: Byte;

{ Map editor: the map number. }
var
  { the map GeoEdit is editing }
  geoMapNumber: Byte;

{ Map editor: wall sets. }
var
  { the three wall sets GeoEdit loads }
  geoWallSets: array[1..3] of Byte;

{ Map editor: the step and the wall type. }
var
  { GeoEdit's step, 1 or -1 }
  geoStep: Integer;
  { the wall type GeoEdit's W command writes to the faced dungeon wall }
  newWallType: Byte;

{ Character viewer, effect aging and spell lists. }
var
  { ViewChar's saved character: the one DisplayChar shows }
  tempCr1: Types.PWork;
  { and the trade selection }
  tempCr2: Types.PWork;
  { GameTime: the creatures whose effects need aging }
  effFlags: array[1..72] of Byte;
  { Magic's menu list }
  spellList: Types.PItemRec;
  { how many of each listed spell there are; Magic walks 81 entries }
  spellCounts: array[0..81] of Byte;
  { the id of each listed spell }
  spellIds: array[0..81] of Byte;
  { the scrolls the listed spells come from }
  scrollPtrs: array[0..48] of Types.PItemRec;
  { how many scrollPtrs hold }
  scrollCount: Byte;
  { a work byte Magic's handlers share }
  gSpellTemp1: Byte;
  { a second one }
  gSpellTemp2: Byte;

{ Encumbrance, the music and sound drivers, keyboard buffer and GAME.CFG. }
var
  { CharHlp: the equipped items' weight }
  gEquipWeight: Word;
  { the music driver image }
  musicDriverImage: Pointer;
  { the song it plays }
  musicSongData: Types.PBytes;
  { and the song's size }
  musicSongSize: Word;
  { the speaker gate MusDrv saves on load and puts back on unload }
  sndSavedGate: Byte;
  { whether MusDrv's driver is loaded }
  sndState: Byte;
  { the driver's far entry point, which MusDrv calls }
  sndEntry: Pointer;
  { the song MusDrv hands the driver }
  sndSong: Pointer;
  { the driver's answer to the last call }
  sndResult: Integer;
  { the two words of a driver call }
  sndArgs: array[0..1] of Word;
  { GameIo's two buffered key bytes }
  queuedKeyBytes: array[1..2] of Byte;
  { set by GameBoot when GAME.CFG must be written again }
  isConfigStale: Boolean;

{ GAME.CFG and the heap. }
var
  { unused }
  spareBeforeCfgChar: Byte;
  { the adapter letter GameBoot reads from GAME.CFG }
  cfgChar: Char;
  { unused }
  spareBeforeCfgText: array[0..9] of Byte;
  { GAME.CFG as GameBoot reads it }
  cfgText: Text;
  { unused }
  spareAfterCfgText: array[0..83] of Byte;
  { unused }
  spareBeforeMemNeeded: array[0..127] of Byte;
  { the heap bytes GameBoot requires }
  memNeeded: LongInt;
  { Config sets it from GAME.CFG, Intro tests it }
  fullIntroFlag: Byte;

{ Game state: the GBVM banks and the game speed. }
var
  { GBVM bank 0, which GameInit allocates }
  gbvmZone0Ptr: Types.PZone0;
  { GBVM bank 1 }
  gbvmZone1Ptr: Types.PZone1;
  { GBVM bank 2 }
  gbvmZone2Ptr: Types.PZone2;
  { the loaded ECL script's bank }
  gbvmScriptPtr: Types.PZone3;
  { the game speed, 0 fastest to 9 slowest, which every delay uses }
  gameDelay: Byte;

{ Game state: ECL entry points and the interface mode. }
var
  { the five ECL entry addresses }
  eclScriptEntries: array[1..5] of Word;
  { the ECL instruction pointer }
  eclScriptInstructionPtr: Word;
  { unused }
  spareBeforeInterfaceState: array[0..3] of Byte;
  { what the interface is doing, a C_Ifc value }
  interfaceState: Byte;
  { CharGen and SaveLoad keep interfaceState here }
  savedInterfaceState: Byte;
  { FixMain's demo switch; the AI then plays the party and no key is read }
  demoMode: Boolean;

{ Game state: pictures, rest and the party's fate. }
var
  { SaveLoad packs this and portraitsFlag into one GBVM word }
  monsterPicturesFlag: Byte;
  { Portrait shows portraits while it is set }
  portraitsFlag: Byte;
  { EclMenu skips an encounter's close-up while it is zero; nothing writes it by name }
  encounterCloseUpFlag: Byte;
  { SaveLoad sets it after a load; EclMenu tests it }
  loadedSavedGameFlag: Byte;
  { GameTime's rest count, checked against bank 1's safe rest time }
  restTicks: Word;
  { EclMenu's portrait head id }
  currentPortraitHead: Byte;
  { EclMenu's portrait body id }
  currentPortraitBody: Byte;
  { set when the party is defeated; MapView then draws nothing }
  partyDefeated: Boolean;
  { set while TrainingMenu runs without its screens }
  isAutoTraining: Boolean;
  { the delay-printing flag }
  msgDelayFlag: Byte;

{ Video: registers, pages and modes. }
var
  { the Dos.Intr register block every BIOS call goes through }
  interruptRegisters: Types.TInterruptRegisters;
  { the segment of the EGA page on display }
  egaCurPage: Word;
  { the segment of the EGA page drawn to }
  egaOtherPage: Word;
  { the EGA page number drawn to }
  otherEgaPage: Byte;
  { the EGA page number on display }
  currentlyDisplayedEga: Byte;
  { the video mode found at start-up, put back on exit }
  savedVideoMode: Byte;
  { the BIOS video mode set last }
  currentVideoMode: Byte;
  { the configured adapter: 0 CGA, 1 EGA, 2 Tandy, 3 VGA }
  displayMode: Byte;

{ Video: the view buffer, dirty spans and frame-buffer row tables. }
var
  { the view buffer }
  viewBuf: Types.PImgBuf;
  { the icon save-under buffer }
  saveUnder: Types.PImgBuf;
  { unused }
  spareBeforeSpanActive: array[0..15] of Byte;
  { the deferred-render span tables, one entry per view scanline, which raster.asm reaches at fixed offsets: set where
    the scanline has a span }
  spanActive: array[0..167] of Byte;
  { the screen offset of the span's scanline }
  spanScreenOfs: array[0..167] of Word;
  { the span's first offset }
  spanFirstOfs: array[0..167] of Word;
  { the span's last offset }
  spanLastOfs: array[0..167] of Word;
  { unused }
  spareBeforeCgaRowSeg: array[0..671] of Byte;
  { each screen row's segment in CGA, filled by GameInit }
  cgaRowSeg: array[0..199] of Word;
  { each screen row's offset in EGA; raster.asm reaches it at a fixed offset }
  fbRowOfs: array[0..199] of Word;
  { each screen row's segment on a Tandy }
  tandyRowSeg: array[0..199] of Word;
  { each screen row's offset in the VGA frame (row * 320); GameInit fills it and nothing else touches it }
  vgaRowOfs: array[0..199] of Word;
  { GameInit sets it to 1; nothing reads it }
  clipFlag: Byte;

{ Sound mode. }
var
  { from GAME.CFG; 3 mutes SoundDrv and Music }
  soundMode: Byte;
  { soundMode as Config set it; GameIo's quit restores soundMode from it }
  soundSaved: Byte;
  { GameInit sets it; EclVm and FixMain choose SoundCommand(255) or SoundSuspend by it }
  soundOnFlag: Byte;

{ Virtual disks and the save directory. }
var
  { the disk DaxIo loads from; SaveLoad keeps it in a save }
  virtualDiskNumber: Byte;
  { the disk PushState saves and PopState restores }
  previousVirtualDisk: Byte;
  { Config reads it from GAME.CFG; SaveLoad and Vault build paths on it }
  saveDir: String[80];
  { DaxIo's OpenWithRetry skips its insert-disk prompt while it is set }
  suppressingInsertDiskFlag: Byte;
  { SaveLoad sets it after a save; CharGen, EclVm and GameInit clear it }
  recentlySavedGameFlag: Byte;

{ DAX buffer, the item catalog, the party, the text output and the picture buffers. }
var
  { DaxIo holds a compressed DAX record here while it decompresses it }
  daxCompressedFilePtr: Pointer;
  { one row per item type, by itemType; GameInit reads ITEMS.1 into it past the file's two-byte prefix, asking for 129
    rows of the file's 128, so the last row is never filled }
  baseItems: array[0..128] of Types.TBaseItemRec;
  { the current creature }
  curChar: Types.PWork;
  { the creature list's head }
  creatureList: Types.PWork;
  { the last missile item used }
  lastMissileItem: Types.PItemRec;
  { unused }
  spareAfterLastMissileItem: array[0..127] of Byte;
  { the byte count GameInit's BlockRead of ITEMS.1 returns; nothing reads it }
  itemsRead: Word;
  { the font TextRend draws from, 8 bytes a glyph }
  gameFont: Types.PFont;
  { the glyph TextRend is drawing, which textrend.asm reads at its fixed offset }
  glyphBits: array[0..7] of Byte;
  { the text cursor's column }
  curCol: Byte;
  { the text cursor's row }
  curRow: Byte;
  { unused }
  spareAfterCurRow: array[0..19] of Byte;
  { the five 8x8 symbol sets Sym8x8 loads and draws from }
  symbolSetPtrs: array[0..4] of Types.PImgBuf;
  { the current 8x8 symbol, which GameInit allocates }
  current8x8SymbolPtr: Types.PImgBuf;
  { the two 2D map tile sets MapTiles loads }
  tileSetImages: array[0..1] of Types.PImgBuf;
  { the icon animation frames, two per slot, which MapTiles loads and CharHlp, CharGen, EclVm, SaveLoad and CbtMap
    draw }
  iconAnimation: array[0..25, 0..1] of Types.PImgBuf;
  { how many combatArenaLocation entries CombatSt has registered }
  arenaScanLimit: Byte;

{ Combat arena: where each combatant stands. }
var
  { each combatant's arena cell, which CombatSt registers }
  combatArenaLocation: array[1..72] of Types.TArenaLoc;
  { CbtMap: each combatant's view-relative column }
  creatureXCoordinate: array[1..72] of ShortInt;
  { and its row }
  creatureYCoordinate: array[1..72] of ShortInt;
  { the registration index standing in each arena cell, [row, column] }
  combatArenaCreature: array[0..24, 0..49] of Byte;
  { each registered combatant }
  creaturePtr: array[1..72] of Types.PWork;
  { the party members downed in the fight }
  combatDownedCharacter: array[1..8] of Types.TDownedRec;
  { how many of them there are }
  downedCount: Byte;

{ Combat arena: the view and target count. }
var
  { the allocated combat view }
  combatArenaPtr: Types.PArena;
  { how many combatTargetData entries are in use }
  targetCount: Byte;

{ Combat targets, treasure and the attack in progress. }
var
  { the targets; CharHlp and FxEngine save and restore them with Move }
  combatTargetData: array[1..72] of Types.TCombatTarget;
  { the treasure an encounter leaves, copper through jewelry }
  treasureMoney: Types.TMoney;
  { its item list; Vault and ViewChar keep the vault's items in the same list }
  treasureItems: Types.PItemRec;
  { each side's live combatant count }
  teamCount: array[0..1] of Byte;
  { where Vault and ViewChar walk or append in the item list }
  itemListCursor: Types.PItemRec;
  { the modified saving-throw roll }
  gSaveRoll: Byte;
  { the effect id being applied, cleared when the target is immune }
  gEffectCheck: Byte;
  { the damage before it is subtracted }
  pendingDamage: Byte;
  { the damage's element mask }
  elementMask: Byte;
  { the attack, or twice the movement, being spent }
  currentAttackCurrent: Byte;
  { the spell being cast }
  currentSpellBeing: Byte;
  { the damage dice }
  currentDamageDice: Byte;

{ The attack in progress: its flags and rolls. }
var
  { set while movement is being calculated }
  currentCreatureCalculatingFlag: Byte;
  { set to suppress targeting }
  currentSuppressTargetingFlag: Byte;
  { set to lock effects }
  effectLockFlag: Byte;
  { set for a multi-target spell }
  currentSpellAffectsFlag: Byte;
  { set to redraw the inventory menu }
  redrawInventoryMenuFlag: Byte;
  { the signed attack roll }
  currentAttackRoll: ShortInt;
  { the primary and secondary hit counts }
  currentNumberHits: array[1..2] of Byte;
  { the morale being tested }
  currentMorale: Byte;

{ Effects: the creature acted on, the saving throw and the effect handlers. }
var
  { the creature being acted on }
  otherCreatureCurrentPtr: Types.PWork;
  { the saving-throw type }
  currentSavingThrow2: Byte;
  { set when FxEngine.RollSavingThrow found the save made; EffHndlr reads it }
  isSavingThrowMade: Boolean;
  { a handler per effect id: EffHndlr installs most of them and Magic seven (86, 88, 90, 126, 128, 131 and 132), and
    FxEngine calls effectHandlers[id], or entry 147 while its override flag is set. Note: GameInit has EffHndlr install
    its own entry 126 after Magic's, so Magic's EffAimedParalyzingGaze never runs. }
  effectHandlers: array[1..159] of Types.TEffectHandler;
  { the wall-symbol slices GameInit allocates }
  wallGfx: Types.PWallGfx;
  { set by View3D for each wall set 1..3 whose 8x8 symbol set holds $D2 or more symbols; the fourth is unused }
  wallSetFlags: array[1..4] of Byte;
  { the four GEO planes GameInit allocates }
  map3d: Types.PGeoMap;
  { the 3D view's sky and ceiling color selector }
  colorSkyCeiling: Byte;
  { the first wall color }
  wallColorA: Byte;
  { the second wall color }
  wallColorB: Byte;
  { the third wall color }
  wallColorC: Byte;
  { the automap switch }
  automapOn: Boolean;

{ The party's position. }
var
  { where the party stands and what it faces }
  partyPos: Types.TPartyPosition;

{ 3D view backdrops and the picture cache. }
var
  { the wall sets loaded into the three symbol slots }
  wallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { View3D's first sky backdrop, drawn facing north }
  skyImage0: Types.PImgBuf;
  { the second }
  skyImage1: Types.PImgBuf;
  { the third }
  skyImage2: Types.PImgBuf;
  { the current animation }
  animationData: Types.TAnimRec;
  { Portrait's cached HEAD and BODY pictures }
  portraitCache: array[1..2] of Types.TPortraitCacheSlot;
  { the current picture archive's name }
  picArcName: String[8];

{ Pictures: the archive Camp saves. }
var
  { Camp's copy of picArcName, from which it reloads the animation }
  savedPictureName: String[8];
  { the current picture archive's id }
  picArcId: Byte;
  { Camp's copy of picArcId }
  savedPictureId: Byte;

{ Pictures: the big picture. }
var
  { the big picture }
  bigPicBuf: Types.PImgBuf;
  { its id; every frame routine resets it to none }
  bigPicId: Byte;

{ Party order. }
var
  { Camp's and CharHlp's party-order selection state }
  orderState: Byte;

{ Menus. }
var
  { the character picked for the party order }
  orderChar: Types.PWork;
  { the vertical menu's first visible entry }
  vertTop: Integer;
  { the horizontal menu's choice }
  horizChoice: Byte;
  { set when the menu key was an extended one }
  extFlag: Boolean;
  { the ticks after which a menu answers itself, 0 for never }
  menuTimeout: LongInt;
  { the key it answers with }
  menuDefaultKey: Char;

{ Menus: mouse hit areas, colors and the last key. }
var
  { the text row of each vertical menu line, which a click is matched against }
  hotRows: array[1..25] of Byte;
  { the menu's first column }
  keyColLo: ShortInt;
  { the menu's last column }
  keyColHi: ShortInt;
  { the party roster's click box: left column }
  rosterLeft: Byte;
  { right column }
  rosterRight: Byte;
  { top row }
  rosterTop: Byte;
  { bottom row }
  rosterBottom: Byte;
  { the row a click picks in CharGen's modify menu }
  modifyRow: Byte;
  { unused }
  spareBeforeQueryColor: Byte;
  { the color of a menu's prompt }
  queryColor: Byte;
  { the color of its options }
  menuColor: Byte;
  { the color of its hotkeys }
  highlightColor: Byte;
  { the last horizontal menu's byte sum; a different menu starts at its first option }
  menuChecksum: Byte;
  { the last menu key }
  menuKey: Char;
  { unused }
  spareBeforeVerticalMenuActive: Byte;
  { set while a vertical menu is up }
  verticalMenuActive: Boolean;
  { set when a party click repeats CharGen's command }
  partyRepeat: Byte;

{ Spell casting and targeting. }
var
  { the item a spell is cast from }
  currentScrollPtr: Types.PItemRec;
  { the cast-target menu, then the spell handlers by spell id, which Magic installs }
  spellFps: Types.TSpellFps;
  { how many targets are chosen }
  numberTargetedCreatures: Byte;

{ Spell targets and clouds. }
var
  { the chosen targets }
  targetCreaturePtr: array[1..72] of Types.PWork;
  { the non-combat target }
  castTargetPtr: Types.PWork;
  { the combat target cell's column }
  gTargetX: ShortInt;
  { and row }
  gTargetY: ShortInt;
  { the Stinking Cloud list }
  linkedListStinkingPtr: Types.PArenaNode;
  { the Cloudkill list }
  cloudkillList: Types.PArenaNode;
  { set while a spell is cast from an item }
  usingItem: Boolean;

{ Treasure. }
var
  { set when the treasure holds money }
  treasureMoneyFlag: Boolean;

{ Rest and healing. }
var
  { the rest clock in its seven units }
  restTime: Types.TClock;
  { each party slot's spell-preparation timer }
  prepTimers: array[1..8] of Byte;
  { the day's rest ticks; 288 heal a day's worth }
  healTicks: Word;
  { set to suppress the status border }
  suppressDrawingBorderFlag: Byte;

{ The map redraw flag. }
var
  { set and cleared, never read }
  mapRedrawPending: Byte;

{ The effect override. }
var
  { while it is set FxEngine calls effect handler 147 instead }
  overrideEffectFlag: Byte;

{ Character import. }
var
  { SaveLoad's and CharGen's character-import mode }
  characterImportMode: ShortInt;

{ Character menus and combat. }
var
  { set to leave SaveLoad's character menu }
  characterMenuDone: Byte;
  { CharGen's hidden STING mode }
  stingMode: Byte;
  { the door-opening attempts: bash, pick, knock }
  doorOpeningBoolean: array[0..2] of Byte;

{ Combat rounds. }
var
  { set when the AI attacked its allies }
  attackedAllies: Byte;
  { the round counter }
  combatRoundCounterCount: Byte;
  { the round at which Combat ends the fight, which CombatSt and CbtActs set }
  roundLimit: Byte;
  { the acting creature's potential targets }
  potentialTargetCreature: array[0..71] of Byte;
  { the attacks made by phase; CbtActs indexes the phase from 0 }
  attacksMade: array[0..2] of Byte;
  { the hostiles' remaining hit points, a percentage }
  hostileCreatureHit: Byte;
  { the quick-magic switch }
  quickMagic: Boolean;
  { set when the creature is done for the round }
  doneRoundFlag: Boolean;
  { unused }
  spareBeforeMoveIconSheet: array[0..4] of Byte;
  { the combat moving-icon sheet }
  moveIconSheet: Types.PImgBuf;
  { set when the AI's target is in weapon range }
  targetInRange: Boolean;
  { set when the combat view must be redrawn }
  combatRedraw: Byte;
  { whether the combat map is visible }
  combatMapVisible: Byte;

{ ECL virtual machine. }
var
  { the script's wall color }
  wallColorSel: Byte;
  { the script's ceiling and floor color }
  ceilFloorColorSel: Byte;
  { the first read register }
  readReg1: Word;
  { the second }
  readReg2: Word;
  { the third }
  readReg3: Word;
  { the GOSUB return stack }
  eclStack: Types.PEclRet;
  { the entry below its top }
  eclStackPrev: Types.PEclRet;
  { the six COMPARE results: eq, ne, lt, gt, le, ge }
  cmpFlags: array[0..5] of Boolean;
  { the previous opcode }
  prevOpcode: Byte;
  { the current opcode }
  curOpcode: Byte;
  { unused }
  spareAfterCurOpcode: Byte;
  { the encounter's monster }
  monId: Byte;
  { its picture }
  monPicId: Byte;
  { the icon animation slot }
  currentIconAnimation: Byte;
  { unused }
  spareBeforeVarTypes: array[0..129] of Byte;
  { each decoded operand's type }
  varTypes: array[1..64] of Byte;
  { its high byte }
  varHi: array[1..64] of Byte;
  { its low byte }
  varLo: array[1..64] of Byte;
  { the cast-target menu's answer for a breath or gaze }
  breathAim: Boolean;
  { a for-control variable eight units share: Blit, ClassCal, InputCfg, Joystick, Portrait, SaveLoad, Magic and
    ViewChar; all but InputCfg read it as a ShortInt }
  sharedLoopIndex: ShortInt;
  { the ECL string operands: EclMenu stores the k-th in slot k }
  gbStrings: array[1..20] of String;
  { which of the monster's pictures are shown }
  monsterFlags: Types.TMonFlags;
  { unused }
  spareAfterMonsterFlags: array[0..1] of Byte;
  { the script's sound }
  sndEffect: Word;
  { the first write register }
  writeReg1: Word;
  { the second }
  writeReg2: Word;
  { set when LOAD CHARACTER clears the status }
  statusCleared: Boolean;
  { set when LOAD CHARACTER clears the name }
  nameCleared: Boolean;
  { the shop session flag Shop, Temple and Vault set }
  shopSessionFlag: Boolean;

{ Encounters: the duel and experience. }
var
  { set for the mirror duel }
  duelFlag: Boolean;
  { the creatures left unanimated, which do not share experience }
  nonAnimCount: Byte;
  { each character's experience share }
  expShare: LongInt;
  { the victory flag }
  combatWon: Boolean;

{ ECL display flags and the debug log. }
var
  { the ECL script id }
  eclScript: Byte;
  { the saved search mode }
  searchModeFlag: Byte;
  { set when the ECL loop has cleared the 3D view }
  ecl3dClearFlag: Byte;
  { set when TextRend must start a new line first }
  protNewLine: Byte;
  { set while the script shows its own graphics }
  eclGraphics: Boolean;
  { set when the encounter's picture is drawn }
  picDrawn: Boolean;
  { set when the protection text is up; EclVm redraws the view frame }
  protectionShown: Byte;
  { set when a sprite is shown }
  sprShown: Boolean;
  { zero while the bottom message stands; Explore clears it }
  bottomMsgCleared: Byte;
  { set while the picture fills the wide region }
  picRegionW: Boolean;
  { set when the script moved the party }
  movedParty: Boolean;
  { set when the creature list holds a monster }
  creatureListContainsFlag: Byte;
  { set to redraw the sky }
  redrawSky: Boolean;
  { set while an ECL opcode is running }
  currentlyEclOpcodeFlag: Byte;
  { the picture id on display }
  picIdShown: Byte;
  { set when the character asked for was not found }
  characterNotFound: Byte;
  { set while a character selection is active }
  characterSelectionActive: Byte;
  { the victory start flag }
  victoryStartFlag: Byte;
  { GameIo's Ctrl-D debug log, a standard Text record; EclVm writes to it }
  debugFile: Text;
  { a start-up flag GameInit clears }
  initFlag1: Byte;
  { a second one }
  initFlag2: Byte;
  { unused }
  spareBeforeCursorImage: array[0..3] of Byte;
  { the one-symbol 8x8 graphics set GameInit allocates and fills with $FF }
  cursorImageBuffer: Types.PImgBuf;
  { the start-up password: FixMain skips the copy protection and Explore forces the automap when the second command-line
    parameter matches it; ModeInit sets it to itemNameComponents[252], 'Wooden' }
  commandText: String[20];

{ Copy protection and the keyboard. }
var
  { CopyProt's four stage flags, cleared and set as the check proceeds }
  protectionFlags: array[0..3] of Byte;
  { the keyboard flags GameInit saves }
  savedKeyboardFlags: Byte;

{ Directories. }
var
  { GAME.CFG's disk 3 directory }
  disk3Dir: String[79];
  { the directory the game runs from }
  exeDir: String[79];
  { GAME.CFG's disk 2 directory }
  disk2Dir: String[79];
  { the drive letter DaxIo's insert-disk prompt names; Config and SaveLoad set it from a directory's first character }
  promptDrive: Char;
  { whether the title music plays: Config sets it for GAME.CFG's 'N', Intro tests it }
  isMusicEnabled: Boolean;
  { the current directory, which GameBoot records at start-up and Config reads from GAME.CFG }
  currentDir: String[80];

{ VGA palette staging, which raster.asm reaches at fixed offsets, and the mouse. }
var
  { the DAC levels for entries 16..31, three bytes each }
  dacTable: array[0..47] of Byte;
  { the staged picture palette, two 4-bit levels a byte }
  paletteWork: Types.TPalette24;
  { the palette the DAC last received }
  paletteShown: Types.TPalette24;
  { the staged picture's frame, 0 for none }
  paletteFrame: Word;
  { set when the mouse's coordinates need scaling }
  isMouseScaled: Boolean;
  { set while a click on a party member is accepted }
  canClickParty: Byte;
  { whether a mouse is in use }
  isMouseOn: Boolean;
  { set when the mouse took a button }
  isMouseClick: Boolean;
  { the buttons the mouse driver reported }
  mouseButtons: Byte;

{ Mouse position and cursor. }
var
  { the mouse's column }
  mouseX: Integer;
  { the mouse's row }
  mouseY: Integer;
  { the column at the last poll }
  mouseOldX: Integer;
  { the row at the last poll }
  mouseOldY: Integer;
  { the cursor GameInit installs }
  mouseCursorMask: ^TMouseCursor;
  { GameInit clears it; nothing reads it }
  mouseInitState: Byte;

{ Joystick. }
var
  { the stick's calibration readings, which InputCfg writes to GAME.CFG }
  joystickCalibration: array[1..2] of Types.TJoyCal;
  { whether a joystick is in use }
  isJoystickOn: Boolean;

{ Joystick center, hooks and click state. }
var
  { the stick's center column }
  joystickCenterX: Integer;
  { the stick's center row }
  joystickCenterY: Integer;
  { EclVm's FinishNewEcl, which DevMenu calls after setting eclScript }
  finishNewEclProc: Types.TNoArgProc;
  { CharHlp's DisplayParty, which MenuCore calls }
  displayPartyProc: Types.TDisplayPartyProc;
  { MenuCore's manual aim flag; CbtActs sets it for the whole of ManualAimCursor }
  manualAimActive: Byte;
  { the arena-move flag }
  arenaMoveActive: Byte;
  { the party-click mode }
  partyClickMode: Byte;
  { set when a click is pending }
  clickPending: Byte;
  { the character before the click }
  priorChar: Types.PWork;
  { the combat mouse mode }
  combatMouseMode: Byte;
  { the arena column under the mouse }
  arenaMouseX: ShortInt;
  { the arena row under the mouse }
  arenaMouseY: ShortInt;
  { GameInit clears it; nothing reads it }
  unreadBeforeJoyClick: Byte;
  { Combat sets it around its round menu }
  joyClickA: Byte;
  { CbtActs sets it around AimTargetMenu's MenuHorizontal }
  joyClickB: Byte;
  { the party's column in the view's text grid, which View3D sets and MenuCore compares a click with }
  partyScreenX: ShortInt;
  { and its row }
  partyScreenY: ShortInt;
  { GameInit sets it when the first command-line parameter is 'Super', and Config for GAME.CFG's 'S' }
  superMode: Byte;
  { starts as superMode's copy; DevMenu's encounter commands test it }
  superModeCopy: Byte;
  { DevMenu's combat switch }
  combatDisabled: Byte;

{ Installed routines. }
var
  { TextRend's DisplayStatusLine }
  displayStatusLineProc: Types.TMessageProc;
  { TextRend's DisplayStatusAndWait }
  displayStatusAndWaitProc: Types.TStatusProc;
  { TextRend's LongToString }
  longToStringFunc: Types.TLongToStringFunc;
  { CharHlp's Uint8Str; nothing calls it through here }
  uint8StrFunc: Types.TUint8StrFunc;
  { TextRend's RenderChar; nothing calls it through here }
  renderCharProc: Pointer;
  { View3D sets it after a VGA view is drawn; MenuCore then remaps the view's colors }
  remapPending: Byte;

{ Music and combat tiles. }
var
  { Music installs StopMusic; Intro calls it }
  stopMusicProc: Types.TNoArgProc;
  { 2 while Music's driver plays }
  musicState: Byte;
  { set once CombatSt has loaded the combat tiles }
  combatTilesLoaded: Byte;
  { the combatants CbtMap counts as eligible }
  eligibleCount: Byte;

{ Sound effects and the ECL and combat flags. }
var
  { effects 2..12, a size and the data each, which GameInit clears and loads }
  soundSamples: array[2..12] of Types.TSoundSample;
  { SoundDrv copies an effect here before it hands the driver driverCommand }
  soundBuffer: Pointer;
  { unused }
  spareBeforeDriverCommand: array[0..3] of Byte;
  { the command SoundDrv clears and hands the driver }
  driverCommand: Types.TSoundDriverCommand;
  { EclVm sets it when a script loads a new ECL script and clears it before each entry point it calls; GameTime stops
    aging effects while it is set }
  newEclFlag: Byte;
  { CbtActs sets it when a fleeing creature gets away in combat mode 1, which ends Combat's round loop }
  combatTransition: Byte;

implementation

end.
