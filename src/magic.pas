{ Spell casting: the spell lists and their menus, range and duration, applying a spell to its targets, casting outside
  combat, the spell handlers and InitSpellFns, which installs them. ClassCanCastSpell decides which spells a character's
  classes can cast, and GenerateSpellList consults it. GDVars.spellFps holds the target menu and the 100 spell handlers,
  and InitSpellFns also installs seven monster special attacks in GDVars.effectHandlers. }
{$O+,F+,S+}
{$A+}
unit Magic;

interface

uses Types, C_Status, C_Effect, C_Race, C_Class, C_Dir, C_Gbvm, C_Ifc, C_Msg, C_Npc, C_Spell, C_Stat, C_Terr, FxEngine,
  CbtMap, Pathing, TextRend, SoundDrv, CharHlp, ClassCal, MenuCore, Border, GDConsts, GDVars,
  C_Keys, Crt;

{ Run the spell list GenerateSpellList built as a vertical menu titled by selType and free it.
  @param(selType 1 cast, 2 memorize, 3 scribe, 4 learn (no Exit); anything else gets no title.)
  @param(idx The highlighted entry; below 0 redraws from the top.)
  @returns(The chosen spell, or 0 when the menu is left; for scribing, GDVars.currentScrollPtr is the spell's scroll.) }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Build GDVars.spellList, the spell menu for menuType, with a heading before each level and class: 0 the memorized
  spells ready to cast, 5 those still being memorized, 1 the known spells, 4 the spells the character can learn, 2 the
  current scroll's spells, 3 all its readable scrolls' spells and 6 those being scribed (the scroll lists group by level
  as they go).
  @param(menuType The list to build.)
  @returns(True when the list has a spell.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range.
  @param(spell The spell.)
  @returns(Its base plus its per-level range times the caster level (an item casts at level 6); a spell with an area
    gets at least 1, and 255 becomes 1.) }
function CalcSpellRange(spell: Byte): Byte;

{ Picks the targets of a spell cast outside combat; it is installed as the cast-target handler outside combat. Target
  mode 1 targets the caster, 2 asks for one party member (remembered for the next cast; giving up clears the targets and
  the cast) and 4 targets each creature in the list; any other mode gives up the cast.
  @param(spell The spell.)
  @param(b Unused.)
  @param(cast Receives True when targets were picked.) }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Cast a spell: outside combat a spell with no targeting offers to lose it, or an item's combat-only spell to use it up;
  a caster with effect 74 miscasts on 1 of 1d2. Otherwise the target menu picks targets; then the cast is announced
  (unless an item casts or ai is clear), animated in combat, the spell taken from memory (unless an item casts) and its
  handler run. Without targets, in combat the player may abort the spell, losing it.
  @param(spell The spell.)
  @param(b True to leave without targets silently, without asking to abort.)
  @param(ai True to announce the cast.)
  @param(sel Set when targets were picked, or when the spell is miscast or an item's spell is used up.) }
procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Tells whether an item is a scroll: it is not nil and its base item's slot is 11, 12 or 13.
  @param(it The item.)
  @returns(True for a readable item.) }
function ItemReadable(it: Pointer): Boolean;

{ Clears the last of a scroll's spell slots holding a spell, pending mark aside, and lowers its spell-count name part;
  the scroll goes once that count falls below 210. Nothing happens when no slot holds the spell.
  @param(cr The scroll's owner.)
  @param(it The scroll.)
  @param(spell The spell.) }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat the caster's name, the given
  text and the spell's name in the text window, then a pause.
  @param(cr The caster.)
  @param(msg Printed after the caster's name outside combat.)
  @param(spell The spell cast.) }
procedure PrintCastSpellMsg(cr: Types.PWork; msg: Types.TStr40; spell: Byte);

{ Spells 43 and 89 (Remove Curse): end the first target's Bestow Curse ('is un-cursed'); without one, unready its first
  cursed item and undo that item's effect when it carries one ('has an item un-cursed'). }
procedure SpellRemoveCurse;

{ Install the spell target menu and the 100 spell handlers in GDVars.spellFps, reset the casting state, and install the
  seven monster special attacks in GDVars.effectHandlers. }
procedure InitSpellFns;

{ Return whether a character's classes can cast a spell by its casting class: cleric spells need wisdom above 8 and a
  cleric level or a paladin level above 8; druid spells wisdom above 8 and a ranger level above 6; magic-user spells
  intelligence above 8 and a magic-user level (not for a human in armor in combat) or a ranger level above 8. Old class
  levels count once EarlierClassActive.
  @param(cr The character.)
  @param(spell The spell; its pending flag is ignored.)
  @returns(True when it can be cast.) }
function ClassCanCastSpell(cr: Types.PWork; spell: Byte): Boolean;

implementation

const
  { the Read Magic spell's effect }
  EFF_READ_MAGIC = 16;
  { the caster's stinking cloud: it owns the cloud list }
  EFF_CAST_STINK = 40;
  { the caster's cloudkill: it owns the cloud list }
  EFF_CAST_CLOUDKILL = 91;

procedure AddScrollSpellLine(spell: Byte); forward;

procedure AddSpellToList(spell: Byte); forward;

procedure AddScrollSpells(forScribe: Boolean); forward;

procedure AddAllScrollSpells(forScribe: Boolean); forward;

function CalcSpellDuration(spell: Byte): Word; forward;

procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40); forward;

function ClassCanCastSpell(cr: Types.PWork; spell: Byte): Boolean;
begin
  spell := spell and C_Spell.ID_MASK;
  ClassCanCastSpell := False;
  case Char(GDConsts.spellTable[spell].castClassS) of
    Chr(C_Spell.CLERIC_LIST): ClassCanCastSpell := Boolean(cr^.mgWisdom > 8) and
      ((cr^.classLevels[C_Class.CLERIC_LEVEL] > 0) or
       (Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))) and
        (cr^.classLevels2[C_Class.CLERIC_LEVEL] > 0)) or (cr^.classLevels[C_Class.PALADIN_LEVEL] > 8) or
      ((cr^.classLevels2[C_Class.PALADIN_LEVEL] > 8) and
       Boolean(ClassCal.EarlierClassActive(Types.PWork(cr)))));
    Chr(C_Spell.DRUID_LIST): ClassCanCastSpell := Boolean(cr^.mgWisdom > 8) and
      ((cr^.classLevels[C_Class.RANGER_LEVEL] > 6) or
       (Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))) and
        (cr^.classLevels2[C_Class.RANGER_LEVEL] > 6)));
    Chr(C_Spell.MAGIC_USER_LIST): if cr^.mgIntelligence > 8 then begin
          if ((cr^.classLevels[C_Class.MAGE_LEVEL] > 0) or
              (Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))) and
               (cr^.classLevels2[C_Class.MAGE_LEVEL] > 0))) and
              ((cr^.race <> C_Race.HUMAN) or (cr^.mgArmor = nil) or (GDVars.interfaceState <> C_Ifc.IN_COMBAT)) then
            ClassCanCastSpell := True;
          if (cr^.classLevels[C_Class.RANGER_LEVEL] > 8) or
              (Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))) and
               (cr^.classLevels2[C_Class.RANGER_LEVEL] > 8)) then
            ClassCanCastSpell := True;
        end;
    #3: ClassCanCastSpell := False;
  end;
end;

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
begin
  case selType of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := '';
  end;
  if selType in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if selType = 2 then
    bottomRow := 15
  else
    bottomRow := 22;
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    redraw := True;
    idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, 5, 38, bottomRow, GDVars.spellList,
                                addExit, redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := GDVars.spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  if ch in [C_Keys.NONE, 'E'] then
    SpellSelection := 0
  else
    SpellSelection := GDVars.spellIds[count];
  if selType = 3 then
    GDVars.currentScrollPtr := GDVars.scrollPtrs[count];
  MenuCore.FreeStringList(GDVars.spellList);
end;

{ Appends a spell to the scroll spell list (and its id list), with a level heading when its level differs from the last
  spell's.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  p: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := GDVars.spellList;
  if GDVars.spellList = nil then begin
    GetMem(p, SizeOf(Types.TItemNode));
    GDVars.spellList := p;
    lastLevel := 0;
    count := 0;
  end else begin
    count := 1;
    while p^.next <> nil do begin
      if p^.inUse = 0 then
        Inc(count);
      p := p^.next;
    end;
    lastLevel := GDConsts.spellTable[GDVars.spellIds[count - 1]].levelS;
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GDConsts.spellTable[spell and C_Spell.ID_MASK].levelS <> lastLevel then begin
    p^.name := GDConsts.spellLevelNames[GDConsts.spellTable[spell and C_Spell.ID_MASK].levelS];
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
    p^.next := nil;
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := '  ';
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
end;

{ Inserts a spell into the spell list in level order. A spell already listed is counted again instead
  (GDVars.spellCounts), and its row shows the count, so a spell memorized several times takes one row. The first call
  clears the counts. The insertion point is the first row whose spell's level is higher, or the row of the same spell; a
  new row's count and spell id are shifted into GDVars.spellCounts and GDVars.spellIds at its place. The row's name is
  rebuilt each time, so its count stays current.
  @param(spell The spell, with the pending flag for one being memorized.) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  tmp: Byte;
  p: Types.PItemRec;
  newNode: Types.PItemRec;
  count: ShortInt;
  newLevel: ShortInt;
  k: Byte;
begin
  p := GDVars.spellList;
  if GDVars.spellList = nil then begin
    FillChar(GDVars.spellCounts, 81, 0);
    GetMem(p, SizeOf(Types.TItemNode));
    p^.next := nil;
    GDVars.spellList := p;
    newLevel := 0;
    count := 0;
    GDVars.spellCounts[count] := 1;
  end else begin
    count := 1;
    newLevel := 0;
    while (p^.next <> nil) and (GDConsts.spellTable[spell and C_Spell.ID_MASK].levelS >= newLevel) do begin
      if p^.inUse = 0 then
        if GDVars.spellIds[count - 1] <> (spell and C_Spell.ID_MASK) then
          Inc(count);
      p := p^.next;
      newLevel := GDConsts.spellTable[GDVars.spellIds[count]].levelS;
    end;
    if GDVars.spellIds[count - 1] <> (spell and C_Spell.ID_MASK) then begin
      newLevel := GDConsts.spellTable[GDVars.spellIds[count - 1]].levelS;
      GetMem(newNode, SizeOf(Types.TItemNode));
      newNode^.next := p^.next;
      p^.next := newNode;
      p := p^.next;
      carry := 1;
      for k := count to 80 do begin
        tmp := GDVars.spellCounts[k];
        GDVars.spellCounts[k] := carry;
        carry := tmp;
      end;
    end else begin
      Dec(count);
      newLevel := GDConsts.spellTable[spell and C_Spell.ID_MASK].levelS;
      Inc(GDVars.spellCounts[count]);
    end;
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := '  ';
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  if GDVars.spellCounts[count] > 1 then
    p^.name := p^.name + ' (' + CharHlp.Uint8Str(GDVars.spellCounts[count]) + ')';
  if GDVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
    carry := GDVars.spellIds[count];
    GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
    for k := count + 1 to 80 do begin
      tmp := GDVars.spellIds[k];
      GDVars.spellIds[k] := carry;
      carry := tmp;
    end;
  end;
end;

{ List the current scroll's spells (AddScrollSpellLine), identifying it first for a reader of magic or, for a cleric's
  scroll, a cleric; an unidentified scroll lists nothing.
  @param(forScribe True to list only the spells being scribed.) }
procedure AddScrollSpells(forScribe: Boolean);
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  if CharHlp.HasEffect(GDVars.curChar, Magic.EFF_READ_MAGIC, Types.PEffectRec(eff)) or
      ((ShortInt(ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.CLERIC_LEVEL)) > 0) and
       (GDVars.baseItems[GDVars.currentScrollPtr^.itemType].slot = 12)) then
    GDVars.currentScrollPtr^.unidMask := 0;
  if GDVars.currentScrollPtr^.unidMask = 0 then
    for i := 1 to SizeOf(GDVars.currentScrollPtr^.spells) do begin
      if (forScribe and (GDVars.currentScrollPtr^.spells[i] > C_Spell.PENDING_FLAG)) or
          (not forScribe and (GDVars.currentScrollPtr^.spells[i] > 0)) then begin
        Magic.AddScrollSpellLine(GDVars.currentScrollPtr^.spells[i]);
        GDVars.scrollPtrs[GDVars.scrollCount] := GDVars.currentScrollPtr;
        Inc(GDVars.scrollCount);
      end;
    end;
end;

{ Clears the scroll table, then adds the spells of each readable item the current character carries, setting the casting
  item to each in turn; the casting item ends as nil.
  @param(forScribe True to add only the spells queued for scribing.) }
procedure AddAllScrollSpells(forScribe: Boolean);
var
  i: Byte;
begin
  for i := 0 to SizeOf(GDVars.scrollPtrs) div SizeOf(GDVars.scrollPtrs[0]) - 1 do
    GDVars.scrollPtrs[i] := nil;
  GDVars.scrollCount := 0;
  GDVars.currentScrollPtr := GDVars.curChar^.itemsAddr;
  while GDVars.currentScrollPtr <> nil do begin
    if Magic.ItemReadable(GDVars.currentScrollPtr) then
      Magic.AddScrollSpells(forScribe);
    GDVars.currentScrollPtr := GDVars.currentScrollPtr^.next;
  end;
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  i: Byte;
  cur: Types.PItemRec;
  n: Types.PItemRec;
  prevLvl: ShortInt;
  lvl: ShortInt;
  doBuild: Boolean;
  prevCls: ShortInt;
  cls: ShortInt;

  { A heading line: the level's and the class's names. }
  function SpellListHeading(level, castClass: ShortInt): String;
  var
    { Unused in this version; see the other implementations of this routine. }
    heading: String;
  begin
    SpellListHeading := GDConsts.spellLevelNames[level] + ' ' + GDConsts.spellClassNames[castClass] + 'spells';
  end;

begin
  doBuild := True;
  GenerateSpellList := False;
  GDVars.spellList := nil;
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
    GDVars.spellIds[i] := 0;
  case menuType of
    0: for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
         if (GDVars.curChar^.memorizedSpells[i] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) and
             (GDVars.curChar^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    5: for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
         if (GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    1: for i := 1 to SizeOf(GDConsts.spellTable) div SizeOf(GDConsts.spellTable[1]) do
         if (GDVars.curChar^.spellsKnown[i] <> 0) and Magic.ClassCanCastSpell(GDVars.curChar, i) then
           Magic.AddSpellToList(i);
    2: begin Magic.AddScrollSpells(False); doBuild := False; end;
    3: begin Magic.AddAllScrollSpells(False); doBuild := False; end;
    6: begin Magic.AddAllScrollSpells(True); doBuild := False; end;
    4: for i := 1 to SizeOf(GDConsts.spellTable) div SizeOf(GDConsts.spellTable[1]) do
         if (GDVars.curChar^.slots[GDConsts.spellTable[i].castClassS, GDConsts.spellTable[i].levelS] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, i) and (GDVars.curChar^.spellsKnown[i] = 0) then
           Magic.AddSpellToList(i);
  end;
  if GDVars.spellList <> nil then begin
    if doBuild then begin
      i := 0;
      lvl := GDConsts.spellTable[GDVars.spellIds[i]].levelS;
      cls := GDConsts.spellTable[GDVars.spellIds[i]].castClassS;
      GetMem(n, SizeOf(Types.TItemNode));
      n^.next := GDVars.spellList;
      GDVars.spellList := n;
      GDVars.spellList^.name := SpellListHeading(lvl, cls);
      GDVars.spellList^.inUse := 1;
      cur := GDVars.spellList;
      repeat
        if GDVars.spellIds[i] <> 0 then begin
          prevLvl := lvl;
          prevCls := cls;
          lvl := GDConsts.spellTable[GDVars.spellIds[i]].levelS;
          cls := GDConsts.spellTable[GDVars.spellIds[i]].castClassS;
          if (prevLvl <> lvl) or (prevCls <> cls) then begin
            GetMem(n, SizeOf(Types.TItemNode));
            n^.next := cur^.next;
            cur^.next := n;
            cur := cur^.next;
            cur^.name := SpellListHeading(lvl, cls);
            cur^.inUse := 1;
          end;
        end;
        Inc(i);
        cur := cur^.next;
      until cur = nil;
    end;
    GenerateSpellList := True;
  end;
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GDVars.usingItem = False then
    r := GDConsts.spellTable[spell].rangeBase + GDConsts.spellTable[spell].rangePerLevel * CharHlp.GetCasterLevel(spell)
  else
    r := GDConsts.spellTable[spell].rangePerLevel * 6 + GDConsts.spellTable[spell].rangeBase;
  if (r = 0) and (GDConsts.spellTable[spell].touch <> 0) then
    r := 1;
  if r = 255 then
    r := 1;
  CalcSpellRange := r;
end;

{ Works out a spell's duration: spells 40, 57, 59, 61 and 63 roll their own (63 longer outside combat), 67 lasts a day
  (1440 minutes), and any other spell lasts its base plus its duration per level times the caster's level.
  @param(spell The spell.)
  @returns(The duration in minutes.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    40: d := FxEngine.RollDice(1, 6) * 10;
    57, 61: d := FxEngine.RollDice(5, 4);
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    63: if GDVars.interfaceState = C_Ifc.IN_COMBAT then
                d := FxEngine.RollDice(2, 10) * 10
              else
                d := (FxEngine.RollDice(1, 10) + 10) * 10;
    67: d := 1440;
  else
    d := GDConsts.spellTable[spell].durBase + GDConsts.spellTable[spell].durPerLevel * CharHlp.GetCasterLevel(spell);
  end;
  CalcSpellDuration := d;
end;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(eff The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(elem The damage's element mask.)
  @param(msg Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PWork;
  saved: Boolean;
begin
  if damage = 0 then
    GDVars.elementMask := 0
  else
    GDVars.elementMask := elem;
  if GDVars.numberTargetedCreatures = 0 then
    Exit;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GDVars.numberTargetedCreatures do begin
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      if not GDConsts.spellTable[spell].saveEffect then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(Pointer(tgt), GDConsts.spellTable[spell].saveType, 0);
      if GDConsts.spellTable[GDVars.currentSpellBeing].rangeBase = 255 then begin
        CharHlp.RecalcStats(Types.PWork(tgt));
        FxEngine.TriggerEffectsWithCondition(11, Pointer(tgt));
        if not FxEngine.AttackRoll(GDVars.curChar, Types.PWork(tgt), tgt^.acCur) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(Pointer(tgt), damage, GDConsts.spellTable[spell].saveResult, saved);
      if GDConsts.spellTable[spell].effectId > 0 then
        FxEngine.AddEffectWithMessage(Pointer(tgt), GDConsts.spellTable[spell].effectId, Magic.CalcSpellDuration(spell),
                                      effLevel, onRemove,
                             GDConsts.spellTable[spell].saveEffect, saved, msg);
    end;
  end;
  GDVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  if GDVars.castTargetPtr = nil then
    GDVars.castTargetPtr := GDVars.curChar;
  GDVars.targetCreaturePtr[1] := GDVars.curChar;
  GDVars.numberTargetedCreatures := 1;
  cast := True;
  case GDConsts.spellTable[spell].targeting of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         CharHlp.SelectChar('Cast Spell on whom', True, GDVars.castTargetPtr);
         if GDVars.castTargetPtr = nil then begin
           GDVars.targetCreaturePtr[1] := nil;
           GDVars.numberTargetedCreatures := 0;
           cast := False;
         end else
           GDVars.targetCreaturePtr[1] := GDVars.castTargetPtr;
       end;
    4: begin
         GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures] := GDVars.creatureList;
         while GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures]^.nextCharAddr <> nil do begin
           GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures + 1] :=
             GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures]^.nextCharAddr;
           Inc(GDVars.numberTargetedCreatures);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  { the d2 roll }
  mr: Byte;
  p: Types.PWork;
  { HasEffect's scratch }
  buf: array[0..3] of Byte;
  announced: Boolean;
begin
  p := GDVars.curChar;
  ok := True;
  if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (GDConsts.spellTable[spell].targeting = 0) then begin
    if GDVars.usingItem = False then begin
      TextRend.DisplayString(1, 19, LightGreen, Black, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, LightGreen, Black, 'can''t be cast here...');
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, LightGreen, White) = 'Y' then
        CharHlp.RemoveSpell(p, spell);
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, Black, 'That Item');
      TextRend.DisplayString(1, 20, LightGreen, Black, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, LightGreen, White) = 'Y' then
        sel := True;
    end;
    ai := False;
    ok := False;
  end;
  if CharHlp.HasEffect(Types.PWork(p), 74, Types.PEffectRec(buf)) then begin
    mr := FxEngine.RollDice(1, 2);
    if mr = 1 then begin
      Magic.PrintCastSpellMsg(p, 'miscasts', spell);
      ai := False;
      ok := False;
      sel := True;
    end;
  end;
  announced := False;
  while ok do begin
    GDVars.spellFps.targetMenu(spell, b, sel);
    if sel then begin
      if (not announced) and ai and (GDVars.usingItem = False) then begin
        Magic.PrintCastSpellMsg(p, 'casts', spell);
        announced := True;
      end;
      ok := False;
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        CharHlp.BuildIconFacings(18);
        x := CbtMap.CombatCellX(Pointer(p));
        y := CbtMap.CombatCellY(Pointer(p));
        if (x = GDVars.gTargetX) and (y = GDVars.gTargetY) then
          k := p^.combatLink^.direction
        else begin
          k := C_Dir.NORTH;
          while not Pathing.IsDirToward(x, y, GDVars.gTargetX, GDVars.gTargetY, k) do
            Inc(k);
        end;
        GDVars.combatMapVisible := 1;
        CbtMap.SetCreatureFacing(Pointer(p), k, 1, 0);
        case spell of
          87, 47: SoundDrv.SoundCommand(11);
          51: SoundDrv.SoundCommand(8);
        else
          SoundDrv.SoundCommand(2);
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 30);
        if CbtMap.CombatIconVisible(Pointer(p), 0) then begin
          CbtMap.SetCreatureFacing(Pointer(p), p^.combatLink^.direction, 1, 1);
          CbtMap.SetCreatureFacing(Pointer(p), p^.combatLink^.direction, 0, 0);
        end;
      end;
      FxEngine.RemoveInvisibility(Types.PWork(p));
      if GDVars.usingItem = False then
        CharHlp.RemoveSpell(p, spell);
      GDVars.currentSpellBeing := spell;
      GDVars.spellFps.spells[GDVars.currentSpellBeing];
      GDVars.currentSpellBeing := 0;
      GDVars.currentSpellAffectsFlag := 0;
    end else begin
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        ok := False
      else if b then
        ok := False
      else if MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y' then
      begin
        CharHlp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItem = False then
          CharHlp.RemoveSpell(p, spell);
        ok := False;
      end;
    end;
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from the origin through the aimed cell,
  extended to the cone's length and cut short by walls, and with two or three rays on one or two more lines to cells
  beside its end; each creature once. Note: once a creature has been met twice on the main line, no later creature on it
  is added. Note: clearing the list writes one byte past its end.
  @param(ox The column of the cone's origin.)
  @param(oy The row of the cone's origin.)
  @param(tx The column of the aimed cell.)
  @param(ty The row of the aimed cell.)
  @param(rays The number of lines: 1, 2 or 3.)
  @param(reach The cone's length in cells.) }
procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte);
type
  TListStore = packed record
    terrIdx: Byte;
    list: array[0..29] of Byte;
  end;
var
  side2X: ShortInt;
  side2Y: ShortInt;
  side1X: ShortInt;
  side1Y: ShortInt;
  req: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  i: Byte;
  n: Byte;
  lastDirIdx: Byte;
  dirs: array[0..49] of Byte;
  listStore: TListStore;
  listCount: Byte;
  destIdx: Byte;
  centerDir: Byte;
  walkDist: Word;
  found: Boolean;

  { Starts the line walk req from (sx, sy) to (ex, ey). }
  procedure SetLine(sx, sy, ex, ey: ShortInt);
  begin
    req.sx := sx;
    req.sy := sy;
    req.ex := ex;
    req.ey := ey;
    Pathing.pathFind(req);
  end;

  { Keep a cell on the arena. }
  procedure ClampCell(var cx, cy: ShortInt);
  begin
    if cx > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then cx := SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1
    else if cx < 0 then cx := 0;
    if cy > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
      cy := SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1
    else if cy < 0 then cy := 0;
  end;

  { Adds each creature on the rest of the walked line to the list, once. }
  procedure CollectAlong;
  var
    j: Byte;
    cfound: Boolean;
  begin
    repeat
      done := not Pathing.nextPathStep(req);
      if not done then begin
        CbtMap.GetArenaContents(ShortInt(req.cx), ShortInt(req.cy), listStore.list[0], listStore.terrIdx);
        j := 1;
        cfound := False;
        if listStore.list[0] > 0 then
          repeat
            if listStore.list[j] = listStore.list[0] then
              cfound := True
            else if listStore.list[j] = 0 then begin
              listStore.list[j] := listStore.list[0];
              cfound := True;
            end else
              Inc(j);
          until cfound;
      end;
    until done;
  end;

begin
  n := 0;
  SetLine(ox, oy, tx, ty);
  repeat
    done := not Pathing.nextPathStep(req);
    if not done then begin
      dirs[n] := req.step;
      Inc(n);
    end;
  until done;

  lastDirIdx := n - 1;
  n := 0;
  reach := reach shl 1;
  i := req.dist;
  done := False;
  while (i < reach) and not done do begin
    if (tx < SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and (tx > 0) and
        (ty < SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and
        (ty > 0) then begin
      case dirs[n] of
        C_Dir.NORTH, C_Dir.EAST, C_Dir.SOUTH, C_Dir.WEST: Inc(i, 2);
        C_Dir.NORTHEAST, C_Dir.SOUTHEAST, C_Dir.SOUTHWEST, C_Dir.NORTHWEST: Inc(i, 3);
      end;
      Inc(tx, GDConsts.dirDX[dirs[n]]);
      Inc(ty, GDConsts.dirDY[dirs[n]]);
      if n = lastDirIdx then n := 0 else Inc(n);
    end else
      done := True;
  end;

  ClampCell(tx, ty);
  walkOk := Pathing.walkLine(ox, oy, tx, ty, walkDist, GDVars.combatArenaPtr);
  SetLine(ox, oy, tx, ty);

  FillChar(listStore.list[1], 30, 0);
  listCount := 1;
  repeat
    done := not Pathing.nextPathStep(req);
    if not done then begin
      CbtMap.GetArenaContents(ShortInt(req.cx), ShortInt(req.cy), listStore.list[0], listStore.terrIdx);
      if listStore.list[0] > 0 then begin
        if listCount > 1 then begin
          for GDVars.sharedLoopIndex := 1 to listCount - 1 do
            if listStore.list[GDVars.sharedLoopIndex] = listStore.list[0] then
              found := True;
        end else
          found := False;
        if not found then begin
          listStore.list[listCount] := listStore.list[0];
          Inc(listCount);
        end;
        centerDir := req.step;
      end;
    end;
  until done;

  if rays > 1 then begin
    side2X := tx + GDConsts.sideRayDX1[centerDir];
    side2Y := ty + GDConsts.sideRayDY1[centerDir];
    ClampCell(side2X, side2Y);
    side1X := tx + GDConsts.sideRayDX2[centerDir];
    side1Y := ty + GDConsts.sideRayDY2[centerDir];
    ClampCell(side1X, side1Y);
    SetLine(ox, oy, side1X, side1Y);
    CollectAlong;
    if rays > 2 then begin
      SetLine(ox, oy, side2X, side2Y);
      CollectAlong;
    end;
  end;

  listCount := 1;
  destIdx := 1;
  GDVars.numberTargetedCreatures := 0;
  if listStore.list[1] <> 0 then
    repeat
      if GDVars.creaturePtr[listStore.list[listCount]] <> GDVars.curChar then begin
        Inc(GDVars.numberTargetedCreatures);
        GDVars.targetCreaturePtr[destIdx] := GDVars.creaturePtr[listStore.list[listCount]];
        Inc(destIdx);
      end;
      Inc(listCount);
    until listStore.list[listCount] = 0;
end;

{ Applies the current spell's effect to each target, drawing a bolt to all but the last, with a save at the given
  modifier. Large or non-person targets always save (except against spell 94), and for spells 79 and 81 the last target
  always saves.
  @param(saveMod The saving-throw modifier.)
  @param(msg Reports the effect on each target.) }
procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40);
var
  tgt: Types.PWork;
  saved: Boolean;
  i: Byte;
  saveNegates: Boolean;
begin
  for i := GDVars.numberTargetedCreatures downto 1 do begin
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      if i < GDVars.numberTargetedCreatures then begin
        SoundDrv.SoundCommand(2);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(GDVars.curChar)),
                                        CbtMap.CombatCellY(Pointer(GDVars.curChar)), CbtMap.CombatCellX(Pointer(tgt)),
                                        CbtMap.CombatCellY(Pointer(tgt)), 4, 30);
      end;
      if ((GDVars.currentSpellBeing = 79) or (GDVars.currentSpellBeing = 81)) and
          (i = GDVars.numberTargetedCreatures) then begin
        saved := True;
        saveNegates := True;
      end else begin
        saved := FxEngine.RollSavingThrow(Pointer(tgt), GDConsts.spellTable[GDVars.currentSpellBeing].saveType,
                                          saveMod);
        saveNegates := GDConsts.spellTable[GDVars.currentSpellBeing].saveEffect;
      end;
      if ((tgt^.charType > 1) or (tgt^.iconDimensions > 1)) and (GDVars.currentSpellBeing <> 94) then
        saved := True;
      FxEngine.AddEffectWithMessage(Pointer(tgt), GDConsts.spellTable[GDVars.currentSpellBeing].effectId,
                           Magic.CalcSpellDuration(GDVars.currentSpellBeing),
                           CharHlp.GetCasterLevel(GDVars.currentSpellBeing), False, saveNegates, saved, msg);
    end;
  end;
end;

{ Resolves the current spell on the targets of one side; Bless in combat also skips a target with an enemy next to it.
  @param(hostFlag The side affected.)
  @param(msg The effect's message.) }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.currentSpellAffectsFlag := 1;
  for i := 1 to GDVars.numberTargetedCreatures do begin
    if (GDVars.targetCreaturePtr[i]^.hostile <> hostFlag) or
        ((GDVars.currentSpellBeing = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.targetCreaturePtr[i], 1) > 0)) then
      GDVars.targetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, msg);
end;

{ ==== the per-spell handlers ========================================== }

{ Casts Bless on the caster's own side. }
procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.curChar^.hostile, 'is Blessed');
end;

{ Casts Curse on the caster's enemies. }
procedure SpellCurse;
begin
  Magic.CastOneSide(ShortInt(CharHlp.NotHostile(GDVars.curChar)), 'is Cursed');
end;

{ Casts Cure Light Wounds: restores 1d8 hit points to the first target. }
procedure SpellCureLightWounds;
begin
  if GDVars.numberTargetedCreatures = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.targetCreaturePtr[1]), FxEngine.RollDice(1, 8), False) then
    CharHlp.AnnounceHealStatus(GDVars.targetCreaturePtr[1]);
end;

{ Casts Cause Light Wounds: 1d8 magic damage. }
procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(1, 8), 8, '');
end;

{ Applies a detection spell's effect to the targets. }
procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is affected');
end;

{ Applies a protection spell's effect to the targets. }
procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is protected');
end;

{ Applies Resist Cold's effect to the targets. }
procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is cold-resistant');
end;

{ Casts Burning Hands: fire damage of 1 point per caster level. }
procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, CharHlp.GetCasterLevel(GDVars.currentSpellBeing), 9, '');
end;

{ Spell 10 (Charm Person): a large or monstrous target is unaffected; otherwise an earlier charm on it is removed and it
  is charmed to the caster's side, its charm handler run. }
procedure SpellCharmPerson;
var
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is unaffected', C_Msg.MESSAGE_ROW, True)
  else begin
    if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.CHARM, Types.PEffectRec(eff)) then begin
      GDVars.effectLockFlag := 1;
      FxEngine.RemoveEffect(Pointer(tgt), C_Effect.CHARM, nil);
      GDVars.effectLockFlag := 0;
    end;
    Magic.ResolveSpell(GDVars.currentSpellBeing,
                 GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.currentSpellBeing), True, 0, 0,
                 'is charmed');
    if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.CHARM, Types.PEffectRec(eff)) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, Pointer(GDVars.targetCreaturePtr[1]), eff, False);
  end;
end;

{ Casts Enlarge: Strength by caster level (18 at level 1, 18/01, 18/51, 18/76, 18/91 and 18/100 at 2 to 6, 19 to 21 at 7
  to 9, 22 at 10 and 11, and 18 at any other level) as the Enlarge effect, when that beats the target's own ("is
  stronger"). }
procedure SpellEnlarge;
var
  enc: Byte;
  tgt: Types.PWork;
begin
  tgt := GDVars.targetCreaturePtr[1];
  GDVars.gSpellTemp1 := 18;
  GDVars.gSpellTemp2 := 0;
  case CharHlp.GetCasterLevel(GDVars.currentSpellBeing) of
    1: GDVars.gSpellTemp2 := 0;
    2: GDVars.gSpellTemp2 := 1;
    3: GDVars.gSpellTemp2 := 51;
    4: GDVars.gSpellTemp2 := 76;
    5: GDVars.gSpellTemp2 := 91;
    6: GDVars.gSpellTemp2 := 100;
    7: GDVars.gSpellTemp1 := 19;
    8: GDVars.gSpellTemp1 := 20;
    9: GDVars.gSpellTemp1 := 21;
    10, 11: GDVars.gSpellTemp1 := 22;
  end;
  if FxEngine.AdjustForNewStrength(Types.PWork(tgt), GDVars.gSpellTemp1, GDVars.gSpellTemp2, enc) then begin
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is stronger', C_Msg.MESSAGE_ROW, True);
    FxEngine.AddEffect(Pointer(tgt), C_Effect.ENLARGE, Magic.CalcSpellDuration(GDVars.currentSpellBeing), enc,
                       True);
    FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
  end else
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is unaffected', C_Msg.MESSAGE_ROW, True);
end;

{ Spell 13 (Reduce): a target that fails its save loses its Enlarge ('has been reduced'). }
procedure SpellReduce;
var
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if tgt <> nil then
    if GDVars.numberTargetedCreatures > 0 then
      if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then
        if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.ENLARGE, Types.PEffectRec(eff)) then begin
          GDVars.effectLockFlag := 1;
          FxEngine.RemoveEffect(Pointer(tgt), C_Effect.ENLARGE, nil);
          GDVars.effectLockFlag := 0;
          FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
          CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'has been reduced', C_Msg.MESSAGE_ROW, True);
        end;
end;

{ Casts Friends: the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, FxEngine.RollDice(2, 4), True, 0, 0, 'is friendly');
  FxEngine.RecalcAbility(Pointer(GDVars.curChar), C_Stat.CHARISMA);
end;

{ Casts Magic Missile: (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing) + 1;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, cl div 2 + FxEngine.RollDamageDice(cl div 2, 4), 8, '');
end;

{ Applies Shield's effect to the targets. }
procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is shielded');
end;

{ Casts Shocking Grasp: 1d8 plus the caster level in electrical damage. }
procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False,
               FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.currentSpellBeing), 12, '');
end;

{ Casts Sleep with a 4d4 hit-dice pool. Each target costs by its level: 0..1 costs 1, 2 costs 2, 3 costs 4, 4 costs 6, 5
  costs 10 for a creature of the monster race and 20 otherwise, and higher levels cost 20. Animated dead, targets
  already asleep and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target
  order. }
procedure SpellSleep;
type
  THdLvl = (hd0, hd1, hd2, hd3, hd4, hd5, hd6, hd7);
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  GDVars.currentSpellAffectsFlag := 1;
  GDVars.gSpellTemp1 := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.numberTargetedCreatures do begin
    case THdLvl(GDVars.targetCreaturePtr[i]^.mgLevelHighest) of
      hd0..hd1: GDVars.gSpellTemp2 := 1;
      hd2: GDVars.gSpellTemp2 := 2;
      hd3: GDVars.gSpellTemp2 := 4;
      hd4: GDVars.gSpellTemp2 := 6;
      hd5: if GDVars.targetCreaturePtr[i]^.race = C_Race.MONSTER then
              GDVars.gSpellTemp2 := 10
            else
              GDVars.gSpellTemp2 := 20;
    else
      GDVars.gSpellTemp2 := 20;
    end;
    if (GDVars.targetCreaturePtr[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.targetCreaturePtr[i], C_Effect.SLEEP, Types.PEffectRec(eff))) and
        (GDVars.gSpellTemp1 >= GDVars.gSpellTemp2) then
      Dec(GDVars.gSpellTemp1, GDVars.gSpellTemp2)
    else
      GDVars.targetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'falls asleep');
end;

{ Hold Person and Hold Monsters: puts the hold effect on up to four targets, with a save modifier by their number: -2 or
  -3 for one, depending on the spell, -1 for two and 0 for three or four. Note: more targets leave the modifier
  undefined. }
procedure SpellHold;
var
  smod: ShortInt;
begin
  case GDVars.numberTargetedCreatures of
    1: if GDVars.currentSpellBeing = 23 then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
    3, 4: smod := 0;
  end;
  Magic.ApplyEffectToTargets(smod, 'is held');
end;

{ Applies Resist Fire's effect to the targets. }
procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is fire resistant');
end;

{ Applies Silence's effect to the targets. }
procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is silenced');
end;

{ Spell 26 (Slow Poison): a poisoned target that is not animated gets up with at least 1 hit point and its poison
  slowed. }
procedure SpellSlowPoison;
var
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.targetCreaturePtr[1] := nil
  else if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.POISONED, Types.PEffectRec(eff)) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_END, nil);
    GDVars.effectLockFlag := 0;
    Magic.ResolveSpell(GDVars.currentSpellBeing, 255, True, 0, 0, 'is affected');
    FxEngine.CallEffectHandler(78, Pointer(tgt), nil, True);
    FxEngine.AddEffect(Pointer(tgt), C_Effect.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Spell 27 (Snake Charm): charm snakes (creature type 14) whose hit points fit within the caster's. }
procedure SpellSnakeCharm;
var
  p: Types.PWork;
begin
  GDVars.gSpellTemp1 := GDVars.curChar^.hpCur;
  GDVars.numberTargetedCreatures := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.charType = 14 then
      if p^.enabled <> 0 then
        if GDVars.gSpellTemp1 >= p^.hpCur then begin
        GDVars.gSpellTemp1 := GDVars.gSpellTemp1 - p^.hpCur;
        Inc(GDVars.numberTargetedCreatures);
        GDVars.targetCreaturePtr[GDVars.numberTargetedCreatures] := p;
      end;
    p := p^.nextCharAddr;
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is charmed');
end;

{ Casts Spiritual Hammer: applies the spell's effect, then runs the Spiritual Hammer effect handler for the first
  target. }
procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRITUAL_HAMMER, Pointer(GDVars.targetCreaturePtr[1]), nil, False);
end;

{ Applies the Invisibility spells' effect to the targets. }
procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Applies Knock's effect to the targets. }
procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'Knock-Knock');
end;

{ Casts Mirror Image: 1d4 images in the effect strength's high nibble, the caster level in the low one. }
procedure SpellMirrorImage;
var
  arg: Byte;
begin
  arg := FxEngine.RollDice(1, 4) shl 4;
  arg := CharHlp.GetCasterLevel(GDVars.currentSpellBeing) or arg;
  Magic.ResolveSpell(GDVars.currentSpellBeing, arg, False, 0, 0, 'is duplicated');
end;

{ Applies Ray of Enfeeblement's effect to the targets. }
procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is weakened');
end;

{ Casts Stinking Cloud: a cloud on the four cells around the target cell. A node joins the stinking-cloud list, numbered
  among the caster's clouds and tracked by an effect on the caster; each cell's terrain is saved (for a cell under
  another cloud or a body, the terrain beneath it) and passable cells get the cloud tile. Creatures inside take the
  cloud once each. Note: the count of the caster's clouds skips the list's last node. }
procedure SpellStinkingCloud;
var
  cloud: Types.PArenaNode;
  node: Types.PArenaNode;
  crIdx: array[1..4] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  d: Byte;
begin
  GDVars.currentSpellAffectsFlag := 1;
  cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  myClouds := 0;
  node := GDVars.linkedListStinkingPtr;
  if GDVars.linkedListStinkingPtr = nil then begin
    GetMem(GDVars.linkedListStinkingPtr, SizeOf(Types.TArenaNode));
    node := GDVars.linkedListStinkingPtr;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(Types.TArenaNode));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(node^), 0);
  FxEngine.AddEffect(Pointer(GDVars.curChar), Magic.EFF_CAST_STINK, cl, cl + myClouds * 16, True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.gTargetX;
  node^.ulY := GDVars.gTargetY;
  for k := 1 to SizeOf(GDConsts.cloudCells) do begin
    d := GDConsts.cloudCells[k];
    CbtMap.GetArenaContents(GDVars.gTargetX + GDConsts.dirDX[d], GDVars.gTargetY + GDConsts.dirDY[d], crIdx[k], terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    if terr = C_Terr.TERRAIN_STINK_CLOUD then begin
      cloud := GDVars.linkedListStinkingPtr;
      while cloud <> nil do begin
        if cloud <> node then
          for j := 1 to SizeOf(GDConsts.cloudCells) do
            if (cloud^.exists[j] <> 0) and
                (cloud^.ulX + GDConsts.dirDX[GDConsts.cloudCells[j]] = GDVars.gTargetX + GDConsts.dirDX[d]) and
                (cloud^.ulY + GDConsts.dirDY[GDConsts.cloudCells[j]] = GDVars.gTargetY + GDConsts.dirDY[d]) then
              if cloud^.under[j] <> C_Terr.TERRAIN_STINK_CLOUD then
                terr := cloud^.under[j];
        cloud := cloud^.next;
      end;
    end else if terr = C_Terr.TERRAIN_CORPSE then begin
      for j := 1 to GDVars.downedCount do
        if GDVars.combatDownedCharacter[j].x = GDVars.gTargetX + GDConsts.dirDX[d] then
          if GDVars.combatDownedCharacter[j].y = GDVars.gTargetY + GDConsts.dirDY[d] then
            terr := GDVars.combatDownedCharacter[j].under;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.combatArenaPtr^.cells[GDVars.gTargetY + GDConsts.dirDY[d],
                  GDVars.gTargetX + GDConsts.dirDX[d]] := C_Terr.TERRAIN_STINK_CLOUD;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a noxious cloud', C_Msg.MESSAGE_ROW, False);
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  { a creature can stand in two of the cloud's cells: keep it once, so the cloud takes it once }
  for k := 2 to SizeOf(crIdx) do
    for j := 1 to SizeOf(crIdx) do
      if (crIdx[k] = crIdx[j]) and (k <> j) then
        crIdx[k] := 0;
  for k := 1 to SizeOf(crIdx) do
    if crIdx[k] > 0 then
      FxEngine.ConsiderTerrainEffects(Pointer(GDVars.creaturePtr[crIdx[k]]), 1);
end;

{ Spell 35 (Strength): raise the target's strength by 1d8 for a warrior, 1d6 for a cleric or thief, else 1d4, past 18
  into exceptional strength for a warrior, when that is higher than its own. }
procedure SpellStrength;
var
  tgt: Types.PWork;
  exStr: Byte;
  roll: Byte;
  newStr: Byte;
  { AdjustForNewStrength's var parameter, then AddEffect's argument }
  effStr: Byte;
begin
  exStr := 0;
  tgt := GDVars.targetCreaturePtr[1];
  if (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(tgt), C_Class.FIGHTER_LEVEL)) > 0) or
      (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(tgt), C_Class.PALADIN_LEVEL)) > 0) or
      (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(tgt), C_Class.RANGER_LEVEL)) > 0) then
    roll := FxEngine.RollDice(1, 8)
  else if (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(tgt), C_Class.CLERIC_LEVEL)) > 0) or
    (ShortInt(ClassCal.EffectiveClassLevel(Types.PWork(tgt), C_Class.THIEF_LEVEL)) > 0) then
    roll := FxEngine.RollDice(1, 6)
  else
    roll := FxEngine.RollDice(1, 4);
  newStr := tgt^.mgStrength + roll;
  if newStr > 18 then begin
    if (tgt^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
        (tgt^.classLevels2[C_Class.FIGHTER_LEVEL] > tgt^.movementBase) or
        (tgt^.classLevels[C_Class.PALADIN_LEVEL] > 0) or
        (tgt^.classLevels2[C_Class.PALADIN_LEVEL] > tgt^.movementBase) or
        (tgt^.classLevels[C_Class.RANGER_LEVEL] > 0) or
        (tgt^.classLevels2[C_Class.RANGER_LEVEL] > tgt^.movementBase) then begin
      exStr := tgt^.mgExStrCur + (newStr - 18) * 10;
      if exStr > 100 then
        exStr := 100;
      newStr := 18;
    end else
      newStr := 18;
  end;
  if FxEngine.AdjustForNewStrength(Types.PWork(tgt), newStr, exStr, effStr) then begin
    effStr := roll + 100;
    FxEngine.AddEffect(Pointer(tgt), C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.currentSpellBeing), effStr,
                       True);
    FxEngine.RecalcAbility(Pointer(tgt), C_Stat.STRENGTH);
  end;
end;

{ Casts Animate Dead: animates up to caster-level dead human creatures whose cell is still a valid location. The
  animation effect's strength is the old side times 16 plus the caster level. Each corpse joins the caster's side under
  computer control, becomes undead (undead level 2, base movement 6, attack level 0), loses its memorized spells and
  gets the animated NPC or player code; if it revives at its full maximum hit points it also gets the animation effect
  and the animated status. }
procedure SpellAnimateDead;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PWork;
begin
  GDVars.currentSpellAffectsFlag := 1;
  n := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  GDVars.numberTargetedCreatures := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_Status.DEAD_STATUS then
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(Pointer(p), CbtMap.CombatCellX(Pointer(p)), CbtMap.CombatCellY(Pointer(p)),
                                     True) then begin
          strength := p^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
          p^.hostile := GDVars.curChar^.hostile;
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.cbAttackLevel := 0;
          { from the saved movementBase }
          p^.moveRate := 6;
          for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
            p^.memorizedSpells[i] := 0;
          if p^.npc > C_Npc.MORALE_MASK then
            p^.npc := C_Npc.ANIMATED_NON_PLAYER
          else
            p^.npc := C_Npc.ANIMATED_PLAYER;
          p^.charType := 4;
          if GDVars.interfaceState = C_Ifc.IN_COMBAT then
            p^.combatLink^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(Pointer(p), p^.cbHpMax) then begin
            FxEngine.AddEffectWithMessage(Pointer(p), C_Effect.ANIMATE_DEAD, 0, strength, True, False, False,
                                          'is animated');
            p^.status := C_Status.ANIMATED;
          end;
        end;
    p := p^.next;
  end;
end;

{ Casts Cure Blindness: ends the first target's blindness ('can see'). }
procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.targetCreaturePtr[1], True, 'can see');
end;

{ Casts Cause Blindness: blinds the targets. }
procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is blind');
end;

{ Removes the first target's diseases under the effect lock: Diseased, the Strength-draining disease (with its hit-point
  and helpless effects) and effect 50 (with effect 57). Note: Camp's spell-effect list calls effect 50 Hot Fire Shield.
  @returns(True when any of the three was present.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLockFlag := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], C_Effect.DISEASE_STRENGTH) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(Pointer(GDVars.targetCreaturePtr[1]), C_Effect.DISEASE_HIT_POINTS, nil);
    FxEngine.RemoveEffect(Pointer(GDVars.targetCreaturePtr[1]), C_Effect.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], 50) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(Pointer(GDVars.targetCreaturePtr[1]), 57, nil);
  end;
  GDVars.effectLockFlag := 0;
end;

{ Casts Cure Disease: removes the first target's disease effects. }
procedure SpellCureDisease;
var
  { Unused in this version; see the other implementations of this routine. }
  cured: Boolean;
begin
  cured := Magic.RemoveDiseaseEffects;
end;

{ Applies Cause Disease's effect to the targets. }
procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, True, 0, 0, 'is diseased');
end;

{ Spells 41 and 46 (Dispel Magic): for each target, roll to strip each dispellable effect, the caster's level against
  the effect's ('is affected' when one goes), then roll to dispel each stinking cloud and cloudkill on the cells around
  the aim cell, by the levels of the two casters. Note: every pass of the target loop reads GDVars.targetCreaturePtr[1],
  so the dispel strips only the first target's effects, however many are targeted; each later pass rolls again against
  what the first target has left. Note: the sweep matches a cloudkill's cells through GDConsts.cloudCells, the stinking
  cloud's four-entry direction table, for all nine of the cloudkill's entries, so entries 5..9 read on into
  GDConsts.cloudCells9. It checks the center, north, northeast, east, southeast and south cells, and never a cloudkill's
  southwest, west or northwest cells. }
procedure SpellDispelMagic;
var
  i: Byte;
  cl: Byte;
  tgt: Types.PWork;
  removed: Boolean;
  found: Boolean;
  eff: Types.PEffectRec;
  nxt: Types.PEffectRec;
  lx: ShortInt;
  ly: ShortInt;
  terr: Byte;
  sel: Byte;
  nextNode: Types.PArenaNode;
  node: Types.PArenaNode;
  curNode: Types.PArenaNode;

  { Roll whether a cloud is dispelled, by the levels of the two casters. }
  function CloudDispelled(cr: Types.PWork): Boolean;
  begin
    GDVars.gSpellTemp2 :=
      ShortInt(cr^.fxClassA[C_Class.MAGE_LEVEL]) +
      ShortInt(cr^.fxClassB[C_Class.MAGE_LEVEL]) * ClassCal.EarlierClassActive(GDVars.curChar);
    if cl > GDVars.gSpellTemp2 then
      GDVars.gSpellTemp1 := (cl - GDVars.gSpellTemp2) * 5 + 50
    else if cl < GDVars.gSpellTemp2 then
      GDVars.gSpellTemp1 := 50 - (GDVars.gSpellTemp2 - cl) * 2
    else
      GDVars.gSpellTemp1 := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.gSpellTemp1;
  end;

begin
  GDVars.currentSpellAffectsFlag := 1;
  cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  for i := 1 to GDVars.numberTargetedCreatures do begin
    removed := False;
    tgt := GDVars.targetCreaturePtr[1];
    eff := tgt^.effects;
    while eff <> nil do begin
      nxt := eff^.next;
      if (eff^.strength < 255) and not (eff^.id in [C_Effect.SUFFOCATING, C_Effect.IMMOBILE]) then begin
        GDVars.gSpellTemp2 := eff^.strength and $F;
        if cl > GDVars.gSpellTemp2 then
          GDVars.gSpellTemp1 := (cl - GDVars.gSpellTemp2) * 5 + 50
        else if cl < GDVars.gSpellTemp2 then
          GDVars.gSpellTemp1 := 50 - (GDVars.gSpellTemp2 - cl) * 2
        else
          GDVars.gSpellTemp1 := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.gSpellTemp1 then begin
          GDVars.effectLockFlag := 1;
          FxEngine.RemoveEffect(Pointer(tgt), eff^.id, eff);
          GDVars.effectLockFlag := 0;
          removed := True;
        end;
      end;
      eff := tgt^.effects;
      while (eff <> nil) and (eff <> nxt) do
        eff := eff^.next;
    end;
    if removed then
      CharHlp.PrintNameStringAnim(Types.PWork(tgt), True, 'is affected');
  end;
  for GDVars.sharedLoopIndex := 0 to 8 do begin
    case GDVars.sharedLoopIndex of
      0: begin lx := GDVars.gTargetX; ly := GDVars.gTargetY; end;
      1: ly := GDVars.gTargetY - 1;
      2: lx := GDVars.gTargetX + 1;
      3: ly := GDVars.gTargetY;
      4: ly := GDVars.gTargetY + 1;
      5: lx := GDVars.gTargetX;
      6: lx := GDVars.gTargetX - 1;
      7: ly := GDVars.gTargetY;
      8: ly := GDVars.gTargetY - 1;
    end;
    CbtMap.GetArenaContents(lx, ly, sel, terr);
    if (terr = C_Terr.TERRAIN_CLOUDKILL) or (terr = C_Terr.TERRAIN_STINK_CLOUD) then begin
      if terr = C_Terr.TERRAIN_CLOUDKILL then begin
        node := GDVars.cloudkillList;
        sel := SizeOf(GDConsts.cloudCells9);
      end else begin
        node := GDVars.linkedListStinkingPtr;
        sel := SizeOf(GDConsts.cloudCells);
      end;
      curNode := node;
      while curNode <> nil do begin
        nextNode := curNode^.next;
        for i := 1 to sel do
          if (lx = curNode^.ulX + GDConsts.dirDX[GDConsts.cloudCells[i]]) and
              (ly = curNode^.ulY + GDConsts.dirDY[GDConsts.cloudCells[i]]) and (curNode^.resolved = 0) then
            if CloudDispelled(Types.PWork(curNode^.caster)) then begin
              eff := Types.PWork(curNode^.caster)^.effects;
              found := False;
              while (eff <> nil) and not found do begin
                if (((eff^.id = Magic.EFF_CAST_CLOUDKILL) and (terr = C_Terr.TERRAIN_CLOUDKILL)) or
                    ((eff^.id = Magic.EFF_CAST_STINK) and (terr = C_Terr.TERRAIN_STINK_CLOUD))) and
                    ((eff^.strength div 16) = curNode^.idx) then
                  found := True
                else
                  eff := eff^.next;
              end;
              if found then
                if terr = C_Terr.TERRAIN_CLOUDKILL then
                  FxEngine.RemoveEffect(Pointer(curNode^.caster), Magic.EFF_CAST_CLOUDKILL, eff)
                else
                  FxEngine.RemoveEffect(Pointer(curNode^.caster), Magic.EFF_CAST_STINK, eff);
            end else
              curNode^.resolved := 1;
        curNode := node;
        while (curNode <> nil) and (curNode <> nextNode) do
          curNode := curNode^.next;
      end;
    end;
  end;
end;

{ Casts Prayer: the effect with the caster's side in bit 4 and the caster level. }
procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing,
                     GDVars.curChar^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.currentSpellBeing), False, 0, 0,
                     'is prayed for');
end;

procedure SpellRemoveCurse;
var
  it: Types.PItemRec;
  found: Boolean;
  i: ShortInt;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], C_Effect.BESTOW_CURSE) then
    CharHlp.PrintNameStringAnim(GDVars.targetCreaturePtr[1], True, 'is un-cursed')
  else begin
    found := False;
    it := GDVars.targetCreaturePtr[1]^.itemsAddr;
    while (it <> nil) and (not found) do begin
      if it^.cursed <> 0 then begin
        found := True;
        it^.equipped := 0;
        if not Magic.ItemReadable(Pointer(it)) then
          if it^.spells[3] > 127 then begin
            GDVars.overrideEffectFlag := 1;
            FxEngine.CallEffectHandler(it^.spells[3], Pointer(GDVars.targetCreaturePtr[1]), Pointer(it), True);
            for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
              FxEngine.RecalcAbility(Pointer(GDVars.targetCreaturePtr[1]), i);
          end;
      end;
      it := it^.next;
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.targetCreaturePtr[1], True, 'has an item un-cursed');
  end;
end;

{ Spells 44 and 100 (Bestow Curse): its effect on the targets. }
procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'has been cursed!');
end;

{ Applies Blink's effect to the targets. }
procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is blinking');
end;

{ Casts Fireball: caster-level d6 fire damage (the item fireball rolls 3, 5 or 7 d6); outside 3D maps the targets are
  every creature within 2 cells of the target cell. }
procedure SpellFireball;
var
  cl: Byte;
  i: Byte;
begin
  GDVars.currentSpellAffectsFlag := 1;
  if GDVars.currentSpellBeing = 64 then
    cl := FxEngine.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then begin
    Pathing.buildTargetList(GDVars.gTargetX, GDVars.gTargetY, 2, 255, 1, GDVars.combatArenaPtr);
    for i := 1 to GDVars.targetCount do
      GDVars.targetCreaturePtr[i] := GDVars.creaturePtr[GDVars.combatTargetData[i].idx];
    GDVars.numberTargetedCreatures := GDVars.targetCount;
  end;
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 0, C_Dir.CENTER);
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(cl, 6), 9, '');
end;

{ Haste and Slow: up to the caster's level of targets on one side lose the opposite effect, or else are given this one.
  @param(removeId The opposite effect.)
  @param(hostFlag The side affected.)
  @param(msg The effect's message.) }
procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.currentSpellAffectsFlag := 1;
  cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  for i := 1 to GDVars.numberTargetedCreatures do begin
    if (GDVars.targetCreaturePtr[i]^.hostile = hostFlag) and (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[i], removeId) then
        GDVars.targetCreaturePtr[i] := nil;
    end else
      GDVars.targetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, msg);
end;

{ Casts Haste on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile, 'is Hasted');
end;

{ The per-cell lightning/breath hit, called by LightningPath, the breath handler (EffBreatheLightning) and the
  lightning-throw handler (EffThrowLightning).
  @param(x Arena column.)
  @param(y Arena row.)
  @param(damage The damage.)
  @param(saveType The save against it, for half.)
  @param(excludeIdx A creature index the bolt passes over.)
  @param(blocked Set when a wall in a dungeon stops the bolt, and cleared on open ground.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; excludeIdx: Byte; var blocked: Boolean);
var
  tgt: Types.PWork;
  crIdx: Byte;
  terr: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hitDamage: Word;
begin
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if (terr > 0) and (GDConsts.terrainInfo[terr].cost = 255) and (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 1) and
      (not blocked) then
    blocked := True
  else
    blocked := False;
  if (crIdx > 0) and (crIdx <> excludeIdx) then begin
    tgt := GDVars.creaturePtr[crIdx];
    GDVars.elementMask := $C;
    FxEngine.InflictNonWeaponDamage(Pointer(tgt), damage, 2, FxEngine.RollSavingThrow(Pointer(tgt), saveType, 0));
    CharHlp.BuildIconFacings(19);
    GDVars.elementMask := 0;
  end;
end;

{ Carries a bolt on from the target cell, away from the caster, for the bolt's length in cells, hitting each creature it
  reaches (not the one just hit); at a wall it turns back toward the caster, the first bounce costing 4 more cells when
  the caster is within 4 cells and the bounce flag is set.
  @param(boltLen The bolt's length in cells.)
  @param(damage The electrical damage to each creature hit.)
  @param(saveType The saving-throw type that halves it.)
  @param(bounce True to let the first bounce cost 4 more cells.) }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  req: Types.TPathReq;
  req2: Types.TPathReq;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terr: Byte;
  budget: Byte;
  { the per-step distance; the budget spends the difference }
  lastDist: Byte;
begin
  blocked := False;
  CharHlp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.gTargetX, GDVars.gTargetY, prevCr, terr);
  lastDist := 0;
  sign := 1;
  x0 := CbtMap.CombatCellX(Pointer(GDVars.curChar));
  y0 := CbtMap.CombatCellY(Pointer(GDVars.curChar));
  doBounce := bounce;
  if x0 = GDVars.gTargetX then
    if y0 = GDVars.gTargetY then
      Exit;
  budget := boltLen * 2;
  GDVars.currentSpellAffectsFlag := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := GDVars.gTargetX;
    req.sy := GDVars.gTargetY;
    req.ex := GDVars.gTargetX + (GDVars.gTargetX - x0) * sign * budget;
    req.ey := GDVars.gTargetY + (GDVars.gTargetY - y0) * sign * budget;
    Pathing.pathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then begin
        repeat
          valid := Pathing.nextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
          if GDConsts.terrainInfo[terr].cost = 1 then
            blocked := False;
        until (valid = False) or ((crIdx > 0) and (crIdx <> prevCr)) or (terr = 0) or
            (GDConsts.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      if terr = 0 then
        budget := 0;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
      Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, prevCr, blocked);
      prevCr := crIdx;
      if blocked then begin
        GDVars.gTargetX := req.cx;
        GDVars.gTargetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := GDVars.gTargetX;
        req2.sy := GDVars.gTargetY;
        req2.ex := x0;
        req2.ey := y0;
        Pathing.pathFind(req2);
        while Pathing.nextPathStep(req2) do ;
        if doBounce then
          if req2.dist <= 8 then
            Inc(req.dist, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0;
      end;
      lastDist := req.dist - lastDist;
      if lastDist < budget then
        Dec(budget, lastDist)
      else
        budget := 0;
      lastDist := req.dist;
    until blocked or (budget = 0);
  end;
  GDVars.currentSpellAffectsFlag := 0;
end;

{ Spell 51 (Lightning Bolt): the caster's level in d6 at the aim cell and along a seven-cell bolt. }
procedure SpellLightningBolt;
var
  dmg: Byte;
  blocked: Boolean;
begin
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.currentSpellBeing), 6);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, dmg, 4, 0, blocked);
  Magic.LightningPath(7, dmg, 4, True);
end;

{ Casts Slow on the caster's enemies; it removes Haste instead where there is one. }
procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, ShortInt(CharHlp.NotHostile(GDVars.curChar)), 'is Slowed');
end;

{ Casts Restoration: when the first target has a drained level, gives one back. Its maximum, current and rolled hit
  points regain the drained hit points divided by the drained levels. Scanning each class, a class with a level becomes
  the pick when that level is not above the current pick's, its next-level experience is nonzero and smaller, and it is
  not at its level cap. The pick gains a level, experience is raised to its next-level experience if lower, class stats
  are recomputed and 'is restored' is shown. Note: if no class qualifies, the class raised is undefined. }
procedure SpellRestoration;
var
  tgt: Types.PWork;
  share: Byte;
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  bestCls: ShortInt;
  cls: ShortInt;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if tgt^.drainedLevels > 0 then begin
    share := tgt^.drainedHps div tgt^.drainedLevels;
    Inc(tgt^.cbHpMax, share);
    Inc(tgt^.hpCur, share);
    Inc(tgt^.pcHpRolled, share);
    Dec(tgt^.drainedHps, share);
    Dec(tgt^.drainedLevels);
    bestLvl := 13;
    bestXp := 10000000;
    for cls := C_Class.CLERIC_LEVEL to SizeOf(tgt^.classLevels) - 1 do begin
      lvl := tgt^.classLevels[cls];
      if (lvl > 0) and (lvl <= bestLvl) and (GDConsts.experienceSpellsClass[cls].xpNeeded[Succ(lvl)] > 0) and
          (GDConsts.experienceSpellsClass[cls].xpNeeded[Succ(lvl)] < bestXp) and
          (not CharHlp.AtLevelCap(Types.PWork(tgt), cls)) then begin
        bestLvl := lvl;
        bestCls := cls;
        bestXp := GDConsts.experienceSpellsClass[cls].xpNeeded[Succ(lvl)];
      end;
    end;
    Inc(tgt^.classLevels[bestCls]);
    if tgt^.experience < bestXp then
      tgt^.experience := bestXp;
    ClassCal.RecalcClassStats(Types.PWork(tgt));
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is restored', C_Msg.MESSAGE_ROW, True);
  end;
end;

{ Removes Slow from the target, or else applies the Potion of Speed's effect. }
procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.targetCreaturePtr[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is Speedy');
end;

{ Casts Cure Serious Wounds: heals the target 2d8 + 1. }
procedure SpellCureSeriousWounds;
begin
  if GDVars.numberTargetedCreatures = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.targetCreaturePtr[1]), FxEngine.RollDice(2, 8) + 1, False) then
    CharHlp.AnnounceHealStatus(GDVars.targetCreaturePtr[1]);
end;

{ Spell 59 (giant strength): strength 21 for 1d4 times 10 plus 40, announced when it is higher than the target's own. }
procedure SpellGiantStrength;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.targetCreaturePtr[1], 21, 0, enc) then
    CharHlp.PrintCreatureMessage(GDVars.targetCreaturePtr[1], 'is stronger', C_Msg.MESSAGE_ROW, True);
  FxEngine.AddEffect(Pointer(GDVars.targetCreaturePtr[1]), 146, FxEngine.RollDice(1, 4) * 10 + 40, enc, True);
  FxEngine.RecalcAbility(Pointer(GDVars.targetCreaturePtr[1]), C_Stat.STRENGTH);
end;

{ Casts the Javelin of Lightning: 1d6 + 20 damage at the aim cell and 20 along a three-cell bolt. }
procedure SpellJavelinOfLightning;
var
  blocked: Boolean;
begin
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, FxEngine.RollDice(1, 6) + 20, 4, 0, blocked);
  Magic.LightningPath(3, 20, 4, False);
end;

{ Applies the Wand of Paralyzation's effect to the targets ("is paralyzed"). }
procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is paralyzed');
end;

{ Heals the first target 2d4 + 2 hit points for the Potion of Healing. }
procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(Pointer(GDVars.targetCreaturePtr[1]), FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.targetCreaturePtr[1], True, 'is Healed');
end;

{ Spell 63 (dust of disappearance): its effect on the targets. }
procedure SpellDustOfDisappearance;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Deals the Wand of Magic Missiles' 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '');
end;

{ Casts Cause Serious Wounds: deals 2d8 + 1 magic damage. }
procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(2, 8) + 1, 8, '');
end;

{ Casts Neutralize Poison: cures the poison of a target that is not animated (Poisoned and both slow-poison effects
  removed with the effect lock), raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;
var
  tgt: Types.PWork;
  eff: Types.PEffectRec;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.targetCreaturePtr[1] := nil
  else if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.POISONED, Types.PEffectRec(eff)) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.POISONED, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_END, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLockFlag := 0;
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is unpoisoned', C_Msg.MESSAGE_ROW, True);
    tgt^.mgEnabled := 1;
    tgt^.status := C_Status.OKAY;
  end else
    CharHlp.PrintCreatureMessage(Types.PWork(tgt), 'is unaffected', C_Msg.MESSAGE_ROW, True);
end;

{ Casts Poison: applies the spell, then, unless the effects of the caster's target cancel the poison attack, runs the
  poison attack's handler (a poison bite) for the caster. }
procedure SpellPoison;
var
  { never assigned }
  eff: Types.PEffectRec;
  tgt: Types.PWork;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 8, '');
  tgt := GDVars.curChar^.combatLink^.other;
  GDVars.gEffectCheck := 64;
  FxEngine.TriggerEffectsWithCondition(9, Pointer(tgt));
  if GDVars.gEffectCheck = 64 then
    FxEngine.CallEffectHandler(64, Pointer(GDVars.curChar), eff, False);
end;

{ Casts Sticks to Snakes: a target below attack level 6 fights snakes, with the caster level as the effect's strength; a
  stronger one "smashes them flat". }
procedure SpellSticksToSnakes;
var
  eff: Types.PEffectRec;
begin
  if ShortInt(GDVars.targetCreaturePtr[1]^.mgLevelHighest) < 6 then begin
    Magic.ResolveSpell(GDVars.currentSpellBeing, CharHlp.GetCasterLevel(GDVars.currentSpellBeing), False, 0, 8, '');
    if CharHlp.HasEffect(GDVars.targetCreaturePtr[1], C_Effect.SNAKES, Types.PEffectRec(eff)) then
      FxEngine.CallEffectHandler(C_Effect.SNAKES, Pointer(GDVars.targetCreaturePtr[1]), eff, False);
  end else
    CharHlp.PrintCreatureMessage(GDVars.targetCreaturePtr[1], 'smashes them flat', C_Msg.MESSAGE_ROW, True);
end;

{ Casts Cure Critical Wounds: heals the target 3d8 + 3. }
procedure SpellCureCriticalWounds;
begin
  if GDVars.numberTargetedCreatures = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(Pointer(GDVars.targetCreaturePtr[1]), FxEngine.RollDice(3, 8) + 3, False) then
    CharHlp.AnnounceHealStatus(GDVars.targetCreaturePtr[1]);
end;

{ Casts Cause Critical Wounds: deals 3d8 + 3 magic damage. }
procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(3, 8) + 3, 8, '');
end;

{ Casts Dispel Evil: gives the caster the dispel evil effect for the spell's duration and applies the spell. }
procedure SpellDispelEvil;
begin
  FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 4, Magic.CalcSpellDuration(73), 0, False, False, False, '');
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is affected');
end;

{ Casts Flame Strike: deals 6d8 fire damage. }
procedure SpellFlameStrike;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(6, 8), 9, '');
end;

{ Casts Raise Dead: a dead or animated first target with Constitution left, and not an elf, loses its animation and its
  poison (under the effect lock), is okay and enabled with 1 hit point, and 'is raised'; unless it was poisoned it
  spends a point of Constitution. }
procedure SpellRaiseDead;
var
  eff: Types.PEffectRec;
  tgt: Types.PWork;
  poisoned: Boolean;
begin
  tgt := GDVars.targetCreaturePtr[1];
  if ((tgt^.status = C_Status.DEAD_STATUS) or (tgt^.status = C_Status.ANIMATED)) and (tgt^.mgConstitution > 0) and
      (tgt^.race <> C_Race.ELF) then begin
    poisoned := CharHlp.HasEffect(Types.PWork(tgt), C_Effect.POISONED, Types.PEffectRec(eff));
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.ANIMATE_DEAD, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.POISONED, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_END, nil);
    GDVars.effectLockFlag := 1;
    FxEngine.RemoveEffect(Pointer(tgt), C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLockFlag := 0;
    tgt^.status := C_Status.OKAY;
    tgt^.mgEnabled := 1;
    tgt^.hpCur := 1;
    if not poisoned then begin
      Dec(tgt^.mgConstitution);
      FxEngine.RecalcAbility(Pointer(tgt), C_Stat.CONSTITUTION);
    end;
    CharHlp.PrintCreatureMessage(Types.PWork(Pointer(tgt)), 'is raised', C_Msg.MESSAGE_ROW, True);
  end;
end;

{ Casts Slay Living: unless the target's effects cancel it, a failed save (type 4) kills the target and a made one costs
  2d8 + 1 magic damage. }
procedure SpellSlayLiving;
var
  tgt: Types.PWork;
begin
  tgt := GDVars.targetCreaturePtr[1];
  GDVars.elementMask := $40;
  GDVars.pendingDamage := 67;
  FxEngine.TriggerEffectsWithCondition(9, Pointer(tgt));
  if GDVars.pendingDamage <> 0 then begin
    if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then
      FxEngine.KillCreature(Pointer(tgt), C_Status.DEAD_STATUS, 'is slain')
    else begin
      GDVars.elementMask := 8;
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), FxEngine.RollDamageDice(2, 8) + 1, 0, False);
    end;
  end else
    CharHlp.PrintCreatureMessage(Types.PWork(Pointer(tgt)), 'is unaffected', C_Msg.MESSAGE_ROW, True);
end;

{ Casts Entangle, which works only outside 3D maps: each target saves (type 4) or is entangled. Note: the duration is
  computed for spell 136, past the end of the spell table. }
procedure SpellEntangle;
var
  tgt: Types.PWork;
  i: Byte;
  saved: Boolean;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then
    Exit;
  for i := 1 to GDVars.numberTargetedCreatures do
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
      FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.ENTANGLED, Magic.CalcSpellDuration(136), 0, False, True,
                                    saved, 'is entangled');
    end;
end;

{ Casts Faerie Fire: ApplyEffectToTargets ("is highlighted"). }
procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, 'is highlighted');
end;

{ Invisibility to Animals: makes the targets invisible, each with the message 'is invisible'. }
procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Casts Charm Monsters: ApplyEffectToTargets ("is charmed"), then the charm handler for each charmed target. }
procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmCount: Integer;
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[0..1] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  targetIndex: Byte;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GDVars.numberTargetedCreatures do
    if CharHlp.HasEffect(GDVars.targetCreaturePtr[i], C_Effect.CHARM, Types.PEffectRec(eff)) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, Pointer(GDVars.targetCreaturePtr[i]), eff, False);
end;

{ Casts Confusion: up to 2d8 targets save (type 4) or are confused. }
procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  tgt: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  effect: array[0..3] of Byte;
  n: Byte;
begin
  n := FxEngine.RollDice(2, 8);
  if GDVars.numberTargetedCreatures > n then
    GDVars.numberTargetedCreatures := n;
  for i := 1 to GDVars.numberTargetedCreatures do
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
      FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.CONFUSED, Magic.CalcSpellDuration(82), 0, False, True,
                                    saved, 'is confused');
    end;
end;

{ Casts Dimension Door. An immobile caster is first freed: each creature next to it that is hugging, draining blood or
  swallowing, and whose first such hold names the caster as its victim, drops all three holds. Then the caster's icon is
  erased and the caster placed at the aim cell (IsValidCreatureLoc's answer is not checked), the view follows it, and it
  'teleports'. Note: a constrictor's hold is not one of the three, so a constricted caster stays held. }
procedure SpellDimensionDoor;
var
  caster: Types.PWork;
  target: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  locOk: Boolean;
  eff: Types.PEffectRec;
  i: Byte;
begin
  caster := GDVars.curChar;
  if CharHlp.HasEffect(Types.PWork(caster), C_Effect.IMMOBILE, Types.PEffectRec(eff)) then begin
    Pathing.buildTargetList(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), 1, 255, 1,
                            GDVars.combatArenaPtr);
    for i := 1 to GDVars.targetCount do begin
      target := GDVars.creaturePtr[GDVars.combatTargetData[i].idx];
      if CharHlp.HasEffect(Types.PWork(target), C_Effect.HUGGING, Types.PEffectRec(eff))
         or CharHlp.HasEffect(Types.PWork(target), C_Effect.DRAINING_BLOOD, Types.PEffectRec(eff))
         or CharHlp.HasEffect(Types.PWork(target), C_Effect.SWALLOWING, Types.PEffectRec(eff)) then
        if GDVars.creaturePtr[eff^.strength] = caster then begin
          FxEngine.RemoveEffect(Pointer(target), C_Effect.DRAINING_BLOOD, nil);
          FxEngine.RemoveEffect(Pointer(target), C_Effect.HUGGING, nil);
          FxEngine.RemoveEffect(Pointer(target), C_Effect.SWALLOWING, nil);
        end;
    end;
  end;
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Pointer(caster)));
  locOk := CbtMap.IsValidCreatureLoc(Pointer(caster), GDVars.gTargetX, GDVars.gTargetY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), 0, C_Dir.CENTER);
  CharHlp.PrintCreatureMessage(Types.PWork(caster), 'teleports', C_Msg.MESSAGE_ROW, True);
end;

{ Casts Fear: a cone of 3 rays and 6 cells from the caster through the aim cell. Each target without effect 133 that
  fails its save (type 4) is afraid ('runs in terror'): it flees under computer control, a party member's npc becomes
  C_Npc.ANIMATED_PLAYER, and it drops its target and its AI effects. The others are 'unaffected'. }
procedure SpellFear;
type
  PFearCombat = ^TFearCombat;
  TFearCombat = record
    otherLead: array[$00..$09] of Byte;
    other: Types.PWork;
    otherTail: array[$0E..$0F] of Byte;
    flee: Byte;
  end;
var
  caster: Types.PWork;
  tgt: Types.PWork;
  i: Byte;
  saved: Boolean;
  eff: Types.PEffectRec;
begin
  caster := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), GDVars.gTargetX,
                           GDVars.gTargetY,
                     3, 6);
  for i := 1 to GDVars.numberTargetedCreatures do begin
    tgt := GDVars.targetCreaturePtr[i];
    saved := FxEngine.RollSavingThrow(Pointer(tgt), 4, 0);
    if (not CharHlp.HasEffect(Types.PWork(tgt), 133, Types.PEffectRec(eff))) and (not saved) then begin
      FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.AFRAID, Magic.CalcSpellDuration(84), 0, True, True,
                                    saved, 'runs in terror');
      PFearCombat(tgt^.combatLink)^.flee := 1;
      tgt^.quickfight := 1;
      if tgt^.npc <= C_Npc.MORALE_MASK then
        tgt^.npc := C_Npc.ANIMATED_PLAYER;
      PFearCombat(tgt^.combatLink)^.other := nil;
      FxEngine.RemoveAiEffects(Pointer(tgt));
    end else
      CharHlp.PrintCreatureMessage(Types.PWork(Pointer(tgt)), 'is unaffected', C_Msg.MESSAGE_ROW, True);
  end;
end;

{ Spell 85 (Fire Shield): asks for hot or cold flames (random for a quick fighter): hot gives the caster effects 50 and
  143, cold 54 and 143; any other answer offers to abort. }
procedure SpellFireShield;
var
  ch: Char;
  ext: Boolean;
  done: Boolean;
begin
  done := False;
  repeat
    { a scared caster (quickfight set) cannot choose }
    if GDVars.curChar^.quickfight <> 0 then begin
      if FxEngine.RollDice(1, 10) > 5 then
        ch := 'H'
      else
        ch := 'C';
    end else
      ch := MenuCore.MenuHorizontal('flame type: ', 'Hot Cold', LightMagenta, LightGreen, White, False, False, ext);
    case ch of
      'H':
        begin
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 50, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, 'is protected');
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 143, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          done := True;
        end;
      'C':
        begin
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 54, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          FxEngine.AddEffectWithMessage(Pointer(GDVars.curChar), 143, Magic.CalcSpellDuration(85), 0, False, False,
                                        False, '');
          done := True;
        end;
    else begin
        ch := MenuCore.MenuHorizontal('Abort spell? ', 'Yes No', LightMagenta, LightGreen, White, False, False, ext);
        if ch = 'Y' then
          done := True;
      end;
    end;
  until done;
end;

{ Casts Fumble: a first target that fails a save (type 4) becomes clumsy ('is clumsy'), one that saves is slowed ('is
  slowed'), each effect with its handler run; then the spell's table effect is resolved on the targets as well ('is
  clumsy'). }
procedure SpellFumble;
var
  tgt: Types.PWork;
  eff: Types.PEffectRec;
begin
  tgt := GDVars.targetCreaturePtr[1];
  GDVars.elementMask := $40;
  if not FxEngine.RollSavingThrow(Pointer(tgt), 4, 0) then begin
    FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.CLUMSY, Magic.CalcSpellDuration(86), 0, False, False,
                                  False, 'is clumsy');
    if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.CLUMSY, Types.PEffectRec(eff)) then
      FxEngine.CallEffectHandler(C_Effect.CLUMSY, Pointer(tgt), nil, False);
  end else begin
    FxEngine.AddEffectWithMessage(Pointer(tgt), C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, False, False,
                                  False, 'is slowed');
    if CharHlp.HasEffect(Types.PWork(tgt), C_Effect.SLOWED, Types.PEffectRec(eff)) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, Pointer(tgt), nil, False);
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, True, 0, 0, 'is clumsy');
end;

{ Casts Ice Storm: deals 3d10 cold damage. }
procedure SpellIceStorm;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, FxEngine.RollDamageDice(3, 10), 10, '');
end;

{ Minor Globe of Invulnerability: protects the targets, each with the message 'is protected'. }
procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, 'is protected');
end;

{ Casts Cloudkill: a 3x3 cloud at the target cell, built like Stinking Cloud on the Cloudkill list and tracked by an
  effect on the caster; a cell under another cloud of either kind keeps the terrain beneath it. Note: after the loop the
  last cell's terrain is saved and its tile set a second time. Note: the count of the caster's clouds skips the list's
  last node. }
procedure SpellCloudkill;
var
  cloud: Types.PArenaNode;
  node: Types.PArenaNode;
  crIdx: array[1..9] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  d: Byte;
  done18: Boolean;
begin
  GDVars.currentSpellAffectsFlag := 1;
  cl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  myClouds := 0;
  node := GDVars.cloudkillList;
  if GDVars.cloudkillList = nil then begin
    GetMem(GDVars.cloudkillList, SizeOf(Types.TArenaNode));
    node := GDVars.cloudkillList;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(Types.TArenaNode));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(node^), 0);
  FxEngine.AddEffect(Pointer(GDVars.curChar), Magic.EFF_CAST_CLOUDKILL, cl, cl + myClouds * 16, True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.gTargetX;
  node^.ulY := GDVars.gTargetY;
  for k := 1 to SizeOf(GDConsts.cloudCells9) do begin
    d := GDConsts.cloudCells9[k];
    CbtMap.GetArenaContents(GDVars.gTargetX + GDConsts.dirDX[d], GDVars.gTargetY + GDConsts.dirDY[d], crIdx[k], terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    case terr of
      C_Terr.TERRAIN_STINK_CLOUD:
        begin
          cloud := GDVars.linkedListStinkingPtr;
          done18 := False;
          while (cloud <> nil) and not done18 do begin
            for j := 1 to SizeOf(GDConsts.cloudCells) do
              if (cloud^.exists[j] <> 0) and
                  (cloud^.ulX + GDConsts.dirDX[GDConsts.cloudCells[j]] = GDVars.gTargetX + GDConsts.dirDX[d]) and
                  (cloud^.ulY + GDConsts.dirDY[GDConsts.cloudCells[j]] = GDVars.gTargetY + GDConsts.dirDY[d]) and
                  (cloud^.under[j] <> C_Terr.TERRAIN_STINK_CLOUD) and
                  (cloud^.under[j] <> C_Terr.TERRAIN_CLOUDKILL) then begin
                terr := cloud^.under[j];
                done18 := True;
              end;
            cloud := cloud^.next;
          end;
        end;
      C_Terr.TERRAIN_CLOUDKILL:
        begin
          cloud := GDVars.cloudkillList;
          done18 := False;
          while (cloud <> nil) and not done18 do begin
            if cloud <> node then
              for j := 1 to SizeOf(GDConsts.cloudCells9) do
                if (cloud^.exists[j] <> 0) and
                    (cloud^.ulX + GDConsts.dirDX[GDConsts.cloudCells9[j]] = GDVars.gTargetX + GDConsts.dirDX[d]) and
                    (cloud^.ulY + GDConsts.dirDY[GDConsts.cloudCells9[j]] = GDVars.gTargetY + GDConsts.dirDY[d]) and
                    (cloud^.under[j] <> C_Terr.TERRAIN_STINK_CLOUD) and
                    (cloud^.under[j] <> C_Terr.TERRAIN_CLOUDKILL) then begin
                  terr := cloud^.under[j];
                  done18 := True;
                end;
            cloud := cloud^.next;
          end;
        end;
      C_Terr.TERRAIN_CORPSE:
        begin
          for j := 1 to GDVars.downedCount do
            if GDVars.combatDownedCharacter[j].x = GDVars.gTargetX + GDConsts.dirDX[d] then
              if GDVars.combatDownedCharacter[j].y = GDVars.gTargetY + GDConsts.dirDY[d] then
                terr := GDVars.combatDownedCharacter[j].under;
        end;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.combatArenaPtr^.cells[GDVars.gTargetY + GDConsts.dirDY[d],
                  GDVars.gTargetX + GDConsts.dirDX[d]] := C_Terr.TERRAIN_CLOUDKILL;
  end;
  { the loop tail once more, with k = 9 and d and terr holding their last values; it rewrites cell 9 }
  node^.under[k] := terr;
  if node^.exists[k] <> 0 then
    GDVars.combatArenaPtr^.cells[GDVars.gTargetY + GDConsts.dirDY[d],
                                 GDVars.gTargetX + GDConsts.dirDX[d]] := C_Terr.TERRAIN_CLOUDKILL;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a poisonous cloud', C_Msg.MESSAGE_ROW, False);
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  for k := 1 to SizeOf(crIdx) do
    if crIdx[k] > 0 then
      FxEngine.ConsiderTerrainEffects(Pointer(GDVars.creaturePtr[crIdx[k]]), 1);
end;

{ Casts Cone of Cold: a cone of 2 rays toward the target cell, reaching (caster level + 1) div 2 cells, at least 1,
  deals caster level + caster-level d4 cold damage. }
procedure SpellConeOfCold;
var
  p: Types.PWork;
  reach: Byte;
  lvl: Byte;
begin
  p := GDVars.curChar;
  lvl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
  reach := (CharHlp.GetCasterLevel(GDVars.currentSpellBeing) + 1) div 2;
  if reach < 1 then
    reach := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(p)), CbtMap.CombatCellY(Pointer(p)), GDVars.gTargetX,
                           GDVars.gTargetY, 2, reach);
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, lvl + FxEngine.RollDamageDice(lvl, 4), 10, '');
end;

{ Casts Feeblemind: applies the spell with the target's saving throw against spells shifted for the save by its class
  (cleric -1, magic-user +4, others +2), then runs the feeblemind effect's handler. }
procedure SpellFeeblemind;
var
  saved: Byte;
  tgt: Types.PWork;
  eff: Types.PEffectRec;
begin
  tgt := GDVars.targetCreaturePtr[1];
  saved := tgt^.mgSpellSave;
  case Char(tgt^.mgCharClass) of
    #0: Dec(tgt^.mgSpellSave);
    #5: Inc(tgt^.mgSpellSave, 4);
  else
    Inc(tgt^.mgSpellSave, 2);
  end;
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, '');
  if CharHlp.HasEffect(Types.PWork(tgt), 68, Types.PEffectRec(eff)) then
    FxEngine.CallEffectHandler(68, Pointer(tgt), nil, False);
  tgt^.mgSpellSave := saved;
end;

{ Spell 95: applies its effect to the targets. }
procedure SpellImmuneBreath;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, '');
end;

{ Spell 96: applies its effect to the targets. }
procedure SpellImmuneParalysis;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, '');
end;

{ Casts the invisibility spell by applying its effect. }
procedure SpellTurnInvisible;
begin
  Magic.ResolveSpell(GDVars.currentSpellBeing, 0, False, 0, 0, '');
end;

{ Casts a cone of 1 ray and 3 cells dealing 6d6 damage; creatures of type 18 take it in full, the others as if saved. }
procedure SpellConeBlast;
var
  i: Byte;
  caster: Types.PWork;
  tgt: Types.PWork;
  saved: Boolean;
begin
  caster := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(Pointer(caster)), CbtMap.CombatCellY(Pointer(caster)), GDVars.gTargetX,
                           GDVars.gTargetY,
                     1, 3);
  for i := 1 to GDVars.numberTargetedCreatures do
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      if tgt^.charType = 18 then
        saved := False
      else
        saved := True;
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), FxEngine.RollDamageDice(6, 6),
                                      GDConsts.spellTable[98].saveResult, saved);
    end;
end;

{ Spell 99: heals the first target 2d4 + 2 hit points ('is Healed'), as the Potion of Healing does. }
procedure SpellHealSelf;
begin
  if FxEngine.RestoreHitPoints(Pointer(GDVars.targetCreaturePtr[1]), FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.targetCreaturePtr[1], True, 'is Healed');
end;

{ Lightning breath, effect 88: after the first round only on 1..50 of 1d100, aim (as spell 51) and breathe a bolt of the
  creature's stored damage (spellsKnown[0]) two cells out and along a ten-cell path, counting the breaths down in the
  effect's strength and removing the effect when they are spent; the creature's turn ends.
  @param(cr The breathing creature.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffBreatheLightning(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  blocked: Boolean;
  x: ShortInt;
  y: ShortInt;
begin
  if GDVars.combatRoundCounterCount <> 0 then
    if FxEngine.RollDice(1, 100) <= 50 then
      Exit;
  GDVars.elementMask := $24;
  x := CbtMap.CombatCellX(Pointer(cr));
  y := CbtMap.CombatCellY(Pointer(cr));
  CharHlp.PrintCreatureMessage(Types.PWork(cr), 'Breathes!', C_Msg.MESSAGE_ROW, True);
  GDVars.spellFps.targetMenu(51, True, GDVars.breathAim);
  GDVars.gTargetX := x + Pathing.signOf(GDVars.gTargetX - x);
  GDVars.gTargetY := y + Pathing.signOf(GDVars.gTargetY - y);
  if GDVars.gTargetX = x + 1 then
    Inc(GDVars.gTargetX);
  if GDVars.gTargetY = y + 1 then
    Inc(GDVars.gTargetY);
  FxEngine.RemoveInvisibility(Types.PWork(cr));
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, cr^.spellsKnown[0], 3, 0, blocked);
  Magic.LightningPath(10, cr^.spellsKnown[0], 3, False);
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(Pointer(cr), 88, p);
  blocked := CharHlp.ClearGuard(Types.PWork(cr));
end;

{ Acid spit, effect 86: aim (as spell 65) at the creature's target; within 6 cells it hits on 1..30 of 1d100 for 1d12
  acid damage, a save for half ('Spits Acid'), else 'Spits Acid and Misses'.
  @param(cr The spitting creature.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSpitAcidBreath(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  roll: Byte;
begin
  GDVars.spellFps.targetMenu(65, True, GDVars.breathAim);
  GDVars.otherCreatureCurrentPtr := cr^.combatLink^.other;
  roll := FxEngine.RollDice(1, 100);
  if CharHlp.CalcDistance(cr, GDVars.otherCreatureCurrentPtr) >= 7 then
    Exit;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  if roll <= 30 then begin
    CharHlp.PrintCreatureMessage(Types.PWork(cr), 'Spits Acid', C_Msg.MESSAGE_ROW, True);
    CharHlp.BuildIconFacings(23);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                    CbtMap.CombatCellX(Pointer(GDVars.otherCreatureCurrentPtr)),
                                    CbtMap.CombatCellY(Pointer(GDVars.otherCreatureCurrentPtr)), 1, 30);
    FxEngine.InflictNonWeaponDamage(Pointer(GDVars.otherCreatureCurrentPtr), FxEngine.RollDamageDice(1, 12), 2,
                                    FxEngine.RollSavingThrow(Pointer(GDVars.otherCreatureCurrentPtr), 3, 0));
  end else
    CharHlp.PrintCreatureMessage(Types.PWork(cr), 'Spits Acid and Misses', C_Msg.MESSAGE_ROW, True);
end;

{ Breathes acid: three breaths a fight, counted in the effect's strength. Aims a cone (one ray, reach 6) and, when it
  catches no one on the creature's own side, breathes the stored damage as acid on each target, a save for half, and
  ends the creature's turn.
  @param(cr The breathing creature.)
  @param(p The effect node.)
  @param(removed Unused.) }
procedure EffBreatheAcid(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  ox: ShortInt;
  oy: ShortInt;
  i: Byte;
  tgt: Types.PWork;
  saved: Boolean;
begin
  GDVars.breathAim := False;
  if GDVars.combatRoundCounterCount = 0 then
    Types.PEffectRec(p)^.strength := 3;
  if Types.PEffectRec(p)^.strength <= 0 then
    Exit;
  GDVars.elementMask := $30;
  ox := CbtMap.CombatCellX(Pointer(cr));
  oy := CbtMap.CombatCellY(Pointer(cr));
  GDVars.spellFps.targetMenu(61, True, GDVars.breathAim);
  if GDVars.breathAim then
    Magic.CollectConeTargets(ox, oy, GDVars.gTargetX, GDVars.gTargetY, 1, 6);
  for i := 1 to GDVars.numberTargetedCreatures do
    if Byte(CharHlp.NotHostile(Types.PWork(cr))) <> Byte(GDVars.targetCreaturePtr[i]^.hostile) then
      GDVars.breathAim := False;
  if not GDVars.breathAim then
    Exit;
  if GDVars.numberTargetedCreatures <= 0 then
    Exit;
  CharHlp.PrintCreatureMessage(Types.PWork(cr), 'breathes acid', C_Msg.MESSAGE_ROW, True);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.targetCreaturePtr[1])),
                                  CbtMap.CombatCellY(Pointer(GDVars.targetCreaturePtr[1])), 1, 30);
  for i := 1 to GDVars.numberTargetedCreatures do
    if GDVars.targetCreaturePtr[i] <> nil then begin
      tgt := GDVars.targetCreaturePtr[i];
      saved := FxEngine.RollSavingThrow(Pointer(tgt), 3, 0);
      FxEngine.InflictNonWeaponDamage(Pointer(tgt), cr^.spellsKnown[0], 2, saved);
    end;
  Dec(Types.PEffectRec(p)^.strength);
  turnDone := CharHlp.ClearGuard(Types.PWork(cr));
end;

{ Fire breath, effect 128: three breaths a fight, counted in the effect's strength. It aims a cone (as spell 61, three
  rays, reach 9) and breathes the stored damage as fire on each target, a save for half, ending the creature's turn.
  @param(cr The breathing creature.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffBreatheFire(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  bx: ShortInt;
  by: ShortInt;
  i: Byte;
  tgt: Types.PWork;
  saved: Boolean;
begin
  if GDVars.combatRoundCounterCount = 0 then
    Types.PEffectRec(p)^.strength := 3;
  if Types.PEffectRec(p)^.strength > 0 then begin
    GDVars.elementMask := $21;
    bx := CbtMap.CombatCellX(Pointer(cr));
    by := CbtMap.CombatCellY(Pointer(cr));
    GDVars.spellFps.targetMenu(61, True, GDVars.breathAim);
    if not GDVars.breathAim then
      Exit;
    Magic.CollectConeTargets(bx, by, GDVars.gTargetX, GDVars.gTargetY, 3, 9);
    if GDVars.numberTargetedCreatures > 0 then begin
      CharHlp.PrintCreatureMessage(Types.PWork(Pointer(cr)), 'breathes fire', C_Msg.MESSAGE_ROW, True);
      CharHlp.BuildIconFacings(18);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                      CbtMap.CombatCellX(Pointer(GDVars.targetCreaturePtr[1])),
                                      CbtMap.CombatCellY(Pointer(GDVars.targetCreaturePtr[1])), 1, 30);
      for i := 1 to GDVars.numberTargetedCreatures do
        if GDVars.targetCreaturePtr[i] <> nil then begin
          tgt := GDVars.targetCreaturePtr[i];
          saved := FxEngine.RollSavingThrow(Pointer(tgt), 3, 0);
          FxEngine.InflictNonWeaponDamage(Pointer(tgt), cr^.spellsKnown[0], 2, saved);
        end;
      Dec(Types.PEffectRec(p)^.strength);
      turnDone := CharHlp.ClearGuard(Types.PWork(Pointer(cr)));
    end;
  end;
end;

{ Breathes fire at close range: on 1 to 50 of 1d100 at an adjacent target, ends the turn and breathes 7 fire damage,
  with a saving throw for half.
  @param(cr The breathing creature.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBreatheFireAdjacent(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  GDVars.spellFps.targetMenu(65, True, GDVars.breathAim);
  GDVars.otherCreatureCurrentPtr := cr^.combatLink^.other;
  if FxEngine.RollDice(1, 100) > 50 then
    Exit;
  if CharHlp.CalcDistance(Pointer(cr), Pointer(GDVars.otherCreatureCurrentPtr)) >= 2 then
    Exit;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  GDVars.elementMask := 1;
  GDVars.breathAim := CharHlp.ClearGuard(Types.PWork(Pointer(cr)));
  CharHlp.PrintCreatureMessage(Types.PWork(Pointer(cr)), 'Breathes Fire', C_Msg.MESSAGE_ROW, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.otherCreatureCurrentPtr)),
                                  CbtMap.CombatCellY(Pointer(GDVars.otherCreatureCurrentPtr)), 1, 30);
  FxEngine.InflictNonWeaponDamage(Pointer(GDVars.otherCreatureCurrentPtr), 7, 2,
                                  FxEngine.RollSavingThrow(Pointer(GDVars.otherCreatureCurrentPtr), 3, 0));
end;

{ Lightning throwing, effect 132, in the first four rounds: aims (as spell 51) and throws 16d6 at the aim cell and
  another 16d6 along a ten-cell path; the creature turns visible and its turn ends.
  @param(cr The throwing creature.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffThrowLightning(cr: Types.PWork; p: Pointer; removed: Boolean);
var
  blocked: Boolean;
  bx: ShortInt;
  by: ShortInt;
begin
  if GDVars.combatRoundCounterCount >= 4 then
    Exit;
  bx := CbtMap.CombatCellX(Pointer(cr));
  by := CbtMap.CombatCellY(Pointer(cr));
  CharHlp.PrintCreatureMessage(Types.PWork(Pointer(cr)), 'throws lightning', C_Msg.MESSAGE_ROW, True);
  GDVars.spellFps.targetMenu(51, True, GDVars.breathAim);
  FxEngine.RemoveInvisibility(Types.PWork(cr));
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(bx, by, GDVars.gTargetX, GDVars.gTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, FxEngine.RollDamageDice(16, 6), 4, 0, blocked);
  Magic.LightningPath(10, FxEngine.RollDamageDice(16, 6), 4, False);
  blocked := CharHlp.ClearGuard(Types.PWork(Pointer(cr)));
end;

{ Paralyzing gaze, effect 126: aims (as spell 36) and gazes at the target, which saves or is held for 60 ('is
  paralyzed'). Note: GameInit has EffHndlr install its own handler for effect 126 after InitSpellFns installs this one,
  so this one never runs.
  @param(cr The gazing creature.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffAimedParalyzingGaze(cr: Types.PWork; p: Pointer; removed: Boolean);
begin
  cr^.combatLink^.other := nil;
  GDVars.spellFps.targetMenu(36, True, GDVars.breathAim);
  GDVars.otherCreatureCurrentPtr := cr^.combatLink^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  CharHlp.PrintCreatureMessage(Types.PWork(cr), 'gazes...', C_Msg.MESSAGE_ROW, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)),
                                  CbtMap.CombatCellX(Pointer(GDVars.otherCreatureCurrentPtr)),
                                  CbtMap.CombatCellY(Pointer(GDVars.otherCreatureCurrentPtr)), 4, 45);
  if not FxEngine.RollSavingThrow(Pointer(GDVars.otherCreatureCurrentPtr), 1, 0) then begin
    FxEngine.AddEffect(Pointer(GDVars.otherCreatureCurrentPtr), C_Effect.HELD, 60, 255, False);
    CharHlp.PrintCreatureMessage(GDVars.otherCreatureCurrentPtr, 'is paralyzed', C_Msg.MESSAGE_ROW, False);
  end;
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and (GDVars.baseItems[Types.PItemRec(it)^.itemType].slot > 10) and
      (GDVars.baseItems[Types.PItemRec(it)^.itemType].slot < 14) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);
var
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  sp := spell;
  found := 0;
  for i := 1 to 3 do
    if Types.PItemRec(it)^.spells[i] and C_Spell.ID_MASK = sp then
      found := i;
  if found = 0 then
    Exit;
  Types.PItemRec(it)^.spells[found] := 0;
  Dec(Types.PItemRec(it)^.nameIds[2]);
  if Types.PItemRec(it)^.nameIds[2] < 210 then
    CharHlp.RemoveItem(Types.PWork(cr), Types.PItemRec(it));
end;

procedure PrintCastSpellMsg(cr: Types.PWork; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(Types.PWork(cr), 'Casts a Spell', C_Msg.MESSAGE_ROW, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, Black, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(Types.PWork(cr), 1, 19, False);
    TextRend.DisplayString(Succ(Succ(Word(Length(cr^.name)))), 19, LightGreen, Black, msg);
    TextRend.DisplayString(1, 20, LightGreen, Black, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure InitSpellFns;
begin
  @GDVars.spellFps.targetMenu := @Magic.NoncombatCastTargetMenu;
  GDVars.effectLockFlag := 0;
  GDVars.usingItem := False;
  GDVars.castTargetPtr := nil;
  GDVars.redrawInventoryMenuFlag := 1;
  @GDVars.spellFps.spells[1] := @Magic.SpellBless;
  @GDVars.spellFps.spells[2] := @Magic.SpellCurse;
  @GDVars.spellFps.spells[3] := @Magic.SpellCureLightWounds;
  @GDVars.spellFps.spells[4] := @Magic.SpellCauseLightWounds;
  @GDVars.spellFps.spells[5] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[6] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[7] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[8] := @Magic.SpellResistCold;
  @GDVars.spellFps.spells[9] := @Magic.SpellBurningHands;
  @GDVars.spellFps.spells[10] := @Magic.SpellCharmPerson;
  @GDVars.spellFps.spells[11] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[12] := @Magic.SpellEnlarge;
  @GDVars.spellFps.spells[13] := @Magic.SpellReduce;
  @GDVars.spellFps.spells[14] := @Magic.SpellFriends;
  @GDVars.spellFps.spells[15] := @Magic.SpellMagicMissile;
  @GDVars.spellFps.spells[16] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[17] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[18] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[19] := @Magic.SpellShield;
  @GDVars.spellFps.spells[20] := @Magic.SpellShockingGrasp;
  @GDVars.spellFps.spells[21] := @Magic.SpellSleep;
  @GDVars.spellFps.spells[22] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[23] := @Magic.SpellHold;
  @GDVars.spellFps.spells[24] := @Magic.SpellResistFire;
  @GDVars.spellFps.spells[25] := @Magic.SpellSilence;
  @GDVars.spellFps.spells[26] := @Magic.SpellSlowPoison;
  @GDVars.spellFps.spells[27] := @Magic.SpellSnakeCharm;
  @GDVars.spellFps.spells[28] := @Magic.SpellSpiritualHammer;
  @GDVars.spellFps.spells[29] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[30] := @Magic.SpellInvisibility;
  @GDVars.spellFps.spells[31] := @Magic.SpellKnock;
  @GDVars.spellFps.spells[32] := @Magic.SpellMirrorImage;
  @GDVars.spellFps.spells[33] := @Magic.SpellRayOfEnfeeblement;
  @GDVars.spellFps.spells[34] := @Magic.SpellStinkingCloud;
  @GDVars.spellFps.spells[35] := @Magic.SpellStrength;
  @GDVars.spellFps.spells[36] := @Magic.SpellAnimateDead;
  @GDVars.spellFps.spells[37] := @Magic.SpellCureBlindness;
  @GDVars.spellFps.spells[38] := @Magic.SpellCauseBlindness;
  @GDVars.spellFps.spells[39] := @Magic.SpellCureDisease;
  @GDVars.spellFps.spells[40] := @Magic.SpellCauseDisease;
  @GDVars.spellFps.spells[41] := @Magic.SpellDispelMagic;
  @GDVars.spellFps.spells[42] := @Magic.SpellPrayer;
  @GDVars.spellFps.spells[43] := @Magic.SpellRemoveCurse;
  @GDVars.spellFps.spells[44] := @Magic.SpellBestowCurse;
  @GDVars.spellFps.spells[45] := @Magic.SpellBlink;
  @GDVars.spellFps.spells[46] := @Magic.SpellDispelMagic;
  @GDVars.spellFps.spells[47] := @Magic.SpellFireball;
  @GDVars.spellFps.spells[48] := @Magic.SpellHaste;
  @GDVars.spellFps.spells[49] := @Magic.SpellHold;
  @GDVars.spellFps.spells[50] := @Magic.SpellInvisibility;
  @GDVars.spellFps.spells[51] := @Magic.SpellLightningBolt;
  @GDVars.spellFps.spells[52] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[53] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[54] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[55] := @Magic.SpellSlow;
  @GDVars.spellFps.spells[56] := @Magic.SpellRestoration;
  @GDVars.spellFps.spells[57] := @Magic.SpellPotionOfSpeed;
  @GDVars.spellFps.spells[58] := @Magic.SpellCureSeriousWounds;
  @GDVars.spellFps.spells[59] := @Magic.SpellGiantStrength;
  @GDVars.spellFps.spells[60] := @Magic.SpellJavelinOfLightning;
  @GDVars.spellFps.spells[61] := @Magic.SpellWandOfParalyzation;
  @GDVars.spellFps.spells[62] := @Magic.SpellPotionOfHealing;
  @GDVars.spellFps.spells[63] := @Magic.SpellDustOfDisappearance;
  @GDVars.spellFps.spells[64] := @Magic.SpellFireball;
  @GDVars.spellFps.spells[65] := @Magic.SpellWandOfMagicMissiles;
  @GDVars.spellFps.spells[66] := @Magic.SpellCauseSeriousWounds;
  @GDVars.spellFps.spells[67] := @Magic.SpellNeutralizePoison;
  { the spells from 68 on; each marked reuse shares another spell's handler }
  @GDVars.spellFps.spells[68] := @Magic.SpellPoison;
  { reuse }
  @GDVars.spellFps.spells[69] := @Magic.SpellProtection;
  @GDVars.spellFps.spells[70] := @Magic.SpellSticksToSnakes;
  @GDVars.spellFps.spells[71] := @Magic.SpellCureCriticalWounds;
  @GDVars.spellFps.spells[72] := @Magic.SpellCauseCriticalWounds;
  @GDVars.spellFps.spells[73] := @Magic.SpellDispelEvil;
  @GDVars.spellFps.spells[74] := @Magic.SpellFlameStrike;
  @GDVars.spellFps.spells[75] := @Magic.SpellRaiseDead;
  @GDVars.spellFps.spells[76] := @Magic.SpellSlayLiving;
  { reuse }
  @GDVars.spellFps.spells[77] := @Magic.SpellDetection;
  @GDVars.spellFps.spells[78] := @Magic.SpellEntangle;
  @GDVars.spellFps.spells[79] := @Magic.SpellFaerieFire;
  @GDVars.spellFps.spells[80] := @Magic.SpellInvisibilityToAnimals;
  @GDVars.spellFps.spells[81] := @Magic.SpellCharmMonsters;
  @GDVars.spellFps.spells[82] := @Magic.SpellConfusion;
  @GDVars.spellFps.spells[83] := @Magic.SpellDimensionDoor;
  @GDVars.spellFps.spells[84] := @Magic.SpellFear;
  @GDVars.spellFps.spells[85] := @Magic.SpellFireShield;
  @GDVars.spellFps.spells[86] := @Magic.SpellFumble;
  @GDVars.spellFps.spells[87] := @Magic.SpellIceStorm;
  @GDVars.spellFps.spells[88] := @Magic.SpellMinorGlobeOfInvulnerability;
  { reuse }
  @GDVars.spellFps.spells[89] := @Magic.SpellRemoveCurse;
  { reuse }
  @GDVars.spellFps.spells[90] := @Magic.SpellAnimateDead;
  @GDVars.spellFps.spells[91] := @Magic.SpellCloudkill;
  @GDVars.spellFps.spells[92] := @Magic.SpellConeOfCold;
  @GDVars.spellFps.spells[93] := @Magic.SpellFeeblemind;
  { reuse }
  @GDVars.spellFps.spells[94] := @Magic.SpellHold;
  @GDVars.spellFps.spells[95] := @Magic.SpellImmuneBreath;
  @GDVars.spellFps.spells[96] := @Magic.SpellImmuneParalysis;
  @GDVars.spellFps.spells[97] := @Magic.SpellTurnInvisible;
  @GDVars.spellFps.spells[98] := @Magic.SpellConeBlast;
  @GDVars.spellFps.spells[99] := @Magic.SpellHealSelf;
  { reuse }
  @GDVars.spellFps.spells[100] := @Magic.SpellBestowCurse;
  @GDVars.effectHandlers[86] := @Magic.EffSpitAcidBreath;
  @GDVars.effectHandlers[88] := @Magic.EffBreatheLightning;
  @GDVars.effectHandlers[90] := @Magic.EffBreatheAcid;
  @GDVars.effectHandlers[126] := @Magic.EffAimedParalyzingGaze;
  @GDVars.effectHandlers[128] := @Magic.EffBreatheFire;
  @GDVars.effectHandlers[131] := @Magic.EffBreatheFireAdjacent;
  @GDVars.effectHandlers[132] := @Magic.EffThrowLightning;
end;

begin
end.
