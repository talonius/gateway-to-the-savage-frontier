{ Game-port joystick input and calibration. CalibrateJoystick, which Config calls, samples stick 1 at the center and two
  corners into GDVars.joystickCalibration; the private JoyZone turns a reading into a compass zone through
  GDConsts.joystickZoneMap, JoyButton tests one button, and GetJoystick combines both for GameIo's key input and
  MenuCore's wait for button release. ReadJoystick is the sampling leaf in joystick.asm; InputCfg has its own copy of
  the calibration. The unit owns no state. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Joystick;

interface

{ Calibrates joystick 1 and enables it. The center is the average of 20 readings; the player then holds the stick at the
  upper-left and lower-right extremes with button 1 down, each taken as the extreme of 20 readings, and the boundaries
  lie a third and two thirds of the way from each extreme to the center. 20000 polls without a press, or a failed read,
  abort the calibration with a message. Does nothing when the joystick cannot be read. }
procedure CalibrateJoystick;

{ Clears both calibration records; when the joystick is enabled, keeps it enabled only if joystick 1 can be read. }
procedure ProbeJoystick;

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives all four button bits of both joysticks, inverted so a set bit is a pressed button and shifted
    to the low nibble.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;

{ Tells whether a joystick button is pressed. Joystick 1's buttons are bits 0 and 1 of the button byte, joystick 2's
  bits 2 and 3; another joystick or button number reads as not pressed.
  @param(joy Joystick 1 or 2.)
  @param(button Button 1 or 2.)
  @returns(True when the button is down; False when the joystick is off or cannot be read.) }
function JoyButton(joy, button: Byte): Boolean;

{ Reads joystick 1 as input: a pressed button and the stick's zone.
  @param(button Receives 2 when button 2 is down, else 1 when button 1 is down, else 0.)
  @param(zone Receives the stick's zone, from JoyZone.) }
procedure GetJoystick(var button: Integer; var zone: Byte);

implementation

uses C_Joy, Crt, GDConsts, GDVars;

{$L JOYSTICK.OBJ}
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean; external;

procedure ProbeJoystick;
var
  x: Word;
  y: Word; b: Byte;
begin
  FillChar(GDVars.joystickCalibration, SizeOf(GDVars.joystickCalibration), 0);
  if GDVars.isJoystickOn then
    GDVars.isJoystickOn := Joystick.ReadJoystick(1, x, y, b);
end;

{ Reads a joystick and places each axis among its calibrated boundaries 1..5, then looks the column and row up in the
  zone map.
  @param(joy Joystick 1 or 2.)
  @returns(The zone from the zone map, or the no-zone value when the joystick is off or cannot be read.) }
function JoyZone(joy: Byte): Byte;
var
  x: Word;
  y: Word;
  col: Integer;
  row: Integer;
  b: Byte;
begin
  JoyZone := C_Joy.NO_ZONE;
  if not GDVars.isJoystickOn then Exit;
  if not Joystick.ReadJoystick(joy, x, y, b) then Exit;
  col := 0;
  for GDVars.sharedLoopIndex := 1 to 5 do
    if GDVars.joystickCalibration[joy].x[GDVars.sharedLoopIndex] < x then col := GDVars.sharedLoopIndex;
  row := 0;
  for GDVars.sharedLoopIndex := 1 to 5 do
    if GDVars.joystickCalibration[joy].y[GDVars.sharedLoopIndex] < y then row := GDVars.sharedLoopIndex;
  JoyZone := GDConsts.joystickZoneMap[row, col];
end;

function JoyButton(joy, button: Byte): Boolean;
var mask: Byte; x: Word; y: Word; b: Byte;
begin
  JoyButton := False;
  if not GDVars.isJoystickOn then Exit;
  mask := 0;
  b := 0;
  if Joystick.ReadJoystick(joy, x, y, b) then
    case joy of
      1: case button of 1: mask := 1; 2: mask := 2 end;
      2: case button of 1: mask := 4; 2: mask := 8 end;
    end;
  JoyButton := (b and mask) > 0;
end;

procedure GetJoystick(var button: Integer; var zone: Byte);
begin
  button := 0;
  if Joystick.JoyButton(1, 2) then button := 2
  else if Joystick.JoyButton(1, 1) then button := 1;
  zone := Joystick.JoyZone(1);
end;

procedure CalibrateJoystick;
var
  sumX: Word;
  sumY: Word;
  ok: Byte;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  reading: Byte;
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.isJoystickOn then Exit;
  sumX := 0; sumY := 0;
  for j := 1 to C_Joy.CALIBRATION_SAMPLES do begin
    ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
    Inc(sumX, x); Inc(sumY, y)
  end;
  GDVars.joystickCalibration[1].x[3] := sumX div C_Joy.CALIBRATION_SAMPLES;
  GDVars.joystickCalibration[1].y[3] := sumY div C_Joy.CALIBRATION_SAMPLES;
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme upper left position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons)); Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr; WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000); Exit
    end;
    sumX := 65535; sumY := 65535;
    for GDVars.sharedLoopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y
        end
      end else begin
        ClrScr; WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000); Exit
      end
  until ok <> 0;
  GDVars.joystickCalibration[1].x[0] := sumX;
  GDVars.joystickCalibration[1].x[1] :=
    GDVars.joystickCalibration[1].x[0] +
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) div 3;
  GDVars.joystickCalibration[1].x[2] :=
    GDVars.joystickCalibration[1].x[0] +
    (GDVars.joystickCalibration[1].x[3] - GDVars.joystickCalibration[1].x[0]) * 2 div 3;
  GDVars.joystickCalibration[1].y[0] := sumY;
  GDVars.joystickCalibration[1].y[1] :=
    GDVars.joystickCalibration[1].y[0] +
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) div 3;
  GDVars.joystickCalibration[1].y[2] :=
    GDVars.joystickCalibration[1].y[0] +
    (GDVars.joystickCalibration[1].y[3] - GDVars.joystickCalibration[1].y[0]) * 2 div 3;
  repeat until not Joystick.JoyButton(1, 1);
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme lower right position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons)); Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr; WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000); Exit
    end;
    sumX := 0; sumY := 0;
    for GDVars.sharedLoopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y
        end
      end else begin
        ClrScr; WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000); Exit
      end
  until ok <> 0;
  GDVars.joystickCalibration[1].x[6] := sumX;
  GDVars.joystickCalibration[1].x[4] :=
    GDVars.joystickCalibration[1].x[3] +
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) div 3;
  GDVars.joystickCalibration[1].x[5] :=
    GDVars.joystickCalibration[1].x[3] +
    (GDVars.joystickCalibration[1].x[6] - GDVars.joystickCalibration[1].x[3]) * 2 div 3;
  GDVars.joystickCalibration[1].y[6] := sumY;
  GDVars.joystickCalibration[1].y[4] :=
    GDVars.joystickCalibration[1].y[3] +
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) div 3;
  GDVars.joystickCalibration[1].y[5] :=
    GDVars.joystickCalibration[1].y[3] +
    (GDVars.joystickCalibration[1].y[6] - GDVars.joystickCalibration[1].y[3]) * 2 div 3;
  GDVars.isJoystickOn := True
end;

begin
end.
