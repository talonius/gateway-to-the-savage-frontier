{ Redraws the 3D view from the party's cell. DisplayMapView takes the event at the party's cell and picks the sky or
  ceiling color from GBVM bank 0. In CGA, while GDVars.picRegionW is set, it also derives the wall colors from the
  script's selectors through three nested helpers; in the other modes it sets the third wall color to 8. It turns the
  automap off where bank 0's no-automap flag is set, has View3D draw the view, and clears GDVars.mapRedrawPending, which
  it also clears up front whenever GDVars.picArcId is $50. Nothing is drawn while the party is defeated or bank 0's
  combat mode is set. }
{$O+,F+}
{$S+}
{$A+}
unit MapView;

interface

{ Redraws the 3D view at the party's cell and facing. }
procedure DisplayMapView;

implementation

uses C_Video, Crt, GDConsts, GDVars, View3D, C_Gbvm;

const
  { GBVM zone 0: the sky and ceiling color and the alternate sky color }
  SKY_CEILING_COLOR = $4BFD;
  ALTERNATE_SKY_COLOR = $4BFE;

procedure DisplayMapView;
var
  { Unused in this version; see the other implementations of this routine. }
  wx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  wy: Integer;

  { The ceiling's CGA color for selector w. }
  function CeilColor(w: Byte): Byte;
  begin
    case w of
      8: CeilColor := Black;
      65: CeilColor := Black;
      232: CeilColor := White;
    else
      CeilColor := White;
    end;
  end;

  { The floor's CGA color for selector w. }
  function FloorColor(w: Byte): Byte;
  begin
    case w of
      8: FloorColor := DarkGray;
      65: FloorColor := LightGray;
      232: FloorColor := LightGray;
    else
      FloorColor := LightGray;
    end;
  end;

  { The walls' CGA color for selector w. }
  function WallColor(w: Byte): Byte;
  begin
    case w of
      11: WallColor := DarkGray;
      9: WallColor := Brown;
      219: WallColor := Brown;
      6: WallColor := Blue;
    else
      WallColor := Brown;
    end;
  end;

begin
  if GDVars.picArcId = 80 then
    GDVars.mapRedrawPending := 0;
  if not GDVars.partyDefeated then begin
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    if GDVars.gbvmZone0Ptr^[C_Gbvm.COMBAT_MODE] = 0 then begin
      if GDVars.partyPos.eventAtCell > 127 then
        GDVars.colorSkyCeiling := GDConsts.skyCeilingColors[GDVars.gbvmZone0Ptr^[MapView.ALTERNATE_SKY_COLOR]]
      else
        GDVars.colorSkyCeiling := GDConsts.skyCeilingColors[GDVars.gbvmZone0Ptr^[MapView.SKY_CEILING_COLOR]];
      if GDVars.displayMode = C_Video.VM_CGA then begin
        if GDVars.picRegionW then begin
          GDVars.wallColorA := CeilColor(GDVars.ceilFloorColorSel);
          GDVars.wallColorB := FloorColor(GDVars.ceilFloorColorSel);
          GDVars.wallColorC := WallColor(GDVars.wallColorSel);
          View3D.SetView3DColors(GDVars.colorSkyCeiling, GDVars.wallColorA, GDVars.wallColorB,
                                 GDVars.wallColorC);
        end;
      end else
        GDVars.wallColorC := DarkGray;
      if GDVars.gbvmZone0Ptr^[C_Gbvm.NO_AUTOMAP] <> 0 then
        GDVars.automapOn := False;
      View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
      GDVars.mapRedrawPending := 0;
    end;
  end;
end;

begin
end.
