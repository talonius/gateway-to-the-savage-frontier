{ The shop. Its stock is the treasure item list; ShopMainMenu clears the treasure pool's money on entry, offers Buy,
  Items, View, Take, Pool, Share and Appraise, and warns before leaving money in the pool. A purchase is paid from the
  current character's coins or, when they fall short, from the pool. shopMenuRedraw is in GDVars. }
{$O+,F+}
{$A+}
{$S+}
unit Shop;

interface

uses Types, C_Ifc, C_Msg, EclMenu, ViewChar, CharHlp, Border, MenuCore, Money, TextRend, GameIo, Crt, GDConsts, GDVars,
  C_Keys;

{ The shop: clear the pool's money, then offer Buy, Items, View, Take, Pool, Share and Appraise until Exit; leaving
  money in the pool brings a warning and the choice to go back for it. }
procedure ShopMainMenu;

{ Appends a copy of it to the current character's items, unless the character cannot carry it.
  @param(it The item to copy.)
  @param(failed True when the character cannot.) }
procedure GiveItemCopyToCreature(it: Types.PItemRec; var failed: Boolean);

implementation

const
  { GBVM zone 1: the price scale, in sixteenths of an item's value }
  PRICE_SCALE = $7F6D;

{ Lists the shop's items with their prices in a vertical Buy menu, then rebuilds the item names. The price is the value
  scaled by the zone's price level, and a level outside the seven scaling values keeps the value; an item whose value is
  0 is given the value 1.
  @param(c Receives the key pressed.)
  @param(itemToBuy Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure ShopBuyItemSelection(var c: Char; var itemToBuy, cursor: Types.PItemRec; var idx: Integer);
var
  head: Types.PItemRec;
  p: Types.PItemRec;
  { the price as text }
  tmp: String[16];
  { the stock line: the name, then the price right-justified }
  s: String[30];
  lenv: Byte;
  i: Byte;
begin
  p := GDVars.treasureItems;
  while p <> nil do begin
    s := '                              ';
    if p^.value = 0 then p^.value := 1;
    case GDVars.gbvmZone1Ptr^[Shop.PRICE_SCALE] of
      1: Str(LongInt(p^.value div 16), tmp);
      2: Str(LongInt(p^.value div 8), tmp);
      4: Str(LongInt(p^.value div 4), tmp);
      8: Str(LongInt(p^.value div 2), tmp);
      32: Str(LongInt(p^.value * 2), tmp);
      64: Str(LongInt(p^.value * 4), tmp);
      128: Str(LongInt(p^.value * 8), tmp);
    else
      Str(LongInt(p^.value), tmp);
    end;
    lenv := Length(tmp);
    for i := 1 to lenv do
      s[SizeOf(s) - 1 - lenv + i] := tmp[i];
    lenv := Length(p^.name);
    for i := 1 to lenv do
      s[i] := p^.name[i];
    p^.name := s;
    p^.name[0] := Chr(30);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  GDVars.horizChoice := 0;
  c := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 1, 38, 22, Types.PItemRec(head),
                             True, GDVars.shopMenuRedraw, idx, Types.PItemRec(cursor));
  itemToBuy := cursor;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
end;

procedure GiveItemCopyToCreature(it: Types.PItemRec; var failed: Boolean);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, it)
      then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    p := GDVars.curChar^.itemsAddr;
    if p = nil then begin
      GetMem(p, SizeOf(Types.TItemRec));
      p^ := it^;
      p^.next := nil;
      GDVars.curChar^.itemsAddr := p;
    end else begin
      while p^.next <> nil do
        p := p^.next;
      GetMem(q, SizeOf(Types.TItemRec));
      q^ := it^;
      q^.next := nil;
      p^.next := q;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ The buy loop: the price is paid from the character's coins, counted in gold as a Word, or else from the pool, counted
  as a LongInt and written back through a Word. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItemRec;
  c: Char;
  done: Boolean;
  price: Word;
  charGold: Word;
  pooled: LongInt;
  failed: Boolean;
  { the menu's position, kept across purchases }
  cursor: Types.PItemRec;
  idx: Integer;
begin
  itemToBuy := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  Border.DrawWindowFrame;
  GDVars.shopMenuRedraw := True;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    if (c <> 'B') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      case GDVars.gbvmZone1Ptr^[Shop.PRICE_SCALE] of
        1: price := itemToBuy^.value div 16;
        2: price := itemToBuy^.value div 8;
        4: price := itemToBuy^.value div 4;
        8: price := itemToBuy^.value div 2;
        32: price := itemToBuy^.value * 2;
        64: price := itemToBuy^.value * 4;
        128: price := itemToBuy^.value * 8;
      else
        price := itemToBuy^.value;
      end;
      charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
      if price <= charGold then begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then begin
          charGold := charGold - price;
          Money.SetCreatureCoinsInGold(charGold);
          CharHlp.PrintBottomLine('Item Purchased');
        end;
      end else begin
        pooled := Money.CoinValueInGold(GDVars.treasureMoney);
        if price <= pooled then begin
          Shop.GiveItemCopyToCreature(itemToBuy, failed);
          if not failed then begin
            pooled := pooled - price;
            Money.SetTreasureCoinsInGold(pooled);
            CharHlp.PrintBottomLine('Item Purchased');
          end;
        end else
          CharHlp.PrintBottomLine('Not enough Money.');
      end;
    end;
  until done;
end;

procedure ShopMainMenu;
var
  menu: String[40];
  { always empty }
  query: String[1];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
  p: Types.PItemRec;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopSessionFlag := False;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopSessionFlag := True;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  query[0] := #0;
  GDVars.treasureMoneyFlag := False;
  done := False;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'Buy ';
    if GDVars.curChar^.numberOfItems > 0 then
      menu := menu + 'Items ';
    menu := menu + 'View ';
    if hasMoney then
      menu := menu + 'Take ';
    if Money.PooledMoney then
      menu := menu + 'Pool ';
    if hasMoney then
      menu := menu + 'Share ';
    menu := menu + 'App Exit';
    GDVars.canClickParty := 1;
    GDConsts.canClickToView := True;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, False, ext);
    GDConsts.canClickToView := False;
    GDVars.canClickParty := 0;
    if GDVars.extFlag then
      ViewChar.SelectPrevNextChar(c)
    else case c of
      'B': Shop.ShopBuyMenu;
      'I': ViewChar.UseItemMenu(ext);
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      'E', C_Keys.NONE: begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             LightGreen, Black, True,
'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ');
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             White, Black, False,
                                             'Do you want to go back and get your Money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                              False);
               { MenuHorizontalCharacterSelect counts from 0: No, so leave }
               if ynIdx = 1 then
                 done := True
               else
                 TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
             end else
               done := True;
           end;
    end;
    case c of
      'B', 'I', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if apprOk then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
  GameIo.KbdNoop;
end;

begin
end.
