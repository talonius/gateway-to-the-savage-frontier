{ The dungeon view. It loads a GEO map (four 16x16 planes: two of wall nibbles, events and barriers) and the WALLDEF
  wall sets, answers the wall, barrier and event of a cell side, and draws the 3D view, the automap in its place while
  GDVars.automapOn is set, or the overland map while zone 0's in-dungeon flag is 0. viewSlotGeom is in GDConsts; the
  map, wall sets, view colors and the party's cell are in GDVars. }
{$O+,F+,I-,S+,A+}
unit View3D;

interface

{ Stores the four 3D view band colors: sky, the two horizon bands and floor.
  @param(cSky The sky color.)
  @param(cHorz1 The first horizon band's color.)
  @param(cHorz2 The second horizon band's color.)
  @param(cFloor The floor color.) }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Reads the wall on one side of a cell; off the map the result is 0 unless GDVars.eclScript is set, when the coordinates
  wrap.
  @param(x The column.)
  @param(y The row.)
  @param(facing The side, 0, 2, 4 or 6.)
  @returns(The wall type, 0..15.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a cell, under GetWallType's coordinate rules.
  @param(x The column.)
  @param(y The row.)
  @param(facing The side, 0, 2, 4 or 6.)
  @returns(The barrier, 0..3; 1, passable, on a dungeon side with no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads a cell's event byte, under GetWallType's coordinate rules.
  @param(x The column.)
  @param(y The row.)
  @returns(The event byte.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Draws the view from cell x, y facing facing: nothing until a map is loaded, the overland map outside a dungeon, the
  automap while it is on or zone 0's combat mode is 1, else the 3D view. The 3D view draws three rows of cells, far to
  near: dist 2, 1 and 0 cells ahead. The far row draws the fronts (slot 0) and the corner slot 9 walking left and then
  right, then the left sides (slot 1) and right sides (slot 2). The middle row draws fronts (slot 3) with left sides
  (slot 4) from two cells left scanning right, then fronts with right sides (slot 5) from two cells right scanning left,
  so the center front is drawn twice; the near row does the same from one cell to each side with slots 6, 7 and 8.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The party's facing.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads WALLDEF record fileId into wall-set slot wsSlot (1..3; others are ignored), and the following slots when the
  record holds more than one set, with their 8x8 symbols. On the overland (zone 0's in-dungeon flag 0) it loads only the
  8x8 symbol set fileId into slot wsSlot.
  @param(fileId The WALLDEF record, or the symbol set on the overland.)
  @param(wsSlot The wall-set slot.) }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Loads GEO<disk> record mapId into GDVars.map3d and records mapId in zone 0; a failed load quits.
  @param(mapId The GEO record.) }
procedure Load3DMap(mapId: Byte);

{ Tells whether a cell is on the 16x16 map.
  @param(x The map column.)
  @param(y The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;

{ Re-reads the wall, barrier and event at the party's cell and facing into GDVars.partyPos.wallAhead, zone 0's
  barrierAhead and GDVars.partyPos.eventAtCell. }
procedure RefreshCurrentMapCell;

implementation

uses Types, C_Dir, C_Video, Crt, GDConsts, GDVars, Sym8x8, Raster, Blit, DaxIo, TextRend,
  GameIo, C_Gbvm;

const
  { GBVM zone 0: the barrier on the side the party faces }
  BARRIER_AHEAD = $4CF6;
  { the automap's party arrows, one per two facings }
  PARTY_ARROW_SYMBOL = 256;
  { the automap's cell symbols, plus 1, 2, 4 and 8 for a N, E, S and W wall }
  AUTOMAP_WALL_SYMBOL = 260;
  { a wall set with this many 8x8 symbols keeps its own symbol numbers }
  LARGE_SYMBOL_SET = 210;
  { GDConsts.symSetFirst[1], the first symbol of wall set 1 }
  WALL_SET1_SYMBOLS = 46;

type
  { A GEO record as LoadDax returns it: a header word Load3DMap skips, then the four planes. }
  TGeoRecord = record
    header: Word;
    planes: Types.TGeoMap;
  end;

procedure RefreshCurrentMapCell;
begin
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  GDVars.gbvmZone0Ptr^[View3D.BARRIER_AHEAD] := View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                      GDVars.partyPos.facing);
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY)
end;

{ The overland map: the 11x11 cells around x, y, each wallsNE byte drawn as a symbol of wall set 1, and the party's
  arrow.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The party's facing.) }
procedure DrawOverlandView(x, y: ShortInt; facing: Byte);
var
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt; sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
 xLo := x - 5; if xLo < 0 then xLo := 0; if xLo > 5 then xLo := 5; pwx := x - xLo;
 yLo := y - 5; if yLo < 0 then yLo := 0; if yLo > 5 then yLo := 5; pwy := y - yLo;
 for wy := 0 to 10 do begin
  my := wy + yLo;
  for wx := 0 to 10 do begin
   mx := wx + xLo; sym := GDVars.map3d^.wallsNE[my][mx];
   Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym + View3D.WALL_SET1_SYMBOLS, True, False)
  end
 end;
 GDVars.partyScreenX := pwx + 3; GDVars.partyScreenY := pwy + 3;
 Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing shr 1 + View3D.PARTY_ARROW_SYMBOL, True, True);
 GDVars.viewBuf^.palette := GDVars.symbolSetPtrs[1]^.palette;
 Raster.FlushView;
 if GDVars.displayMode = C_Video.VM_VGA then GDVars.remapPending := 1
end;

{ The 11x11 automap around x, y: each cell's symbol from its four wall types, then the party's arrow, and while
  GDConsts.areEventsShown a dot for each cell's event and indoor bit.
  @param(x The party's column.)
  @param(y The party's row.)
  @param(facing The party's facing.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  { the party's column in the window }
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  { the window's origin on the map, 0..5 }
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := View3D.AUTOMAP_WALL_SYMBOL;
      if View3D.GetWallType(mx, my, 0) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, 2) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, 4) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, 6) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, True, False);
    end;
  end;
  GDVars.partyScreenX := pwx + 3; GDVars.partyScreenY := pwy + 3;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + View3D.PARTY_ARROW_SYMBOL, True, True);
  Raster.FlushView;
  if GDConsts.areEventsShown then
   for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
     mx := wx + xLo;
     if (GDVars.map3d^.events[my][mx] and $7F) <> 0 then
      Blit.PlotViewPixel((wx + 3) * 8 + 2, (wy + 3) * 8 + 3, White);
     if (GDVars.map3d^.events[my][mx] and $80) <> 0 then
      Blit.PlotViewPixel((wx + 3) * 8 + 5, (wy + 3) * 8 + 3, LightGreen)
    end
   end;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.colorSkyCeiling := cSky;
  GDVars.wallColorA := cHorz1;
  GDVars.wallColorB := cHorz2;
  GDVars.wallColorC := cFloor;
end;

{ Fills the view's bands, 11 characters wide from column 2. In CGA (GDVars.displayMode VM_CGA) rows 16..58 and 60..103
  are black and row 59 is GDVars.wallColorA. Otherwise the sky, rows 16..59, is GDVars.colorSkyCeiling, rows 60..61
  GDVars.wallColorB and the floor, rows 62..103, GDVars.wallColorC; on an outdoor cell (event bit 7 clear) under an open
  sky of color 11 it places the sun (GDVars.skyImage1) by zone 0's hour for the east, south and west facings, and
  GDVars.skyImage0 facing north; then GDVars.skyImage2. }
procedure DrawBackdrop;
var
  feat: Word;
  bx0: Byte;
  by0: Byte;
  bx1: Byte;
  { Unused in this version; see the other implementations of this routine. }
  by1: Byte;
begin
 if GDVars.displayMode = C_Video.VM_CGA then begin
  Blit.FillPicRect(2, 16, 11, 43, 0, GDVars.viewBuf);
  Blit.FillPicRect(2, 59, 11, 1, GDVars.wallColorA, GDVars.viewBuf);
  Blit.FillPicRect(2, 60, 11, 2, 0, GDVars.viewBuf);
  Blit.FillPicRect(2, 62, 11, 42, 0, GDVars.viewBuf)
 end else begin
  Blit.FillPicRect(2, 16, 11, 44, GDVars.colorSkyCeiling, GDVars.viewBuf);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.wallColorB, GDVars.viewBuf);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.wallColorC, GDVars.viewBuf);
  if View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) < $80 then
   if GDVars.colorSkyCeiling = 11 then begin
    bx0 := 2; by0 := 2; bx1 := 12; by1 := 12; feat := GDVars.gbvmZone0Ptr^[C_Gbvm.CLOCK_HOURS];
    case feat of
     1..5: case GDVars.partyPos.facing of
      C_Dir.EAST: Raster.BlitTileClipped(bx1 - 3, by0 + 5 - feat, 0, 1, GDVars.skyImage1, GDVars.viewBuf);
      C_Dir.SOUTH: if feat > 2 then
        Raster.BlitTileClipped(bx0 + feat - 3, by0 + 5 - feat, 0, 1, GDVars.skyImage1, GDVars.viewBuf)
     end;
     13..18: case GDVars.partyPos.facing of
      C_Dir.WEST: Raster.BlitTileClipped(bx0, by0 + feat - 13, 0, 1, GDVars.skyImage1, GDVars.viewBuf);
      C_Dir.SOUTH: if feat < 16 then
        Raster.BlitTileClipped(bx0 + feat - 8, by0 + feat - 13, 0, 1, GDVars.skyImage1, GDVars.viewBuf)
     end
    end;
    if GDVars.partyPos.facing = C_Dir.NORTH then
      Raster.BlitTileClipped(bx0, by0, 0, 1, GDVars.skyImage0, GDVars.viewBuf)
   end;
  Raster.BlitTileClipped(2, 7, 0, 1, GDVars.skyImage2, GDVars.viewBuf)
 end
end;

{ Draws view slot slot's shape of wall type wallType with its top left at text cell x+2, y+2, skipping zero symbols and
  cells outside the 11x11 view; cnt steps through the shape's cells whether drawn or not. The symbol is indexed again
  for the draw.
  @param(x The text column, less 2.)
  @param(y The text row, less 2.)
  @param(wallType The wall type.)
  @param(slot The view slot.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  cnt: Byte;
  symOfs: Word;
  setNo: Byte;
begin
  setNo := (wallType - 1) div 5 + 1;
  cnt := GDConsts.viewSlotGeom.start[slot];
  if GDVars.wallSetFlags[setNo] <> 0 then symOfs := (setNo - 1) * 256 + 296
  else symOfs := 0;
  colLim := GDConsts.viewSlotGeom.cols[slot] + x - 1;
  rowLim := GDConsts.viewSlotGeom.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (GDVars.wallGfx^.slices[wallType][cnt] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, GDVars.wallGfx^.slices[wallType][cnt] + symOfs, True, True);
      Inc(cnt);
    end;
end;

function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    b := 1;
    if (View3D.GetWallType(x, y, facing) > 0) or (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) then
      { the reverse of GetWallType's order }
      case facing of
        C_Dir.WEST: b := (GDVars.map3d^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.map3d^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.map3d^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.map3d^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    { no else: an odd facing leaves the result unset }
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.map3d^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.map3d^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.map3d^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.map3d^.wallsSW[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then
    GetMapEvent := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.map3d^.events[y][x];
  end;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  { the facing to the left }
  fL: Byte;
  { to the right }
  fR: Byte;
  { behind }
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  dxF: Word;
  dyF: Word;
  wx: Integer;
  wy: Integer;
  side: Byte;
  symOfs: Integer;
  dist: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  wallBack: Byte;
  prevWall: Byte;
begin
  GDVars.remapPending := 0;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.GEO_MAP_ID] = 0 then Exit;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then View3D.DrawOverlandView(x, y, facing)
  else if GDVars.automapOn or (GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1) then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    fL := (facing + 6) mod 8;
    fB := (facing + 4) mod 8;
    fR := (facing + 2) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirDX[facing];
    dyF := GDConsts.dirDY[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          { far row: fronts and the corner slot 9, walking left }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fR) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDX[fL], wy - GDConsts.dirDY[fL], fL) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDX[fL];
            wy := wy + GDConsts.dirDY[fL];
          end;
          { far row: fronts and the corner slot 9, walking right }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fL) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDX[fR], wy - GDConsts.dirDY[fR], fR) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs - 1, GDConsts.viewSlotGeom.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDX[fR];
            wy := wy + GDConsts.dirDY[fR];
          end;
          { far row: left sides, slot 1 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs, GDConsts.viewSlotGeom.yRow[1], wallSide, 1)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[1] + symOfs - 1, GDConsts.viewSlotGeom.yRow[1],
                                     wallSide, 1);
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDX[fL];
            wy := wy + GDConsts.dirDY[fL];
          end;
          { far row: right sides, slot 2 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs, GDConsts.viewSlotGeom.yRow[2], wallSide, 2)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[2] + symOfs + 1, GDConsts.viewSlotGeom.yRow[2],
                                     wallSide, 2);
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDX[fR];
            wy := wy + GDConsts.dirDY[fR];
          end;
        end;
        1: begin
          { middle row: from two cells left, scanning right; fronts slot 3, left sides slot 4 }
          wx := cxPos + GDConsts.dirDX[fL];
          wx := wx + GDConsts.dirDX[fL];
          wy := cyPos + GDConsts.dirDY[fL];
          wy := wy + GDConsts.dirDY[fL];
          side := 0;
          symOfs := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[4] + symOfs, GDConsts.viewSlotGeom.yRow[4], wallSide, 4);
            Inc(side);
            Inc(symOfs, 3);
            wx := wx + GDConsts.dirDX[fR];
            wy := wy + GDConsts.dirDY[fR];
          end;
          { middle row: from two cells right, scanning left; fronts slot 3, right sides slot 5 }
          wx := cxPos + GDConsts.dirDX[fR];
          wx := wx + GDConsts.dirDX[fR];
          wy := cyPos + GDConsts.dirDY[fR];
          wy := wy + GDConsts.dirDY[fR];
          side := 0;
          symOfs := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[3] + symOfs, GDConsts.viewSlotGeom.yRow[3], wallFront, 3);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[5] + symOfs, GDConsts.viewSlotGeom.yRow[5], wallSide, 5);
            Inc(side);
            Dec(symOfs, 3);
            wx := wx + GDConsts.dirDX[fL];
            wy := wy + GDConsts.dirDY[fL];
          end;
        end;
        0: begin
          { near row: the left cell and the center; fronts slot 6, left sides slot 7 }
          wx := cxPos + GDConsts.dirDX[fL];
          wy := cyPos + GDConsts.dirDY[fL];
          side := 0;
          symOfs := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[7] + symOfs, GDConsts.viewSlotGeom.yRow[7], wallSide, 7);
            Inc(side);
            Inc(symOfs, 7);
            wx := wx + GDConsts.dirDX[fR];
            wy := wy + GDConsts.dirDY[fR];
          end;
          { near row: the right cell and the center; fronts slot 6, right sides slot 8 }
          wx := cxPos + GDConsts.dirDX[fR];
          wy := cyPos + GDConsts.dirDY[fR];
          side := 0;
          symOfs := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[6] + symOfs, GDConsts.viewSlotGeom.yRow[6], wallFront, 6);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[8] + symOfs, GDConsts.viewSlotGeom.yRow[8], wallSide, 8);
            Inc(side);
            Dec(symOfs, 7);
            wx := wx + GDConsts.dirDX[fL];
            wy := wy + GDConsts.dirDY[fL];
          end;
        end;
      end;
      cxPos := cxPos + GDConsts.dirDX[fB];
      cyPos := cyPos + GDConsts.dirDY[fB];
      Dec(dist);
    until dist = 255;
    if GDVars.displayMode = C_Video.VM_VGA then
      Blit.ShowPic(1, 1, GDConsts.viewFramePic);
    Raster.FlushView;
  end;
end;

procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PBytes;
  readOfs: Word;
  symOfs: Word;
  row: Byte;
  i: Word;
  col: Integer;
  count: Byte;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  if (wsSlot < 1) or (wsSlot > 3) then Exit;
  { formatted and not used }
  Str(LongInt(GDVars.virtualDiskNumber), numStr);
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then begin
    Sym8x8.Load8x8Set(fileId, wsSlot);
    GDVars.wallSetCache[wsSlot].wallDefId := fileId;
    GDVars.wallSetCache[wsSlot].symbolSlot := wsSlot;
    Exit
  end;
  DaxIo.LoadDax('WALLDEF', '.dax', fileId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead div SizeOf(Types.TWallDef) + wsSlot > 4) then begin
    TextRend.DisplayAndPause(White, Black, 'Cannot find wall');
    Exit
  end;
  symOfs := GDConsts.symSetFirst[wsSlot] - GDConsts.symSetFirst[1];
  readOfs := 0;
  i := 1;
  repeat
    Move(data^[readOfs], GDVars.wallGfx^.sets[wsSlot + i - 1], SizeOf(Types.TWallDef));
    Inc(readOfs, SizeOf(Types.TWallDef));
    Inc(i);
  until readOfs >= sizeRead;
  FreeMem(data, sizeRead);
  count := i - 1;
  for i := 1 to count do
    if (wsSlot + i - 1) in [1..3] then begin
      GDVars.wallSetCache[wsSlot + i - 1].wallDefId := -1;
      GDVars.wallSetCache[wsSlot + i - 1].symbolSlot := -1;
      if count > 1 then
        Sym8x8.Load8x8Set(fileId * 10 + i, wsSlot + i - 1)
      else
        Sym8x8.Load8x8Set(fileId, wsSlot + i - 1);
      if GDVars.symbolSetPtrs[wsSlot + i - 1]^.count >= View3D.LARGE_SYMBOL_SET then
        GDVars.wallSetFlags[wsSlot + i - 1] := 1
      else begin
        GDVars.wallSetFlags[wsSlot + i - 1] := 0;
      for row := 1 to 5 do
        for col := 0 to 155 do begin
          if GDVars.wallGfx^.sets[wsSlot + i - 1][row][col] >= GDConsts.symSetLast[0] then
            Inc(GDVars.wallGfx^.sets[wsSlot + i - 1][row][col], symOfs);
        end
      end
    end;
  GDVars.wallSetCache[wsSlot].wallDefId := fileId;
  GDVars.wallSetCache[wsSlot].symbolSlot := wsSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PBytes;
  readOfs: Word;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  GDVars.displayStatusLineProc('Loading...Please Wait');
  Str(GDVars.virtualDiskNumber, numStr);
  DaxIo.LoadDax('GEO' + numStr, '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> SizeOf(TGeoRecord)) then begin
    Blit.RestoreVideoMode;
    {$I+}
    WriteLn('Unable to load geo in Load3DMap.');
    {$I-}
    discardedKey := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  readOfs := SizeOf(TGeoRecord) - SizeOf(Types.TGeoMap);
  Move(data^[readOfs], GDVars.map3d^.wallsNE, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.map3d^.wallsSW, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.map3d^.events, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.map3d^.barriers, SizeOf(Types.TGeoPlane));
  FreeMem(data, sizeRead);
  GDVars.gbvmZone0Ptr^[C_Gbvm.GEO_MAP_ID] := mapId;
end;

begin
end.
