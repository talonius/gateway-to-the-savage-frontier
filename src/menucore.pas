{ The menu engine. MenuHorizontal shows a menu on the bottom lines and waits for a key, a mouse click or a joystick
  move, stepping the portrait animation and the 3D view's color cycle (RemapView, from MCREMAP.OBJ) while it waits;
  MenuVertical pages a string list in a window above it; YesNoMenu and YesNoMenuClear ask Yes or No; AllocStringList and
  FreeStringList build and free the lists. The menu state is in GDVars: the choice, the key and the extended-key flag,
  the colors, the auto-answer time and key, and the vertical menu's page, text rows and click columns. }
{$O+,F+,S+}
{$A+}
unit MenuCore;

interface

uses TextRend, GDConsts, GDVars, C_Keys, C_Dir, C_Ifc, C_Menu, C_Pic, C_Screen, Portrait, Border, GameIo,
  Mouse, Joystick, CbtMap, Types, Crt, C_Gbvm;

{ Finds a member of a string list by position.
  @param(n The member's position, counting from 0.)
  @param(list The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Shows query and menu on the bottom line ('@' in menu starts a second line, one row up) and waits for a choice. A
  menu's options start at its digits and capitals; the current one, GDVars.horizChoice, is drawn black on the highlight
  color. A mouse click answers for the option, roster line, arena cell or 3D view cell under it. The colors go back to
  their defaults on return.
  @param(query The prompt, at the line's start.)
  @param(menu The options.)
  @param(qCol The query's color.)
  @param(mCol The menu's color.)
  @param(hlCol The highlight color: the choice characters' and the current option's background.)
  @param(reinterpret Returns '1'..'9' as the keypad keys' scan codes (GDConsts.keypadScan) and '\' as 55, as extended
    keys.)
  @param(animate Steps the portrait animation while it waits, as zone 0's picture-fade flag does.)
  @param(ext Set when the key returned is an extended scan code.)
  @returns(The key chosen, also left in GDVars.menuKey; #0 for Escape.) }
function MenuHorizontal(query: Types.TStr40; menu: Types.TStr80; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Shows list in the window ulCol, ulRow to lrCol, lrRow, with MenuHorizontal's options below it: menu, then Next and
  Prev as they apply, and Exit when addExit. The arrows move the selection, the pages and Next and Prev turn the page,
  and label members (inUse set) are skipped.
  @param(query The prompt of the options below.)
  @param(menu The options before Next, Prev and Exit.)
  @param(qCol The prompt's and the labels' color.)
  @param(mCol The members' and the options' color.)
  @param(hlCol The highlight color.)
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(list The members.)
  @param(addExit True to offer Exit.)
  @param(redraw Draws the page first; cleared on return, except when list is nil.)
  @param(idx The selected member, 0-based, in and out.)
  @param(sel The chosen member, nil when none.)
  @returns(The key that chose, #0 for Escape, Exit or an empty list.) }
function MenuVertical(query: Types.TStr40; menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                      lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;

{ Asks query with Yes and No, Yes selected first, until one is chosen.
  @returns('Y' or 'N'.)
  @param(query The prompt.)
  @param(qCol The prompt's color.)
  @param(mCol The options' color.)
  @param(hlCol The highlight color.) }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Asks query with Yes and No, No selected first, until one is chosen, then clears the bottom line.
  @returns('Y' or 'N'.)
  @param(query The prompt.)
  @param(qCol The prompt's color.)
  @param(mCol The options' color.)
  @param(hlCol The highlight color.) }
function YesNoMenuClear(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Allocates a list of empty members, as many as asked; the first is allocated before the count is read, so a count below
  1 gives one member.
  @param(n Members wanted.)
  @param(list Receives the first member.) }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Frees each member of a string list; the caller's pointer is not set to nil.
  @param(list The list's first member, or nil.) }
procedure FreeStringList(var list: Types.PItemRec);

implementation

{$L MCREMAP.OBJ}

{ Steps the three cycled colors of the VGA 3D view one place. }
procedure RemapView; external;

const
  { the last text column }
  LAST_COLUMN = 39;
  { A hotRows entry with no selectable line, and keyColLo and keyColHi with no vertical menu. }
  NO_HOT_ROW = 255;
  CLOSED_CLICK_LEFT = 127;
  CLOSED_CLICK_RIGHT = -128;
  { GDVars.horizChoice with Yes selected }
  DEFAULT_YES = 1;
  DEFAULT_NO = 2;
  { the combat view's first text column and row }
  VIEW_SCREEN_OFFSET = 1;
  { GDVars.modifyRow's rows in CharGen's modify menu beyond the six abilities }
  MODIFY_NAME_FIELD = 7;
  MODIFY_HIT_POINTS_FIELD = 6;

type
  { one horizontal-menu option: its first and last character in the menu }
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

{ Returns the direction from x1, y1 to x2, y2, 0 (north) to 7 clockwise; the diagonals take the slopes between 106/256
  and 618/256.
  @param(x1 The start column.)
  @param(y1 The start row.)
  @param(x2 The end column.)
  @param(y2 The end row.)
  @returns(The direction.) }
function DirectionBetween(x1, y1, x2, y2: Integer): Byte;
var d: Byte; isFound: Boolean; adx: Integer; ady: Integer;
begin
  adx := Abs(x2 - x1);
  ady := Abs(y2 - y1);
  d := 0;
  isFound := False;
  while not isFound do begin
    case d of
      C_Dir.NORTHEAST: isFound := (y2 < y1) and (x2 > x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.SOUTHEAST: isFound := (y2 > y1) and (x2 > x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.SOUTHWEST: isFound := (y2 > y1) and (x2 < x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.NORTHWEST: isFound := (y2 < y1) and (x2 < x1) and ((618 * adx) div 256 >= ady) and
        ((106 * adx) div 256 <= ady);
      C_Dir.NORTH: isFound := (y2 <= y1) and ((618 * adx) div 256 <= ady);
      C_Dir.EAST: isFound := (x2 >= x1) and ((106 * adx) div 256 >= ady);
      C_Dir.SOUTH: isFound := (y2 >= y1) and ((618 * adx) div 256 <= ady);
      C_Dir.WEST: isFound := (x2 <= x1) and ((106 * adx) div 256 >= ady)
    end;
    if not isFound then Inc(d)
  end;
  DirectionBetween := d
end;

function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts the members of a string list.
  @param(list The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

{ Keeps the menu's byte sum in GDVars.menuChecksum; a menu that differs from the last one starts at its first option,
  unless the checksum holds KEEP_MENU_CHOICE.
  @param(s The menu.) }
procedure TrackMenu(var s: Types.TStr80);
var
  sum: Byte;
  i: Byte;
begin
  sum := 0;
  for i := Length(s) downto 1 do
    Inc(sum, Ord(s[i]));
  if (sum <> GDVars.menuChecksum) and (GDVars.menuChecksum <> C_Menu.KEEP_MENU_CHOICE) then
    GDVars.horizChoice := 1;
  GDVars.menuChecksum := sum;
end;

function MenuHorizontal(query: Types.TStr40; menu: Types.TStr80; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
var
  frameTick: LongInt;
  { the text cell clicked; a letter key reuses mouseCol }
  mouseCol: Integer;
  mouseRow: Integer;
  { a roster line, a combat slot, a hotRows index, a menu character, the joystick's zone }
  scratch: Byte;
  isDone: Boolean;
  mLen: Byte;
  qLen: Byte;
  { opt[0].last holds the option count }
  opt: array[0..20] of TOptRange;
  walk: Types.PWork;
  buttons: Integer;
  releaseX: Integer;
  releaseY: Integer;
  hasAt: Boolean;
  displayRow: Byte;
  { the options on the first of two lines }
  spanCount: Byte;
  prevFrame: Byte;

  { Find the options in menu, each from a digit or capital, into opt, with the count in opt[0].last. }
  procedure ParseMenu;
  var
    wordIdx: Byte;
    i: Byte;
    len: Byte;
  begin
    FillChar(opt[1], SizeOf(opt) - SizeOf(TOptRange), 0);
    wordIdx := 1;
    len := Length(menu);
    for i := 1 to len do
      if menu[i] in ['0'..'9', 'A'..'Z'] then
        if opt[wordIdx].first = 0 then
          opt[wordIdx].first := i
        else begin
          opt[wordIdx].last := i - 2;
          Inc(wordIdx);
          opt[wordIdx].first := i;
        end else if menu[i] = '@' then
        spanCount := wordIdx;
    opt[wordIdx].last := len;
    opt[0].last := wordIdx;
  end;

  { Draw the menu, option cur highlighted and the choice characters in the highlight color. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
    col: Byte;
    row: Byte;
  begin
    Mouse.HideMouse;
    col := 1;
    row := displayRow;
    if mLen > 0 then
      for i := 1 to mLen do
        if menu[i] = '@' then
        begin
          Border.ClearBox(qLen + col - 1, row, MenuCore.LAST_COLUMN, row);
          Inc(row);
          col := 1;
        end else begin
          if (opt[cur].first <= i) and (opt[cur].last >= i)
             and (GDVars.highlightColor <> 0) then
            TextRend.RenderChar(qLen + col - 1, row, 0, GDVars.highlightColor, 1, Ord(menu[i]), 1)
          else if menu[i] in ['0'..'9', 'A'..'Z'] then
            TextRend.RenderChar(qLen + col - 1, row, GDVars.highlightColor, 0, 1, Ord(menu[i]), 1)
          else
            TextRend.RenderChar(qLen + col - 1, row, GDVars.menuColor, 0, 1, Ord(menu[i]), 1);
          Inc(col);
        end;
    if qLen + col - 1 <= MenuCore.LAST_COLUMN then
      Border.ClearBox(qLen + col - 1, row, MenuCore.LAST_COLUMN, row);
    Mouse.ShowMouse;
  end;

  { Answers with the current option's key (Enter for an empty one) and finishes. }
  procedure AcceptCurrent;
  begin
    GDVars.extFlag := False;
    GDVars.menuKey := menu[opt[GDVars.horizChoice].first];
    if GDVars.menuKey = C_Keys.NONE then
      GDVars.menuKey := C_Keys.ENTER;
    isDone := True;
  end;

  { Whether the click is on the party roster where the roster may be clicked. }
  function PartyClick: Boolean;
  begin
    PartyClick := (GDVars.canClickParty <> 0)
      and (GDVars.interfaceState in [C_Ifc.MAIN_MENU, C_Ifc.SHOP_TEMPLE, C_Ifc.CAMPING, C_Ifc.EXPLORING,
                                       C_Ifc.LOOT, C_Ifc.IN_VAULT])
      and (GDVars.rosterLeft <= mouseCol) and (GDVars.rosterRight >= mouseCol)
      and (GDVars.rosterTop <= mouseRow) and (GDVars.rosterBottom >= mouseRow);
  end;

  { Select the roster line clicked, or view the current character when it is clicked again. }
  procedure HandlePartyClick;
  var
    i: Byte;
    old: Types.PWork;
  begin
    if GDVars.bigPicId <> C_Pic.NO_BIG_PICTURE then Exit;
    old := GDVars.curChar;
    scratch := mouseRow - GDVars.rosterTop;
    walk := GDVars.creatureList;
    for i := 1 to scratch do
      if walk <> nil then
        walk := walk^.next;
    if walk = nil then Exit;
    isDone := True;
    if GDVars.orderState <> 0 then
      GDVars.orderChar := walk
    else begin
      if GDVars.curChar = walk then begin
        if GDVars.interfaceState = C_Ifc.EXPLORING then begin
          GDVars.extFlag := False;
          GDVars.menuKey := 'V';
          GDVars.partyClickMode := 0;
          isDone := True;
        end else if (((GDVars.interfaceState <> C_Ifc.EXPLORING) or (GDVars.partyClickMode = 0)) and
                     GDConsts.canClickToView) then begin
          GDVars.extFlag := False;
          GDVars.menuKey := 'V';
          isDone := True;
        end;
      end else begin
        GDVars.priorChar := GDVars.curChar;
        GDVars.curChar := walk;
      end;
    end;
    Mouse.HideMouse;
    GDVars.displayPartyProc(GDVars.curChar);
    Mouse.ShowMouse;
    GameIo.WaitMouseRelease;
    if (GDVars.interfaceState = C_Ifc.MAIN_MENU) and GDVars.verticalMenuActive then begin
      GDVars.menuKey := C_Keys.ENTER;
      GDVars.extFlag := False;
      isDone := False;
      if walk = old then begin
        GDVars.partyRepeat := 1;
        AcceptCurrent;
        GDVars.isMouseClick := False;
      end;
    end;
  end;

  { Tells whether a click is on the combat map view while moving or aiming. }
  function ArenaClick: Boolean;
  begin
    ArenaClick := ((GDVars.arenaMoveActive <> 0) or (GDVars.manualAimActive <> 0))
      and (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseRow <= 21);
  end;

  { Put the arena cell clicked in GDVars.arenaMouseX and arenaMouseY, noting a cell outside the inner ones. }
  procedure PrepareArenaClick;
  var
    x: ShortInt;
    y: ShortInt;
  begin
    x := (mouseCol - MenuCore.VIEW_SCREEN_OFFSET) div 3;
    y := (mouseRow - MenuCore.VIEW_SCREEN_OFFSET) div 3;
    GDVars.arenaMouseX := x + GDVars.combatArenaPtr^.ox;
    GDVars.arenaMouseY := y + GDVars.combatArenaPtr^.oy;
    if (x >= 1) and (x <= 5) and (y >= 1) and (y <= 5) then
      GDConsts.isArenaClickOutside := False
    else
      GDConsts.isArenaClickOutside := True;
  end;

  { Answer a click on the arena: accept, move the aim cursor, or the direction key toward the cell. }
  procedure HandleArenaClick;
  var
    x: ShortInt;
    y: ShortInt;
  begin
    isDone := True;
    GDVars.extFlag := True;
    if GDVars.manualAimActive <> 0 then begin
      releaseX := GDVars.arenaMouseX - GDVars.combatArenaPtr^.ox;
      releaseY := GDVars.arenaMouseY - GDVars.combatArenaPtr^.oy;
    end else begin
      scratch := CbtMap.CombatSlot(GDVars.curChar);
      releaseX := GDVars.combatArenaLocation[scratch].x - GDVars.combatArenaPtr^.ox;
      releaseY := GDVars.combatArenaLocation[scratch].y - GDVars.combatArenaPtr^.oy;
    end;
    x := (mouseCol + 2) div 3 - 1;
    y := (mouseRow + 2) div 3 - 1;
    if (x = releaseX) and (y = releaseY) then
      AcceptCurrent
    else if (GDVars.manualAimActive <> 0) and (x >= 0) and (x <= 6)
            and (y >= 0) and (y <= 6) then begin
      CbtMap.RedrawArenaCell(GDVars.arenaMouseX, GDVars.arenaMouseY);
      PrepareArenaClick;
      if GDConsts.isArenaClickOutside then
        GDVars.menuKey := '5'
      else
        GDVars.menuKey := '!';
    end else
      GDVars.menuKey := GDConsts.directionKeys[MenuCore.DirectionBetween(releaseX, releaseY, x, y)];
  end;

  { A click on the 3D view: its whole 15 by 15 cells outdoors or with the automap up, else its inner 3..13. }
  function ViewAreaClick: Boolean;
  begin
    ViewAreaClick := False;
    if GDVars.interfaceState = C_Ifc.EXPLORING then
      if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) or GDVars.automapOn then
        ViewAreaClick := (mouseCol >= 1) and (mouseCol <= 15)
          and (mouseRow >= 1) and (mouseRow <= 15)
      else
        ViewAreaClick := (mouseCol >= 3) and (mouseCol <= 13)
          and (mouseRow >= 3) and (mouseRow <= 13);
  end;

  { The distance between two bytes. }
  function ByteDistance(a, b: Byte): Byte;
  begin
    if a >= b then ByteDistance := a - b
    else ByteDistance := b - a;
  end;

  { The facing from the party's cell toward the cell clicked, along the longer axis. }
  function ClickDirection: Byte;
  var
    dir: Byte;
    { Unused in this version; see the other implementations of this routine. }
    clickedNode: Pointer;
  begin
    if (GDVars.partyScreenX = mouseCol) and (GDVars.partyScreenY = mouseRow) then
      dir := GDVars.partyPos.facing
    else
      if ByteDistance(mouseRow, GDVars.partyScreenY) >= ByteDistance(mouseCol, GDVars.partyScreenX) then
        if GDVars.partyScreenY < mouseRow then dir := C_Dir.SOUTH else dir := C_Dir.NORTH
      else if GDVars.partyScreenX < mouseCol then dir := C_Dir.EAST else dir := C_Dir.WEST;
    ClickDirection := dir;
  end;

  { Answer a click on the 3D view with an arrow key. }
  procedure HandleViewAreaClick;
  var dir: Byte;
  begin
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) or GDVars.automapOn then begin
      dir := ClickDirection + 8 - GDVars.partyPos.facing;
      while dir >= 8 do Dec(dir, 8);
      case dir of
        0: GDVars.menuKey := C_Keys.UP;
        2: GDVars.menuKey := C_Keys.RIGHT;
        4: GDVars.menuKey := C_Keys.DOWN;
        6: GDVars.menuKey := C_Keys.LEFT;
      end;
      GDVars.extFlag := True;
      GDVars.partyClickMode := 1;
      isDone := True;
    end else begin
      GDVars.extFlag := True;
      GDVars.menuKey := Char(GDConsts.vectorScan[mouseRow, mouseCol]);
      GDVars.partyClickMode := 1;
      isDone := True;
    end;
  end;

  { Tells whether the click is on the menu's rows or below them. }
  function MenuRowClick: Boolean;
  begin
    MenuRowClick := displayRow <= mouseRow;
  end;

  { Answer with the option clicked on the menu's rows. }
  procedure HandleMenuRowClick;
  var i: Byte;
  begin
    Inc(mouseCol);
    if qLen < mouseCol then begin
      mouseCol := mouseCol - qLen;
      if hasAt then
        if displayRow < mouseRow then
          Inc(mouseCol, Pos('@', menu))
        else if Pos('@', menu) <= mouseCol then
          Exit;
      for i := 1 to opt[0].last do
        if (opt[i].first <= mouseCol) and (opt[i].last >= mouseCol) then begin
          GDVars.menuKey := menu[opt[i].first];
          GDVars.horizChoice := i;
          DisplayOption(GDVars.horizChoice);
          isDone := True;
        end;
    end;
  end;

  { Answer '!' for a click in the side panel, and ignore any other click. }
  procedure SpecialClick;
  begin
    if (mouseRow >= 4) and (mouseRow < 22) and (mouseCol >= 19) and (mouseCol < 37) then begin
      GDVars.menuKey := '!';
      isDone := True;
    end else begin
      GDVars.isMouseClick := False;
      GDVars.menuKey := C_Keys.NONE;
      isDone := False;
    end;
    GDVars.extFlag := False;
  end;

  { A click in CharGen's modify menu picks the row: the name, the hit points or an ability. }
  procedure HandleModifyClick;
  begin
    isDone := True;
    case mouseRow of
      1: if (mouseCol >= 1) and (mouseCol <= 17) then GDVars.modifyRow := MenuCore.MODIFY_NAME_FIELD;
      3: if (mouseCol >= 32) and (mouseCol <= 34) then GDVars.modifyRow := MenuCore.MODIFY_HIT_POINTS_FIELD;
      9..14: if (mouseCol >= 5) and (mouseCol <= 10) then
               GDVars.modifyRow := mouseRow - 9;
    else
      isDone := False;
    end;
    GDVars.isMouseClick := False;
    GDVars.extFlag := True;
  end;

  { Accepts the current option for a click in a vertical menu's columns at or below a selectable line. }
  procedure HandleHotspotClick;
  begin
    if isDone then Exit;
    if (GDVars.keyColLo <= mouseCol) and (GDVars.keyColHi >= mouseCol) then begin
      scratch := 1;
      while (scratch <= 25) and not isDone do begin
        if (GDVars.hotRows[scratch] <= mouseRow) and (GDVars.hotRows[scratch] <> MenuCore.NO_HOT_ROW) then begin
          isDone := True;
          GDVars.menuKey := menu[opt[GDVars.horizChoice].first];
        end;
        Inc(scratch);
      end;
    end;
  end;

  { Highlights the previous option, wrapping to the last. }
  procedure MoveLeft;
  begin
    if GDVars.horizChoice = 1 then GDVars.horizChoice := opt[0].last
    else Dec(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

  { Highlights the next option, wrapping to the first. }
  procedure MoveRight;
  begin
    if GDVars.horizChoice = opt[0].last then GDVars.horizChoice := 1
    else Inc(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

  { Moves to the other line of a two-line menu, clamped to its options. }
  procedure MoveVertical;
  begin
    if GDVars.horizChoice <= spanCount then begin
      Inc(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > opt[0].last then
        GDVars.horizChoice := opt[0].last;
    end else begin
      Dec(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > spanCount then
        GDVars.horizChoice := spanCount;
    end;
    DisplayOption(GDVars.horizChoice);
    isDone := False;
  end;

begin
  GDVars.queryColor := qCol;
  GDVars.highlightColor := hlCol;
  GDVars.menuColor := mCol;
  if Pos('@', menu) > 0 then begin hasAt := True; displayRow := C_Screen.STATUS_ROW - 1 end
  else begin hasAt := False; displayRow := C_Screen.STATUS_ROW end;
  GDVars.extFlag := False;
  { stored and never read }
  opt[0].first := Ord((GDVars.menuColor <> 0) or (GDVars.highlightColor <> 0));
  qLen := Length(query) + 0;
  ParseMenu;
  MenuCore.TrackMenu(menu);
  if (GDVars.horizChoice > opt[0].last) or (GDVars.horizChoice = 0) then
    GDVars.horizChoice := 1;
  mLen := Length(menu);
  GDVars.menuKey := C_Keys.NONE;
  isDone := False;
  frameTick := TextRend.GetTicks;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, displayRow, GDVars.queryColor, Black, query);
  DisplayOption(GDVars.horizChoice);
  Mouse.ShowMouse;
  prevFrame := 255;
  GameIo.WaitMouseRelease;
  repeat
    if ((GDVars.gbvmZone0Ptr^[C_Gbvm.PICTURE_FADE] <> 0) or animate) and (GDVars.animationData.current > 0) then begin
      if GDVars.animationData.current <> prevFrame then begin
        Mouse.HideMouse;
        Portrait.DisplayImageBuf(3, 3, animate, GDVars.animationData.frames[GDVars.animationData.current].pic);
        Mouse.ShowMouse;
        prevFrame := GDVars.animationData.current;
      end;
      if (TextRend.GetTicks - frameTick >= GDVars.animationData.frames[GDVars.animationData.current].delay * 10)
         or (GDVars.gbvmZone0Ptr^[C_Gbvm.PICTURE_FADE] <> 0) then begin
        Inc(GDVars.animationData.current);
        if GDVars.animationData.current > GDVars.animationData.count then GDVars.animationData.current := 1;
        frameTick := TextRend.GetTicks;
      end;
      GDVars.remapPending := 0;
    end;
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0) or
        (GDVars.interfaceState <> C_Ifc.EXPLORING) then GDVars.remapPending := 0;
    if (GDVars.remapPending <> 0) and (TextRend.GetTicks - frameTick > 25) then begin
      MenuCore.RemapView;
      frameTick := TextRend.GetTicks;
    end;
    if (GDVars.menuTimeout > 0) and (TextRend.GetTicks - frameTick >= GDVars.menuTimeout) then begin
      GDVars.menuKey := GDVars.menuDefaultKey;
      isDone := True;
    end;
    if GameIo.InputPending then begin
      GDVars.menuKey := GameIo.ReadGameKey;
      if GDVars.isMouseClick then begin
        mouseRow := GDVars.mouseY div 8;
        mouseCol := GDVars.mouseX div 8;
      end;
      if GDVars.menuKey = #0 then begin
        GDVars.menuKey := GameIo.ReadGameKey;
        GDVars.extFlag := True;
        isDone := True;
        if opt[0].last > 1 then
          case GDVars.menuKey of
            C_Keys.LEFT: MoveLeft;
            C_Keys.RIGHT: MoveRight;
            C_Keys.UP, C_Keys.DOWN: if hasAt then MoveVertical;
          end;
      end else begin
        GDVars.extFlag := False;
        case GDVars.menuKey of
          C_Keys.ESCAPE:
            if GDVars.isMouseClick and (GDVars.clickPending <> 0) then
              HandleModifyClick
            else begin isDone := True; GDVars.menuKey := C_Keys.NONE end;
          C_Keys.ENTER: if GDVars.isMouseClick then begin
                 if GDConsts.isEclMenuActive and (opt[0].last = 1) then begin
                   isDone := True;
                   GDVars.menuKey := C_Keys.ENTER;
                 end else if MenuRowClick then HandleMenuRowClick
                 else if GDVars.verticalMenuActive then HandleHotspotClick
                 else if (GDVars.combatMouseMode <> 0) and (mouseRow <= 22) then
                   SpecialClick
                 else if PartyClick then HandlePartyClick
                 else if ArenaClick then HandleArenaClick
                 else if ViewAreaClick then HandleViewAreaClick
                 else if GDVars.clickPending <> 0 then HandleModifyClick
                 else if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (mouseRow <= 22) then begin
                   if GDVars.joyClickA <> 0 then begin
                     GDConsts.isArenaClickPending := True;
                     PrepareArenaClick;
                     GDVars.menuKey := 'A';
                     isDone := True;
                   end else if GDVars.joyClickB <> 0 then begin
                     GDConsts.isArenaClickPending := True;
                     PrepareArenaClick;
                     GDVars.menuKey := 'M';
                     isDone := True;
                   end;
                 end else if opt[0].last > 1 then GDVars.menuKey := C_Keys.NONE
                 else isDone := True;
               end else AcceptCurrent;
        else begin
          GDVars.menuKey := UpCase(GDVars.menuKey);
          if GDVars.menuKey in [' ', '0'..'9', 'A'..'Z'] then
            if GDVars.menuKey = ' ' then
              isDone := True
            else
              for scratch := 1 to mLen do
                if menu[scratch] = GDVars.menuKey then begin
                  isDone := True;
                  mouseCol := 1;
                  while scratch <> opt[mouseCol].first do Inc(mouseCol);
                  GDVars.horizChoice := mouseCol;
                  DisplayOption(GDVars.horizChoice);
                end;
        end;
        if not isDone and (opt[0].last > 1) then
          if GDVars.menuKey = '4' then MoveLeft
          else if GDVars.menuKey = '6' then MoveRight
          else if (GDVars.menuKey in ['2', '8', 'H', 'P']) and hasAt then MoveVertical;
        if reinterpret then
          if GDVars.menuKey in ['1'..'9', '\'] then
          begin
            if GDVars.menuKey = '\' then
              GDVars.menuKey := #55
            else
              GDVars.menuKey := Char(GDConsts.keypadScan[Ord(GDVars.menuKey) - Ord('1')]);
            GDVars.extFlag := True;
            isDone := True;
          end;
        end;
      end;
    end;
  until isDone;
  GDVars.queryColor := LightMagenta;
  GDVars.highlightColor := White;
  GDVars.menuColor := LightGreen;
  GameIo.DrainKeys;
  if GDVars.isJoystickOn then
    repeat Joystick.GetJoystick(buttons, scratch) until buttons = 0;
  ext := GDVars.extFlag;
  MenuHorizontal := GDVars.menuKey;
  Mouse.HideMouse;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, MenuCore.LAST_COLUMN + 1);
end;

function MenuVertical(query: Types.TStr40; menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                      lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;
var
  width: Byte;
  line: Byte;
  count: Integer;
  rows: Integer;
  prevCh: Char;
  hMenu: Types.TStr40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItemRec;
  headerCnt: Integer;
  total: Integer;
  mouseCellCol: Byte;
  mouseCellRow: Byte;

  { Returns the last label member among the first n, else the first member when it is a label. }
  function LastLabelBefore(n: Integer; l: Types.PItemRec): Types.PItemRec;
  var
    pp: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Draw the members from top, recording each selectable line's row in GDVars.hotRows. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItemRec;
    row: ShortInt;
  begin
    FillChar(GDVars.hotRows, SizeOf(GDVars.hotRows), MenuCore.NO_HOT_ROW);
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    line := 1;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, GDVars.queryColor, Black, pp^.name)
      else begin
        GDVars.hotRows[line] := row;
        TextRend.DisplayString(ulCol, row, GDVars.menuColor, Black, pp^.name);
      end;
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, 0, width - Length(pp^.name), Ord(' '), 1);
      pp := pp^.next;
      Inc(row);
      Inc(line);
    end;
    Mouse.ShowMouse;
  end;

  { Returns the position of the first non-space character of s (its length when all spaces, 1 when empty). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Returns the position of the last non-space character of s (1 when all spaces, 0 when empty). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraws member n, trimmed, black on the highlight color. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), Black, GDVars.highlightColor,
                           Copy(pp^.name, a, b));
  end;

  { Redraws member n, trimmed, in its resting color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.queryColor, Black,
                             Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.menuColor, Black,
                             Copy(pp^.name, a, b));
  end;

  { Steps the selection off label members, wrapping within the page. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows) and
          ((MenuCore.FindListMember(idx, list) = nil) or (MenuCore.FindListMember(idx, list)^.inUse <> 0)) do begin
        Inc(k);
        Inc(idx);
        if GDVars.vertTop + rows - 1 < idx then
          idx := GDVars.vertTop;
        if count - 1 < idx then
          idx := GDVars.vertTop;
      end;
    end else
      while (k < rows) and
          ((MenuCore.FindListMember(idx, list) = nil) or (MenuCore.FindListMember(idx, list)^.inUse <> 0)) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.vertTop then
          idx := GDVars.vertTop + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
      end;
  end;

  { Scroll a page down or up, clamped to the list, keep the cursor's row on the page and redraw it. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.vertTop;
    if down then begin
      Inc(GDVars.vertTop, rows);
      if count - rows < GDVars.vertTop then
        GDVars.vertTop := count - rows;
    end else begin
      Dec(GDVars.vertTop, rows);
      if GDVars.vertTop < 0 then
        GDVars.vertTop := 0;
    end;
    idx := GDVars.vertTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertTop);
  end;

  { Move the cursor one line, wrapping within the visible page and clamped to the list, then skip label rows. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.vertTop + rows - 1 < idx then
        idx := GDVars.vertTop;
      if count - 1 < idx then
        idx := GDVars.vertTop;
    end else begin
      Dec(idx);
      if idx < GDVars.vertTop then
        idx := GDVars.vertTop + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    GDVars.keyColLo := MenuCore.CLOSED_CLICK_LEFT;
    GDVars.keyColHi := MenuCore.CLOSED_CLICK_RIGHT;
    MenuVertical := C_Keys.NONE;
    Exit;
  end;
  prevCh := 'N';
  GDVars.keyColLo := ulCol;
  GDVars.keyColHi := lrCol;
  width := lrCol - ulCol + 1;
  count := MenuCore.ListCount(list);
  rows := lrRow - ulRow + 1;
  p := list;
  headerCnt := 0;
  while (p <> nil) and (p^.inUse <> 0) do begin
    p := p^.next;
    Inc(headerCnt);
  end;
  p := list;
  total := 0;
  while p <> nil do begin
    p := p^.next;
    Inc(total);
  end;
  if total <= rows then GDVars.vertTop := 0;
  if GDVars.vertTop > idx then begin
    GDVars.vertTop := idx;
    redraw := True;
  end;
  if GDVars.vertTop > total then begin
    GDVars.vertTop := 0;
    redraw := True;
  end;
  Inc(idx);
  MoveLine(False);
  if redraw then DrawPage(GDVars.vertTop);
  redraw := False;
  repeat
    HighlightLine(idx);
    hMenu := menu;
    hasNext := False;
    hasPrev := False;
    if count - rows > GDVars.vertTop then begin
      hMenu := hMenu + ' Next';
      hasNext := True;
    end;
    if GDVars.vertTop > headerCnt then begin
      hMenu := hMenu + ' Prev';
      hasPrev := True;
    end;
    if addExit then hMenu := hMenu + ' Exit';
    GDVars.verticalMenuActive := True;
    GDVars.menuKey := MenuCore.MenuHorizontal(query, hMenu, qCol, mCol, hlCol, True, False, GDVars.extFlag);
    GDVars.verticalMenuActive := False;
    UnhighlightLine(idx);
    mouseCellRow := GDVars.mouseY div 8;
    mouseCellCol := GDVars.mouseX div 8;
    if GDVars.extFlag then
      case GDVars.menuKey of
        C_Keys.UP: MoveLine(False);
        C_Keys.DOWN: MoveLine(True);
        C_Keys.PAGE_UP: if hasPrev then MovePage(False);
        C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
      end else
      case GDVars.menuKey of
        'P': if not GDVars.isMouseClick or
          (GDVars.isMouseClick and (mouseCellRow = C_Screen.STATUS_ROW)) then MovePage(False);
        'N': if not GDVars.isMouseClick or
          (GDVars.isMouseClick and (mouseCellRow = C_Screen.STATUS_ROW)) then MovePage(True);
        C_Keys.ESCAPE, 'E', C_Keys.NONE:
          begin
            sel := nil;
            MenuVertical := C_Keys.NONE;
            GDVars.keyColLo := MenuCore.CLOSED_CLICK_LEFT;
            GDVars.keyColHi := MenuCore.CLOSED_CLICK_RIGHT;
            Exit;
          end;
      else
        if GDVars.isMouseClick and (mouseCellRow <> C_Screen.STATUS_ROW) then begin
          if (mouseCellCol >= GDVars.keyColLo) and (mouseCellCol <= GDVars.keyColHi) then begin
            line := 1;
            while line <= 25 do begin
              if GDVars.hotRows[line] = mouseCellRow then
                if line - 1 + GDVars.vertTop = idx then begin
                  sel := MenuCore.FindListMember(idx, list);
                  MenuVertical := GDVars.menuKey;
                  Exit;
                end else begin
                  UnhighlightLine(idx);
                  idx := line - 1 + GDVars.vertTop;
                  HighlightLine(idx);
                end;
              Inc(line);
            end;
          end;
        end else if not GDVars.isMouseClick or (GDVars.isMouseClick and (prevCh = GDVars.menuKey)) then begin
          sel := MenuCore.FindListMember(idx, list);
          MenuVertical := GDVars.menuKey;
          GDVars.keyColLo := MenuCore.CLOSED_CLICK_LEFT;
          GDVars.keyColHi := MenuCore.CLOSED_CLICK_RIGHT;
          Exit;
        end;
      end;
    prevCh := GDVars.menuKey;
  until False;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  {$V-} MenuCore.TrackMenu(GDConsts.yesNoText); {$V+}
  GDVars.horizChoice := MenuCore.DEFAULT_YES;
  repeat
    ch := MenuCore.MenuHorizontal(query, GDConsts.yesNoText, qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

function YesNoMenuClear(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  {$V-} MenuCore.TrackMenu(GDConsts.yesNoText); {$V+}
  GDVars.horizChoice := MenuCore.DEFAULT_NO;
  repeat
    ch := MenuCore.MenuHorizontal(query, GDConsts.yesNoText, qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  MenuCore.ClearBottomLine;
  YesNoMenuClear := ch;
end;

procedure AllocStringList(n: Integer; var list: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TItemNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TItemNode));
  end;
end;

begin
end.
