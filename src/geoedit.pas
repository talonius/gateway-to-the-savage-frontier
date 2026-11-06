{ The GEO map editor, a developer tool reached from Explore while GDVars.superMode is set. It edits the loaded map's
  walls, barriers, events and indoor flag cell by cell in the 3D view, and saves and loads the map as ..\geo\GEOnn. Its
  map number, wall sets, step, wall type, file names and menus are in GDConsts and GDVars. }
{$O+,F+,I-,S+,A+}
unit GeoEdit;

interface

{ Runs the editor's command loop on the party's cell and facing until E or Delete. It does nothing unless
  GDVars.superMode is set. }
procedure GeoEditor;

implementation

uses C_Dir, C_Keys, C_Msg, Crt, GDConsts, GDVars, MapView, View3D, TextRend, MenuCore, CharHlp, C_Gbvm;

const
  { a cell's event bit the editor shows as location=inside }
  INDOOR_FLAG = $80;

type
  { GBVM zone 0 (GDVars.gbvmZone0Ptr) as far as GeoEdit reads it as bytes: the low byte of the loaded GEO map's number
    (C_Gbvm.GEO_MAP_ID). }
  PZone0 = ^TZone0;
  TZone0 = record
    geoMapIdLead: array[0..$189] of Byte;
    geoMapId: Byte;
  end;

{ Formats a number in decimal.
  @param(v The number.)
  @returns(Its digits.) }
function GeoByteStr(v: Byte): String;
var s: String;
begin
  Str(v:0, s);
  GeoByteStr := s;
end;

{ Write the map to ..\geo\GEOnn, nn the editor's map number, after the file's header; I/O errors are ignored. }
procedure SaveMapFile;
var
  f: File;
  { Unused in this version; see the other implementations of this routine. }
  err: Byte;
  result: Word;
begin
  GDConsts.geoSaveName[5] := Chr(GDVars.geoMapNumber mod 10 + Ord('0'));
  GDConsts.geoSaveName[4] := Chr(GDVars.geoMapNumber div 10 + Ord('0'));
  Assign(f, '..\geo\' + GDConsts.geoSaveName);
  Rewrite(f, 1);
  BlockWrite(f, GDConsts.geoFileHeader, SizeOf(GDConsts.geoFileHeader));
  BlockWrite(f, GDVars.map3d^, SizeOf(Types.TGeoMap), result);
  Close(f);
  err := IOResult;
end;

{ Read the map from ..\geo\GEOnn, nn the editor's map number, past the file's 2-byte header; I/O errors are ignored. }
procedure LoadMapFile;
var
  f: File;
  { Unused in this version; see the other implementations of this routine. }
  err: Byte;
  result: Word;
begin
  GDConsts.geoLoadName[5] := Chr(GDVars.geoMapNumber mod 10 + Ord('0'));
  GDConsts.geoLoadName[4] := Chr(GDVars.geoMapNumber div 10 + Ord('0'));
  Assign(f, '..\geo\' + GDConsts.geoLoadName);
  Reset(f, 1);
  Seek(f, 2);
  BlockRead(f, GDVars.map3d^, SizeOf(Types.TGeoMap), result);
  Close(f);
  err := IOResult;
end;

{ Sets the 2-bit field of a cell's barrier byte that starts at bit field (0, 2, 4 or 6). Outside the view's coordinates
  the edit is made only while GDVars.eclScript is nonzero, and never off the map.
  @param(x The map column.)
  @param(y The map row.)
  @param(field The side's first bit: 0, 2, 4 or 6.)
  @param(value The barrier, 0..3.) }
procedure SetMapField(x, y: ShortInt; field, value: Byte);
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then Exit;
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then Exit;
  value := value and 3;
  case field of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := (GDVars.map3d^.barriers[y, x] and $3F) or (value shl 6);
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := (GDVars.map3d^.barriers[y, x] and $CF) or (value shl 4);
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := (GDVars.map3d^.barriers[y, x] and $F3) or (value shl 2);
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := (GDVars.map3d^.barriers[y, x] and $FC) or value;
  end;
end;

{ Sets the wall on side field (0, 2, 4 or 6) of a cell, a nibble of wallsNE or wallsSW, under SetMapField's conditions.
  @param(x The map column.)
  @param(y The map row.)
  @param(field The side: 0, 2, 4 or 6.)
  @param(value The wall type, 0..15.) }
procedure SetWallField(x, y: ShortInt; field, value: Byte);
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then Exit;
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then Exit;
  value := value and $0F;
  case field of
    C_Dir.NORTH: GDVars.map3d^.wallsNE[y, x] := (GDVars.map3d^.wallsNE[y, x] and $0F) or (value shl 4);
    C_Dir.EAST: GDVars.map3d^.wallsNE[y, x] := (GDVars.map3d^.wallsNE[y, x] and $F0) or value;
    C_Dir.SOUTH: GDVars.map3d^.wallsSW[y, x] := (GDVars.map3d^.wallsSW[y, x] and $0F) or (value shl 4);
    C_Dir.WEST: GDVars.map3d^.wallsSW[y, x] := (GDVars.map3d^.wallsSW[y, x] and $F0) or value;
  end;
end;

{ Sets a cell's event byte under SetMapField's conditions.
  @param(x The map column.)
  @param(y The map row.)
  @param(value The event byte.) }
procedure SetMapEvent(x, y: ShortInt; value: Byte);
begin
  if not View3D.Valid3DCoords(x, y) and (GDVars.eclScript = 0) then Exit;
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then Exit;
  GDVars.map3d^.events[y, x] := value;
end;

{ The F command's submenu: the map number, the three wall sets, the step, the wall-set load, saving and loading the map,
  the overland/dungeon switch and the event display. }
procedure MapOptions;
var
  i: Byte;
  c: Char;
  ext: Boolean;
begin
  repeat
    TextRend.ClearRect(1, 18, 38, 22);
    TextRend.DisplayString(20, 18, LightGreen, Black, 'map=' + GeoEdit.GeoByteStr(GDVars.geoMapNumber));
    for i := 1 to 3 do
      TextRend.DisplayString(1, i + 17, LightGreen, Black,
                             'wall' + GeoEdit.GeoByteStr(i) + '=' + GeoEdit.GeoByteStr(GDVars.geoWallSets[i]));
    if GDVars.geoStep = 1 then
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=inc')
    else
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=dec');
    if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then
      TextRend.DisplayString(20, 22, LightGreen, Black, 'Overland')
    else
      TextRend.DisplayString(20, 22, LightGreen, Black, 'Dungeon ');
    c := MenuCore.MenuHorizontal('', GDConsts.mapOptionsMenu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if c = C_Keys.DELETE_KEY then begin
        TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        Exit;
      end;
    end else
      case c of
        '1', '2', '3': begin
          GDVars.geoWallSets[Ord(c) - Ord('0')] := GDVars.geoWallSets[Ord(c) - Ord('0')] + GDVars.geoStep;
        end;
        'D': if GDVars.geoStep = 1 then
               GDVars.geoStep := -1
             else
               GDVars.geoStep := 1;
        'W': begin
          for i := 1 to 3 do
            if GDVars.geoWallSets[i] <> 255 then
              View3D.LoadWallSet(GDVars.geoWallSets[i], i);
          MapView.DisplayMapView;
        end;
        'S': GeoEdit.SaveMapFile;
        'L': begin
          GeoEdit.LoadMapFile;
          MapView.DisplayMapView;
        end;
        'M': begin
          GDVars.geoMapNumber := GDVars.geoMapNumber + GDVars.geoStep;
          if GDVars.geoMapNumber = 100 then GDVars.geoMapNumber := 0;
          if GDVars.geoMapNumber = 255 then GDVars.geoMapNumber := 99;
        end;
        'E': begin
          TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
          Exit;
        end;
        'O': begin
          if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] := 1
          else GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] := 0;
          MapView.DisplayMapView;
        end;
        'I': begin
          GDVars.automapOn := True;
          GDConsts.areEventsShown := GDConsts.areEventsShown = False;
          MapView.DisplayMapView;
        end;
      end;
  until False;
end;

{ Copies a cell to the eight cells around it: its event and, on the overland, its wallsNE byte, which is stored without
  SetMapEvent's checks, so at the map's edge it lands outside the plane; in a dungeon the copies keep only the indoor
  flag and lose their walls and barriers.
  @param(x The map column.)
  @param(y The map row.) }
procedure CopyCellArea(x, y: ShortInt);
var
  xx: ShortInt;
  yy: ShortInt;
  field: Byte;
begin
  if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then begin
    for xx := x - 1 to x + 1 do
      for yy := y - 1 to y + 1 do begin
        GeoEdit.SetMapEvent(xx, yy, View3D.GetMapEvent(x, y));
        GDVars.map3d^.wallsNE[yy, xx] := GDVars.map3d^.wallsNE[y, x];
      end;
  end else begin
    for xx := x - 1 to x + 1 do
      for yy := y - 1 to y + 1 do begin
        GeoEdit.SetMapEvent(xx, yy, View3D.GetMapEvent(x, y) and GeoEdit.INDOOR_FLAG);
        field := 0;
        while field <= 6 do begin
          GeoEdit.SetMapField(xx, yy, field, 0);
          GeoEdit.SetWallField(xx, yy, field, 0);
          field := field + 2;
        end;
      end;
  end;
end;

procedure GeoEditor;
var
  wall: Byte;
  eventValue: Byte;
  ext: Boolean;
  c: Char;
begin
  if GDVars.superMode = 0 then Exit;
  if not GDConsts.isGeoEditorInitialized then
    GDVars.geoMapNumber := PZone0(GDVars.gbvmZone0Ptr)^.geoMapId;
  GDConsts.isGeoEditorInitialized := True;
  TextRend.DisplayString(1, 17, LightGreen, Black, 'Geo Editor');
  if GDVars.geoStep <> -1 then GDVars.geoStep := 1;
  { The wall sets View3D has loaded: each cached WALLDEF id's low byte. }
  GDVars.geoWallSets[1] := Byte(GDVars.wallSetCache[1].wallDefId);
  GDVars.geoWallSets[2] := Byte(GDVars.wallSetCache[2].wallDefId);
  GDVars.geoWallSets[3] := Byte(GDVars.wallSetCache[3].wallDefId);
  repeat
    TextRend.ClearRect(1, 18, 38, 22);
    if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] = 0 then
      TextRend.DisplayString(1, 18, LightGreen, Black,
                             'wall=' +
                             GeoEdit.GeoByteStr(GDVars.map3d^.wallsNE[GDVars.partyPos.mapY, GDVars.partyPos.mapX]))
    else
      TextRend.DisplayString(1, 18, LightGreen, Black,
                             'wall=' +
                             GeoEdit.GeoByteStr(View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing)));
    TextRend.DisplayString(1, 19, LightGreen, Black,
                           'block=' +
                           GDConsts.barrierNames [View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                        GDVars.partyPos.facing)]);
    TextRend.DisplayString(1, 20, LightGreen, Black,
                           'special=' +
                           GeoEdit.GeoByteStr(View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) and $7F));
    if (View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) and GeoEdit.INDOOR_FLAG) = 0 then
      TextRend.DisplayString(1, 21, LightGreen, Black, 'location=outdoors')
    else
      TextRend.DisplayString(1, 21, LightGreen, Black, 'location=inside');
    if GDVars.geoStep = 1 then
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=inc')
    else
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=dec');
    c := MenuCore.MenuHorizontal('', GDConsts.geoEditorMenu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if c = C_Keys.DELETE_KEY then begin
        TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        Exit;
      end;
    end else
      case c of
        'W': begin
          if GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] <> 0 then begin
            GDVars.newWallType := GDVars.newWallType and $0F;
            wall := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
            if GDVars.newWallType = wall then
              GDVars.newWallType := (wall + GDVars.geoStep) and $0F;
            GeoEdit.SetWallField(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing,
                                 GDVars.newWallType);
          end else
            Inc(GDVars.map3d^.wallsNE[GDVars.partyPos.mapY, GDVars.partyPos.mapX], GDVars.geoStep);
          MapView.DisplayMapView;
        end;
        'S': begin
          eventValue := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
          eventValue := (eventValue and GeoEdit.INDOOR_FLAG) + ((eventValue + GDVars.geoStep) and $7F);
          GeoEdit.SetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY, eventValue);
        end;
        'B': GeoEdit.SetMapField(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing,
                                 View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                       GDVars.partyPos.facing) + GDVars.geoStep);
        'L': begin
          GeoEdit.SetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                              View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) xor GeoEdit.INDOOR_FLAG);
          MapView.DisplayMapView;
        end;
        'D': if GDVars.geoStep = 1 then GDVars.geoStep := -1
             else GDVars.geoStep := 1;
        'E': begin
          TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
          Exit;
        end;
        'C': begin
          GeoEdit.CopyCellArea(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
          MapView.DisplayMapView;
        end;
        'F': begin
          GeoEdit.MapOptions;
          MapView.DisplayMapView;
        end;
        'M': begin
          Inc(GDVars.partyPos.mapX, GDConsts.dirDX[GDVars.partyPos.facing]);
          Inc(GDVars.partyPos.mapY, GDConsts.dirDY[GDVars.partyPos.facing]);
          GDVars.partyPos.mapX := GDVars.partyPos.mapX and $0F;
          GDVars.partyPos.mapY := GDVars.partyPos.mapY and $0F;
          CharHlp.PrintPositionAndTime;
          MapView.DisplayMapView;
        end;
      end;
  until False;
end;

begin
  GDVars.newWallType := 0;
end.
