{ The developer menu.  Explore opens DeveloperMenu; it offers Tport, Item (when superModeCopy is set), Wealth,
  Spells, Combat and Jump:
    TeleportEditor  moves the party on the 16-by-16 map, or walks it (WalkEditor), and from the
                    map's edge can send the party off the map;
    ItemEditor      edits a copy of the current character's items field by field and can add it
                    to the inventory;
    WealthEditor    edits the purse (when superModeCopy is set), experience, hit points and two
                    of Camp's zone-0 words, the statues and the ring;
    SpellEditor     memorizes any spell the character's classes can cast;
    CombatEditor    switches combat off and on (GDVars.combatDisabled);
    Jump            selects disk 5 and ECL script 99 and runs EclVm's installed finishNewEcl.
  Its field positions and item-type names are in GDConsts, itemEditorField in GDVars. }
{$O+,F+,S+,A+}
unit DevMenu;

interface

{ Run the developer menu until Exit, or until a teleport off the map or a Jump sets done; then record the party's
  position as its previous one and re-read the map cell.
  @param(done Set by a teleport off the map or a Jump.) }
procedure DeveloperMenu(var done: Boolean);

implementation

uses Types, C_Keys, C_Msg, Crt, GDConsts, GDVars, TextRend, MapView, Magic, Camp, CharHlp,
  MenuCore, ViewChar, View3D, DaxIo, C_Gbvm;

{ Return 'YES' or 'NO'.
  @param(value The flag.)
  @returns(Its text.) }
function BoolStr(value: Boolean): String;
begin
  if value then BoolStr := 'YES' else BoolStr := 'NO';
end;

{ Show the edited item's name and fields under the view, and '>' at the field being changed.
  @param(item The item being edited.) }
procedure DrawItem(item: Types.PItemRec);
begin
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  with item^ do begin
  CharHlp.PrintItemString(GDVars.curChar, item, 6, 17, True, True);
  TextRend.DisplayString(2, 18, White, Black, 'Type:');
  if itemType in [1..128] then
    TextRend.DisplayString(7, 18, White, Black, GDConsts.itemTypeNames[itemType]);
  TextRend.DisplayString(2, 19, White, Black, 'identified:' + CharHlp.Uint8Str(unidMask));
  TextRend.DisplayString(21, 19, White, Black, 'cursed:' + DevMenu.BoolStr(Boolean(cursed)));
  TextRend.DisplayString(2, 20, White, Black, 'plus:' + CharHlp.Uint8Str(Byte(plus)));
  TextRend.DisplayString(21, 20, White, Black, 'plussave: ' + CharHlp.Uint8Str(Byte(saveBonus)));
  TextRend.DisplayString(2, 21, White, Black, 'weight:' + CharHlp.Uint16Str(weight));
  TextRend.DisplayString(21, 21, White, Black, 'value:' + CharHlp.Uint16Str(value));
  TextRend.DisplayString(4, 22, White, Black,
                         'specials:' + CharHlp.Uint8Str(charges) + ' ' + CharHlp.Uint8Str(effect) + ' ' +
                           CharHlp.Uint8Str(special));
  end;
  TextRend.DisplayStringClipped(GDConsts.itemFieldX[GDVars.itemEditorField],
                                GDConsts.itemFieldY[GDVars.itemEditorField], LightRed, Black, '>');
end;

{ Edit a copy of the current character's items field by field: the arrow keys pick the field, Add and Sub change it by
  the step, which Inc multiplies by ten up to 1000, Next takes a copy of the next item, and Keep adds the copy to the
  inventory if it can be carried. }
procedure ItemEditor;
var
  item: Types.TItemRec;
  source: Types.PItemRec;
  increment: Integer;
  c: Char;
  ext: Boolean;

  { Change the selected field of the edited item by delta, or toggle a flag field. }
  procedure ChangeItem(delta: Integer);
  var value: Integer;
  begin
    case GDVars.itemEditorField of
      0: item.equipped := Ord(item.equipped = 0);
      1: Inc(item.quantity, delta);
      2, 3, 4: begin
        value := item.nameIds[5 - GDVars.itemEditorField] + delta;
        if value in [0..255] then
          item.nameIds[5 - GDVars.itemEditorField] := value;
      end;
      5: begin
        value := item.itemType + delta;
        if value in [1..128] then item.itemType := value;
      end;
      6: item.unidMask := (item.unidMask + delta) and 7;
      7: item.cursed := Ord(item.cursed = 0);
      8: Inc(item.plus, delta);
      9: Inc(item.saveBonus, delta);
      10: Inc(item.weight, delta);
      11: Inc(item.value, delta);
      12, 13, 14: Inc(item.spells[GDVars.itemEditorField - 11], delta);
    end;
  end;

begin
  GDVars.itemEditorField := 0;
  increment := 1;
  source := GDVars.curChar^.itemsAddr;
  if source <> nil then begin
    item := source^;
    source := source^.next;
  end else begin
    FillChar(item, SizeOf(item), 0);
    item.itemType := 1;
  end;
  repeat
    DevMenu.DrawItem(@item);
    c := MenuCore.MenuHorizontal('Change by ' + CharHlp.Uint16Str(increment) + ':', 'Add Sub Inc Next Keep Exit',
                                 LightMagenta, LightGreen, White, True, False, ext);
    if ext then case c of
      { the next field }
      C_Keys.DOWN: begin
        Inc(GDVars.itemEditorField);
        if GDVars.itemEditorField > 14 then
          GDVars.itemEditorField := 0
      end;
      { the previous field }
      C_Keys.UP: if GDVars.itemEditorField = 0 then
             GDVars.itemEditorField := 14
           else Dec(GDVars.itemEditorField);
    end else if not ext then case c of
      'I': begin increment := increment * 10; if increment >= 10000 then increment := 1 end;
      'A': ChangeItem(increment);
      'S': ChangeItem(-increment);
      'N': begin
        if source <> nil then begin
          item := source^; source := source^.next
        end else source := GDVars.curChar^.itemsAddr
      end;
      'K': if not ViewChar.CannotCarryItem(GDVars.curChar, @item) then begin
        CharHlp.AddItemCopy(GDVars.curChar, @item);
        TextRend.DisplayAndPause(White, Black, 'Item added to inventory')
      end else
        TextRend.DisplayAndPause(White, Black, 'Inventory full');
      'E': ;
    end;
  until c = 'E';
end;

{ After a walk step or a teleport: redraw the status line (coordinates, facing, time and the camping/search/boat tag on
  row 15, through CharHlp.PrintPositionAndTime), the 3D view at the party's cell and the sheet headers. }
procedure RedrawStatusLineViewAndHeaders;
begin
  CharHlp.PrintPositionAndTime;
  MapView.DisplayMapView;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ Shows 'visible' or 'invisible' by whether the current character is hostile, and the free heap. }
procedure DrawPosition;
begin
  if GDVars.curChar^.hostile = 0 then
    TextRend.DisplayStringClipped(1, 20, White, Black, 'visible')
  else
    TextRend.DisplayStringClipped(1, 20, White, Black, 'invisible');
  TextRend.DisplayStringClipped(1, 21, White, Black,
                                GDVars.longToStringFunc(MemAvail) + ' ' + GDVars.longToStringFunc(MaxAvail));
end;

{ Moves the party: Up steps it forward, wrapping on the 16-by-16 map; Down, Left and Right turn it about, left and
  right; Exit ends. }
procedure WalkEditor;
var ext: Boolean; c: Char;
begin
  repeat
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    DevMenu.DrawPosition;
    c := MenuCore.MenuHorizontal('(Use arrow keys):', 'Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then
      case c of
        C_Keys.UP: begin
          Inc(GDVars.partyPos.mapX, GDConsts.dirDX[GDVars.partyPos.facing]);
          Inc(GDVars.partyPos.mapY, GDConsts.dirDY[GDVars.partyPos.facing]);
          GDVars.partyPos.mapX := GDVars.partyPos.mapX and $0F;
          GDVars.partyPos.mapY := GDVars.partyPos.mapY and $0F;
          DevMenu.RedrawStatusLineViewAndHeaders;
        end;
        C_Keys.DOWN: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime
        end;
        C_Keys.LEFT: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime
        end;
        C_Keys.RIGHT: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime
        end;
      end else case c of
      'E': Exit;
    end;
  until False;
end;

{ Lets the player pick a map cell to teleport the party to, X and Y stepping by the increment (Inc flips it between 1
  and -1) and wrapping on the 16-by-16 map; Self moves the party there and, with Map set at the map's edge, sends it off
  the map. Walk runs WalkEditor.
  @param(done Set when the party is sent off the map.) }
procedure TeleportEditor(var done: Boolean);
var
  x: Byte;
  y: Byte;
    { Unused in this version; see the other implementations of this routine. }
    field: Byte;
    c: Char; ext: Boolean; all: Boolean; increment: Integer;
begin
  x := Byte(GDVars.partyPos.mapX); y := Byte(GDVars.partyPos.mapY);
  all := False; increment := 1;
  repeat
    if (x <> 15) and (x <> 0) and (y <> 0) and (y <> 15) then
      all := False;
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    TextRend.DisplayString(1, 17, LightGreen, Black, 'teleport to: ' + CharHlp.Uint8Str(x) + ' ' + CharHlp.Uint8Str(y));
    TextRend.DisplayString(1, 18, LightGreen, Black, 'go off of map: ' + DevMenu.BoolStr(all));
    if increment = -1 then
      TextRend.DisplayString(1, 21, LightGreen, Black, 'Increment: -1')
    else
      TextRend.DisplayString(1, 21, LightGreen, Black, 'Increment: 1');
    TextRend.DisplayString(1, 22, LightGreen, Black, 'Self=teleport self, all=teleport all');
    DevMenu.DrawPosition;
    c := MenuCore.MenuHorizontal('', 'Walk X Y Inc Map Self Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar)
    end else case c of
      'I': increment := -increment;
      'A': ;
      'M': all := not all;
      'S': begin
        GDVars.partyPos.mapX := x; GDVars.partyPos.mapY := y;
        DevMenu.RedrawStatusLineViewAndHeaders;
        if all then begin
          GDVars.gbvmZone1Ptr^[C_Gbvm.LEAVE_MAP] := 1;
          GDVars.gbvmZone1Ptr^[C_Gbvm.MOVE_LOCK] := 255;
          done := True;
        end;
      end;
      'X': begin Inc(x, increment); x := x and $0F end;
      'Y': begin Inc(y, increment); y := y and $0F end;
      'W': begin DevMenu.WalkEditor; x := Byte(GDVars.partyPos.mapX); y := Byte(GDVars.partyPos.mapY) end;
      'E': ;
    end;
  until (c = 'E') or done;
end;

{ Edit the current character's coins (in super mode), experience, hit points and maximum hit points, and the camp
  statues and ring, field by field with the arrow keys; Add and Sub change the field by the step, which Inc multiplies
  by ten up to 1000. }
procedure WealthEditor;
var field: Byte;
    { Unused in this version; see the other implementations of this routine. }
    fieldIndex: array[0..2] of Byte;
    increment: Integer; c: Char; ext: Boolean; startField: Byte;

  { Show the editable values and '>' at the field being changed. }
  procedure DrawStats;
  var i: Byte;
  begin
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    if GDVars.superModeCopy <> 0 then
      for i := 0 to 6 do
        TextRend.DisplayString(GDConsts.wealthFieldX[i] + 1, GDConsts.wealthFieldY[i], White, Black,
                               GDConsts.moneyNames[ShortInt(i + 0)] + ' ' +
                                 CharHlp.Uint16Str(GDVars.curChar^.coinsA[ShortInt(i + 0)]));
    TextRend.DisplayStringClipped(2, 21, White, Black,
                                  'Experience ' + CharHlp.Int32Str(GDVars.curChar^.experience));
    TextRend.DisplayStringClipped(2, 22, White, Black,
                                  'Current HP ' + CharHlp.Uint8Str(GDVars.curChar^.hpCur));
    TextRend.DisplayStringClipped(21, 22, White, Black, 'Max HP ' + CharHlp.Uint8Str(GDVars.curChar^.evMaxHp));
    TextRend.DisplayStringClipped(GDConsts.wealthFieldX[field], GDConsts.wealthFieldY[field], LightRed, Black, '>');
    TextRend.DisplayStringClipped(21, 20, White, Black,
                                  'stat(1f2w4e8a) ' + CharHlp.Uint8Str(GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES]));
    TextRend.DisplayStringClipped(21, 21, White, Black,
                                  'ring ' + CharHlp.Uint8Str(GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_RING]));
  end;

  { Change the selected value by delta; the statues and the ring wrap within their bits. }
  procedure ChangeScalar(delta: Integer);
  begin
    case field of
      0..6: Inc(GDVars.curChar^.coinsA[ShortInt(field + 0)], delta);
      7: Inc(GDVars.curChar^.experience, delta);
      8: Inc(GDVars.curChar^.hpCur, delta);
      9: Inc(GDVars.curChar^.evMaxHp, delta);
      10: GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] := (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] + delta) and $0F;
      11: GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_RING] := (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_RING] + delta) and 1;
    end;
  end;

begin
  if GDVars.superModeCopy <> 0 then
    startField := 0 else startField := 7;
  field := startField;
  increment := 1;
  repeat
    DrawStats;
    c := MenuCore.MenuHorizontal('Change by ' + CharHlp.Uint16Str(increment) + ':', 'Add Sub Inc Exit', LightMagenta,
                                 LightGreen, White, True, False, ext);
    if ext then case c of
      { the next field }
      C_Keys.DOWN: begin
        Inc(field);
        if field > 11 then field := startField
      end;
      { the previous field }
      C_Keys.UP: if field = startField then field := 11 else Dec(field);
    end else if not ext then case c of
      'I': begin
        increment := increment * 10;
        if increment >= 10000 then increment := 1
      end;
      'A': ChangeScalar(increment);
      'S': ChangeScalar(-increment);
      'E': ;
    end;
  until c = 'E';
end;

{ Lets the player pick a spell from 1 to 100, Add and Sub stepping by 1 or 10 (Inc), showing whether the character's
  classes can cast it; Memorize memorizes it in the first free slot when they can, and otherwise shows 'Cannot use
  spell'. The memorized spells are sorted on leaving. }
procedure SpellEditor;
var c: Char; ext: Boolean; spell: Byte; increment: Word; candidate: Byte;

  { Memorize spell value in the first free slot and show its name. }
  procedure AddMemorizedSpell(value: Byte);
  var i: Byte;
  begin
    for i := 0 to 80 do
      if GDVars.curChar^.memorizedSpells[i] = 0 then begin
        GDVars.curChar^.memorizedSpells[i] := value;
        TextRend.DisplayAndPause(White, Black, GDConsts.spellNames[value]);
        Exit
      end;
  end;

begin
  increment := 1;
  spell := 1;
  repeat
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    TextRend.DisplayStringClipped(2, 17, White, Black,
                                  DevMenu.BoolStr(Magic.ClassCanCastSpell(GDVars.curChar, spell)) + '-' +
                                  GDConsts.spellNames[spell]);
    c := MenuCore.MenuHorizontal('Change by ' + CharHlp.Uint16Str(increment) + ':', 'Memorize Add Sub Inc Exit',
                                 LightMagenta, LightGreen, White, True, False, ext);
    if not ext then case c of
      'M': if Magic.ClassCanCastSpell(GDVars.curChar, spell) then
             AddMemorizedSpell(spell)
           else
             TextRend.DisplayAndPause(White, Black, 'Cannot use spell');
      'I': begin
        increment := increment * 10;
        if increment >= 100 then increment := 1
      end;
      'A': begin
        candidate := spell + increment;
        if candidate in [1..100] then spell := candidate
      end;
      'S': begin
        candidate := spell - increment;
        if candidate in [1..100] then spell := candidate
      end;
      'E': ;
    end;
  until c = 'E';
  Camp.SortMemorizedSpells;
end;

{ Switches combat off (Disable) and on (Reenable) through the combat-disabled flag, until Exit or the aim flag is set. }
procedure CombatEditor;
var c: Char; ext: Boolean;
begin
  repeat
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    DevMenu.DrawPosition;
    if GDVars.combatDisabled = 0 then
      TextRend.DisplayStringClipped(1, 21, White, Black, 'combat enabled')
    else
      TextRend.DisplayStringClipped(1, 21, White, Black, 'combat disabled');
    c := MenuCore.MenuHorizontal('', 'Disable Reenable Exit', LightMagenta, LightGreen, White, True, False, ext);
    if not ext then case c of
      'D': begin
        GDVars.combatDisabled := 1;
        GDVars.displayStatusLineProc('Combat disabled')
      end;
      'R': begin
        GDVars.combatDisabled := 0;
        GDVars.displayStatusLineProc('Combat reenabled')
      end;
    end;
  until (c = 'E') or GDVars.breathAim;
  MenuCore.ClearBottomLine;
end;

procedure DeveloperMenu(var done: Boolean);
var menu: String; ext: Boolean; c: Char;
begin
  menu := 'Tport ';
  if GDVars.superModeCopy <> 0 then
    menu := menu + 'Item ';
  menu := menu + 'Wealth Spells Combat Jump E';
  repeat
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    DevMenu.DrawPosition;
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    if not ext then case c of
      'C': DevMenu.CombatEditor;
      'T': DevMenu.TeleportEditor(done);
      'S': DevMenu.SpellEditor;
      'I': DevMenu.ItemEditor;
      'W': DevMenu.WealthEditor;
      'J': begin
        DaxIo.PushState(5);
        GDVars.eclScript := 99;
        GDVars.finishNewEclProc;
        done := True
      end;
    end;
  until (c = 'E') or done;
  GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_X] := ShortInt(GDVars.partyPos.mapX);
  GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_Y] := ShortInt(GDVars.partyPos.mapY);
  { the map cell's wall, barrier and event }
  View3D.RefreshCurrentMapCell;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

begin
end.
