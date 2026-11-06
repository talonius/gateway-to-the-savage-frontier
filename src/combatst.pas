{ Combat setup. CombatStart clears the previous fight's state, builds the arena (Types.TArena, at GDVars.combatArenaPtr)
  and places the combatants. In a dungeon BuildDungeonArena draws the 13 by 5 map cells around the party, each a skewed
  6 by 5 block of floor, walls and doors, and DecorateCell decorates an enclosed cell; in the wilderness
  BuildWildernessArena lays a river, trees and features by the terrain's class bits. InitCreatureCombatData gives each
  creature its combatant record and facing. PlaceAllCreatures builds each team's quad grid and FindPlacement spirals
  each creature out from its team's origin, ring by ring, to a free quad and a clear cell. In combat mode 1 the party's
  cell comes from bank 0, where the script sets it. }
{$O+,F+}
{$A+}
{$R-}
{$S+}
unit CombatSt;

interface

{ Set up a combat: clear the last one's state, build the arena, give each creature its combatant record and place it,
  draw the combat screen, and run each creature's combat-start effects. }
procedure CombatStart;

implementation

uses Types, C_Cond, C_Dir, C_Ifc, C_Npc, C_Pic, C_Terr, Crt, GDConsts, GDVars, CbtMap, CharGen, MapTiles,
  CharHlp, FxEngine, View3D, Portrait, Raster, TextRend, DaxIo, GameIo, CbtActs, MenuCore, C_Gbvm;

type
  { GBVM bank 0 (GDVars.gbvmZone0Ptr) as CombatSt reads it as bytes: the low bytes of the party's map cell, of the
    overland location, which is the wilderness terrain under the party, and of the party's cell for a combat in combat
    mode 1 }
  PZone0 = ^TZone0;
  TZone0 = record
    partyXLead: array[$000..$185] of Byte;
    partyX: Byte;
    partyYLead: Byte;
    partyY: Byte;
    terrainCharLead: array[$189..$341] of Byte;
    terrainChar: Byte;
    combatPartyXLead: array[$343..$3FB] of Byte;
    combatPartyX: Byte;
    combatPartyYLead: array[$3FD..$3FF] of Byte;
    combatPartyY: Byte;
  end;

var
  { bank 0's low bytes }
  zone0: PZone0 absolute GDVars.gbvmZone0Ptr;

{ Plots a terrain value plus 1 at a spot of the current map cell's skewed block, inside the arena.
  @param(i Column within the block.)
  @param(j Row within the block.)
  @param(t Terrain id less 1.) }
procedure PlotCell(i, j, t: Byte);
var
  x: ShortInt;
  y: ShortInt;
begin
  x := GDVars.dungeonCellDX * 6 + GDVars.dungeonCellDY * 5 + 21 + i;
  y := GDVars.dungeonCellDY * 5 + 10 + j;
  if (x >= 0) and (x <= SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and (y >= 0) and
      (y <= SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then
    GDVars.combatArenaPtr^.cells[y, x] := t + 1;
end;

{ Decorates the current dungeon cell's floor. It records whether the cell is enclosed: at least one solid wall, no door,
  and no opposed pair of solid walls unless all four are solid. When the caller's map-event decoration flag is set and
  the cell is enclosed, each of its six middle spots that is open floor (terrain 22) has an even chance of becoming
  terrain 26, and each open-floor spot beside such a spot a nine in ten chance of becoming terrain 27. }
procedure DecorateCell;
var
  i: ShortInt;
  j: ShortInt;
  px: ShortInt;
  py: ShortInt;
  px2: ShortInt;
  py2: ShortInt;
  k: Byte;
begin
  GDVars.isCellEnclosed := ((GDVars.wallN = 1) or (GDVars.wallE = 1) or (GDVars.wallS = 1) or (GDVars.wallW = 1)) and
    ((GDVars.wallN <> 1) or (GDVars.wallS <> 1) or ((GDVars.wallE = 1) and (GDVars.wallW = 1))) and
    ((GDVars.wallE <> 1) or (GDVars.wallW <> 1) or ((GDVars.wallN = 1) and (GDVars.wallS = 1))) and
    ((GDVars.wallN <> 3) and (GDVars.wallE <> 3) and (GDVars.wallS <> 3) and (GDVars.wallW <> 3));
  for i := 2 to 3 do
    for j := 2 to 4 do begin
      px := GDVars.dungeonCellDX * 6 + GDVars.dungeonCellDY * 5 + 21 + i + j;
      py := GDVars.dungeonCellDY * 5 + 10 + j;
      if (px >= 0) and (px <= SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and (py >= 0) and
          (py <= SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then
        if GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[py, px]].tileId = 22 then
          if GDVars.isDecorationAllowed then
            if GDVars.isCellEnclosed then
              if FxEngine.RollDice(1, 10) <= 5 then begin
                GDVars.combatArenaPtr^.cells[py, px] := 26;
                for k := 1 to 4 do begin
                  px2 := GDConsts.featDX[k] + px;
                  py2 := GDConsts.featDY[k] + py;
                  if (px2 >= 0) and (px2 <= SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and (py2 >= 0) and
                      (py2 <= SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then
                    if GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[py2, px2]].tileId = 22 then
                      if FxEngine.RollDice(1, 10) <= 9 then
                        GDVars.combatArenaPtr^.cells[py2, px2] := 27;
                end;
              end;
    end;
end;

{ Classifies the edge between a map cell and its neighbor in a direction, from both sides. Off the map it is open on the
  party's row going east or west, otherwise blocked.
  @param(x Map column.)
  @param(y Map row.)
  @param(dir Direction of the neighbor.)
  @returns(0 open, 1 blocked, 3 a wall that can be passed; the two sides' bits combined.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearWall: Byte;
  farWall: Byte;
  opp: Byte;

  { The edge on one side: View3D's on the 16-by-16 map; off it, open east-west on the party's row, else solid. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.combatPartyY) and ((pdir = C_Dir.EAST) or (pdir = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  nearWall := GetWallKind(x, y, dir);
  farWall := GetWallKind(x + GDConsts.dirDX[dir], y + GDConsts.dirDY[dir], opp);
  WallBetween := nearWall or farWall;
end;

{ Draw the dungeon arena: for each map cell 6 either side of the party and 2 before and behind, probe its walls and draw
  its block, then decorate it unless the zone is underwater. }
procedure BuildDungeonArena;
var
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cornerIndex: Integer;

  { Draws the cell's three floor rows and its west wall or door. }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        CombatSt.PlotCell(c, r, 22);
    if GDVars.wallW = 1 then begin
      for r := 2 to 4 do begin
        CombatSt.PlotCell(r - 1, r, 4);
        CombatSt.PlotCell(r, r, 3);
        CombatSt.PlotCell(r + 1, r, 13);
      end;
    end else if GDVars.wallW = 3 then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.wallN = 1 then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner by its walls and whether the corner between its neighbors is open. }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = 0) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case Char(GDVars.wallN) of
             #0: case Char(GDVars.wallW) of
                  #0: topLeftTile := 22;
                  #3: topLeftTile := 13;
                  #1: if open <> 0 then topLeftTile := 0 else topLeftTile := 13;
                end;
             #3, #1: if GDVars.wallW = 0 then begin
                     if open <> 0 then topLeftTile := 15 else topLeftTile := 5;
                   end else begin
                     if open <> 0 then topLeftTile := 18 else topLeftTile := 2;
                   end;
           end;
        2: case Char(GDVars.wallN) of
             #0: topRightTile := 22;
             #3: topRightTile := 17;
             #1: topRightTile := 5;
           end;
        3: case Char(GDVars.wallW) of
             #0: if GDVars.wallN = 0 then
                  bottomLeftTile := 22
                else if open <> 0 then
                  bottomLeftTile := 16
                else
                  bottomLeftTile := 10;
             #3: if open <> 0 then bottomLeftTile := 20 else bottomLeftTile := 7;
             #1: if open <> 0 then bottomLeftTile := 1 else bottomLeftTile := 3;
           end;
        4: case Char(GDVars.wallW) of
             #0, #3: case Char(GDVars.wallN) of
                     #0: bottomRightTile := 22;
                     #3: bottomRightTile := 23;
                     #1: bottomRightTile := 10;
                   end;
             #1: case Char(GDVars.wallN) of
                  #0: bottomRightTile := 13;
                  #3: bottomRightTile := 21;
                  #1: bottomRightTile := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, topLeftTile);
    CombatSt.PlotCell(2, 0, topRightTile);
    CombatSt.PlotCell(1, 1, bottomLeftTile);
    CombatSt.PlotCell(2, 1, bottomRightTile);
  end;

  { Fills the cell's northeast corner (spots 5..6 on rows 0..1) by its walls and its neighbors'. }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
    northWall: Byte;
    eastWall: Byte;
  begin
    northWall := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    eastWall := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (northWall = 0) and (eastWall = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case Char(GDVars.wallN) of
             #0: if northWall = 1 then topLeftTile := 4 else topLeftTile := 22;
             #3: topLeftTile := 15;
             #1: topLeftTile := 5;
           end;
        2: if GDVars.wallN = 0 then begin
             case Char(northWall) of
               #0: topRightTile := 22;
               #3: if (GDVars.wallE = 0) and (eastWall <> 0) then
                    topRightTile := 24
                  else
                    topRightTile := 1;
               #1: if GDVars.wallE = 0 then begin
                    if eastWall <> 0 then topRightTile := 11 else topRightTile := 7;
                  end else
                    topRightTile := 3;
             end;
           end else begin
             if GDVars.wallE <> 0 then
               topRightTile := 9
             else if eastWall <> 0 then
               topRightTile := 5
             else if open <> 0 then
               topRightTile := 17
             else
               topRightTile := 19;
           end;
        3: case Char(GDVars.wallN) of
             #0: bottomLeftTile := 22;
             #3: bottomLeftTile := 16;
             #1: bottomLeftTile := 10;
           end;
        4: if GDVars.wallN = 0 then begin
             if northWall = 0 then
               bottomRightTile := 22
             else if GDVars.wallE <> 0 then
               bottomRightTile := 4
             else if eastWall = 0 then
               bottomRightTile := 8
             else
               bottomRightTile := 12;
           end else begin
             if GDVars.wallE <> 0 then
               bottomRightTile := 14
             else if eastWall = 0 then
               bottomRightTile := 23
             else
               bottomRightTile := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, topLeftTile);
    CombatSt.PlotCell(6, 0, topRightTile);
    CombatSt.PlotCell(5, 1, bottomLeftTile);
    CombatSt.PlotCell(6, 1, bottomRightTile);
  end;

begin
  FillChar(GDVars.combatArenaPtr^.cells, SizeOf(GDVars.combatArenaPtr^.cells), 22);
  for GDVars.dungeonCellDY := -2 to 2 do
    for GDVars.dungeonCellDX := -6 to 6 do begin
      cellX := GDVars.combatPartyX + GDVars.dungeonCellDX;
      cellY := GDVars.combatPartyY + GDVars.dungeonCellDY;
      GDVars.wallW := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      GDVars.wallN := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      GDVars.wallE := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      GDVars.wallS := CombatSt.WallBetween(cellX, cellY, C_Dir.SOUTH);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
      GDVars.isDecorationAllowed := (View3D.GetMapEvent(cellX, cellY) = $80);
      if GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0 then
        CombatSt.DecorateCell;
    end;
end;

{ Looks up the class bits of the current terrain type, which steer the wilderness arena generators.
  @returns(The class bits.) }
function TerrainClassOf: Byte;
begin
  TerrainClassOf := GDConsts.terrainClass[GDVars.terrainChar];
end;

{ Places a river running down the arena and drifting a column a row, with fords, as the terrain's class and chance
  decide. }
procedure PlaceRiver;
var
  thresh: Byte;
  { Unused in this version; see the other implementations of this routine. }
  startCol: ShortInt;
  col: ShortInt;
  row: ShortInt;

  { A ford across the river at row, beside column col. }
  procedure PlotFord(row, col: ShortInt);
  begin
    if col < SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
      GDVars.combatArenaPtr^.cells[row, col + 1] := 64;
    if (row < SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) and
        (col < SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then
      GDVars.combatArenaPtr^.cells[row + 1, col + 1] := 65;
  end;

begin
  thresh := 0;
  if CombatSt.TerrainClassOf and $20 <> 0 then thresh := 35;
  if CombatSt.TerrainClassOf and $10 <> 0 then thresh := 75;
  if FxEngine.RollDice(1, 100) > thresh then Exit;
  col := 34 - FxEngine.RollDice(5, 4);
  while (col + 2) mod 7 > 0 do Dec(col);
  startCol := col;
  for row := 0 to SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 do
    if col <= SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then begin
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 59;
      if col < SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
        GDVars.combatArenaPtr^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 61;
      if FxEngine.RollDice(1, 20) = 1 then
        PlotFord(row, col);
      Inc(col);
    end;
end;

{ Trees, one or two cells tall, on grass, at a density set by the terrain's class. }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  col: ShortInt;
  row: ShortInt;
  dens: ShortInt;
begin
  if CombatSt.TerrainClassOf and $80 <> 0 then Exit;
  dens := 10;
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(dens, 5);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(dens, 2);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(dens, 5);
  if CombatSt.TerrainClassOf and $08 <> 0 then Inc(dens, 10);
  if dens < 0 then dens := 1;
  for col := 0 to SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 do
    for row := 1 to SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 do
      if (GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[row, col]].tileId = 22) and
          (GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[row - 1, col]].tileId = 22) and
          (dens >= FxEngine.RollDice(1, 100)) then
        if dens >= FxEngine.RollDice(1, 100) then
          GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 41
        else begin
          GDVars.combatArenaPtr^.cells[row - 1, col] := FxEngine.RollDice(1, 5) + 31;
          GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 5) + 36;
        end;
end;

{ Scatters features over the grass cells of the wilderness arena, with the odds of each kind chosen by a weight the
  terrain's class bits raise and lower. }
procedure ScatterFeatures;
var
  col: ShortInt;
  row: ShortInt;
  weight: Integer;

  { Roll d100 against the five bands' chances and plot the band's feature. }
  procedure ScatterOneCell(col, row: ShortInt; firstChance, secondChance, thirdChance, fourthChance, fifthChance: Byte);
  var
    roll: Byte;
  begin
    roll := FxEngine.RollDice(1, 100);
    if roll <= firstChance then
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 57
    else if roll <= firstChance + secondChance then
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 2) + 47
    else if roll <= firstChance + secondChance + thirdChance then
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 4) + 43
    else if roll <= firstChance + secondChance + thirdChance + fourthChance then
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 3) + 54
    else if roll <= firstChance + secondChance + thirdChance + fourthChance + fifthChance then
      GDVars.combatArenaPtr^.cells[row, col] := FxEngine.RollDice(1, 4) + 49;
  end;

begin
  weight := 50;
  if CombatSt.TerrainClassOf and $10 <> 0 then Inc(weight, 10);
  if CombatSt.TerrainClassOf and $20 <> 0 then Inc(weight, 30);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(weight, 20);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(weight, 10);
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(weight, 20);
  if CombatSt.TerrainClassOf and $80 <> 0 then Dec(weight, 50);
  for col := 0 to SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 do
    for row := 0 to SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 do
      if GDConsts.terrainInfo[GDVars.combatArenaPtr^.cells[row, col]].tileId = 22 then
        case weight of
          -30..9: ScatterOneCell(col, row, 0, 0, 0, 30, 15);
          10..29: ScatterOneCell(col, row, 0, 1, 5, 20, 10);
          30..69: ScatterOneCell(col, row, 0, 2, 5, 10, 5);
          70..89: ScatterOneCell(col, row, 10, 2, 10, 10, 1);
          90..110: ScatterOneCell(col, row, 15, 5, 15, 10, 1);
        end;
end;

{ Fill the arena with grass and lay the wilderness features of the terrain under the party. The party's map cell is read
  and not used. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: Integer;
begin
  FillChar(GDVars.combatArenaPtr^.cells, SizeOf(GDVars.combatArenaPtr^.cells), 23);
  mapX := zone0^.partyX;
  mapY := zone0^.partyY;
  GDVars.terrainChar := zone0^.terrainChar;
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
end;

{ Load the dungeon or wilderness combat tiles when the last combat used the other set, then allocate the arena and build
  it. }
procedure LoadCombatTileSet;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then begin
    if GDVars.combatTilesLoaded = 0 then begin
      DaxIo.PushState(1);
      MapTiles.Load24x24Set('DungCom', 1, 0, 25);
      DaxIo.PopState;
    end;
    GDVars.combatTilesLoaded := 1;
  end else begin
    if GDVars.combatTilesLoaded <> 0 then begin
      DaxIo.PushState(6);
      MapTiles.Load24x24Set('WildCom', 1, 0, 33);
      DaxIo.PopState;
    end;
    GDVars.combatTilesLoaded := 0;
  end;
  GetMem(GDVars.combatArenaPtr, SizeOf(Types.TArena));
  FillChar(GDVars.combatArenaPtr^, SizeOf(Types.TArena), 0);
  GDVars.combatArenaPtr^.cursorOn := False;
  GDVars.combatArenaPtr^.cursorSize := 1;
  GDVars.combatArenaPtr^.distMode := 0;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Gives each creature a zeroed combat record after recalculating its statistics: creatures past the party's size are
  marked as non-party members, allies face the party's way and hostiles the other way, and a friendly non-party creature
  with no morale, or one above 102, takes the zone's base morale as a non-player. }
procedure InitCreatureCombatData;
var
  p: Types.PWork;
  count: Byte;
  morale: Byte;
begin
  p := GDVars.creatureList;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if count > GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadDir[GDVars.partyPos.facing div 2];
    if p^.hostile = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    morale := p^.npc and C_Npc.MORALE_MASK;
    if (p^.hostile = 0) and (p^.combatAddr^.notPcNpc = 1) and ((morale = 0) or (morale > 102)) then
      p^.npc := GDVars.gbvmZone1Ptr^[C_Gbvm.MORALE_THRESHOLD] + C_Npc.NON_PLAYER;
    p := p^.next;
  end;
end;

{ Tells whether a placement square lies off the 11x6 grid on both axes.
  @param(qx The square's column.)
  @param(qy The square's row.)
  @returns(True when both coordinates are off the grid.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Place creature slot on quad qx, qy of ring, from the quad origin bqx, bqy, when the quad is free and its arena cell
  holds no creature and passable terrain.
  @param(slot The creature's combat slot.)
  @param(qx Quad column.)
  @param(qy Quad row.)
  @param(bqx The origin's map column offset.)
  @param(bqy The origin's map row offset.)
  @param(ring The ring.)
  @returns(1 when placed, else 0.) }
function TryPlaceAt(slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  crIdx: Byte;
  terrIdx: Byte;
  hasStinkCloud: Byte;
  hasCloudkill: Byte;
begin
  TryPlaceAt := 0;
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (GDVars.quadFree[GDVars.team, ring, qy, qx] = 0) then begin
  end else begin
    GDVars.combatArenaLocation[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.combatArenaLocation[slot].y := qy + bqy * 5 + 10;
    if (GDVars.combatArenaLocation[slot].x < 0) or
        (GDVars.combatArenaLocation[slot].x > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) or
        (GDVars.combatArenaLocation[slot].y < 0) or
        (GDVars.combatArenaLocation[slot].y >
         SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then begin
    end else begin
      CbtMap.ProbeDirection(GDVars.creaturePtr[slot], C_Dir.CENTER, crIdx, terrIdx, hasStinkCloud,
                            hasCloudkill);
      if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < C_Terr.TERRAIN_IMPASSABLE) then begin
        TryPlaceAt := 1;
        GDVars.quadFree[GDVars.team, ring, qy, qx] := 0;
      end else
        TryPlaceAt := 0;
    end;
  end;
end;

{ Searches the team's placement grid for a square for a creature, in zigzag legs from the ring's start square. A leg
  ends at a square partly off the grid or after a set number of tries, and the next leg starts a step further back; for
  team 0 facing diagonally, ring 0's first step back is doubled when any of the ring's three directions is not walled
  off (always outdoors). A square fully off the grid moves on to the next ring whose direction is not walled off (always
  outdoors), up to ring 3.
  @param(slot The creature's combat slot.)
  @returns(True when the creature was placed; False when no ring is left.) }
function FindPlacement(slot: Byte): Boolean;
var
  placed: Byte;
  firstPass: Byte;
  giveUp: Byte;
  offGrid: Byte;
  open: Byte;
  state: Byte;
  dir: Byte;
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  baseQX: ShortInt;
  baseQY: ShortInt;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQX := GDVars.placeX[GDVars.team];
  baseQY := GDVars.placeY[GDVars.team];
  repeat
    quad := GDConsts.ringStart[GDVars.teamDir[GDVars.team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 2) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 2) mod 4]];
           legX := GDConsts.startQX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.startQY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 1) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 3) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= GDVars.teamRows[GDVars.team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (GDVars.team = 0) and Odd(GDVars.teamDir[0]) and (ring = 0) and (legShift = 1) then begin
          wallX := GDVars.placeX[GDVars.team] + GDVars.combatPartyX;
          wallY := GDVars.placeY[GDVars.team] + GDVars.combatPartyY;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], k];
            if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
      placed := 0;
      state := 0;
      while (ring < 3) and (state <> 1) do begin
        Inc(ring);
        wallX := GDVars.placeX[GDVars.team] + GDVars.combatPartyX;
        wallY := GDVars.placeY[GDVars.team] + GDVars.combatPartyY;
        dir := GDConsts.ringDirTbl[GDVars.teamDir[GDVars.team], ring];
        if (GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
          baseQX := GDVars.placeX[GDVars.team] + GDConsts.dirDX[dir];
          baseQY := GDVars.placeY[GDVars.team] + GDConsts.dirDY[dir];
          legShift := 0;
          state := 1;
        end;
      end;
      if state <> 1 then giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(slot, qx, qy, baseQX, baseQY, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Set each team's origin, direction and rows, free each ring's quads inside the direction's row bands, then place each
  creature in turn: a downed party member leaves a corpse (not in a duel), and a creature outside the party that finds
  no place is removed. }
procedure PlaceAllCreatures;
var
  x: ShortInt;
  y: ShortInt;
  prev: Types.PWork;
  p: Types.PWork;
  slot: Byte;
  quadIdx: Byte;
  bandDir: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
begin
  CbtMap.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  GDVars.arenaScanLimit := 1;
  FillChar(GDVars.combatArenaLocation, SizeOf(GDVars.combatArenaLocation), 0);
  CbtMap.BuildArenaArrays;
  GDVars.placeX[0] := GDVars.partyPos.mapX - GDVars.combatPartyX;
  GDVars.placeY[0] := GDVars.partyPos.mapY - GDVars.combatPartyY;
  GDVars.teamDir[0] := GDVars.partyPos.facing div 2;
  GDVars.placeX[1] := GDConsts.dirDX[GDVars.partyPos.facing] * GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] +
    GDVars.placeX[0];
  GDVars.placeY[1] := GDConsts.dirDY[GDVars.partyPos.facing] * GDVars.gbvmZone1Ptr^[C_Gbvm.MONSTER_DIST] +
    GDVars.placeY[0];
  GDVars.teamDir[1] := (GDVars.partyPos.facing + 4) mod 8 div 2;
  for GDVars.team := 0 to 1 do
    GDVars.teamRows[GDVars.team] := (GDVars.teamCount[GDVars.team] + 1) div 2;
  for GDVars.team := 0 to 1 do
    for quadIdx := 0 to 3 do begin
      if quadIdx = 1 then bandDir := 4 else bandDir := GDVars.teamDir[GDVars.team];
      for y := 0 to 5 do
        for x := 0 to 10 do
          if (GDConsts.rowBand[bandDir, y].lo > x) or (GDConsts.rowBand[bandDir, y].hi < x) then
            GDVars.quadFree[GDVars.team, quadIdx, y, x] := 0
          else
            GDVars.quadFree[GDVars.team, quadIdx, y, x] := 1;
    end;
  slot := 1;
  GDVars.arenaScanLimit := 1;
  prev := GDVars.creatureList;
  p := GDVars.creatureList;
  while p <> nil do begin
    GameIo.DiscardPendingKeys;
    GDVars.creaturePtr[slot] := p;
    GDVars.team := p^.hostile;
    GDVars.combatArenaLocation[slot].slotIndex := slot;
    GDVars.combatArenaLocation[slot].size := p^.iconDim and 7;
    if CombatSt.FindPlacement(slot) then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.combatArenaLocation[slot].size := 0;
        if (not GDVars.duelFlag) and (p^.combatAddr^.notPcNpc = 0) then begin
          x := GDVars.combatArenaLocation[slot].x;
          y := GDVars.combatArenaLocation[slot].y;
          Inc(GDVars.downedCount);
          GDVars.combatDownedCharacter[GDVars.downedCount].under := GDVars.combatArenaPtr^.cells[y, x];
          GDVars.combatArenaPtr^.cells[y, x] := C_Terr.TERRAIN_CORPSE;
          GDVars.combatDownedCharacter[GDVars.downedCount].cr := p;
          GDVars.combatDownedCharacter[GDVars.downedCount].x := x;
          GDVars.combatDownedCharacter[GDVars.downedCount].y := y;
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaScanLimit);
      Inc(placedCnt);
    end else begin
      GDVars.combatArenaLocation[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.creaturePtr[slot] := nil;
        GDVars.curChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaScanLimit);
      end;
    end;
    p := p^.next;
  end;
  prev^.next := nil;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  p: Types.PWork;
begin
  GDVars.msgDelayFlag := 0;
  Portrait.FreeAnimation(GDVars.animationData);
  Portrait.FreePortraitBufs;
  Raster.FreePic(GDVars.bigPicBuf);
  if GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 1 then begin
    GDVars.combatPartyX := zone0^.combatPartyX;
    GDVars.combatPartyY := zone0^.combatPartyY;
  end else begin
    GDVars.combatPartyX := GDVars.partyPos.mapX;
    GDVars.combatPartyY := GDVars.partyPos.mapY;
  end;
  GDVars.bigPicId := C_Pic.NO_BIG_PICTURE;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'A battle begins...');
  GDVars.quickMagic := False;
  GDVars.combatRoundCounterCount := 0;
  GDVars.roundLimit := 15;
  GDVars.currentAttackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.linkedListStinkingPtr := nil;
  GDVars.cloudkillList := nil;
  GDVars.lastMissileItem := nil;
  FillChar(GDVars.combatDownedCharacter, SizeOf(GDVars.combatDownedCharacter), 0);
  GDVars.gbvmZone1Ptr^[C_Gbvm.ATTACKED_ALLIES] := 0;
  GDVars.gbvmZone0Ptr^[C_Gbvm.ESCAPED_HOSTILES] := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Raster.AllocPic(24, 3, 4, 1, GDVars.moveIconSheet);
  GDVars.combatArenaPtr^.ox := CbtMap.CombatCellX(GDVars.creatureList) - 7 div 2;
  GDVars.combatArenaPtr^.oy := CbtMap.CombatCellY(GDVars.creatureList) - 7 div 2;
  if GDVars.combatArenaPtr^.ox < 0 then GDVars.combatArenaPtr^.ox := 0;
  if GDVars.combatArenaPtr^.oy < 0 then GDVars.combatArenaPtr^.oy := 0;
  if GDVars.combatArenaPtr^.ox >
      SizeOf(GDVars.combatArenaPtr^.cells[0]) -
      7 then GDVars.combatArenaPtr^.ox := SizeOf(GDVars.combatArenaPtr^.cells[0]) - 7;
  if GDVars.combatArenaPtr^.oy >
      SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 7 then
    GDVars.combatArenaPtr^.oy := SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 7;
  CharHlp.DisplayCombatInterface;
  p := GDVars.creatureList;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.COMBAT_START, p);
    FxEngine.TriggerEffectsWithCondition(22, p);
    p := p^.next;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.arenaMoveActive := 0;
  GDVars.manualAimActive := 0;
  GDVars.joyClickA := 0;
  GDVars.joyClickB := 0;
  GDConsts.isArenaClickPending := False;
  GDVars.combatTransition := 0;
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
end;

begin
end.
