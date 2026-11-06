{ The end of a combat. PostCombat settles who won, fled or fell, gathers the fallen monsters' coins, items and
  experience into the treasure pool and shares the experience out, removes the monsters and the combat records, lets the
  NPCs take their share of the coins, shows the summary and runs the loot menu (View, Take, Pool, Share, Detect), or the
  game-over screen when the party is destroyed. Vault calls the Take menu, LootTakeMenu, too. The treasure pool, the
  party and the combat flags are in GDVars. }
{$O+,F+,S+,A+}
unit PostCbt;

interface

{ Settles a finished combat and runs its aftermath; in demo mode it only clears up. It ends by clearing zone 1's combat
  modifiers, its no-combat-items flag and its mirror-duel flag. }
procedure PostCombat;

{ The Take menu: Money, Items or Exit while the pool holds both, else the one there is.
  @param(hasMoney Whether the pool holds coins; kept current as the party takes them.)
  @param(items Whether the pool holds items; kept current likewise.) }
procedure LootTakeMenu(var hasMoney, items: Boolean);

implementation

uses CharGen, Shop, EclMenu, Types, C_Status, C_Ifc, C_Item, C_Msg, C_Npc, C_Spell, CharHlp, FxEngine,
  Border, TextRend, MenuCore, ViewChar, Money, Magic, GameIo,
  Crt, GDConsts, GDVars, C_Keys, C_Gbvm;

const
  { GBVM zone 0: 1 skips the treasure share and the summary after a combat }
  SKIP_AFTERMATH = $4CFA;
  { GBVM zone 1: the monsters the party defeated }
  MONSTERS_DEFEATED = $7EC8;
  { GBVM zone 1: 1 keeps the defeated monsters' items out of the treasure }
  NO_COMBAT_ITEMS = $7EE3;
  { GBVM zone 1: the monsters' and the party's to-hit adjustments }
  MONSTER_THAC0_MODIFIER = $7F70;
  PARTY_THAC0_MODIFIER = $7F71;
  { zone 1's combat result (0 won, 128 lost, 129 fled) }
  RESULT_LOST = $80;
  RESULT_FLED = $81;
  { spellNames' cleric and druid Detect Magic; C_Spell names the magic-user's. }
  SPELL_DETECT_MAGIC_CLERIC = 5;
  SPELL_DETECT_MAGIC_DRUID = 77;

{ The experience each party member earns: in a duel 100 per level of the current character; otherwise the pool gathers
  each fallen hostile creature's coins and every item it carried but monster weapons (none while zone 1's
  no-combat-items flag is 1), and the experience is each one's award and its bonus per hit point rolled, the coins'
  worth and 400 per plus of each pooled item ahead of GDVars.lastMissileItem, divided by zone 1's party size less
  GDVars.nonAnimCount, the party members DetermineCombatResults counts as out of play (enabled 0) or animated.
  @param(share Receives the experience each party member earns.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PWork;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  it: Types.PItemRec;
  cnt: Byte;
begin
  if GDVars.duelFlag then
    share := GDVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GDVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      it := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_Status.OKAY) and (p^.status <> C_Status.RUNNING) then begin
        GDVars.monstersKilled := 1;
        for i := 0 to 6 do
          Inc(GDVars.treasureMoney[i], p^.coinsA[i]);
        expTotal := expTotal + p^.xpAward + p^.xpBonusPerHp * p^.pcHpRolled;
        if GDVars.gbvmZone1Ptr^[PostCbt.NO_COMBAT_ITEMS] <> 1 then
          while it <> nil do begin
            if not (it^.itemType in
                    [C_Item.VH_BOULDER, C_Item.LT_BOULDER, C_Item.HY_BOULDER, C_Item.MANT_TAIL]) then begin
              Inc(cnt);
              if GDVars.treasureItems = nil then begin
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(p, it, 0, 0, False, False);
                GDVars.treasureItems^ := it^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := nil;
              end else begin
                q := GDVars.treasureItems;
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(p, it, 0, 0, False, False);
                GDVars.treasureItems^ := it^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := q;
              end;
            end;
            it := it^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    Inc(expTotal, GDVars.treasureMoney[0] div 200);
    Inc(expTotal, GDVars.treasureMoney[1] div 20);
    Inc(expTotal, GDVars.treasureMoney[2] div 2);
    Inc(expTotal, GDVars.treasureMoney[3]);
    Inc(expTotal, GDVars.treasureMoney[4] * 5);
    Inc(expTotal, GDVars.treasureMoney[5] * 250);
    Inc(expTotal, GDVars.treasureMoney[6] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    { Note: divides by zero when they are equal }
    share :=
      expTotal div (GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] - GDVars.nonAnimCount);
  end;
end;

{ Gives xp to each creature in play that is not animated: 10% more to a single-classed character whose prime requisites
  are all above 15 (class 0 Wis, 2 Str, 3 Str and Wis, 4 Str, Int and Wis, 5 Int, 6 Dex), half to the two-class
  combinations and a third to the three-class ones.
  @param(xp The experience.) }
procedure AwardExperience(xp: LongInt);
var
  p: Types.PWork;
  share: LongInt;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_Status.ANIMATED) then begin
      share := xp;
      case p^.charClass of
        0: if p^.wisCur > 15 then share := xp div 10 + xp;
        2: if p^.strCur > 15 then share := xp div 10 + xp;
        3: if (p^.strCur > 15) and (p^.wisCur > 15) then share := xp div 10 + xp;
        4: if (p^.strCur > 15) and (p^.intCur > 15) and (p^.wisCur > 15) then share := xp div 10 + xp;
        5: if p^.intCur > 15 then share := xp div 10 + xp;
        6: if p^.dexCur > 15 then share := xp div 10 + xp;
        8, 10..14, 16: share := xp div 2;
        9, 15: share := xp div 3;
      end;
      Inc(p^.experience, share);
    end;
    p := p^.nextCharAddr;
  end;
end;

{ Settles the combat: whether the party fled, was defeated or won, GDVars.nonAnimCount (the party members out of play or
  animated) and each creature's combat effects. A win shares the experience; then a surviving party loses the hostile
  creatures and gets its fled, dying and unconscious members back by the combat's rules, and a defeated one loses
  everyone. After a flight it records RESULT_FLED in zone 1's combat result while a hostile creature still stands, takes
  the fled members back and, while zone 0's combat mode is 0, removes the others. A duel while GDVars.demoMode is set
  takes the last branch instead: the experience is shared once for each party member left standing, and the dying fall
  unconscious. Note: a duel is never a defeat, nor is a mirror duel while any creature is in play, unconscious, fled or
  dying: that scan walks the whole list, monsters included, so any creature still in play satisfies it. Note: after a
  flight with the combat mode set, the walk never steps past a member that did not flee, so it does not end. }
procedure DetermineCombatResults;
var
  p: Types.PWork;
  b: Boolean;
  clearIdx: Byte;
  anyDown: Boolean;
  { a hostile creature still stands }
  hostileOkay: Boolean;
begin
  GDVars.nonAnimCount := 0;
  GDVars.partyDefeated := True;
  GDVars.partyFled := 0;
  hostileOkay := False;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.hostile = 1) and (p^.status = C_Status.OKAY) then
      hostileOkay := True;
    p := p^.nextCharAddr;
  end;
  p := GDVars.creatureList;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := 1;
    p := p^.nextCharAddr;
  end;
  p := GDVars.creatureList;
  anyDown := False;
  while (p <> nil) and (not anyDown) do begin
    if (p^.enabled <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then
      anyDown := True;
    p := p^.nextCharAddr;
  end;
  if GDVars.duelFlag or ((GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] <> 0) and anyDown) then
    GDVars.partyDefeated := False;
  GDVars.combatWon := False;
  p := GDVars.creatureList;
  if not GDVars.duelFlag or not GDVars.demoMode then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and (p^.hostile = 0) and (p^.npc < C_Npc.NON_PLAYER) then
        GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True;
        GDVars.partyFled := 0;
      end;
      if (p^.enabled = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.nonAnimCount);
      for clearIdx := 1 to 20 do begin
        GDVars.effectLockFlag := 1;
        FxEngine.RemoveEffect(p, GDConsts.clearEffects[clearIdx], nil);
      end;
      GDVars.effectLockFlag := 0;
      p := p^.nextCharAddr;
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare);
      PostCbt.AwardExperience(GDVars.expShare);
    end;
    p := GDVars.creatureList;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        if p^.hostile = 1 then begin
          GDVars.curChar := p;
          p := p^.nextCharAddr;
          CharGen.RemoveCreature(False, True);
        end else if GDVars.partyFled = 0 then begin
          case Char(p^.status) of
            Chr(C_Status.RUNNING):
              begin
                p^.status := C_Status.OKAY;
                p^.enabled := 1;
              end;
            Chr(C_Status.DYING):
              if GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] <> 0 then begin
                p^.status := C_Status.OKAY;
                p^.enabled := 1;
                p^.pcHpCur := 1;
              end else
                p^.status := C_Status.UNCONSCIOUS;
            Chr(C_Status.UNCONSCIOUS):
              if p^.pcHpCur > 0 then begin
                p^.status := C_Status.OKAY;
                p^.enabled := 1;
              end else if GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] <> 0 then begin
                p^.status := C_Status.OKAY;
                p^.enabled := 1;
                p^.pcHpCur := 1;
              end;
          end;
          p := p^.nextCharAddr;
        end else begin
          if hostileOkay then
            GDVars.gbvmZone1Ptr^[C_Gbvm.COMBAT_RESULT] := PostCbt.RESULT_FLED;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.enabled := 1;
            p := p^.nextCharAddr;
          end else if GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 0 then begin
            GDVars.curChar := p;
            p := p^.nextCharAddr;
            CharGen.RemoveCreature(False, True);
          end;
        end;
      end;
    end else begin
      p := GDVars.creatureList;
      b := False;
      while (p <> nil) and (not b) do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          b := True;
        p := p^.nextCharAddr;
      end;
      GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> 1) then begin
        GDVars.combatWon := True;
        PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare);
      end;
      p := p^.nextCharAddr;
    end;
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
      p := p^.nextCharAddr;
    end;
  end;
end;

{ Whether the treasure pool holds money or items.
  @returns(True when it does.) }
function HasTreasure: Boolean;
var
  i: ShortInt;
begin
  HasTreasure := True;
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] <> 0 then
      Exit;
  if GDVars.treasureItems <> nil then Exit;
  HasTreasure := False;
end;

{ The summary screen: fled (the pool is emptied), lost, won or treasure found, and the experience each character
  receives, none after a flight or a loss.
  @param(xp The experience each character receives.) }
procedure PostCombatSummary(xp: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  { always empty }
  query: String[1];
  ext: Boolean;
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  query[0] := #0;
  Border.DrawWindowFrame;
  if (GDVars.monstersKilled <> 0) or GDVars.duelFlag then begin
    if GDVars.partyFled <> 0 then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, 'The party has fled.');
      xp := 0;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p^.next;
        FreeMem(p, SizeOf(Types.TItemRec));
        p := q;
      end;
      FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
    end else if (GDVars.duelFlag and not GDVars.combatWon) or
      (not GDVars.combatWon and (GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] <> 0)) then begin
      GDVars.gbvmZone1Ptr^[C_Gbvm.COMBAT_RESULT] := PostCbt.RESULT_LOST;
      TextRend.DisplayString(1, 3, LightGreen, Black, 'You have lost the fight.');
      xp := 0;
    end else begin
      if GDVars.duelFlag then
        TextRend.DisplayString(1, 3, LightGreen, Black, 'You have won the duel.')
      else
        TextRend.DisplayString(1, 3, LightGreen, Black, 'The party has won.');
    end;
  end else
    TextRend.DisplayString(1, 3, LightGreen, Black, 'The party has found Treasure!');
  if xp <> 0 then begin
    Str(xp, numStr);
    if GDVars.duelFlag then
      msg := 'The duelist receives ' + numStr
    else
      msg := 'Each character receives ' + numStr;
    TextRend.DisplayString(1, 5, LightGreen, Black, msg);
    TextRend.DisplayString(1, 7, LightGreen, Black, 'experience points.');
  end;
  if not PostCbt.HasTreasure then
    TextRend.DisplayString(1, 9, LightGreen, Black, 'No treasure found.');
  c := MenuCore.MenuHorizontal(query, 'press <enter>/<return> to continue', White, White, White, True, False, ext);
end;

{ Lists the treasure items in a vertical Take menu.
  @param(c Receives the key pressed.)
  @param(itemToTake Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  tmp: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { the menu clears it }
  redraw: Boolean;
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindowFrame;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True, redraw, idx,
                             cursor);
  itemToTake := cursor;
end;

{ Unlinks an item from the treasure pool and frees it; a nil item is ignored.
  @param(item The item.) }
procedure RemoveTreasureItem(item: Types.PItemRec);
var
  p: Types.PItemRec;
begin
  if item = nil then Exit;
  p := GDVars.treasureItems;
  if p = item then
    GDVars.treasureItems := item^.next
  else begin
    while (p <> nil) and (p^.next <> item) do
      p := p^.next;
    if p <> nil then
      p^.next := item^.next;
  end;
  FreeMem(item, SizeOf(Types.TItemRec));
end;

{ Takes items from the pool for the current character until Exit or the pool is empty. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        PostCbt.RemoveTreasureItem(itemToTake);
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var hasMoney, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if hasMoney then begin
    if items then begin
      repeat
        GDVars.canClickParty := 1;
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White, True, True, ext);
        GDVars.canClickParty := 0;
        if GDVars.extFlag then
          ViewChar.SelectPrevNextChar(c)
        else case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
               end;
          'I': PostCbt.LootTakeItemMenu;
          'E', C_Keys.NONE: done := True;
        end;
        CharHlp.DisplayParty(GDVars.curChar);
        Money.DetermineTreasure(hasMoney, items);
        if not hasMoney or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ The loot menu: View, Take while the pool holds anything, Pool, Share while it holds coins, Detect while the current
  character has Detect Magic memorized and the pool holds items, and Exit, which asks first while treasure is left. }
procedure LootMenu;
var
  hasMoney: Boolean;
  items: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  canDetect: Byte;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  { always empty }
  query: String[1];
  ynIdx: Byte;
  i: Byte;
  detectSpell: Byte;
  hasDetect: Byte;
  tail: String[13];
  menuExt: Boolean;
begin
  query[0] := #0;
  done := False;
  CharHlp.DisplayNoncombatInterface;
  hasMoney := False;
  repeat
    Money.DetermineTreasure(hasMoney, items);
    i := 0;
    hasDetect := 0;
    if items then
      while (i <= C_Spell.MEMORIZED_SPELL_SLOTS - 1) and (hasDetect = 0) do begin
        if ((GDVars.curChar^.memorizedSpells[i] = PostCbt.SPELL_DETECT_MAGIC_CLERIC) or
            (GDVars.curChar^.memorizedSpells[i] = C_Spell.DETECT_MAGIC_MAGE) or
            (GDVars.curChar^.memorizedSpells[i] = PostCbt.SPELL_DETECT_MAGIC_DRUID)) and
            (GDVars.curChar^.enabled <> 0) then begin
          hasDetect := 1;
          detectSpell := GDVars.curChar^.memorizedSpells[i];
        end;
        Inc(i);
      end;
    if hasDetect <> 0 then
      tail := 'Detect Exit'
    else
      tail := 'Exit';
    menu := 'View ';
    if hasMoney or items then
      menu := menu + 'Take ';
    if Money.PooledMoney then
      menu := menu + 'Pool ';
    if hasMoney then
      menu := menu + 'Share ' + tail
    else
      menu := menu + tail;
    GDVars.canClickParty := 1;
    GDConsts.canClickToView := True;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, True, menuExt);
    GDConsts.canClickToView := False;
    GDVars.canClickParty := 0;
    if menuExt then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else case c of
      'V': ViewChar.ViewCharMenu(ext);
      'T': PostCbt.LootTakeMenu(hasMoney, items);
      'P': Money.PoolMoney;
      'S': Money.ShareMoney;
      'D': Magic.CastSpell(detectSpell, False, False, ext);
      'E', C_Keys.NONE: begin
                 Money.DetermineTreasure(hasMoney, items);
                 if hasMoney or items then begin
                   menu := '~Yes ~No';
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, LightGreen, Black,
                                                 True, 'There is still treasure left.  ');
                   TextRend.AdvanceTextCursor;
                   TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                                                 C_Msg.TEXT_BOTTOM, White, Black, False,
                                                 'Do you want to go back and claim your treasure?');
                   ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                                  False);
                   if ynIdx = 1 then
                     done := True
                   else
                     TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
                 end else
                   done := True;
               end;
    end;
  until done;
end;

{ Removes the monsters, counting in zone 1's count of monsters defeated those out of play, frees the party's combat
  records and leaves the current character at the head of the list. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PWork;
  next: Types.PWork;
begin
  GDVars.gbvmZone1Ptr^[PostCbt.MONSTERS_DEFEATED] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.combatAddr^.notPcNpc = 1 then begin
      GDVars.monstersKilled := 1;
      if p^.enabled <> 1 then
        Inc(GDVars.gbvmZone1Ptr^[PostCbt.MONSTERS_DEFEATED]);
      next := p^.nextCharAddr;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      p := p^.nextCharAddr;
    end;
  end;
  GDVars.curChar := GDVars.creatureList;
end;

{ Lets each okay NPC take its share of the treasure money: its weight is the low three bits of its modified field,
  everyone else counts 1, and the NPCs' shares come out of each coin type. Each NPC that took a share says so, and the
  player presses Enter. }
procedure NpcTreasureShare;
var
  p: Types.PWork;
  npcShares: Byte;
  total: Byte;
  cut: Byte;
  row: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  msg: String[8];
  { Unused in this version; see the other implementations of this routine. }
  share: Byte;
  took: Boolean;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  took := False;
  p := GDVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    if (p^.npc > C_Npc.MORALE_MASK) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.modified and 7);
      Inc(total, p^.modified and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := 0 to 6 do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindowFrame;
    p := GDVars.creatureList;
    row := 0;
    while p <> nil do begin
      if (p^.npc > C_Npc.MORALE_MASK) and (p^.status = C_Status.OKAY) and (p^.modified > 0) then begin
        if p^.pcGender = 0 then
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, Black, True,
                                        p^.name + ' takes and hides ' + 'his' + ' share.')
        else
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, Black, True,
                                        p^.name + ' takes and hides ' + 'her' + ' share.');
        Inc(row, 2);
      end;
      p := p^.nextCharAddr;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White, True, False, ext);
  end;
end;

procedure PostCombat;
var
  p: Types.PItemRec;
  q: Types.PItemRec;
  cp: Types.PWork;
begin
  GDVars.gbvmZone1Ptr^[C_Gbvm.COMBAT_RESULT] := 0;
  GDVars.monstersKilled := 0;
  if not GDVars.demoMode then
    PostCbt.DetermineCombatResults;
  GDVars.interfaceState := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.demoMode then begin
    cp := GDVars.creatureList;
    while cp <> nil do begin
      CharHlp.RecalcStats(cp);
      cp := cp^.nextCharAddr;
    end;
    if not GDVars.partyDefeated or GDVars.duelFlag then begin
      if GDVars.partyFled <> 0 then begin
        p := GDVars.treasureItems;
        while p <> nil do begin
          q := p;
          p := p^.next;
          FreeMem(q, SizeOf(Types.TItemRec));
        end;
        GDVars.treasureItems := nil;
      end;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p;
        p := p^.next;
        if (q^.itemType = C_Item.HAMMER) and (q^.nameIds[2] = C_Item.HAMMER_COMPONENT) and
            (q^.nameIds[3] = C_Item.SPIRITUAL_COMPONENT) then
          PostCbt.RemoveTreasureItem(q);
      end;
      cp := GDVars.creatureList;
      while cp <> nil do begin
        p := cp^.itemsAddr;
        while p <> nil do begin
          q := p;
          p := p^.next;
          if (q^.itemType = C_Item.HAMMER) and (q^.nameIds[2] = C_Item.HAMMER_COMPONENT) and
              (q^.nameIds[3] = C_Item.SPIRITUAL_COMPONENT) then begin
            CharHlp.RemoveItem(cp, q);
            CharHlp.RecalcStats(cp);
          end;
        end;
        cp := cp^.nextCharAddr;
      end;
      if GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1 then
        GDVars.partyPos.facing := GDVars.gbvmZone0Ptr^[C_Gbvm.FLEE_DIRECTION];
      if not GDVars.demoMode and (GDVars.gbvmZone0Ptr^[PostCbt.SKIP_AFTERMATH] <> 1) then begin
        PostCbt.NpcTreasureShare;
        PostCbt.PostCombatSummary(GDVars.expShare);
        if PostCbt.HasTreasure then
          PostCbt.LootMenu;
      end;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p;
        p := p^.next;
        FreeMem(q, SizeOf(Types.TItemRec));
      end;
      GDVars.treasureItems := nil;
    end else begin
      GDVars.gbvmZone1Ptr^[C_Gbvm.COMBAT_RESULT] := PostCbt.RESULT_LOST;
      Border.DrawWindowFrame;
      GDVars.curCol := 2;
      GDVars.curRow := 6;
      TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, Black, True, 'The party has been destroyed.');
      TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
    end;
    GDVars.msgDelayFlag := 1;
    GDVars.gbvmZone1Ptr^[PostCbt.MONSTER_THAC0_MODIFIER] := 0;
    GDVars.gbvmZone1Ptr^[PostCbt.PARTY_THAC0_MODIFIER] := 0;
    GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_MOVE_MODIFIER] := 0;
    GDVars.gbvmZone1Ptr^[PostCbt.NO_COMBAT_ITEMS] := 0;
    GDVars.gbvmZone1Ptr^[C_Gbvm.MIRROR_DUEL] := 0;
    GameIo.KbdNoop;
  end;
end;

begin
end.
