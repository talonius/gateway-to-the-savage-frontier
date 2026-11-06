{ The temple. TempleMainMenu offers healing, the character view and the treasure pool's Take, Pool, Share and Appraise;
  HealMenu lists GDConsts.templeSpells and charges the current character, or else the pool, for each cure. It owns no
  storage. }
{$O+,F+}
{$A+}
{$S+}
unit Temple;

interface

{ The temple: Shop's main menu without Buy and Items, offering Heal, View, Take, Pool, Share and Appraise until Exit. It
  clears the treasure pool on entry and warns before leaving money in it. The redraw case keeps Shop's 'B' arm, which no
  temple choice reaches. }
procedure TempleMainMenu;

implementation

uses Crt, GDConsts, GDVars, C_Keys, Money, Types, C_Status, C_Effect, C_Class, C_Ifc, C_Msg,
  C_Screen, C_Stat, CharHlp, FxEngine, MenuCore, TextRend, ViewChar, ClassCal, GameIo, Magic, Border, EclMenu;

{ Reports that the current character does not need the cure and asks whether to cast it anyway.
  @param(msg The report, printed after the character's name.)
  @returns('Y' or 'N'.) }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharHlp.ClearMessageWindow;
end;

{ Shows a cure's price and asks whether to pay. The price is paid from the current character's coins when they cover it,
  and otherwise from the pooled money; when neither covers it, the cure is refused. A paid cure prints that the
  character is cured.
  @param(spell The cure's name.)
  @param(cost The price in gold pieces.)
  @returns(Y when the cure was paid for, N otherwise.) }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  c: Char;
  charGold: Word;
  pooled: LongInt;
begin
  spell := spell + ' will only cost ' + CharHlp.Uint16Str(cost) + ' gold pieces.';
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                Black, True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, LightGreen, White);
  if c = 'Y' then begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if cost <= charGold then begin
      Dec(charGold, cost);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      pooled := Money.CoinValueInGold(GDVars.treasureMoney);
      if cost <= pooled then begin
        Dec(pooled, cost);
        Money.SetTreasureCoinsInGold(Word(pooled));
      end else begin
        CharHlp.PrintBottomLine('Not enough money.');
        c := 'N';
      end;
    end;
  end;
  if c = 'Y' then begin
    CharHlp.ClearMessageWindow;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'is cured.', 0, True);
  end;
  ConfirmCureCost := c;
end;

{ Cures the current character's blindness for 1000 gold pieces, asking first when it is not blind. }
procedure CureBlindness;
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, eff) then
    c := Temple.ConfirmCureAnyway('is not blind.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Blindness', 1000);
    if c = 'Y' then
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
  end;
end;

{ Cures the current character's diseases for 1000 gold pieces, asking first when it has none of the six disease effects.
  All six are removed under the effect lock. }
procedure CureDisease;
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  i: Byte;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  for i := 1 to 6 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], eff) then
      found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Disease', 1000);
    if c = 'Y' then begin
      GDVars.effectLockFlag := 1;
      for i := 1 to 6 do
        FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
      GDVars.effectLockFlag := 0;
    end;
  end;
end;

{ spell 1, 2, 3: Cure Light (1d8, 100 gp), Serious (2d8+1, 350 gp) or Critical Wounds (3d8+3, 600 gp); 4: Heal, 5000 gp,
  which restores all but 1d4 hit points and removes blindness, the disease effects and effect 68.
  @param(spell The cure, 1..4.) }
procedure CureWounds(spell: Byte);
var
  hp: Byte;
  i: Byte;
  c: Char;
  { Unused in this version; see the other implementations of this routine. }
  restored: Boolean;
begin
  case spell of
    1: begin
         c := Temple.ConfirmCureCost('Cure Light Wounds', 100);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(1, 8);
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    2: begin
         c := Temple.ConfirmCureCost('Cure Serious Wounds', 350);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(2, 8) + 1;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    3: begin
         c := Temple.ConfirmCureCost('Cure Critical Wounds', 600);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(3, 8) + 3;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    4: begin
         c := Temple.ConfirmCureCost('Heal', 5000);
         if c = 'Y' then begin
           hp := GDVars.curChar^.tpHpMax - GDVars.curChar^.hpCur - FxEngine.RollDice(1, 4);
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
           FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
           for i := 1 to 6 do
             FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
           FxEngine.RemoveEffect(GDVars.curChar, 68, nil);
           FxEngine.RecalcAbility(GDVars.curChar, C_Stat.INTELLIGENCE);
           FxEngine.RecalcAbility(GDVars.curChar, C_Stat.WISDOM);
         end;
       end;
  end;
end;

{ Raise Dead, 5500 gp, for a Dead or Animated character: strips poison and animation and restores 1 hit point. Unless it
  was poisoned, it also loses a point of Constitution (none at 0); if 14 or more remain, with fewer than 17 or fighter
  levels (second-class ones when ClassCal.EarlierClassActive is nonzero), the hit-point maximum loses its excess over
  tpHpRolled, divided by the Constitution bonus when that is nonzero. }
procedure RaiseDead;
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  wasDead: Boolean;
  hpLoss: Byte;
  hpBonus: Byte;
  i: ShortInt;
  cr: Types.PWork;
  poisoned: Boolean;
begin
  cr := GDVars.curChar;
  wasDead := False;
  s := '';
  c := 'Y';
  if (cr^.status = C_Status.DEAD_STATUS) or (cr^.status = C_Status.ANIMATED) then
    wasDead := True;
  if not wasDead then
    c := Temple.ConfirmCureAnyway('is not dead.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Raise Dead', 5500);
    if c = 'Y' then begin
      if wasDead then begin
        poisoned := CharHlp.HasEffect(cr, C_Effect.POISONED, eff);
        GDVars.effectLockFlag := 1;
        FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
        GDVars.effectLockFlag := 1;
        FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_END, nil);
        GDVars.effectLockFlag := 1;
        FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
        GDVars.effectLockFlag := 1;
        FxEngine.RemoveEffect(cr, C_Effect.ANIMATE_DEAD, nil);
        GDVars.effectLockFlag := 0;
        cr^.hpCur := 1;
        cr^.status := C_Status.OKAY;
        cr^.enabled := 1;
        if poisoned then begin
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'is detoxified.', 0, True);
          Exit;
        end;
        if cr^.tpConCur > 0 then
          Dec(cr^.tpConCur);
        if cr^.tpHpMax > cr^.tpHpRolled then
          hpLoss := cr^.tpHpMax - cr^.tpHpRolled
        else
          hpLoss := 0;
        hpBonus := 0;
        if cr^.tpConCur >= 14 then begin
          for i := 0 to 7 do
            if cr^.classLevels[i] > 0 then begin
              if i = C_Class.FIGHTER_LEVEL then
                Inc(hpBonus, (cr^.tpConCur - 14) * cr^.classLevels[i])
              else if cr^.tpConCur > 15 then
                Inc(hpBonus, cr^.classLevels[i] * 2)
              else
                Inc(hpBonus, cr^.classLevels[i]);
            end;
          if hpBonus > 0 then
            hpLoss := hpLoss div hpBonus;
          if (cr^.tpConCur < 17) or (cr^.classLevels[C_Class.FIGHTER_LEVEL] > 0) or
              ((ClassCal.EarlierClassActive(Types.PWork(cr)) <> 0) and
               (cr^.classLevels2[C_Class.FIGHTER_LEVEL] > 0)) then
            Dec(cr^.tpHpMax, hpLoss);
        end;
      end;
    end;
  end;
end;

{ Neutralize Poison, 1000 gp: removes the poison effects under the effect lock and revives a character at 0 hit
  points. }
procedure NeutralizePoison;
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, eff) then
    found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not poisoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Neutralize Poison', 1000);
    if c = 'Y' then begin
      GDVars.effectLockFlag := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
      GDVars.effectLockFlag := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
      GDVars.effectLockFlag := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, nil);
      GDVars.effectLockFlag := 0;
      if GDVars.curChar^.hpCur = 0 then
        GDVars.curChar^.hpCur := 1;
      GDVars.curChar^.enabled := 1;
      GDVars.curChar^.status := C_Status.OKAY;
    end;
  end;
end;

{ Removes curses from the current character for 3500 gold pieces through the Remove Curse spell, asking first when it
  carries no cursed item and is not cursed. }
procedure RemoveCurse;
var
  cursed: Boolean;
  it: Types.PItemRec;
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  cursed := False;
  it := GDVars.curChar^.itemsAddr;
  while (it <> nil) and (not cursed) do begin
    if it^.cursed <> 0 then
      cursed := True;
    it := it^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, eff) then
      c := Temple.ConfirmCureAnyway('is not cursed.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Remove Curse', 3500);
    if c = 'Y' then begin
      GDVars.targetCreaturePtr[1] := GDVars.curChar;
      Magic.SpellRemoveCurse;
    end;
  end;
end;

{ Turns the current character from stone to flesh for 2000 gold pieces, asking first when it is not stoned. A stoned
  character comes back okay and enabled, with one hit point. }
procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if GDVars.curChar^.status <> C_Status.STONED then
    c := Temple.ConfirmCureAnyway('is not stoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Stone to Flesh', 2000);
    if c = 'Y' then
      if GDVars.curChar^.status = C_Status.STONED then begin
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.enabled := 1;
        GDVars.curChar^.hpCur := 1;
      end;
  end;
end;

{ Lists the temple's ten healing services and runs the chosen one (Heal or Enter) for the current character until the
  player leaves, then redraws the party display. }
procedure HealMenu;
var
  list: Types.PItemRec;
  { the list's head, then the menu's selection }
  sel: Types.PItemRec;
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  s: String[40];
  c: Char;
begin
  done := False;
  list := nil;
  sel := nil;
  MenuCore.AllocStringList(10, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    list^.name := GDConsts.templeSpells[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  TextRend.ClearRect(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
  redraw := True;
  Border.DrawTextFrame;
  repeat
    s := GDVars.curChar^.tpName + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, Black, s);
    c := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, False, redraw, idx,
                               sel);
    case c of
      'H', C_Keys.ENTER:
        case idx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.CureWounds(4);
          6: Temple.NeutralizePoison;
          7: Temple.RaiseDead;
          8: Temple.RemoveCurse;
          9: Temple.StoneToFlesh;
          10: done := True;
        end;
      C_Keys.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure TempleMainMenu;
var
  c: Char;
  done: Boolean;
  ext: Boolean;
  menu: String[40];
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopSessionFlag := False;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopSessionFlag := True;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'Heal View ';
    if hasItems or hasMoney then
      menu := menu + 'Take ';
    if Money.PooledMoney then
      menu := menu + 'Pool ';
    if hasMoney then
      menu := menu + 'Share ';
    menu := menu + 'Appraise Exit';
    GDVars.canClickParty := 1;
    GDConsts.canClickToView := True;
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    GDVars.canClickParty := 0;
    GDConsts.canClickToView := False;
    if ext then
      ViewChar.SelectPrevNextChar(c)
    else begin
      case c of
      'H': if not ext then Temple.HealMenu;
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      C_Keys.NONE, 'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             LightGreen, Black, True,
'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             LightGreen, Black, True,
                                             'Do you want to go back and retrieve your money?');
               ynIdx := EclMenu.MenuHorizontalCharacterSelect('', menu, LightMagenta, LightGreen, White, False, False);
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
        'B', 'T': CharHlp.DisplayNoncombatInterface;
        'A': if apprOk then CharHlp.DisplayNoncombatInterface;
      end;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
  GameIo.KbdNoop;
end;

begin
end.
