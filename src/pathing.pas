{ Combat line walking and targeting. PathFind and NextPathStep step a line cell by cell, counting two for a straight
  step and three for a diagonal one; WalkLine walks a line of sight across the combat arena's terrain; IsDirToward tests
  whether a cell lies in the 90-degree cone ahead of a facing; and BuildTargetList fills GDVars.combatTargetData with
  the combatants the acting one can reach, nearest first. The unit owns no storage. }
{$O+,F+,I-,R-,S+,V-,B-,A+}
unit Pathing;

interface

uses CbtMap, Types, C_Dir, GDConsts, GDVars;

{ Gives the sign of a number.
  @param(v The number.)
  @returns(-1, 0 or 1.) }
function SignOf(v: Integer): Integer;

{ Starts a line walk from its start point to its end point: sets the current point, the deltas, the step signs, and zero
  error and distance.
  @param(req The walk, with its start and end points set.) }
procedure PathFind(var req: Types.TPathReq);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(req The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ Tells whether a direction leads from one arena cell toward another: the target must lie in the 90-degree cone around
  the cell one step away in that direction. A target on the start cell or on the cell one step away always counts.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell.)
  @param(ty Arena row of the target cell.)
  @param(dir The direction, 0 to 7; 8 or 255 for any direction, which always counts.)
  @returns(True when the direction leads toward the target; False when a cell lies outside the arena. Note: a direction
    from 9 to 254 matches no case and leaves the result unset.) }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;

{ Walks a line between two arena cells until terrain or the range stops it. The walk stops once the doubled distance (2
  per straight step, 3 per diagonal) exceeds twice the range plus 1, or, when the arena's distance mode is 0, at a cell
  whose terrain rises above the line of sight from the start cell's clearance.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell; receives the cell where the walk stopped.)
  @param(ty Arena row of the target cell; receives the cell where the walk stopped.)
  @param(dist The range in cells; receives the doubled distance walked.)
  @param(view The arena.)
  @returns(True when the walk reached the target.) }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;

{ Builds the target list from an icon's position: each combatant with an icon on the arena is a target when a line from
  a tile of the icon reaches a tile of its icon within range, in the required direction. Each target keeps its shortest
  doubled distance and a direction toward it: the required direction itself when it is 0 to 7, otherwise the lowest
  direction that leads from the best pair of tiles. The list is then sorted by distance.
  @param(x Arena column of the icon's upper-left cell.)
  @param(y Arena row of the icon's upper-left cell.)
  @param(range The range in cells.)
  @param(filter The direction a target must lie in, 0 to 7; 8 or 255 for any direction.)
  @param(size The icon size.)
  @param(view The arena.) }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter, size: Byte; view: Pointer);

implementation

const
  { as a facing, every direction, as CENTER is }
  NO_FACING = 255;

function SignOf(v: Integer): Integer;
begin
 if v < 0 then SignOf := -1 else if v > 0 then SignOf := 1 else SignOf := 0
end;

{ Sorts the target list nearest first; on equal distance a lower direction goes first unless it is diagonal and the
  other is not. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  auxJ: Byte;
  auxI: Byte; tmp: Types.TCombatTarget;
begin
 if GDVars.targetCount <= 1 then Exit;
 for i := 1 to GDVars.targetCount - 1 do
  for j := i + 1 to GDVars.targetCount do begin
   auxI := GDVars.combatTargetData[i].dir; auxJ := GDVars.combatTargetData[j].dir;
   if (GDVars.combatTargetData[j].dist < GDVars.combatTargetData[i].dist) or
       ((GDVars.combatTargetData[j].dist = GDVars.combatTargetData[i].dist) and (auxJ < auxI) and
        (auxJ mod 2 <= auxI mod 2)) then begin
    tmp := GDVars.combatTargetData[i]; GDVars.combatTargetData[i] := GDVars.combatTargetData[j];
    GDVars.combatTargetData[j] := tmp
   end
  end
end;

procedure PathFind(var req: Types.TPathReq);
begin
 with req do begin
  cx := sx; cy := sy; adx := Abs(ex - sx); ady := Abs(ey - sy);
  stepX := Pathing.SignOf(ex - sx); stepY := Pathing.SignOf(ey - sy); err := 0; dist := 0
 end
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
{ the step's x and y, each plus 1, indexing GDConsts.dirByDelta }
var
  dxi: ShortInt;
  dyi: ShortInt;
begin
 NextPathStep := False; dxi := 1; dyi := 1;
 with req do begin
  if adx >= ady then begin
   if cx <> ex then begin
    Inc(cx, stepX); dxi := stepX + 1; Inc(err, ady); Inc(err, ady);
    Inc(dist); Inc(dist);
    if err >= adx then begin
     Dec(err, adx); Dec(err, adx); Inc(cy, stepY); dyi := stepY + 1; Inc(dist)
    end;
    NextPathStep := True
   end
  end else if cy <> ey then begin
   Inc(cy, stepY); dyi := stepY + 1; Inc(err, adx); Inc(err, adx);
   Inc(dist); Inc(dist);
   if err >= ady then begin
    Dec(err, ady); Dec(err, ady); Inc(cx, stepX); dxi := stepX + 1; Inc(dist)
   end;
   NextPathStep := True
  end;
  step := GDConsts.dirByDelta[dyi, dxi]
 end
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;
var
  walk: Types.TPathReq;
  meter: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stepped: Boolean;
  maxDist: Word;
begin
 maxDist := dist * 2 + 1;
 walk.sx := x; walk.sy := y; walk.ex := tx; walk.ey := ty; Pathing.PathFind(walk);
 meter.sx := 0;
 meter.sy := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
 if walk.adx > walk.ady then meter.ex := walk.adx else meter.ex := walk.ady;
 meter.ey := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance; Pathing.PathFind(meter);
 done := False;
 repeat
  if ((Types.PArena(view)^.distMode = 0) and
      (GDConsts.terrainInfo[Types.PArena(view)^.cells[walk.cy, walk.cx]].blocking > meter.cy)) or
        (walk.dist > maxDist) then begin
   tx := walk.cx; ty := walk.cy; dist := walk.dist; WalkLine := False; Exit
  end;
  stepped := Pathing.NextPathStep(meter); done := not Pathing.NextPathStep(walk)
 until done;
 dist := walk.dist; WalkLine := True
end;

function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
 if (x < 0) or (x > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) or (y < 0) or
     (y > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) or (tx < 0) or
     (tx > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) or (ty < 0) or
     (ty > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1) then begin
  IsDirToward := False; Exit
 end;
 if dir = Pathing.NO_FACING then dir := C_Dir.CENTER;
 nx := x + GDConsts.dirDX[dir]; ny := y + GDConsts.dirDY[dir];
 if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
  IsDirToward := True; Exit
 end;
 case dir of
  C_Dir.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
  C_Dir.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
    ((tx >= (nx + ny) - ty) and (ty <= ny));
  C_Dir.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
  C_Dir.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
    ((tx >= nx) and (ty >= (tx - nx) + ny));
  C_Dir.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
  C_Dir.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
    ((tx <= (nx + ny) - ty) and (ty >= ny));
  C_Dir.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
  C_Dir.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
    ((tx <= nx) and (ty <= (tx - nx) + ny));
  C_Dir.CENTER: IsDirToward := True
 end
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter, size: Byte; view: Pointer);
var
 i: Byte;
 bestDir: Byte;
 k: Byte;
 j: Byte;
 bestK: Byte;
 bestJ: Byte; found: Boolean;
 tx: ShortInt;
 ty: ShortInt;
 dx8: ShortInt;
 dy8: ShortInt;
 myX: array[0..3] of ShortInt;
 myY: array[0..3] of ShortInt;
 tgX: array[0..3] of ShortInt;
 tgY: array[0..3] of ShortInt;
 dist: Word;
 bestDist: Word;
begin
 for k := 0 to SizeOf(myX) - 1 do
  if CbtMap.GetIconTileDelta(size, k, dx8, dy8) then begin
   myX[k] := x + dx8; myY[k] := y + dy8
  end else myX[k] := -1;
 GDVars.targetCount := 0;
 for i := 1 to GDVars.arenaScanLimit do
  if GDVars.combatArenaLocation[i].size > 0 then begin
   found := False; bestDist := 255;
   for j := 0 to SizeOf(tgX) - 1 do
    if CbtMap.GetIconTileDelta(GDVars.combatArenaLocation[i].size, j, dx8, dy8) then begin
     tgX[j] := GDVars.combatArenaLocation[i].x + dx8; tgY[j] := GDVars.combatArenaLocation[i].y + dy8
    end else tgX[j] := -1;
   for j := 0 to SizeOf(tgX) - 1 do if tgX[j] >= 0 then
    for k := 0 to SizeOf(myX) - 1 do if myX[k] >= 0 then
     if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
      tx := tgX[j]; ty := tgY[j]; dist := range;
      if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then begin
       found := True;
       if dist < bestDist then begin bestDist := dist; bestK := k; bestJ := j end
      end
     end;
   if found then begin
    Inc(GDVars.targetCount); GDVars.combatTargetData[GDVars.targetCount].idx := i;
    GDVars.combatTargetData[GDVars.targetCount].dist := bestDist; bestDir := C_Dir.NORTH;
    if filter < C_Dir.CENTER then bestDir := filter else
     while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
      Inc(bestDir);
    GDVars.combatTargetData[GDVars.targetCount].dir := bestDir
   end
  end;
 Pathing.SortTargets
end;

begin end.
