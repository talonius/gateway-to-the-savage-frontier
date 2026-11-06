{ Coins and the treasure pool. It weighs, gives, trades, drops, pools and shares a character's money, runs the
  take-money and gem-appraisal menus, and makes the random items treasure holds.

  The exchange values, the random-item templates and the coin and money-name tables are in GDConsts; the current
  character, the creature list, the interface state and the treasure pool and its flag are in GDVars. }
{$O+,F+}
{$S+,A+}
unit Money;

interface

uses Types, Crt, GDConsts, GDVars, C_Keys, C_Ifc, C_Item, C_Npc, C_Screen, CharHlp, TextRend, GameIo,
  FxEngine, Border, MenuCore;

{ Whether carrying w more coins would take p past what it can carry. CarryingCapacity is called again on the overload
  path, not kept.
  @param(p The creature.)
  @param(w The coins to add.)
  @param(takable The spare capacity when it would, else 0.)
  @returns(True when p would be overloaded.) }
function CheckOverload(p: Types.PWork; w: Word; var takable: Word): Boolean;

{ Moves the money of each player character, and of each NPC with the value $B3, into the pool, taking its weight off,
  and marks the pool as holding money. }
procedure PoolMoney;

{ Divides the pool. Each money type's share is the pool divided by CountPoolers, the remainder held back. The first pass
  gives each member with an NPC value below $80, highest money type first, its share and one coin of the remainder while
  they fit, or as much of the share as it can carry, the rest going back to the remainder. The second pass hands what is
  left, type by type, to each member in list order as far as it can carry, and the rest stays in the pool, which is
  marked as holding money when anything stays. Note: the divisor counts animated members ($B3), whom the first pass
  skips, and not NPC values 1 to $7F, whom it pays. }
procedure ShareMoney;

{ Runs the take-money menu over the pooled coin types, copper first: the amount asked for, at most the low word of the
  pool's amount, is taken by the current character. It repeats while money is left. Note: the menu entries are freed
  only after a take, not when the menu is left. }
procedure TakeMoneyMenu;

{ Gives platinum to the current character; what does not fit goes to the pooled money, with a message on the bottom row.
  @param(pp The platinum pieces.) }
procedure GivePlatinum(pp: Word);

{ Reads a money type from the start of a menu entry. Leading spaces are skipped, unchecked; the first letter gives the
  type, and for G the second letter, upper-cased, tells gems from gold. An unknown letter leaves the result and the name
  unset.
  @param(s The menu entry.)
  @param(typeName Receives the type's name, as the take prompt shows it.)
  @returns(The money type.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Reads a number of up to max on the bottom line after query, in color color. It takes digits, Backspace, Return and
  Escape; an entry above max becomes max.
  @param(max The largest number accepted.)
  @param(query The prompt.)
  @param(color The prompt's color.)
  @returns(The number, or 0 when Escape ends the entry.) }
function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

{ Moves qty of money type mType from giver to rcv, unless rcv cannot carry it; the weight goes with the coins.
  @param(giver The creature giving.)
  @param(rcv The creature receiving.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PWork; qty: Word; mType: ShortInt);

{ Takes money from a character; in the loot screen, in shops and temples and in the vault it goes into the pool,
  elsewhere it is lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PWork; qty: Word; mType: ShortInt);

{ Tells whether money or items are left in the pool.
  @param(hasMoney Receives True when money is left.)
  @param(items Receives True when items are left.) }
procedure DetermineTreasure(var hasMoney, items: Boolean);

{ Sets the current character's coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The
  other coin types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetCreatureCoinsInGold(gp: Word);

{ Sets the pooled coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The other coin
  types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetTreasureCoinsInGold(gp: Word);

{ Works out the worth of the five coin types in gold, rounding half up; gems and jewelry are left out.
  @param(m The money.)
  @returns(The worth in gold pieces.) }
function CoinValueInGold(m: Types.TMoney): LongInt;

{ Makes a random item of item type kind in it. Weapons and armor get a bonus, a name, a weight and a value; scrolls get
  one to three spells of the priest or mage schools; the other kinds that name a template copy it from
  randomItemTemplates, through word templateWordIndex of the flat views.
  @param(kind The item type.)
  @param(it Receives the item.) }
procedure GenerateRandomItem(kind: Byte; var it: Types.TItemRec);

{ Appraises the current character's gems and jewelry one at a time, each sold or kept. Each is valued in gold on a d100;
  a sold one pays that value in platinum (a platinum piece is five gold, the remainder lost), a kept one becomes an item
  of type 70 worth it.
  @param(ok False when there is nothing to appraise.) }
procedure AppraiseMenu(var ok: Boolean);

{ InputNumberMax with a background color it ignores.
  @param(max The largest number accepted.)
  @param(query The prompt.)
  @param(color The prompt's color.)
  @param(backColor Unused.)
  @returns(The number, or 0 when Escape ends the entry.) }
function InputNumber(max: Word; query: Types.TStr40; color, backColor: Byte): Word;

{ Changes the current character's coins of types 0..mType up into the next type, as many as exchangeValue allows.
  @param(mType The highest type changed up.) }
procedure ConvertMoney(mType: Byte);

{ Whether a party member, or a character animated from one, still carries money.
  @returns(True when some such creature carries money.) }
function PooledMoney: Boolean;

implementation

type
  { a LongInt's low and high words }
  TLoW = record
    lo: Word;
    hi: Word;
  end;
  { a Word's low and high bytes }
  TWB = record
    lo: Byte;
    hi: Byte;
  end;

var
  { The pool's amounts as low words. }
  treasureMoneyLo: array[0..6] of TLoW absolute GDVars.treasureMoney;
  { The random-item templates read as one word array: template n starts at word 8n-7, and each use stays within one
    template (the largest index is 49 + 7, the last). }
  randItemW: array[1..56] of Word absolute GDConsts.randomItemTemplates;
  randItemB: array[1..56] of TWB absolute GDConsts.randomItemTemplates;

procedure RemoveWeight(p: Types.PWork; w: Word); forward;

procedure AddWeight(p: Types.PWork; w: Word); forward;

procedure ConvertMoney(mType: Byte);
var i: ShortInt;
begin
  for i := 0 to mType do
    while GDVars.curChar^.coinsA[i] >= GDConsts.exchangeValue[i] do begin
      Dec(GDVars.curChar^.coinsA[i], GDConsts.exchangeValue[i]);
      Money.RemoveWeight(GDVars.curChar, GDConsts.exchangeValue[i]);
      Inc(GDVars.curChar^.coinsA[Succ(i)]);
      Money.AddWeight(GDVars.curChar, 1);
    end;
end;

{ The coins p can carry.
  @param(p The creature.)
  @returns(The coins p can carry.) }
function CarryingCapacity(p: Types.PWork): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(Types.PWork(p))
     + C_Item.CARRY_ALLOWANCE;
end;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight removed.) }
procedure RemoveWeight(p: Types.PWork; w: Word);
begin
  p^.encumbrance := p^.encumbrance - w;
end;

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight added.) }
procedure AddWeight(p: Types.PWork; w: Word);
begin
  p^.encumbrance := p^.encumbrance + w;
end;

function CheckOverload(p: Types.PWork; w: Word; var takable: Word): Boolean;
begin
  if p^.encumbrance + w > Money.CarryingCapacity(p) then begin
    CheckOverload := True;
    if Money.CarryingCapacity(p) > p^.encumbrance then
      takable := Money.CarryingCapacity(p) - p^.encumbrance
    else
      takable := 0;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

function CoinValueInGold(m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := 0 to 4 do
    Inc(total, GDConsts.coinValues[i] * m[i]);
  CoinValueInGold := (total + 100) div GDConsts.coinValues[3];
end;

procedure SetCreatureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.curChar^.coinsA[i] := 0;
  { platinum }
  GDVars.curChar^.coinsA[4] := gp div 5;
  { gold }
  GDVars.curChar^.coinsA[3] := gp mod 5;
end;

procedure SetTreasureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.treasureMoney[i] := 0;
  GDVars.treasureMoney[4] := gp div 5;
  GDVars.treasureMoney[3] := gp mod 5;
end;

procedure GivePlatinum(pp: Word);
var
  takable: Word;
begin
  if Money.CheckOverload(GDVars.curChar, pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coinsA[4], takable);
    Money.AddWeight(GDVars.curChar, takable);
    GDVars.treasureMoney[4] := pp + GDVars.treasureMoney[4] - takable;
  end else begin
    Inc(GDVars.curChar^.coinsA[4], pp);
    Money.AddWeight(GDVars.curChar, pp);
  end;
end;

function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  queryLength: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  extCh: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, color, Black, query);
  qLen := Length(query);
  Str(max, maxStr);
  s := '';
  GameIo.WaitMouseRelease;
  TextRend.DisplayString(qLen, C_Screen.STATUS_ROW, White, Black, '@');
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      #0: extCh := GameIo.ReadGameKey;
      '0'..'9': begin
          if (ch <> '0') and (s = '0') then
            s := '';
          if (ch = '0') and (s = '0') then begin
          end else begin
            s := Concat(s, ch);
            Val(s, v, code);
            if max < v then
              s := maxStr;
            TextRend.DisplayString(qLen, C_Screen.STATUS_ROW, White, Black, Concat(s, '@ '));
          end;
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          TextRend.DisplayString(qLen, C_Screen.STATUS_ROW, White, Black, Concat(s, '@ '));
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

function InputNumber(max: Word; query: Types.TStr40; color, backColor: Byte): Word;
begin
  InputNumber := Money.InputNumberMax(max, query, color);
end;

procedure TradeMoney(var giver, rcv: Types.PWork; qty: Word; mType: ShortInt);
begin
  if rcv^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    giver^.coinsA[mType] := giver^.coinsA[mType] - qty;
    Money.RemoveWeight(giver, qty);
    rcv^.coinsA[mType] := rcv^.coinsA[mType] + qty;
    Money.AddWeight(rcv, qty);
    CharHlp.PrintBottomLine('Money given');
  end else
    CharHlp.PrintBottomLine('Overloaded');
end;

procedure PoolMoney;
var
  p: Types.PWork;
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.creatureList;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PLAYER) then begin
      for i := 0 to 6 do begin
        mt := i;
        GDVars.treasureMoney[mt] := p^.coinsA[mt] + GDVars.treasureMoney[mt];
        Money.RemoveWeight(p, p^.coinsA[mt]);
      end;
      FillChar(p^.coinsA, SizeOf(p^.coinsA), 0);
    end;
    p := p^.nextCharAddr;
  end;
end;

function PooledMoney: Boolean;
var
  p: Types.PWork;
  i: ShortInt;
  mt: ShortInt;
begin
  PooledMoney := True;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PLAYER) then begin
      for i := 0 to 6 do begin
        mt := i;
        if p^.coinsA[mt] <> 0 then Exit;
      end;
    end;
    p := p^.nextCharAddr;
  end;
  PooledMoney := False;
end;

{ Counts the party members and animated creatures (NPC value 0 or $B3).
  @returns(The count.) }
function CountPoolers: Byte;
var
  p: Types.PWork;
  n: Byte;
begin
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PLAYER) then
      Inc(n);
    p := p^.nextCharAddr;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PWork;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: Word;
  share: array[0..6] of Word;
  rem: array[0..6] of Word;
  i: ShortInt;
begin
  done := False;
  cnt := Money.CountPoolers;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.npc < C_Npc.NON_PLAYER then
      for i := 6 downto 0 do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coinsA[i] := share[i] + p^.coinsA[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, 1, takable) then begin
              p^.coinsA[i] := p^.coinsA[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coinsA[i] := p^.coinsA[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.nextCharAddr;
  end;
  for i := 6 downto 0 do
    if rem[i] > 0 then begin
      p := GDVars.creatureList;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coinsA[i] := p^.coinsA[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coinsA[i] := p^.coinsA[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.nextCharAddr;
      end;
    end;
  GDVars.treasureMoneyFlag := False;
  for i := 0 to 6 do begin
    GDVars.treasureMoney[i] := rem[i];
    if GDVars.treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

procedure DropMoney(p: Types.PWork; qty: Word; mType: ShortInt);
begin
  p^.coinsA[mType] := p^.coinsA[mType] - qty;
  Money.RemoveWeight(p, qty);
  if (GDVars.interfaceState = C_Ifc.LOOT) or (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE)
     or (GDVars.interfaceState = C_Ifc.IN_VAULT) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Takes qty of mType from the pool for p, at most the pool's low word; refuses the whole amount when p cannot carry it.
  @param(p The creature.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PWork; qty: Word; mType: ShortInt);
var
  takable: Word;
begin
  if Money.CheckOverload(p, qty, takable) then
    CharHlp.PrintBottomLine('Overloaded')
  else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := treasureMoneyLo[mType].lo;
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    p^.coinsA[mType] := p^.coinsA[mType] + qty;
    Money.AddWeight(p, qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do Inc(i);
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := 5; typeName := 'Gems '
         end else begin typeName := 'Gold '; ParseMoneyType := 3 end;
    'P': begin typeName := 'Platinum '; ParseMoneyType := 4 end;
    'E': begin typeName := 'electrum '; ParseMoneyType := 2 end;
    'S': begin typeName := 'silver '; ParseMoneyType := 1 end;
    'C': begin typeName := 'Copper '; ParseMoneyType := 0 end;
    'J': begin typeName := 'Jewelry '; ParseMoneyType := 6 end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame;
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := 6 downto 0 do
      if GDVars.treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin ', 'Select', LightMagenta, LightGreen, White, 2, 2, 15, 8, p, True,
                                redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      numStr := 'How much ' + numStr + 'will you take? ';
      n := Money.InputNumberMax(treasureMoneyLo[mType].lo, numStr, LightGreen);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := 0 to 6 do
        if GDVars.treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var hasMoney, items: Boolean);
var
  i: ShortInt;
begin
  hasMoney := False;
  items := False;
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] <> 0 then
      hasMoney := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ A magic weapon or armor's bonus: +1 on 1..14 of a d20, +2 on 15..20.
  @returns(The bonus.) }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..20: RandomBonus := 2;
  end;
end;

procedure GenerateRandomItem(kind: Byte; var it: Types.TItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  { 0 for no template }
  templateWordIndex: Byte;
  spell: Byte;
begin
  FillChar(it, SizeOf(it), 0);
  templateWordIndex := 0;
  with it do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..59, 73, 77, 93: begin
          plus := Money.RandomBonus;
          case itemType of
            21: begin
                   r := FxEngine.RollDice(1, 5);
                   if r = 5 then
                     templateWordIndex := 49;
                   nameIds[3] := 21;
                   nameIds[2] := plus + 161;
                 end;
            28: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + 161;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            73: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + 161;
                 end;
            77: begin
                   nameIds[3] := 79;
                   nameIds[2] := 167;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := 221;
                     6: nameIds[1] := 222;
                   end;
                 end;
            93: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + 161;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 161;
                 end;
          end;
          saveBonus := 0;
          quantity := 0;
          case itemType of
            1, 13, 14, 35:
              weight := 75;
            2, 20, 29, 31, 32, 33, 39, 42, 44, 46, 59:
              weight := 50;
            3, 24, 40:
              weight := 125;
            4, 15, 23, 34, 43, 45, 51:
              weight := 100;
            5, 12, 17, 19, 50:
              weight := 150;
            6: weight := 15;
            7: weight := 30;
            8, 77:
              weight := 10;
            9: begin
                 weight := 25;
                 quantity := 5;
               end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            21: weight := 20;
            22, 30:
              weight := 40;
            37: weight := 35;
            38, 53:
              weight := 250;
            52: weight := 200;
            54, 56:
              weight := 400;
            55: weight := 300;
            57: weight := 350;
            58: weight := 450;
            47, 93:
              weight := 1;
            else begin
                   weight := 40;
                   quantity := 10;
                 end;
          end;
          case itemType of
            59: value := plus * 2500;
            73, 28: value := plus * 150;
            53, 54: value := plus * 3000;
            55, 56: value := plus * 3500;
            57: value := plus * 4000;
            58: value := plus * 5000;
            77: value := plus * 3000;
            else value := plus * 2000;
          end;
        end;
      61, 62: begin
          n := FxEngine.RollDice(1, 3);
          if itemType = 61 then
            nameIds[3] := 209
          else
            nameIds[3] := 208;
          nameIds[2] := n + 209;
          nameIds[1] := 0;
          plus := 1;
          weight := 25;
          quantity := 0;
          value := 0;
          for j := 1 to n do begin
            r := FxEngine.RollDice(1, 5);
            if itemType = 61 then
              { clerical schools }
              case r of
                1: spell := FxEngine.RollDice(1, 13) + 8;
                2: spell := FxEngine.RollDice(1, 7) + 28;
                3: spell := FxEngine.RollDice(1, 11) + 44;
                4: spell := FxEngine.RollDice(1, 9) + 80;
                5: spell := FxEngine.RollDice(1, 4) + 90;
              end else
              { mage schools }
              case r of
                1: spell := FxEngine.RollDice(1, 8);
                2: spell := FxEngine.RollDice(1, 7) + 21;
                3: spell := FxEngine.RollDice(1, 8) + 36;
                4: spell := FxEngine.RollDice(1, 5) + 65;
                5: spell := FxEngine.RollDice(1, 6) + 70;
              end;
            spells[j] := spell;
            value := r * 300 + value;
          end;
        end;
      63, 67: templateWordIndex := 41;
      78, 79: templateWordIndex := 33;
      84, 92: templateWordIndex := 9;
      71: begin
             r := FxEngine.RollDice(1, 8);
             case r of
               1..5: templateWordIndex := 17;
               6..8: templateWordIndex := 1;
             end;
           end;
    end;
    if templateWordIndex <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := randItemB[templateWordIndex + j].lo;
      plus := 1;
      saveBonus := 1;
      weight := randItemW[templateWordIndex + 3];
      quantity := 0;
      value := randItemW[templateWordIndex + 4];
      for j := 1 to 3 do
        spells[j] := randItemB[templateWordIndex + 4 + j].lo;
    end;
  end;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  value: Word;
  takable: Word;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coinsA[5] = 0) and (GDVars.curChar^.coinsA[6] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coinsA[5] = 0) and (GDVars.curChar^.coinsA[6] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coinsA[5], gemStr);
        Str(GDVars.curChar^.coinsA[6], jwlStr);
        case GDVars.curChar^.coinsA[5] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
          else gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coinsA[6] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
          else jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, Black, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, Black, gemStr);
        TextRend.DisplayString(1, 10, White, Black, jwlStr);
        menu := '';
        if GDVars.curChar^.coinsA[5] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coinsA[6] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, True, False, ext);
        case ch of
          'G': if GDVars.curChar^.coinsA[5] <> 0 then begin
              Dec(GDVars.curChar^.coinsA[5]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 10;
                26..50: value := 50;
                51..70: value := 100;
                71..90: value := 500;
                91..99: value := 1000;
                100: value := 5000;
              end;
              Str(value, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' gp.';
              TextRend.DisplayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= C_Item.MAX_CARRIED_ITEMS) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 101;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  GDVars.curChar^.itemsAddr := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'J': if GDVars.curChar^.coinsA[6] <> 0 then begin
              Dec(GDVars.curChar^.coinsA[6]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(900)) + 100;
                11..20: value := Trunc(Random(1000)) + 200;
                21..40: value := Trunc(Random(1500)) + 300;
                41..50: value := Trunc(Random(2500)) + 500;
                51..70: value := Trunc(Random(5000)) + 1000;
                71..90: value := Trunc(Random(6000)) + 2000;
                91..100: value := Trunc(Random(10000)) + 2000;
              end;
              Str(value, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' gp.';
              TextRend.DisplayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= C_Item.MAX_CARRIED_ITEMS) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 214;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  GDVars.curChar^.itemsAddr := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
