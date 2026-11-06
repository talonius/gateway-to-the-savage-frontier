{ The combat map. The arena is 50 by 25 cells of terrain ids (Types.TArena, at GDVars.combatArenaPtr); the view shows 7
  by 7 of them from the arena's ox, oy. BuildArenaArrays enters every combatant's icon cells in
  GDVars.combatArenaCreature and its view offset in creatureXCoordinate/YCoordinate; ScrollView recenters the view,
  redraws the visible icons and the cursor; SetCreatureFacing turns an icon; CreatureDowned flashes the skull, leaves a
  corpse and takes the creature out of play; IsValidCreatureLoc places a creature. ProbeDirection reports what lies one
  step away, CountTeams counts each side's combatants, and the two palette routines switch color 8 between combat and
  the rest of the game. SetCreatureFacing and DisplayMapViewCentered draw only while GDVars.combatMapVisible is set.
  CbtMap owns no storage. }
{$O+,F+}
{$A+}{$R-}{$S+}
unit CbtMap;

interface

uses Types, C_Dir, C_Ifc, C_Npc, C_Terr, C_Video, GDConsts, GDVars, Raster, Blit, TextRend, Crt, MapTiles,
  SoundDrv, C_Gbvm;

{ Find an icon cell's offset from the icon's own cell.
  @param(size The icon size; only its low three bits count.)
  @param(idx The icon cell, 0..3.)
  @param(dx Receives the column offset.)
  @param(dy Receives the row offset.)
  @returns(False for size 0 or above 4, or a cell the icon does not use.) }
function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;

{ In an underwater zone, turn color 8 (dark gray) blue for combat, through the EGA or Tandy palette register or the VGA
  palette. }
procedure SetCombatPalette;

{ In an underwater zone, return color 8 to dark gray after combat, through the EGA or Tandy palette register or the VGA
  palette. }
procedure SetNoncombatPalette;

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds the arena's creature-index grid: clears it, then for each creature with a nonzero icon size marks every cell
  its icon covers with the creature's combat slot and recomputes the creature's view coordinates. }
procedure BuildArenaArrays;

{ Return the creature index and terrain id at an arena cell; both are 0 outside the arena.
  @param(x Arena column.)
  @param(y Arena row.)
  @param(crIdx Receives the creature index there, 0 for none.)
  @param(terrIdx Receives the terrain id.) }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(crIdx The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(cr The creature.)
  @param(whole Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(cr: Types.PWork; whole: Byte): Boolean;

{ Targets the arena cell one step in the given direction from a cell and redraws the whole view if needed
  (BuildViewBuffer), redrawing each visible icon of a creature in play after a full redraw. Then redraws the cell, draws
  the cursor at the target (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(delta How far the target may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(dir Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; delta, dir: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or `frame` or
  `eraseOnly` is nonzero. It stores the new facing and, unless `eraseOnly` is set, draws its sprite and flushes when it
  is visible and the map shows.
  @param(cr The creature.)
  @param(dir The new facing, 0 to 7.)
  @param(frame The animation frame to draw.)
  @param(eraseOnly Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(cr: Types.PWork; dir, frame, eraseOnly: Byte);

{ Finds a creature's arena column.
  @param(cr The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(cr: Types.PWork): ShortInt;

{ Finds a creature's arena row.
  @param(cr The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(cr: Types.PWork): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(cr The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(cr: Types.PWork): Byte;

{ Finds a combatant's combat slot. Note: with no combatants, or more than 72, the search runs past the end of the table.
  @param(cr The combatant.)
  @returns(The slot, or 0 if it is not in the fight.) }
function CombatSlot(cr: Types.PWork): Byte;

{ Probes the cells one step in the given direction from each of the creature's icon tiles.
  @param(cr The creature.)
  @param(dir The direction, 0 to 7; 8 probes the creature's own cells.)
  @param(crIdx Receives an adjacent creature's combat slot (0 for none); the creature itself is ignored and the last one
    found wins.)
  @param(terrIdx Receives the dominant terrain: 0 (off the arena) beats everything, otherwise the highest cost wins (the
    later tile on a tie), starting from terrain 23 at cost 1. Stinking clouds and cloudkill do not compete, and once it
    is 0 later cells set no cloud flags.)
  @param(hasStinkCloud Receives 1 when a probed cell holds a stinking cloud, else 0.)
  @param(hasCloudkill Receives 1 when a probed cell holds cloudkill, else 0.) }
procedure ProbeDirection(cr: Types.PWork; dir: Byte; var crIdx, terrIdx, hasStinkCloud, hasCloudkill: Byte);

{ Outside combat, play sound 5 and pause. In combat, unless the creature already lies among the downed, flash the skull
  over its icon, leave a corpse under a party creature (saving the terrain), take it out of play and clear its
  initiative, movement, spell and guard; when the last enemy falls in combat mode 1, say the party may leave. Note: the
  downed-list check reads the entry of an unset index, not of its loop counter.
  @param(cr The creature put down.) }
procedure CreatureDowned(cr: Types.PWork);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell, probes its own cells and rejects the place, zeroing the icon size, on any creature, terrain 0 or impassable
  terrain. On success with `moving` set, for a party member it clears the creature's body entries and, unless another
  body lies on the cell, writes into it the terrain its last body covered, or the probed terrain when it has no body
  entry or the body covered a corpse cell. The creature grid is then refilled.
  @param(cr The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(moving True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(cr: Types.PWork; x, y: Byte; moving: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView toward its own cell) when the combat map shows, drawing the cursor over
  its icon footprint when `cursor` is set; afterwards the cursor is off with size 1.
  @param(cr The creature.)
  @param(delta How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(cursor True to draw the cursor.) }
procedure DisplayMapViewCentered(cr: Types.PWork; delta: Byte; cursor: Boolean);

{ Count each side's enabled combatants in GDVars.teamCount, and the party's enabled members that are not NPCs in
  GDVars.eligibleCount. }
procedure CountTeams;

implementation

const
  { the GDVars.iconAnimation slot of the skull }
  DOWNED_ANIMATION = 24;
  { the GDVars.iconAnimation slot of the cursor }
  CURSOR_ANIMATION_INDEX = 25;

procedure CountTeams;
var
  p: Types.PWork;
begin
  GDVars.eligibleCount := 0;
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.enabled <> 0 then begin
      Inc(GDVars.teamCount[p^.hostile]);
      { a party member, not an NPC }
      if (p^.hostile = 0) and (p^.npc <= C_Npc.MORALE_MASK) then
        Inc(GDVars.eligibleCount);
    end;
    p := p^.next;
  end;
end;

function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  size := size and 7;
  if (size = 0) or (size > 4) then Exit;
  dx := GDConsts.iconDelta[size, idx].dx;
  dy := GDConsts.iconDelta[size, idx].dy;
  if dx >= 0 then
    GetIconTileDelta := True;
end;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaScanLimit do begin
    GDVars.creatureXCoordinate[i] := GDVars.combatArenaLocation[i].x - GDVars.combatArenaPtr^.ox;
    GDVars.creatureYCoordinate[i] := GDVars.combatArenaLocation[i].y - GDVars.combatArenaPtr^.oy;
  end;
end;

procedure SetCombatPalette;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0 then Exit;
  case GDVars.displayMode of
    C_Video.VM_EGA: Blit.SetPaletteRegister(DarkGray, Blue);
    C_Video.VM_TANDY: Blit.SetPaletteRegisterTandy(DarkGray, Blue);
    C_Video.VM_VGA: Raster.SetPaletteEntry(DarkGray, 0, 0, 41);
  end;
end;

procedure SetNoncombatPalette;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0 then Exit;
  case GDVars.displayMode of
    C_Video.VM_EGA: Blit.SetPaletteRegister(DarkGray, DarkGray);
    C_Video.VM_TANDY: Blit.SetPaletteRegisterTandy(DarkGray, DarkGray);
    C_Video.VM_VGA: Raster.SetPaletteEntry(DarkGray, 21, 21, 21);
  end;
end;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure DrawCursorCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  cellCr: Byte;
  cellTerr: Byte;
begin
  relX := x - GDVars.combatArenaPtr^.ox;
  relY := y - GDVars.combatArenaPtr^.oy;
  for i := 0 to 3 do
    if CbtMap.GetIconTileDelta(GDVars.combatArenaPtr^.cursorSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        MapTiles.Copy2DTile((relX + tdx) * 3, (relY + tdy) * 3,
                            GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[y + tdy, x + tdx]].tileId, 0);
        if GDVars.combatArenaPtr^.cursorOn then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, CbtMap.CURSOR_ANIMATION_INDEX);
      end;
  CbtMap.GetArenaContents(x, y, cellCr, cellTerr);
  if cellCr > 0 then
    if CbtMap.CombatIconVisible(GDVars.creaturePtr[cellCr], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.creatureXCoordinate[cellCr], GDVars.creatureYCoordinate[cellCr],
                                  Types.PWork(GDVars.creaturePtr[cellCr])^.combatAddr^.direction, 0,
                                  Types.PWork(GDVars.creaturePtr[cellCr])^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  cellCr: Byte;
  cellTerr: Byte;
begin
  relX := x - GDVars.combatArenaPtr^.ox;
  relY := y - GDVars.combatArenaPtr^.oy;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  CbtMap.GetArenaContents(x, y, cellCr, cellTerr);
  if cellCr > 0 then
    if CbtMap.CombatIconVisible(GDVars.creaturePtr[cellCr], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.creatureXCoordinate[cellCr], GDVars.creatureYCoordinate[cellCr],
                                  Types.PWork(GDVars.creaturePtr[cellCr])^.combatAddr^.direction, 0,
                                  Types.PWork(GDVars.creaturePtr[cellCr])^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  FillChar(GDVars.combatArenaCreature, SizeOf(GDVars.combatArenaCreature), 0);
  for i := 1 to GDVars.arenaScanLimit do
    if GDVars.combatArenaLocation[i].size > 0 then begin
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.combatArenaLocation[i].size, j, tdx, tdy) then
          GDVars.combatArenaCreature[GDVars.combatArenaLocation[i].y + tdy,
                                       GDVars.combatArenaLocation[i].x + tdx] := i;
      GDVars.creatureXCoordinate[i] := GDVars.combatArenaLocation[i].x - GDVars.combatArenaPtr^.ox;
      GDVars.creatureYCoordinate[i] := GDVars.combatArenaLocation[i].y - GDVars.combatArenaPtr^.oy;
    end;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if (x >= 0) and (x <= SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and (y >= 0) and
      (y <= SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then begin
    terrIdx := GDVars.combatArenaPtr^.cells[y, x];
    crIdx := GDVars.combatArenaCreature[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);
var
  absX: ShortInt;
  absY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  cellTerr: Byte;
  size: Byte;
begin
  if crIdx = 0 then begin
    absX := x + GDVars.combatArenaPtr^.ox;
    absY := y + GDVars.combatArenaPtr^.oy;
    CbtMap.GetArenaContents(absX, absY, crIdx, cellTerr);
  end;
  if crIdx > 0 then begin
    x := GDVars.creatureXCoordinate[crIdx];
    y := GDVars.creatureYCoordinate[crIdx];
    absX := x + GDVars.combatArenaPtr^.ox;
    absY := y + GDVars.combatArenaPtr^.oy;
    size := GDVars.combatArenaLocation[crIdx].size;
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          MapTiles.Copy2DTile((x + tdx) * 3, (y + tdy) * 3,
                              GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[absY + tdy, absX + tdx]].tileId, 0);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[absY, absX]].tileId, 0);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(cr: Types.PWork; whole: Byte): Boolean;
var
  i: Byte;
  slot: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  slot := CbtMap.CombatSlot(cr);
  if GDVars.combatArenaLocation[slot].size = 0 then
    CombatIconVisible := False
  else
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(GDVars.combatArenaLocation[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(GDVars.creatureXCoordinate[slot] + tdx,
                                      GDVars.creatureYCoordinate[slot] + tdy) then begin
          CombatIconVisible := False;
          if whole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if whole = 0 then Exit;
        end;
end;

{ Recenters the 7x7 view on a target cell when it lies farther from the view center than allowed, keeping the view
  inside the arena, then draws the view's terrain and recomputes the creatures' view coordinates.
  @param(x Arena column of the target.)
  @param(y Arena row of the target.)
  @param(delta How far the target may lie from the view center; 255 forces a redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  margin: Byte;
  pixX: ShortInt;
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
begin
  BuildViewBuffer := False;
  cX := GDVars.combatArenaPtr^.ox + 3;
  cY := GDVars.combatArenaPtr^.oy + 3;
  margin := delta;
  if delta = 255 then
    margin := 0;
  minX := cX - margin;
  maxX := cX + margin;
  minY := cY - margin;
  maxY := cY + margin;
  if (delta <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 - 3) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and
        (cY < SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 - 3) do Inc(cY);
  GDVars.combatArenaPtr^.ox := cX - 3;
  GDVars.combatArenaPtr^.oy := cY - 3;
  pixY := 0;
  cY := GDVars.combatArenaPtr^.oy;
  for j := 0 to 6 do begin
    pixX := 0;
    cX := GDVars.combatArenaPtr^.ox;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixX, pixY, GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[cY, cX]].tileId, 0);
      Inc(pixX, 3);
      Inc(cX);
    end;
    Inc(pixY, 3);
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, dir: Byte);
var
  p: Types.PWork;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GDConsts.dirDX[dir];
  ty := y + GDConsts.dirDY[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then
    for i := 1 to GDVars.arenaScanLimit do begin
      p := GDVars.creaturePtr[i];
      if (p^.enabled <> 0) and (GDVars.combatArenaLocation[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.creatureXCoordinate[i], GDVars.creatureYCoordinate[i],
                                      p^.combatAddr^.direction, 0, p^.orderNumber);
    end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.combatArenaPtr^.ox, ty - GDVars.combatArenaPtr^.oy) then begin
    if tx > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then tx := SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1;
    if tx < 0 then tx := 0;
    if ty > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
      ty := SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Raster.FlushView;
end;

procedure SetCreatureFacing(cr: Types.PWork; dir, frame, eraseOnly: Byte);
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(cr);
  if not CbtMap.CombatIconVisible(cr, 1) then
    if GDVars.combatMapVisible <> 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
  if (cr^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    if GDVars.combatMapVisible <> 0 then
      CbtMap.UpdateCombatMapTile(0, 0, slot);
  cr^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(cr, 0) then
      if GDVars.combatMapVisible <> 0 then begin
        MapTiles.DrawIconAnimSprite(GDVars.creatureXCoordinate[slot], GDVars.creatureYCoordinate[slot], dir, frame,
                                    cr^.orderNumber);
        Raster.FlushView;
      end;
end;

function CombatCellX(cr: Types.PWork): ShortInt;
begin
  CombatCellX := GDVars.combatArenaLocation[CbtMap.CombatSlot(cr)].x;
end;

function CombatCellY(cr: Types.PWork): ShortInt;
begin
  CombatCellY := GDVars.combatArenaLocation[CbtMap.CombatSlot(cr)].y;
end;

function GetIconSize(cr: Types.PWork): Byte;
begin
  GetIconSize := GDVars.combatArenaLocation[CbtMap.CombatSlot(cr)].size;
end;

function CombatSlot(cr: Types.PWork): Byte;
var
  found: Boolean;
  i: Byte;
begin
  found := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.creaturePtr[i] = cr then
      found := True;
  until found or (i = GDVars.arenaScanLimit);
  if found then
    CombatSlot := i;
end;

procedure ProbeDirection(cr: Types.PWork; dir: Byte; var crIdx, terrIdx, hasStinkCloud, hasCloudkill: Byte);
var
  i: Byte;
  slot: Byte;
  cellCr: Byte;
  cellTerr: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  crIdx := 0;
  terrIdx := 23;
  best := 1;
  hasStinkCloud := 0;
  hasCloudkill := 0;
  slot := CbtMap.CombatSlot(cr);
  x := GDVars.combatArenaLocation[slot].x;
  y := GDVars.combatArenaLocation[slot].y;
  for i := 0 to 3 do
    if CbtMap.GetIconTileDelta(GDVars.combatArenaLocation[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GDConsts.dirDX[dir];
      ny := y + tdy + GDConsts.dirDY[dir];
      CbtMap.GetArenaContents(nx, ny, cellCr, cellTerr);
      if cellCr = slot then
        cellCr := 0;
      if cellCr > 0 then
        crIdx := cellCr;
      if (cellTerr = 0) or (terrIdx = 0) then
        terrIdx := 0
      else
        case cellTerr of
          C_Terr.TERRAIN_STINK_CLOUD: hasStinkCloud := 1;
          C_Terr.TERRAIN_CLOUDKILL: hasCloudkill := 1;
        else
          if GDConsts.terrainInfo[cellTerr].cost >= best then begin
            best := GDConsts.terrainInfo[cellTerr].cost;
            terrIdx := cellTerr;
          end;
        end;
    end;
end;

procedure CreatureDowned(cr: Types.PWork);
var
  slot: Byte;
  k: Byte;
  frame: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: Integer;
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
    SoundDrv.SoundCommand(5);
    TextRend.PauseOnly;
  end else begin
    k := 1;
    { Note: the downed list is indexed by frame, unset here, not by k. }
    while (k < 9) and (GDVars.combatDownedCharacter[frame].cr <> cr) do
      Inc(k);
    if k < 9 then Exit;
    slot := CbtMap.CombatSlot(cr);
    cellX := CbtMap.CombatCellX(cr);
    cellY := CbtMap.CombatCellY(cr);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, C_Dir.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    SoundDrv.SoundCommand(5);
    for frame := 0 to 8 do begin
      for k := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.combatArenaLocation[slot].size, k, tdx, tdy) then
          if CbtMap.ViewCoordsValid(GDVars.creatureXCoordinate[slot] + tdx,
                                    GDVars.creatureYCoordinate[slot] + tdy) then
            Raster.BlitTileClipped((GDVars.creatureXCoordinate[slot] + tdx) * 3,
                                     (GDVars.creatureYCoordinate[slot] + tdy) * 3, 0, 5,
                                     GDVars.iconAnimation[CbtMap.DOWNED_ANIMATION, frame mod 2],
                                     GDVars.viewBuf);
      Raster.FlushView;
      Delay(10);
    end;
    if cr^.combatAddr^.notPcNpc = 0 then begin
      Inc(GDVars.downedCount);
      GDVars.combatDownedCharacter[GDVars.downedCount].under := GDVars.combatArenaPtr^.cells[cellY, cellX];
      if GDVars.combatArenaPtr^.cells[cellY, cellX] <> C_Terr.TERRAIN_STINK_CLOUD then
        GDVars.combatArenaPtr^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE;
      GDVars.combatDownedCharacter[GDVars.downedCount].cr := cr;
      GDVars.combatDownedCharacter[GDVars.downedCount].x := cellX;
      GDVars.combatDownedCharacter[GDVars.downedCount].y := cellY;
    end;
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GDVars.combatArenaLocation[CbtMap.CombatSlot(cr)].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.combatArenaPtr^.ox + 3, GDVars.combatArenaPtr^.oy + 3, 3, C_Dir.CENTER);
    cr^.combatAddr^.initiative := 0;
    cr^.combatAddr^.movement := 0;
    cr^.combatAddr^.spellCast := 0;
    cr^.combatAddr^.guarding := 0;
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1) and (cr^.hostile = 1) then begin
      CbtMap.CountTeams;
      if GDVars.teamCount[1] = 0 then begin
        GDVars.displayStatusAndWaitProc('All enemies destroyed. (more)');
        GDVars.displayStatusAndWaitProc('Continue through the (more)');
        GDVars.displayStatusAndWaitProc('maze off any map edge. (more)');
      end;
    end;
  end;
end;

function IsValidCreatureLoc(cr: Types.PWork; x, y: Byte; moving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  cellCr: Byte;
  cellTerr: Byte;
  found: Boolean;
  hasStinkCloud: Byte;
  hasCloudkill: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(cr);
    GDVars.combatArenaLocation[slot].size := cr^.iconDim and $7F;
    GDVars.combatArenaLocation[slot].x := x;
    GDVars.combatArenaLocation[slot].y := y;
    CbtMap.ProbeDirection(cr, C_Dir.CENTER, cellCr, cellTerr, hasStinkCloud, hasCloudkill);
    if (cellCr <> 0) or (cellTerr = 0) or (GDConsts.terrainInfo[cellTerr].cost = C_Terr.TERRAIN_IMPASSABLE) then
      GDVars.combatArenaLocation[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if cr^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.combatDownedCharacter[i].cr = cr then begin
              if GDVars.combatDownedCharacter[i].under <> C_Terr.TERRAIN_CORPSE then
                cellTerr := GDVars.combatDownedCharacter[i].under;
              FillChar(GDVars.combatDownedCharacter[i], SizeOf(GDVars.combatDownedCharacter[i]), 0);
            end;
          found := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.combatDownedCharacter[i].cr <> nil) and (GDVars.combatDownedCharacter[i].x = x)
               and (GDVars.combatDownedCharacter[i].y = y) then
              found := True;
          if not found then
            GDVars.combatArenaPtr^.cells[y, x] := cellTerr;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(cr: Types.PWork; delta: Byte; cursor: Boolean);
begin
  GDVars.combatArenaPtr^.cursorOn := cursor;
  GDVars.combatArenaPtr^.cursorSize := GDVars.combatArenaLocation[CbtMap.CombatSlot(cr)].size;
  if GDVars.combatMapVisible <> 0 then
    CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), delta, C_Dir.CENTER);
  GDVars.combatArenaPtr^.cursorOn := False;
  GDVars.combatArenaPtr^.cursorSize := 1;
end;

begin
end.
