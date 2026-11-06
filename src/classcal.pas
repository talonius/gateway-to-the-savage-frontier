{ A character's class-derived values and the human's change of class. RecalcClassStats rebuilds THAC0, the highest
  level, the attacks, the spell slots and known spells, the saving throws, the thief skills and the usable-class mask,
  and unequips the items the mask no longer allows; RecalcClericSlots, RecalcSaves and RecalcThiefSkills redo one part
  each. ChangeClass runs the "Pick New Class" menu that turns a human into a first-level character of a new class,
  keeping the old class's levels. The dual-class queries (FirstEarlierClass, FirstCurrentClass, CurrentDualClassLevel,
  EarlierClassActive, EffectiveClassLevel), the experience table (XpForLevel) and the level caps (AtClassLevelCap) serve
  the other units. Its rules tables, levelCaps among them, are in GDConsts. }
{$O+,F+}
{$S+}
{$A+}
unit ClassCal;

interface

uses Types, TextRend, GDConsts, GDVars, C_Keys, C_Class, C_Race, C_Spell, C_Stat, MenuCore, Crt;

{ Rebuild the class-derived values: THAC0 (levelHi), the highest level (clLevelHighest), 1 1/2 attacks for a fighter or
  paladin above 6 or a ranger above 7, the spell slots, the saves, the thief skills and the usable-class mask,
  unequipping the uncursed items the mask no longer allows. Old levels count too once EarlierClassActive.
  @param(cr The character.) }
procedure RecalcClassStats(cr: Types.PWork);

{ Adds the Wisdom bonus cleric slots when the character has cleric levels, counting its earlier cleric levels once it
  has passed them. Wisdom above 12 and above 13 each add a first-level slot, above 14 and above 15 each a second-level
  slot, above 16 a third-level slot and above 17 a fourth-level slot, each only to a spell level that already has slots.
  @param(cr The character to update.)
  @param(rebuild True to rebuild the cleric slots from the cleric progression before adding the bonus.) }
procedure RecalcClericSlots(cr: Types.PWork; rebuild: Boolean);

{ Take each save's lowest over the class levels and, once EarlierClassActive, the old levels; then add to save 0 the
  Constitution bonus for a dwarf, a halfling or the wearer of an item with special code 6
  (SAVING_THROW_BONUS_ITEM_CODE), and for anyone the bonus of a Constitution above 18.
  @param(cr The character.) }
procedure RecalcSaves(cr: Types.PWork);

{ Recomputes a character's eight thief skills from the thief skill table at its thief level, counting its earlier thief
  levels once it has passed them. Each skill takes the race adjustment, falling to 0 when a race penalty exceeds it, and
  skills 1 to 5 also take the Dexterity adjustment. The first equipped item with a thief-skill special counts: one kind
  raises a level below 4 to 4, or else adds 10 to each skill; the other computes skill 1 at level 5 at least and skill 2
  at level 7 at least, adding 5 to a skill whose level is already that high, and the 5 or 0 chosen for skill 2 is added
  to skills 3 to 8 as well. Note: without the second kind of item the bonus added to each skill is never set, so it adds
  whatever the local held.
  @param(cr The character to update.) }
procedure RecalcThiefSkills(cr: Types.PWork);

{ Run the "Pick New Class" menu. A human whose current class has no old levels may take a class of its race whose prime
  requisites it has above MAX_NEW_CLASS_BASE_STAT, if its current class's are above MAX_OLD_CLASS_BASE_STAT and the
  class allows its alignment. The new class starts at level 1 with no experience and the old one's levels move to
  clOldClassLevels; items the new class may not use are unequipped.
  @param(cr The character.) }
procedure ChangeClass(cr: Types.PWork);

{ Finds the first class in which a human has an earlier (pre-change) level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstEarlierClass(cr: Types.PWork): Byte;

{ Finds the first class in which a human has a current level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstCurrentClass(cr: Types.PWork): Byte;

{ Finds a human's current level in its first class with a level.
  @param(cr The character to check.)
  @returns(That level; 0 for a non-human or a human with no level.) }
function CurrentDualClassLevel(cr: Types.PWork): ShortInt;

{ Tells whether a human's current class level exceeds the level it had when it changed class, which lets its earlier
  class's abilities count again.
  @param(cr The character to check.)
  @returns(1 when the earlier class counts again, 0 otherwise.) }
function EarlierClassActive(cr: Types.PWork): ShortInt;

{ Return the experience a class needs for a level: the table's figure or, past its last level, the last figure plus
  GDConsts.xpPerExtraLevel for each level more; MaxLongInt past level 40. Note: the table's rows start at level 2, so a
  level below 2 reads the bytes before its row.
  @param(cr Unused.)
  @param(lvl The level.)
  @param(cls The class.)
  @returns(The experience needed.) }
function XpForLevel(cr: Types.PWork; lvl, cls: ShortInt): LongInt;

{ Return whether a class has reached its level cap.
  @param(cls The class.)
  @param(lvl The level.)
  @returns(True at or above the class's cap in GDConsts.levelCaps.) }
function AtClassLevelCap(cls, lvl: ShortInt): Boolean;

{ Return a character's level in a class; where it has none, its old level there once EarlierClassActive.
  @param(cr The character.)
  @param(cls The class.)
  @returns(The level.) }
function EffectiveClassLevel(cr: Types.PWork; cls: ShortInt): Byte;

implementation

const
  NO_CLASS = 17;

  BASE_SAVING_THROW = 20;
  { attacks per round, doubled }
  BASE_ATTACK_RATE = 2;
  ONE_AND_HALF_ATTACKS = 3;
  { an item's special: this bit and a code }
  SPECIAL_ITEM_CODE_BASE = $80;
  SPECIAL_ITEM_CODE_MASK = $7F;
  SAVING_THROW_BONUS_ITEM_CODE = 6;
  LAST_SUPPORTED_XP_LEVEL = 40;
  { a class minimum this high marks a prime requisite }
  CLASS_REQUIREMENT_MARKER = 9;
  MAX_OLD_CLASS_BASE_STAT = 14;
  MAX_NEW_CLASS_BASE_STAT = 16;

  DOUBLE_MAGE_SLOTS_ITEM = $81;

  { the spell id of the cleric's Animate Dead }
  SPELL_ANIMATE_DEAD = 36;

function IsHuman(cr: Types.PWork): Byte; forward;

{ Rebuilds a character's spell slots from its class levels, using an earlier class's level instead once a dual-class
  character has passed it. A cleric gets one first-level slot plus the cleric progression for each level above 1, the
  Wisdom bonus slots, and knows each cleric spell of a level it has slots for, except Animate Dead. A paladin above
  level 8 adds its cleric slots for levels 9 up and knows each cleric spell of a level it has slots for. A ranger above
  level 7 adds its druid slots (spell levels 1 to 3) and magic-user slots (spell levels 1 and 2) for levels 8 up and
  knows each druid spell. A magic-user gets one first-level slot plus its progression. Each equipped item that doubles
  magic-user slots doubles those of spell levels 1 to 3.
  @param(cr The character to update.) }
procedure RecalcSpellSlots(cr: Types.PWork);
var
  cls: ShortInt;
  level: ShortInt;
  j: ShortInt;
  mageLevel: ShortInt;
  k: ShortInt;
  spell: Byte;
  item: Types.PItemRec;
begin
  with cr^ do begin
    FillChar(slots, SizeOf(slots), 0);
    for cls := 0 to 7 do begin
      if (ClassCal.EarlierClassActive(cr) <> 0) and (clOldClassLevels[cls] <> 0) then
        level := clOldClassLevels[cls]
      else
        level := lvl[cls];
      if level > 0 then
        case cls of
          C_Class.CLERIC_LEVEL:
            begin
              Inc(cleric[1]);
              for j := 2 to level do
                for k := 1 to 5 do
                  Inc(cleric[k], GDConsts.experienceSpellsClass[C_Class.CLERIC_LEVEL].slotGains[j, k]);
              ClassCal.RecalcClericSlots(cr, False);
              for spell := 1 to 100 do
                with GDConsts.spellTable[spell] do
                  if (castClass = C_Spell.CLERIC_LIST) and (cleric[levelS] > 0) and
                      (spell <> ClassCal.SPELL_ANIMATE_DEAD) then
                    known[spell] := 1;
            end;
          C_Class.PALADIN_LEVEL:
            if level > 8 then begin
              for j := 9 to level do
                for k := 1 to 5 do
                  Inc(cleric[k], GDConsts.experienceSpellsClass[C_Class.PALADIN_LEVEL].slotGains[j, k]);
              for spell := 1 to 100 do
                with GDConsts.spellTable[spell] do
                  if (castClass = C_Spell.CLERIC_LIST) and (cleric[levelS] > 0) then
                    known[spell] := 1;
            end;
          { druid spells, then magic-user spells from columns 4 and 5 }
          C_Class.RANGER_LEVEL:
            if level > 7 then begin
              for j := 8 to level do begin
                for k := 1 to 3 do
                  Inc(clDruidSlots[k], GDConsts.experienceSpellsClass[C_Class.RANGER_LEVEL].slotGains[j, k]);
                for k := 4 to 5 do begin
                  mageLevel := k - 3;
                  Inc(clMageSlots[mageLevel], GDConsts.experienceSpellsClass[C_Class.RANGER_LEVEL].slotGains[j, k]);
                end;
              end;
              for spell := 1 to 100 do
                if GDConsts.spellTable[spell].castClass = C_Spell.DRUID_LIST then
                  known[spell] := 1;
            end;
          C_Class.MAGE_LEVEL:
            begin
              Inc(clMageSlots[1]);
              for j := 2 to level do
                for k := 1 to 5 do
                  Inc(clMageSlots[k], GDConsts.experienceSpellsClass[C_Class.MAGE_LEVEL].slotGains[j, k]);
            end;
        end;
    end;
    item := itemsHd;
    while item <> nil do begin
      if item^.special = ClassCal.DOUBLE_MAGE_SLOTS_ITEM then
        if item^.equipped <> 0 then
          for k := 1 to 3 do
            Inc(cr^.clMageSlots[k], cr^.clMageSlots[k]);
      item := item^.next;
    end;
  end;
end;

procedure RecalcClassStats(cr: Types.PWork);
var
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: ShortInt;
  level: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  slot: ShortInt;
begin
  cr^.levelHi := 0;
  for cls := 0 to 7 do begin
    level := cr^.lvl[cls];
    if GDConsts.thac0Tbl[cls, level] > cr^.levelHi then cr^.levelHi := GDConsts.thac0Tbl[cls, level];
    if cr^.clLevelHighest < level then cr^.clLevelHighest := level;
    case cls of
      C_Class.FIGHTER_LEVEL: if level > 6 then cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
      C_Class.RANGER_LEVEL: if level > 7 then cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
      C_Class.PALADIN_LEVEL: if level > 6 then cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
    end;
  end;
  ClassCal.RecalcSpellSlots(cr);
  ClassCal.RecalcSaves(cr);
  if cr^.lvl[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(cr);
  cr^.clClassMask := 0;
  for cls := 0 to 7 do
    if (cr^.lvl[cls] > 0) or ((cr^.clOldClassLevels[cls] > 0) and (cr^.clOldClassLevels[cls] < cr^.clLevelHighest)) then
      Inc(cr^.clClassMask, GDConsts.createClassBits[cls]);
  for slot := 0 to 12 do
    if cr^.equip[slot] <> nil then
      if (GDVars.baseItems[cr^.equip[slot]^.itemType].classMask and cr^.clClassMask) = 0 then
        if cr^.equip[slot]^.cursed = 0 then
          cr^.equip[slot]^.equipped := 0;
  if ClassCal.EarlierClassActive(cr) <> 0 then begin
    for cls := 0 to 7 do begin
      level := cr^.clOldClassLevels[cls];
      case cls of
        C_Class.FIGHTER_LEVEL, C_Class.PALADIN_LEVEL: if level > 6 then cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
        C_Class.RANGER_LEVEL: if level > 7 then cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
      end;
      if GDConsts.thac0Tbl[cls, level] > cr^.levelHi then cr^.levelHi := GDConsts.thac0Tbl[cls, level];
    end;
    if (cr^.clOldClassLevels[C_Class.FIGHTER_LEVEL] > 6) or (cr^.clOldClassLevels[C_Class.RANGER_LEVEL] > 7) or
        (cr^.clOldClassLevels[C_Class.PALADIN_LEVEL] > 6) then
      cr^.attacks := ClassCal.ONE_AND_HALF_ATTACKS;
    if cr^.clOldClassLevels[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(cr);
  end;
end;

procedure RecalcClericSlots(cr: Types.PWork; rebuild: Boolean);
var
  j: ShortInt;
  k: ShortInt;
  level: ShortInt;
begin
  level := cr^.lvl[C_Class.CLERIC_LEVEL] + cr^.clOldClassLevels[C_Class.CLERIC_LEVEL] *
    ClassCal.EarlierClassActive(cr);
  if level > 0 then
    with cr^ do begin
      if rebuild then begin
        for k := 2 to 5 do cleric[k] := 0;
        cleric[1] := 1;
        for j := 2 to level do
          for k := 1 to 5 do
            Inc(cleric[k], GDConsts.experienceSpellsClass[C_Class.CLERIC_LEVEL].slotGains[j, k]);
      end;
      if (stats[C_Stat.WISDOM].current > 12) and (cleric[1] > 0) then Inc(cleric[1]);
      if (stats[C_Stat.WISDOM].current > 13) and (cleric[1] > 0) then Inc(cleric[1]);
      if (stats[C_Stat.WISDOM].current > 14) and (cleric[2] > 0) then Inc(cleric[2]);
      if (stats[C_Stat.WISDOM].current > 15) and (cleric[2] > 0) then Inc(cleric[2]);
      if (stats[C_Stat.WISDOM].current > 16) and (cleric[3] > 0) then Inc(cleric[3]);
      if (stats[C_Stat.WISDOM].current > 17) and (cleric[4] > 0) then Inc(cleric[4]);
    end;
end;

procedure RecalcSaves(cr: Types.PWork);
var
  save: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  level: Byte;
  special: ShortInt;
  item: Types.PItemRec;
  hasSaveItem: ShortInt;
begin
  hasSaveItem := 0;
  item := cr^.itemsHd;
  while (item <> nil) and (hasSaveItem = 0) do begin
    if item^.special > ClassCal.SPECIAL_ITEM_CODE_BASE then
      if item^.equipped <> 0 then begin
        special := item^.special and ClassCal.SPECIAL_ITEM_CODE_MASK;
        hasSaveItem := Ord(special = ClassCal.SAVING_THROW_BONUS_ITEM_CODE);
      end;
    item := item^.next;
  end;
  for save := 0 to 4 do begin
    cr^.clSaves[save] := ClassCal.BASE_SAVING_THROW;
    for cls := 0 to 7 do begin
      if cr^.lvl[cls] > 0 then
        if cr^.clSaves[save] > GDConsts.savingThrow[cls, cr^.lvl[cls], save] then
          cr^.clSaves[save] := GDConsts.savingThrow[cls, cr^.lvl[cls], save];
      if ClassCal.EarlierClassActive(cr) <> 0 then
        if cr^.clOldClassLevels[cls] <> 0 then
          if cr^.clSaves[save] > GDConsts.savingThrow[cls, cr^.clOldClassLevels[cls], save] then
            cr^.clSaves[save] := GDConsts.savingThrow[cls, cr^.clOldClassLevels[cls], save];
    end;
    if save = 0 then begin
      if (cr^.race = C_Race.DWARF) or (cr^.race = C_Race.HALFLING) or (hasSaveItem <> 0) then begin
        case cr^.stats[C_Stat.CONSTITUTION].current of
          4..6: Inc(cr^.clSaves[save]);
          7..10: Inc(cr^.clSaves[save], 2);
          11..13: Inc(cr^.clSaves[save], 3);
          14..17: Inc(cr^.clSaves[save], 4);
          18: Inc(cr^.clSaves[save], 5);
        end;
      end;
    end;
    if save = 0 then begin
      case cr^.stats[C_Stat.CONSTITUTION].current of
        19, 20: Inc(cr^.clSaves[save]);
        21, 22: Inc(cr^.clSaves[save], 2);
        23, 24: Inc(cr^.clSaves[save], 3);
        25: Inc(cr^.clSaves[save], 4);
      end;
    end;
  end;
end;

procedure RecalcThiefSkills(cr: Types.PWork);
var
  skill: Byte;
  bonus: Byte;
  special: ShortInt;
  level: ShortInt;
  baseLevel: ShortInt;
  item: Types.PItemRec;
  raisesPickAndLock: ShortInt;
  raisesAllSkills: ShortInt;
begin
  with cr^ do begin
    raisesPickAndLock := 0;
    raisesAllSkills := 0;
    item := itemsHd;
    while (item <> nil) and (raisesPickAndLock = 0) and (raisesAllSkills = 0) do begin
      if item^.special > ClassCal.SPECIAL_ITEM_CODE_BASE then
        if item^.equipped <> 0 then begin
          special := item^.special and ClassCal.SPECIAL_ITEM_CODE_MASK;
          raisesPickAndLock := Ord(special = 11);
          raisesAllSkills := Ord(special = 2);
        end;
      item := item^.next;
    end;
    level := cr^.lvl[C_Class.THIEF_LEVEL] + cr^.clOldClassLevels[C_Class.THIEF_LEVEL] *
      ClassCal.EarlierClassActive(cr);
    if (level < 4) and (raisesAllSkills <> 0) then begin
      level := 4;
      raisesAllSkills := 0;
    end;
    baseLevel := level;
    for skill := 1 to 8 do begin
      if raisesPickAndLock <> 0 then
        case skill of
          1: if level < 5 then begin level := 5; bonus := 0; end
             else bonus := 5;
          2: if level < 7 then begin level := 7; bonus := 0; end
             else bonus := 5;
        end;
      if (GDConsts.raceAdj[race, skill] < 0) and
          (GDConsts.thiefBase[level, skill] < Abs(GDConsts.raceAdj[race, skill]) + bonus) then
        thiefSk[skill] := 0
      else begin
        thiefSk[skill] := GDConsts.thiefBase[level, skill] + GDConsts.raceAdj[race, skill] + bonus;
        if skill < 6 then
          thiefSk[skill] := thiefSk[skill] + GDConsts.dexAdj[stats[C_Stat.DEXTERITY].current, skill];
      end;
      if raisesAllSkills <> 0 then
        Inc(thiefSk[skill], 10);
      level := baseLevel;
    end;
  end;
end;

procedure ChangeClass(cr: Types.PWork);
var
  menuKey: Char;
  newClass: ShortInt;
  classCount: Byte;
  listHead: Types.PItemRec;
  node: Types.PItemRec;
  count: Integer;
  addExit: Boolean;
  redraw: Boolean;
  item: Types.PItemRec;

  { Return whether the character may change to class c, by its prime requisites and alignment. }
  function QualifiesForClass(c: ShortInt): Boolean;
  var
    qual: Boolean;
    stat: ShortInt;
    alignIdx: Byte;
  begin
    qual := Byte(GDConsts.classesByRace[cr^.race, GDVars.sharedLoopIndex]) <> ClassCal.FirstCurrentClass(cr);
    stat := 0;
    while (stat <= 5) and
        not ((GDConsts.minimumStatisticsClass[ShortInt(ClassCal.FirstCurrentClass(cr)), stat] >=
              ClassCal.CLASS_REQUIREMENT_MARKER) and (cr^.stats[stat].permanent <= ClassCal.MAX_OLD_CLASS_BASE_STAT)) do
      Inc(stat);
    qual := qual and (stat > 5);
    stat := 0;
    while (stat <= 5) and
        not ((GDConsts.minimumStatisticsClass[c, stat] >= ClassCal.CLASS_REQUIREMENT_MARKER) and
             (cr^.stats[stat].permanent <= ClassCal.MAX_NEW_CLASS_BASE_STAT)) do
      Inc(stat);
    qual := qual and (stat > 5);
    alignIdx := 1;
    while (Byte(GDConsts.alignmentsAllowedClass[c, 0]) >= alignIdx) and
        (Byte(GDConsts.alignmentsAllowedClass[c, alignIdx]) <> cr^.clAlignment) do
      Inc(alignIdx);
    qual := qual and (Byte(GDConsts.alignmentsAllowedClass[c, 0]) >= alignIdx);
    QualifiesForClass := qual;
  end;

begin
  if (ClassCal.FirstEarlierClass(cr) <> ClassCal.NO_CLASS) or (ClassCal.IsHuman(cr) = 0) then
    TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', Red, White)
  else begin
    classCount := GDConsts.classesByRace[cr^.race, 0];
    GetMem(listHead, SizeOf(Types.TItemNode));
    node := listHead;
    node^.next := nil;
    node^.inUse := 1;
    node^.name := 'Pick New Class';
    count := 1;
    for GDVars.sharedLoopIndex := 1 to classCount do begin
      newClass := GDConsts.classesByRace[cr^.race, GDVars.sharedLoopIndex];
      if QualifiesForClass(newClass) then begin
        GetMem(node^.next, SizeOf(Types.TItemNode));
        node := node^.next;
        node^.next := nil;
        node^.inUse := 0;
        node^.name := GDConsts.classNames[newClass];
        Inc(count);
      end;
    end;
    if count = 1 then begin
      TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', Red, White);
      MenuCore.FreeStringList(listHead);
    end else begin
      node := listHead;
      count := 1;
      addExit := True;
      redraw := True;
      repeat
        menuKey := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, listHead, addExit,
                                         redraw, count, node);
        if menuKey = C_Keys.NONE then Exit;
      until menuKey = 'S';
      cr^.clExperience := 0;
      cr^.attacks := ClassCal.BASE_ATTACK_RATE;
      newClass := 0;
      while (newClass <= 7) and (GDConsts.classNames[newClass] <> node^.name) do
        Inc(newClass);
      MenuCore.FreeStringList(listHead);
      cr^.clOldClassLevels[ShortInt(ClassCal.FirstCurrentClass(cr))] := ClassCal.CurrentDualClassLevel(cr);
      cr^.clLevelAtChange := cr^.clLevelHighest;
      cr^.clLevelHighest := 1;
      cr^.lvl[ShortInt(ClassCal.FirstCurrentClass(cr))] := 0;
      cr^.lvl[newClass] := 1;
      FillChar(cr^.slots, SizeOf(cr^.slots), 0);
      case newClass of
        C_Class.CLERIC_LEVEL: cr^.cleric[1] := 1;
        C_Class.MAGE_LEVEL:
          begin
            cr^.clMageSlots[1] := 1;
            cr^.known[C_Spell.DETECT_MAGIC_MAGE] := 1;
            cr^.known[C_Spell.READ_MAGIC] := 1;
            cr^.known[C_Spell.ENLARGE] := 1;
            cr^.known[C_Spell.SLEEP] := 1;
          end;
      end;
      cr^.clCharClass := newClass;
      TextRend.PrintAndPause(cr^.name + ' is now a 1st level ' + GDConsts.classNames[newClass] + '.', LightGreen,
                             Black);
      FillChar(cr^.clMemorizedSpells[0], C_Spell.MEMORIZED_SPELL_SLOTS, 0);
      ClassCal.RecalcClassStats(cr);
      ClassCal.RecalcClericSlots(cr, True);
      ClassCal.RecalcSaves(cr);
      ClassCal.RecalcThiefSkills(cr);
      item := cr^.itemsHd;
      while item <> nil do begin
        if (GDVars.baseItems[item^.itemType].classMask and cr^.clClassMask) = 0 then
          if item^.cursed = 0 then
            item^.equipped := 0;
        item := item^.next;
      end;
    end;
  end;
end;

function FirstEarlierClass(cr: Types.PWork): Byte;
var
  cls: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    FirstEarlierClass := ClassCal.NO_CLASS
  else begin
    cls := 0;
    while (cls < 7) and (cr^.clOldClassLevels[cls] = 0) do
      Inc(cls);
    if cr^.clOldClassLevels[cls] > 0 then
      FirstEarlierClass := cls
    else
      FirstEarlierClass := ClassCal.NO_CLASS;
  end;
end;

function FirstCurrentClass(cr: Types.PWork): Byte;
var
  cls: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    FirstCurrentClass := ClassCal.NO_CLASS
  else begin
    cls := 0;
    while (cls < 7) and (cr^.lvl[cls] = 0) do
      Inc(cls);
    if cr^.lvl[cls] > 0 then
      FirstCurrentClass := cls
    else
      FirstCurrentClass := ClassCal.NO_CLASS;
  end;
end;

function CurrentDualClassLevel(cr: Types.PWork): ShortInt;
var
  cls: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    CurrentDualClassLevel := 0
  else begin
    cls := 0;
    while (cls < 7) and (cr^.lvl[cls] = 0) do
      Inc(cls);
    CurrentDualClassLevel := cr^.lvl[cls];
  end;
end;

{ Tells whether a character is human.
  @param(cr The character to check.)
  @returns(1 for a human, 0 otherwise.) }
function IsHuman(cr: Types.PWork): Byte;
begin
  IsHuman := Ord(cr^.race = C_Race.HUMAN);
end;

function EarlierClassActive(cr: Types.PWork): ShortInt;
begin
  EarlierClassActive := Ord(ClassCal.CurrentDualClassLevel(cr) > cr^.clLevelAtChange);
end;

function EffectiveClassLevel(cr: Types.PWork; cls: ShortInt): Byte;
var
  level: Byte;
begin
  level := cr^.lvl[cls];
  if level = 0 then
    if ClassCal.EarlierClassActive(cr) <> 0 then
      level := cr^.clOldClassLevels[cls];
  EffectiveClassLevel := level;
end;

function XpForLevel(cr: Types.PWork; lvl, cls: ShortInt): LongInt;
begin
  XpForLevel := MaxLongInt;
  if lvl < ClassCal.LAST_SUPPORTED_XP_LEVEL + 1 then
    if lvl <= SizeOf(GDConsts.experienceSpellsClass[cls].xpNeeded) div SizeOf(LongInt) + 1 then
      XpForLevel := GDConsts.experienceSpellsClass[cls].xpNeeded[lvl]
    else
      XpForLevel :=
        (lvl - (SizeOf(GDConsts.experienceSpellsClass[cls].xpNeeded) div SizeOf(LongInt) + 1)) *
        GDConsts.xpPerExtraLevel[cls] +
        GDConsts.experienceSpellsClass[cls].xpNeeded[SizeOf(GDConsts.experienceSpellsClass[cls].xpNeeded) div
                                                     SizeOf(LongInt) + 1];
end;

function AtClassLevelCap(cls, lvl: ShortInt): Boolean;
begin
  AtClassLevelCap := GDConsts.levelCaps[cls] <= lvl;
end;

begin
end.
