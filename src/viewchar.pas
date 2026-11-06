{ The character sheet and its menus. DisplayChar draws a character's sheet, with PrintStat, PrintMoney and
  PrintCombatStats for its parts; ViewCharMenu is the View command of every menu that has one (Items, Spells, Trade,
  Drop or Deposit, and a paladin's Heal and Cure); UseItemMenu is the Items menu (Ready, Use, Trade, Drop or Deposit,
  Halve, Join, and Sell and Id in a shop). Readying or removing an item with an equip effect applies or undoes it
  (ToggleItemEffect). SpellMenu opens the spell lists Camp, CbtActs and CharGen pick from, SelectPrevNextChar steps the
  current character, and CannotCarryItem and CreatureCoinValueInGold serve the shops, Temple, SaveLoad, CharGen and
  DevMenu. ViewChar owns no storage. }
{$O+,F+,S+}
{$A+}
unit ViewChar;

interface

uses Types, C_Status, C_Effect, C_Class, C_Equip, C_Ifc, C_Item, C_Msg, C_Npc, C_Spell, C_Stat, Money, Border, CharHlp,
  ClassCal, Magic, Crt, GDConsts, GDVars, C_Keys, TextRend, MenuCore, CbtMap, FxEngine, C_Gbvm;

{ Draw the current character's sheet: name, status, age, alignment, race, class, levels, experience, ability scores,
  money, combat values and the readied weapon and armor. The character is kept in tempCr1, which the sheet's menus
  read. }
procedure DisplayChar;

{ Draw the current character's armor class, hit points, THAC0, damage, encumbrance and movement. Note: the movement
  shown is doubled when slowed and halved when hasted. }
procedure PrintCombatStats;

{ Draw one ability score of the current character, with exceptional strength.
  @param(statIdx The ability, 0 strength to 5 charisma.)
  @param(modifying True to highlight it, as CharGen's modify menu does.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Draw the current character's coins, each kind it has on its own line. }
procedure PrintMoney;

{ Run the View menu on the current character's sheet until Exit.
  @param(done Set when an item used in combat ends the character's turn.) }
procedure ViewCharMenu(var done: Boolean);

{ Run the Items menu on the current character's items until Exit or it has none.
  @param(done Set when an item used in combat ends the character's turn.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies an item for the current character. A cursed item cannot be unreadied. Readying checks, the later
  checks winning, the free hands, an occupied slot or ammunition slot and the class mask; the hands-full message is
  skipped for a quick-fighting creature in combat. An item with a special above $7F calls its effect handler when
  readied and when unreadied.
  @param(it The item.) }
procedure ToggleReadyItem(it: Types.PItemRec);

{ Use a readied item of the current character's: cast from a scroll, or cast the item's spell, spending a charge or the
  scroll's spell when it was cast.
  @param(it The item.)
  @param(done Set when the spell was cast; in combat, after a combat spell, CharHlp.ClearGuard's result.) }
procedure UseItem(it: Types.PItemRec; var done: Boolean);

{ Tells whether a character cannot take an item: it already holds 16 items, or the item's weight, times its quantity,
  would take it past its weight allowance plus 1500. The character's stats are recomputed first.
  @param(cr The character.)
  @param(it The item.)
  @returns(True when the character cannot take the item.) }
function CannotCarryItem(cr: Types.PWork; it: Types.PItemRec): Boolean;

{ Make the previous party member (the up arrow) or the next (the down arrow) the current character, wrapping at the
  ends; nothing happens during a mouse click (GDVars.isMouseClick).
  @param(c The extended key.) }
procedure SelectPrevNextChar(c: Char);

{ Works out the worth of a character's five coin types in gold, rounding half up; gems and jewelry are left out.
  @param(cr The character.)
  @returns(The worth in gold pieces.) }
function CreatureCoinValueInGold(cr: Types.PWork): LongInt;

{ Show a spell list of the current character's and let the player pick from it.
  @param(menuType The list: 0 memorized, 1 the spellbook, 2 a scroll, 3 the scrolls, 4 to choose from, 5 being
    memorized, 6 being scribed (Magic.GenerateSpellList).)
  @param(selType Magic.SpellSelection's mode; 1 always redraws the frame.)
  @param(idx The selection, below 0 to draw the frame.)
  @param(notEmpty Set when the list has any spell.)
  @returns(The spell picked, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

implementation

const
  { Types.TWork.equipped's last slot of a single-item kind }
  EQUIP_BOOTS = 8;

  { the effects the Heal action sets for a day and the Cure action for a week; while one is set the character cannot
    heal, or cure, again }
  EFF_RECENT_HEAL = 140;
  EFF_RECENT_CURE = 141;

  { TItemRec.special's equip-effect id }
  SPECIAL_ID_MASK = $7F;
  { TItemRec.special's bit for an effect readying applies }
  SPECIAL_ON_READY = $80;
  { thac0Cur holds 60 less the THAC0 }
  THAC0_BIAS = 60;
  { the strength that has a percentile }
  STRENGTH_EXCEPTIONAL = 18;
  { gold pieces }
  IDENTIFY_PRICE = 200;
  { the price of a stacked item is for 20 }
  AMMO_BUNDLE = 20;
  { a thief above it may cast from a scroll }
  THIEF_SCROLL_LEVEL = 9;
  { percent }
  THIEF_SCROLL_CHANCE = 75;
  { minutes: a day }
  HEAL_COOLDOWN = 1440;
  { minutes: a week }
  CURE_COOLDOWN = 10080;

  { the first of the message lines at the foot of the screen }
  LINES_TOP = 21;

{ Return source with spaces before it to width characters.
  @param(source The text.)
  @param(width The width.)
  @returns(The padded text.) }
function RightAlignField(source: String; width: Byte): String;
var
  spaces: String;
begin
  spaces := '';
  while Length(source) < width do begin
    spaces := spaces + ' ';
    Dec(width);
  end;
  RightAlignField := spaces + source;
end;

{ Return source with spaces after it to width characters.
  @param(source The text.)
  @param(width The width.)
  @returns(The padded text.) }
function LeftAlignField(source: String; width: Byte): String;
var
  spaces: String;
begin
  spaces := '';
  while Length(source) < width do begin
    spaces := spaces + ' ';
    Dec(width);
  end;
  LeftAlignField := source + spaces;
end;

procedure ItemTradeMenu(it: Types.PItemRec); forward;

procedure HalveItem(it: Types.PItemRec); forward;

procedure JoinItem(it: Types.PItemRec); forward;

procedure SellItem(it: Types.PItemRec); forward;

procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

procedure ToggleItemEffect(it: Types.PItemRec; equipping: Boolean); forward;

function CanHeal(cr: Types.PWork): Boolean; forward;

function CanCure(cr: Types.PWork): Boolean; forward;

procedure PaladinLayOnHands(cr: Types.PWork); forward;

procedure PaladinCureDisease(cr: Types.PWork); forward;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statColumn: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  isMulticlass: Byte;
begin
  Border.DrawSheetFrame;
  GDVars.tempCr1 := GDVars.curChar;
  CharHlp.DisplayCreatureName(GDVars.tempCr1, 1, 1, False);
  if GDVars.tempCr1^.npc > C_Npc.MORALE_MASK then
    TextRend.DisplayString(Length(GDVars.tempCr1^.name) + 3, 1, LightGreen, Black, '(NPC)');
  TextRend.DisplayString(20, 1, White, Black, 'Status');
  TextRend.DisplayString(27, 1, LightGreen, Black, GDConsts.statusNames[GDVars.tempCr1^.statusS]);
  s := GDConsts.genderNames[GDVars.tempCr1^.gender];
  TextRend.DisplayString(1, 3, White, Black, s);
  TextRend.DisplayString(12, 3, White, Black, 'Age ' + CharHlp.Uint16Str(GDVars.tempCr1^.age));
  s := GDConsts.alignNames[GDVars.tempCr1^.alignment];
  TextRend.DisplayString(1, 4, White, Black, s);
  s := GDConsts.raceNames[GDVars.tempCr1^.race];
  TextRend.DisplayString(20, 4, White, Black, s);
  s := GDConsts.classNames[GDVars.tempCr1^.charClass];
  TextRend.DisplayString(1, 5, White, Black, s);
  multi := False;
  s := '';
  for j := 0 to 7 do
    if (GDVars.tempCr1^.classLevels[j] > 0) or
        ((GDVars.tempCr1^.classLevels2[j] < ClassCal.CurrentDualClassLevel(Types.PWork(GDVars.tempCr1))) and
         (GDVars.tempCr1^.classLevels2[j] > 0)) then begin
      if multi then
        s := s + '/';
      s := s + CharHlp.Uint8Str(GDVars.tempCr1^.classLevels[j] + GDVars.tempCr1^.classLevels2[j]);
      multi := True;
    end;
  TextRend.DisplayString(1, 7, White, Black, 'Level');
  TextRend.DisplayString(7, 7, White, Black, s);
  TextRend.DisplayString(20, 7, White, Black,
                         'Experience ' + ViewChar.RightAlignField(CharHlp.Int32Str(GDVars.tempCr1^.experience), 7));
  for i := 0 to 5 do begin
    case i of
      0: s := 'STR ';
      1: s := 'INT ';
      2: s := 'WIS ';
      3: s := 'DEX ';
      4: s := 'CON ';
      5: s := 'CHA ';
    end;
    TextRend.DisplayString(1, i + 9, LightGreen, Black, s);
    ViewChar.PrintStat(i, False);
  end;
  ViewChar.PrintMoney;
  ViewChar.PrintCombatStats;
  if GDVars.tempCr1^.equipped[C_Equip.WEAPON] <> nil then begin
    TextRend.DisplayString(1, 21, White, Black, 'Weapon');
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[C_Equip.WEAPON], 8, 21, False, True);
  end;
  if GDVars.tempCr1^.equipped[C_Equip.ARMOR] <> nil then begin
    TextRend.DisplayString(1, 22, White, Black, 'Armor');
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[C_Equip.ARMOR], 8, 22, False, True);
  end;
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(20, 9, 38, 15);
  row := 9;
  for m := 6 downto 0 do
    if GDVars.curChar^.coinsA[m] > 0 then begin
      s := GDConsts.moneyNames[m];
      TextRend.DisplayString(20, row, LightGreen, Black,
                             s +
                             ViewChar.RightAlignField(CharHlp.Uint16Str(GDVars.curChar^.coinsA[m]), 18 - Length(s)));
      Inc(row);
    end;
end;

procedure PrintCombatStats;
var
  p: Types.PWork;
  mv: Byte;
  s: Types.TStr40;
  eff: Types.PEffectRec;
begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  TextRend.DisplayString(1, 17, White, Black, 'ARMOR CLASS');
  CharHlp.PrintArmorClassAligned(p, 16, 17);
  TextRend.DisplayString(20, 3, White, Black, 'HIT POINTS');
  CharHlp.PrintHitPointsAligned(p, 32, 3, False);
  TextRend.DisplayString(35, 3, LightGreen, Black, '/' + ViewChar.LeftAlignField(CharHlp.Uint8Str(p^.tpHpMax), 3));
  TextRend.DisplayString(1, 18, White, Black, 'THAC0');
  TextRend.DisplayString(15, 18, LightGreen, Black,
                         ViewChar.RightAlignField(CharHlp.Uint8Str(ViewChar.THAC0_BIAS - p^.thac0Cur), 4));
  s := CharHlp.Uint8Str(p^.curRolls) + 'd' + CharHlp.Uint8Str(p^.curDice);
  if p^.curMod > 0 then
    s := s + '+' + CharHlp.Uint8Str(p^.curMod);
  if p^.curMod < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(p^.curMod));
  TextRend.DisplayString(1, 19, White, Black, 'Damage');
  TextRend.DisplayString(8, 19, LightGreen, Black, ViewChar.RightAlignField(s, 11));
  TextRend.DisplayString(20, 17, White, Black, 'Encumbrance ');
  TextRend.DisplayString(32, 17, LightGreen, Black, ViewChar.RightAlignField(CharHlp.Uint16Str(p^.encumbrance), 6));
  mv := p^.movementCur;
  if CharHlp.HasEffect(p, C_Effect.SLOWED, eff) then
    mv := mv * 2;
  if CharHlp.HasEffect(p, C_Effect.HASTED, eff) then
    mv := mv div 2;
  TextRend.DisplayString(20, 18, White, Black, 'Movement');
  TextRend.DisplayString(34, 18, LightGreen, Black, ViewChar.RightAlignField(CharHlp.Uint8Str(mv), 4));
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := White
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 9, 11, statIdx + 9);
  if GDVars.curChar^.stat[statIdx].current < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 9, hlCol, Black, CharHlp.Uint8Str(GDVars.curChar^.stat[statIdx].current));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.stat[C_Stat.STRENGTH].current = ViewChar.STRENGTH_EXCEPTIONAL) and
      (GDVars.curChar^.exStrCur > 0) then begin
    s := CharHlp.Uint8Str(GDVars.curChar^.exStrCur);
    if GDVars.curChar^.exStrCur < 10 then
      s := '0' + s;
    if GDVars.curChar^.exStrCur = 100 then
      s := '00';
    TextRend.DisplayString(7, 9, hlCol, Black, '(' + s + ')');
  end;
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  GDVars.tempCr2 := GDVars.curChar;
  ViewChar.DisplayChar;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
      if GDVars.tempCr1^.memorizedSpells[i] in [1..100] then
        hasSpells := True;
    for j := 0 to 6 do
      if GDVars.tempCr1^.coinsA[j] > 0 then
        hasMoney := True;
    if GDVars.tempCr1^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    if ((GDVars.tempCr1^.npc < C_Npc.NON_PLAYER) or (GDVars.tempCr1^.enabled = 0) or
        (GDVars.tempCr1^.statusS = C_Status.ANIMATED)) and
        hasMoney and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
      s := s + 'Trade ';
    if hasMoney then
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        s := s + 'Deposit '
      else
        s := s + 'Drop ';
    if ViewChar.CanHeal(GDVars.curChar) then
      s := s + 'Heal ';
    if ViewChar.CanCure(GDVars.curChar) then
      s := s + 'Cure ';
    s := s + 'Exit';
    ch := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    if not ext then
      case ch of
        'I': ViewChar.UseItemMenu(done);
        'S': i := ViewChar.SpellMenu(0, 0, idx, hasSpells);
        'T': ViewChar.TradeTreasureMenu;
        'D': begin
               ViewChar.DropMoneyMenu;
               ViewChar.PrintMoney;
             end;
        'H': ViewChar.PaladinLayOnHands(GDVars.curChar);
        'C': ViewChar.PaladinCureDisease(GDVars.curChar);
      end;
    if not done and (ch in ['I', 'S', 'T']) then
      ViewChar.DisplayChar;
  end;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharHlp.DisplayNoncombatInterface;
end;

{ Return whether an item may leave the character: not while readied, and a scroll with a spell being scribed from it
  only if the player agrees to lose the scribing.
  @param(it The item.)
  @returns(True when the item may leave.) }
function CheckItemAvail(it: Types.PItemRec): Boolean;
begin
  CheckItemAvail := False;
  if it^.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(it) then
    CheckItemAvail := True
  else if (it^.spells[1] > C_Spell.ID_MASK) or (it^.spells[2] > C_Spell.ID_MASK) or
    (it^.spells[3] > C_Spell.ID_MASK) then begin
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, ViewChar.LINES_TOP, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := ViewChar.LINES_TOP;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, Yellow,
                                  Black, False,
                                  ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevItem: Types.PItemRec;
  cr: Types.PWork;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedChoice: Byte;
begin
  cr := GDVars.curChar;
  ch := ' ';
  sel := cr^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  while not (ch in [C_Keys.NONE, 'E']) and not done and (cr^.numberOfItems > 0) do begin
    itemCount := cr^.numberOfItems;
    if cr^.itemsAddr <> nil then begin
      s := 'Ready';
      if (cr^.enabled <> 0) and (GDVars.gbvmZone0Ptr^[C_Gbvm.ANTI_MAGIC] = 0) and
          ((GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.EXPLORING) or
           ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and (cr^.combatAddr^.itemUseAllowed <> 0))) then
        s := s + ' Use';
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.enabled = 0) or (cr^.statusS = C_Status.ANIMATED)) and
          (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
        s := s + ' Trade';
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        s := s + ' Deposit'
      else
        s := s + ' Drop';
      if cr^.numberOfItems < C_Item.MAX_CARRIED_ITEMS then
        s := s + ' Halve';
      s := s + ' Join';
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.enabled = 0) or (cr^.statusS = C_Status.ANIMATED)) and
          (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE) then
        s := s + ' Sell';
      if GDVars.interfaceState = C_Ifc.SHOP_TEMPLE then
        s := s + ' Id';
      p := cr^.itemsAddr;
      while p <> nil do begin
        CharHlp.PrintItemString(cr, p, 0, 0, True, False);
        p := p^.next;
      end;
      if needRedraw or (GDVars.redrawInventoryMenuFlag <> 0) then begin
        Border.DrawTitleInset;
        CharHlp.DisplayCreatureName(cr, 1, 1, True);
        TextRend.DisplayString(Length(cr^.name) + 4, 1, LightGreen, Black, 'Items');
        TextRend.DisplayString(1, 3, White, Black, 'Ready Item');
        vmRedraw := True;
        needRedraw := False;
        GDVars.redrawInventoryMenuFlag := 0;
      end;
      ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22, Types.PItemRec(cr^.itemsAddr),
                                  True, vmRedraw, idx, Types.PItemRec(sel));
      if sel <> nil then
        case ch of
          'R': ViewChar.ToggleReadyItem(sel);
          'U': if sel^.equipped = 0 then
               begin
                 CharHlp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if Magic.ItemReadable(sel) or
                 ((sel^.effect > 0) and (sel^.special < ViewChar.SPECIAL_ON_READY)) then begin
                 ViewChar.UseItem(sel, done);
                 if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
                   done := False;
                 if not done then
                   needRedraw := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needRedraw := True;
               end;
          'D': if ViewChar.CheckItemAvail(sel) then
               begin
                 GDVars.itemListCursor := GDVars.treasureItems;
                 while (GDVars.itemListCursor <> nil) and (GDVars.itemListCursor^.next <> nil) do
                   GDVars.itemListCursor := GDVars.itemListCursor^.next;
                 CharHlp.PrintItemString(cr, sel, 0, 0, False, False);
                 if GDVars.interfaceState = C_Ifc.IN_VAULT then begin
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, Yellow, Black, True,
                                                 'Your ' + sel^.name + 'will be left in the vault');
                   TextRend.PauseOnly;
                   if GDVars.treasureItems = nil then begin
                     GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                     GDVars.itemListCursor := GDVars.treasureItems;
                   end else begin
                     GetMem(GDVars.itemListCursor^.next, SizeOf(Types.TItemRec));
                     GDVars.itemListCursor := GDVars.itemListCursor^.next;
                   end;
                   GDVars.itemListCursor^ := sel^;
                   GDVars.itemListCursor^.next := nil;
                   CharHlp.RemoveItem(cr, sel);
                   vmRedraw := True;
                 end else begin
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, Yellow, Black, True,
                                                 'Your ' + sel^.name + 'will be gone forever');
                   if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
                   begin
                     CharHlp.RemoveItem(GDVars.curChar, sel);
                     vmRedraw := True;
                   end;
                 end;
                 Border.ClearBox(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': ViewChar.JoinItem(sel);
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, vmRedraw);
        end;
      CharHlp.RecalcStats(cr);
    end;
    if cr^.numberOfItems <> itemCount then
      vmRedraw := True;
  end;
end;

{ Apply an item's equip effect as it is readied, or undo it as it is removed; its effect id is the low seven bits of
  special. 0: FxEngine's handler for the item. 1: readying doubles the magic-user's spell slots of levels 1 to 3, and
  removing rebuilds them from the magic-user level and drops the memorized magic-user spells beyond them. 4 and 14: an
  item of another alignment or race is removed again and, 4 always and 14 with a high nibble, deals that many points of
  damage. 9: removing ends the Spiritual Hammer. The others recompute ability scores (FxEngine.RecalcAbility; 8 the one
  its effect byte names) or the thief skills. The level index is a Byte into spellCnt and a ShortInt into slots.
  @param(it The item.)
  @param(equipping True as it is readied, False as it is removed.) }
procedure ToggleItemEffect(it: Types.PItemRec; equipping: Boolean);
var
  effId: Byte;
  classLevel: Byte;
  damage: Byte;
  cr: Types.PWork;
  i: ShortInt;
  newLevel: Byte;
  j: ShortInt;
  k: Byte;
  lvl: Byte;
  spellCnt: array[1..5] of Byte;
begin
  if Magic.ItemReadable(it) then
    Exit;
  cr := GDVars.curChar;
  effId := it^.special and ViewChar.SPECIAL_ID_MASK;
  case effId of
    0: begin
         GDVars.overrideEffectFlag := 1;
         FxEngine.CallEffectHandler(it^.special, cr, it, equipping = False);
       end;
    1: if equipping then begin
         for i := 1 to 3 do
           Inc(cr^.slots[C_Spell.MAGIC_USER_LIST, i], cr^.slots[C_Spell.MAGIC_USER_LIST, i]);
       end else begin
         classLevel := ClassCal.EarlierClassActive(Types.PWork(cr)) * cr^.classLevels2[C_Class.MAGE_LEVEL]
                       + cr^.classLevels[C_Class.MAGE_LEVEL];
         newLevel := classLevel;
         for i := 1 to 5 do
           cr^.slots[C_Spell.MAGIC_USER_LIST, i] := 0;
         cr^.slots[C_Spell.MAGIC_USER_LIST, 1] := 1;
         for j := 2 to newLevel do
           for i := 1 to 5 do
             Inc(cr^.slots[C_Spell.MAGIC_USER_LIST, i],
                 GDConsts.experienceSpellsClass[C_Class.MAGE_LEVEL].slotGains[j, i]);
         FillChar(spellCnt[1], SizeOf(spellCnt), 0);
         for k := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
           if cr^.memorizedSpells[k] in [1..100] then
             if GDConsts.spellTable[cr^.memorizedSpells[k]].castClass = C_Spell.MAGIC_USER_LIST then begin
               lvl := GDConsts.spellTable[cr^.memorizedSpells[k]].level;
               Inc(spellCnt[lvl]);
               if spellCnt[lvl] > cr^.slots[C_Spell.MAGIC_USER_LIST, ShortInt(lvl)] then
                 cr^.memorizedSpells[k] := 0;
             end;
       end;
    2: begin
         FxEngine.RecalcAbility(cr, C_Stat.DEXTERITY);
         ClassCal.RecalcThiefSkills(Types.PWork(cr));
       end;
    4: if (it^.effect and $F) <> Byte(cr^.alignment) then begin
         it^.equipped := 0;
         damage := it^.effect div 16;
         GDVars.elementMask := 8;
         if GDVars.interfaceState = C_Ifc.IN_COMBAT then
           CharHlp.DisplayCombatInterface;
         FxEngine.InflictNonWeaponDamage(cr, damage, 0, False);
         GDVars.redrawInventoryMenuFlag := 1;
       end;
    5: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    6: begin
         FxEngine.RecalcAbility(cr, C_Stat.CONSTITUTION);
         FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
       end;
    8: case it^.effect of
         C_Stat.STRENGTH: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
         C_Stat.INTELLIGENCE: FxEngine.RecalcAbility(cr, C_Stat.INTELLIGENCE);
         C_Stat.WISDOM: FxEngine.RecalcAbility(cr, C_Stat.WISDOM);
         C_Stat.DEXTERITY: FxEngine.RecalcAbility(cr, C_Stat.DEXTERITY);
         C_Stat.CONSTITUTION: FxEngine.RecalcAbility(cr, C_Stat.CONSTITUTION);
         C_Stat.CHARISMA: FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
       end;
    9: if not equipping then
         FxEngine.RemoveEffect(cr, C_Effect.SPIRITUAL_HAMMER, nil);
    10: FxEngine.RecalcAbility(cr, C_Stat.DEXTERITY);
    11: ClassCal.RecalcThiefSkills(Types.PWork(cr));
    12: FxEngine.RecalcAbility(cr, C_Stat.INTELLIGENCE);
    13: begin
          FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
          FxEngine.RecalcAbility(cr, C_Stat.INTELLIGENCE);
        end;
    14: if Byte(it^.effect and $F) <> Byte(cr^.race) then begin
          CharHlp.PrintBottomLine('Wrong race');
          it^.equipped := 0;
          damage := it^.effect div 16;
          if damage <> 0 then begin
            GDVars.elementMask := 8;
            if GDVars.interfaceState = C_Ifc.IN_COMBAT then
              CharHlp.DisplayCombatInterface;
            FxEngine.InflictNonWeaponDamage(cr, damage, 0, False);
          end;
          GDVars.redrawInventoryMenuFlag := 1;
        end;
  end;
end;

procedure ToggleReadyItem(it: Types.PItemRec);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  cr: Types.PWork;
begin
  hasSpecial := it^.special > ViewChar.SPECIAL_ID_MASK;
  cr := GDVars.curChar;
  if it^.equipped <> 0 then begin
    if it^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed')
    else begin
      it^.equipped := 0;
      if hasSpecial then
        ViewChar.ToggleItemEffect(it, False);
    end;
  end else begin
    err := 0;
    if cr^.handsEquipped + GDVars.baseItems[it^.itemType].hands > 2 then
      err := 3;
    slot := GDVars.baseItems[it^.itemType].slot;
    case Byte(slot) of
      C_Equip.WEAPON..ViewChar.EQUIP_BOOTS: if cr^.equipped[slot] <> nil then
                                   err := 2;
      C_Equip.FIRST_RING: if cr^.equipped[C_Equip.SECOND_RING] <> nil then
                     err := 2;
    end;
    if it^.itemType = C_Item.ARROWS then
      if cr^.equipped[C_Equip.ARROW] <> nil then begin
        err := 2;
        slot := C_Equip.ARROW;
      end;
    if it^.itemType = C_Item.QUARRELS then
      if cr^.equipped[C_Equip.BOLT] <> nil then begin
        err := 2;
        slot := C_Equip.BOLT;
      end;
    if GDVars.baseItems[it^.itemType].classMask and cr^.itemLimits = 0 then
      err := 1;
    case err of
      0: begin
           it^.equipped := 1;
           if hasSpecial then
             ViewChar.ToggleItemEffect(it, True);
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, cr^.equipped[slot], 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + cr^.equipped[slot]^.name);
         end;
      3: if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) or (cr^.quickfight = 0) then
           CharHlp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

{ Give an item to another party member who can carry it.
  @param(it The item.) }
procedure ItemTradeMenu(it: Types.PItemRec);
var
  tgt: Types.PWork;
begin
  tgt := GDVars.tempCr2;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, tgt);
  if tgt <> nil then begin
    GDVars.tempCr2 := tgt;
    if ViewChar.CannotCarryItem(tgt, it) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.PrintBottomLine('Item traded');
      CharHlp.AddItemCopy(tgt, it);
      CharHlp.RemoveItem(GDVars.curChar, it);
      CharHlp.RecalcStats(tgt);
    end;
  end;
end;

{ Splits an item stack: a copy holding half the quantity, rounded down, and unreadied, follows the original, which keeps
  the rest. A quantity below 2 cannot be halved ("Can't halve that").
  @param(it The item.) }
procedure HalveItem(it: Types.PItemRec);
var
  newIt: Types.PItemRec;
  half: Byte;
  rest: Byte;
begin
  half := it^.quantity div 2;
  if half > 0 then begin
    rest := it^.quantity - half;
    GetMem(newIt, SizeOf(Types.TItemRec));
    Move(it^, newIt^, SizeOf(Types.TItemRec));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := it^.next;
    it^.quantity := rest;
    it^.next := newIt;
  end else
    CharHlp.PrintBottomLine('Can''t halve that');
end;

{ Merges into an item each other stack of the current character's that has a quantity and the same name, type, plus,
  save bonus, curse and weight and fewer than 2 charges. When the total would pass 255, the item is filled to 255 and
  the merging goes on into the stack that keeps the excess. Note: the charges, effect and special tests compare a stack
  with itself, so they always pass.
  @param(it The item to merge into.) }
procedure JoinItem(it: Types.PItemRec);
var
  cur: Types.PItemRec;
  next: Types.PItemRec;
  dst: Types.PItemRec;
  qty: Byte;
begin
  dst := it;
  qty := dst^.quantity;
  cur := GDVars.curChar^.itemsAddr;
  while cur <> nil do begin
    next := cur^.next;
    if (cur <> dst) and (cur^.quantity > 0) and (cur^.nameIds[1] = dst^.nameIds[1]) and
        (cur^.nameIds[2] = dst^.nameIds[2]) and (cur^.nameIds[3] = dst^.nameIds[3]) and
        (cur^.itemType = dst^.itemType) and (cur^.plus = dst^.plus) and (cur^.saveBonus = dst^.saveBonus) and
        (cur^.cursed = dst^.cursed) and (cur^.weight = dst^.weight) and (cur^.charges = cur^.charges) and
        (cur^.charges < 2) and (cur^.effect = cur^.effect) and (cur^.special = cur^.special) then begin
      if qty + cur^.quantity <= 255 then begin
        Inc(qty, cur^.quantity);
        CharHlp.RemoveItem(GDVars.curChar, cur);
      end else begin
        dst^.quantity := 255;
        cur^.quantity := cur^.quantity - (255 - qty);
        qty := cur^.quantity;
        dst := cur;
      end;
    end;
    cur := next;
  end;
  dst^.quantity := qty;
end;

procedure UseItem(it: Types.PItemRec; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItem := False;
  spell := 0;
  if Magic.ItemReadable(it) then begin
    GDVars.currentScrollPtr := it;
    spell := ViewChar.SpellMenu(2, 1, idx, notEmpty);
  end else if (it^.effect > 0) and (it^.special < ViewChar.SPECIAL_ON_READY) then begin
    GDVars.usingItem := True;
    spell := it^.effect and C_Spell.ID_MASK;
  end;
  if spell = 0 then
    done := False
  else begin
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItem then begin
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'uses an item', C_Msg.MESSAGE_ROW, False);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, Black, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, it, 5, 23, False, True);
      end else
        CharHlp.PrintItemString(GDVars.curChar, it, 1, 22, False, True);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
    end;
    GDVars.usingItem := True;
    if Magic.ItemReadable(it) then begin
      if (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.MAGE_LEVEL) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.MAGE_LEVEL) or
          (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.CLERIC_LEVEL) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.CLERIC_LEVEL) or
          (GDVars.curChar^.classLevels[C_Class.MAGE_LEVEL] > 0) or
          (GDVars.curChar^.classLevels[C_Class.CLERIC_LEVEL] > 0) then
        Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done)
      else if (GDVars.curChar^.classLevels[C_Class.THIEF_LEVEL] > ViewChar.THIEF_SCROLL_LEVEL) and
        (FxEngine.RollDice(1, 100) <= ViewChar.THIEF_SCROLL_CHANCE) then
        Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done)
      else
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'oops!', GDVars.curRow + 1, True);
    end else
      Magic.CastSpell(spell, Boolean(GDVars.curChar^.quickfight), False, done);
    GDVars.usingItem := False;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      if GDConsts.spellTable[spell].combatOk <> 0 then
        done := CharHlp.ClearGuard(GDVars.curChar);
    TextRend.PauseOnly;
  end;
  if done then begin
    if Magic.ItemReadable(it) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, it, spell)
    else if it^.charges > 0 then begin
      if it^.quantity > 1 then
        Dec(it^.quantity)
      else begin
        Dec(it^.charges);
        if it^.charges = 0 then
          CharHlp.RemoveItem(GDVars.curChar, it);
      end;
    end;
  end;
end;

{ Offers half an item's value for it; a stack of more than one is priced at its quantity over 20 of that. The price is
  paid in platinum and gold; when the character is overloaded, the platinum it cannot take goes to the pooled money.
  Note: the arrows-and-quarrels test joins two inequalities with or, so it always holds and the full-quantity price is
  never used.
  @param(it The item.) }
procedure SellItem(it: Types.PItemRec);
var
  price: Word;
  plat: Word;
  gold: Word;
  takable: Word;
begin
  price := 0;
  if it^.value > 0 then
    price := it^.value div 2;
  if it^.quantity > 1 then begin
    if (it^.itemType <> C_Item.ARROWS) or (it^.itemType <> C_Item.QUARRELS) then
      price := price * it^.quantity div ViewChar.AMMO_BUNDLE
    else
      price := price * it^.quantity;
  end;
  CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, Yellow, Black,
                                True,
                                'I''ll give you ' + CharHlp.Uint16Str(price) + ' gold pieces for your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharHlp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(GDVars.curChar, it);
    plat := price div 5;
    gold := price mod 5;
    if Money.CheckOverload(GDVars.curChar, gold + plat, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      if takable > plat then
        Inc(GDVars.curChar^.coinsA[4], plat)
      else begin
        Inc(GDVars.curChar^.coinsA[4], takable);
        Inc(GDVars.treasureMoney[4], plat - takable);
      end;
      Inc(GDVars.curChar^.coinsA[3], gold);
    end else begin
      Inc(GDVars.curChar^.coinsA[4], plat);
      Inc(GDVars.curChar^.coinsA[3], gold);
    end;
  end;
  Border.ClearBox(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ Identifies an item for 200 gold pieces, paid from the character's coins when they are worth enough, and otherwise from
  the pooled money. Note: only the low word of the gold left is passed on.
  @param(it The item.)
  @param(newInfo Set to True when the identification told something new; never cleared.) }
procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean);
var
  charGold: LongInt;
  poolGold: LongInt;
  paid: Boolean;
begin
  paid := False;
  CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, Yellow, Black,
                                True, 'For 200 gold pieces I''ll identify your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if charGold >= ViewChar.IDENTIFY_PRICE then begin
      paid := True;
      Dec(charGold, ViewChar.IDENTIFY_PRICE);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      poolGold := Money.CoinValueInGold(GDVars.treasureMoney);
      if poolGold >= ViewChar.IDENTIFY_PRICE then begin
        paid := True;
        Dec(poolGold, ViewChar.IDENTIFY_PRICE);
        Money.SetTreasureCoinsInGold(poolGold);
      end else
        CharHlp.PrintBottomLine('Not Enough Money');
    end;
  end;
  if paid then begin
    if it^.unidMask = 0 then
      TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, Yellow,
                                    Black, True, 'I can''t tell anything new about your ' + it^.name)
    else begin
      it^.unidMask := 0;
      CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
      TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, Yellow,
                                    Black, True, 'It looks like some sort of ' + it^.name);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.PauseOnly;
  Border.ClearBox(C_Msg.TEXT_LEFT, ViewChar.LINES_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ Trades coins from the current character to another. The player picks the receiver, then a coin type and an amount up
  to the holding, repeating while coins are left. Note: escaping the coin menu leaves the outer loop's exit flag unset,
  so on the first pass whether the menu ends depends on an uninitialized local. }
procedure TradeTreasureMenu;
var
  tgt: Types.PWork;
  m: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  count: Word;
  idx: Integer;
  numStr: String[15];
  { Unused in this version; see the other implementations of this routine. }
  line: String[4];
  prompt: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := GDVars.tempCr2;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar('Trade to?', True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.tempCr2 := tgt;
        p := nil;
        prev := nil;
        list := nil;
        count := 0;
        for m := 0 to 6 do
          if GDVars.curChar^.coinsA[m] <> 0 then begin
            Inc(count);
            if p = nil then begin
              GetMem(p, SizeOf(Types.TItemNode));
              p^.next := nil;
            end else begin
              prev := p;
              GetMem(p, SizeOf(Types.TItemNode));
              p^.next := prev;
            end;
            Str(GDVars.curChar^.coinsA[m], numStr);
            p^.name := GDConsts.moneyNames[m] + ViewChar.RightAlignField(numStr, 18 - Length(GDConsts.moneyNames[m]));
            p^.inUse := 0;
          end;
        list := p;
        idx := 0;
        redraw := True;
        ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 37, 15,
                                    p, True, redraw, idx, prev);
        if prev = nil then
          exitInner := True
        else begin
          prompt := '';
          mType := Money.ParseMoneyType(prev^.name, prompt);
          prompt := 'How much ' + prompt + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], prompt, LightGreen);
          Money.TradeMoney(GDVars.curChar, Types.PWork(tgt), amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := 0 to 6 do
            if GDVars.curChar^.coinsA[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(list);
      until exitInner;
    end;
  until exitOuter;
end;

{ Lets the current character drop money, or deposit it in the vault, until it has none left or the player leaves. }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  count: Word;
  idx: Integer;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  exitFlag: Boolean;
  redraw: Boolean;
  numStr: String[15];
  { Unused in this version; see the other implementations of this routine. }
  line: String[4];
  prompt: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    p := nil;
    prev := nil;
    list := nil;
    count := 0;
    for m := 0 to 6 do
      if GDVars.curChar^.coinsA[m] <> 0 then begin
        Inc(count);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := nil;
        end else begin
          prev := p;
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := prev;
        end;
        Str(GDVars.curChar^.coinsA[m], numStr);
        p^.name := GDConsts.moneyNames[m] + ViewChar.RightAlignField(numStr, 18 - Length(GDConsts.moneyNames[m]));
        p^.inUse := 0;
      end;
    list := p;
    idx := 0;
    redraw := True;
    ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 37, 15, p,
                                True, redraw, idx, prev);
    if prev = nil then
      exitFlag := True
    else begin
      prompt := '';
      mType := Money.ParseMoneyType(prev^.name, prompt);
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        prompt := 'How much ' + prompt + 'will you deposit? '
      else
        prompt := 'How much ' + prompt + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], prompt, LightGreen);
      Money.DropMoney(GDVars.curChar, amount, mType);
      exitFlag := True;
      for m := 0 to 6 do
        if GDVars.curChar^.coinsA[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(list);
  until exitFlag;
end;

function CannotCarryItem(cr: Types.PWork; it: Types.PItemRec): Boolean;
var
  f: Boolean;
  w: Word;
begin
  CharHlp.RecalcStats(cr);
  f := False;
  if cr^.numberOfItems > C_Item.MAX_CARRIED_ITEMS - 1 then
    f := True;
  w := it^.weight;
  if it^.quantity > 0 then
    w := w * it^.quantity;
  if cr^.encumbrance + w > CharHlp.WeightAllowance(cr) + C_Item.CARRY_ALLOWANCE then
    f := True;
  CannotCarryItem := f;
end;

procedure SelectPrevNextChar(c: Char);
var
  p: Types.PWork;
begin
  if GDVars.isMouseOn and GDVars.isMouseClick then
    Exit;
  if GDVars.curChar = nil then
    GDVars.curChar := GDVars.creatureList;
  if GDVars.curChar = nil then
    Exit;
  case c of
    C_Keys.UP: if GDVars.curChar = GDVars.creatureList then begin
           while GDVars.curChar^.next <> nil do
             GDVars.curChar := GDVars.curChar^.next;
         end else begin
           p := GDVars.creatureList;
           while (p <> nil) and (p^.next <> GDVars.curChar) do
             p := p^.next;
           GDVars.curChar := p;
         end;
    C_Keys.DOWN: if GDVars.curChar^.next <> nil then
           GDVars.curChar := GDVars.curChar^.next
         else
           GDVars.curChar := GDVars.creatureList;
  end;
end;

function CreatureCoinValueInGold(cr: Types.PWork): LongInt;
var
  sum: LongInt;
  m: ShortInt;
begin
  sum := 0;
  for m := 0 to 4 do
    Inc(sum, GDConsts.coinValues[m] * cr^.coinsA[m]);
  CreatureCoinValueInGold := (sum + 100) div GDConsts.coinValues[3];
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Grimoire';
    2: s := 'on Scroll';
    3: s := 'on Scrolls';
    4: s := 'to Choose';
    5: s := 'to Memorize';
    6: s := 'to Scribe';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then begin
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
        if selType = 2 then
          Border.DrawMemorizeFrame
        else
          Border.DrawTitleInset;
      end else
        Border.DrawWindowFrame;
    end;
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
    TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, Black, 'Spells ' + s);
    SpellMenu := Magic.SpellSelection(selType, idx);
  end else
    SpellMenu := 0;
end;

{ Tells whether a character can lay on hands: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, and not within a day of its last healing.
  @param(cr The character.)
  @returns(True when it can heal.) }
function CanHeal(cr: Types.PWork): Boolean;
var
  eff: Types.PEffectRec;
begin
  CanHeal := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.classLevels2[C_Class.PALADIN_LEVEL] > 0) and
               Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))))) and
                 (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.statusS = C_Status.OKAY) and
                 not CharHlp.HasEffect(cr, ViewChar.EFF_RECENT_HEAL, eff);
end;

{ Tells whether a character can cure disease: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, with a cure left.
  @param(cr The character.)
  @returns(True when it can cure.) }
function CanCure(cr: Types.PWork): Boolean;
begin
  CanCure := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.classLevels2[C_Class.PALADIN_LEVEL] > 0) and
               Boolean(ClassCal.EarlierClassActive(Types.PWork(cr))))) and
                 (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.statusS = C_Status.OKAY) and
                 (cr^.diseaseCount > 0);
end;

{ Lays on hands: the party member the player picks regains 2 hit points per paladin level of the healer (earlier paladin
  levels count while active), who cannot heal again for a day. Picking no one just redraws the sheet.
  @param(cr The paladin.) }
procedure PaladinLayOnHands(cr: Types.PWork);
var
  tgt: Types.PWork;
begin
  CharHlp.DisplayNoncombatInterface;
  tgt := GDVars.creatureList;
  CharHlp.SelectChar('Heal whom? ', True, tgt);
  if tgt = nil then
    ViewChar.DisplayChar
  else begin
    if FxEngine.RestoreHitPoints(tgt,
         (cr^.classLevels2[C_Class.PALADIN_LEVEL] *
          ClassCal.EarlierClassActive(Types.PWork(cr)) +
          cr^.classLevels[C_Class.PALADIN_LEVEL]) * 2, False) then
      CharHlp.PrintBottomLine(tgt^.name + ' feels better')
    else
      CharHlp.PrintBottomLine(tgt^.name + ' is unaffected');
    FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_HEAL, ViewChar.HEAL_COOLDOWN, 0, False);
    ViewChar.DisplayChar;
  end;
end;

{ Cures the diseases of the party member the player picks (asking first when there are none), using one of the paladin's
  cures and starting its seven-day cure effect if it is not already running.
  @param(cr The paladin.) }
procedure PaladinCureDisease(cr: Types.PWork);
var
  tgt: Types.PWork;
  found: Boolean;
  ch: Char;
  eff: Types.PEffectRec;
begin
  CharHlp.DisplayNoncombatInterface;
  tgt := GDVars.creatureList;
  CharHlp.SelectChar('Cure whom? ', True, tgt);
  if tgt = nil then
    ViewChar.DisplayChar
  else begin
    found := False;
    for GDVars.sharedLoopIndex := 1 to 6 do
      if CharHlp.HasEffect(tgt, GDConsts.diseaseEffects[GDVars.sharedLoopIndex], eff) then
        found := True;
    ch := 'Y';
    if not found then begin
      CharHlp.PrintCreatureMessage(tgt, 'is not diseased', 0, False);
      ch := MenuCore.YesNoMenuClear('cure anyway: ', LightMagenta, LightGreen, White);
      CharHlp.ClearMessageWindow;
    end;
    if ch = 'Y' then
    begin
      GDVars.effectLockFlag := 1;
      for GDVars.sharedLoopIndex := 1 to 6 do
        FxEngine.RemoveEffect(tgt, GDConsts.diseaseEffects[GDVars.sharedLoopIndex], nil);
      GDVars.effectLockFlag := 0;
      if cr^.diseaseCount > 0 then
        Dec(cr^.diseaseCount);
      if not CharHlp.HasEffect(cr, ViewChar.EFF_RECENT_CURE, eff) then
        FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_CURE, ViewChar.CURE_COOLDOWN, 0, True);
      CharHlp.PrintBottomLine(tgt^.name + ' is cured');
    end;
    ViewChar.DisplayChar;
  end;
end;

begin
end.
