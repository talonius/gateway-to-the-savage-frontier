{ The main menu's input-device setting: InputConfigMenu, which CharGen's main menu runs, turns the mouse or the joystick
  on or off and rewrites GAME.CFG's input letter to match. Turning the joystick on runs this unit's own copy of the
  calibration, which prompts in the game's text window where Joystick.CalibrateJoystick writes to the DOS screen, and
  stores it in GAME.CFG; the mouse and neither choices, and turning the joystick off, write zeros for it instead. The
  unit owns no state. }
{$O+,F+,I-,S+,A+,V-}
unit InputCfg;

interface

{ Offers the mouse, the joystick or neither until the player leaves the menu. }
procedure InputConfigMenu;

implementation

uses C_Joy, C_Video, Crt, GDConsts, GDVars, Border, Joystick, Mouse, TextRend, MenuCore, Types;

procedure CalibrateJoystickInWindow; forward;

procedure InputConfigMenu;
var
  cfgName: String;
  { GAME.CFG's first eight lines; the eighth is the input letter }
  line: array[1..8] of String[80];
  list: Types.PItemRec;
  node: Types.PItemRec;
  done: Byte;
  key: Char;
  redraw: Boolean;
  sel: Integer;
  buttons: Integer;
  x: Integer;
  y: Integer;
  cur: Types.PItemRec;
  cfgIn: Text;
  cfgOut: Text;
  i: Byte;
  items: array[1..3] of String[40];
begin
  cfgName := GDVars.exeDir + 'game.cfg';
  Assign(cfgIn, cfgName);
  Reset(cfgIn);
  for i := 1 to 8 do begin line[i] := ''; ReadLn(cfgIn, line[i]) end;
  Close(cfgIn);
  MenuCore.AllocStringList(3, list);
  redraw := True; done := 0; cur := list; sel := 0;
  repeat
    if GDVars.isMouseOn then items[1] := 'mouse ON' else items[1] := 'mouse OFF';
    if GDVars.isJoystickOn then items[2] := 'joystick ON' else items[2] := 'joystick OFF';
    items[3] := 'disable both';
    node := list;
    for i := 1 to 3 do begin node^.name := items[i]; node^.inUse := 0; node := node^.next end;
    redraw := True;
    key := MenuCore.MenuVertical('Init Mouse/Joystick: ', 'Select', LightMagenta, LightGreen, White, 9, 12, 38, 22,
                                 list, True, redraw, sel, cur);
    if key = 'S' then case sel of
      0: begin
        GDVars.isMouseOn := not GDVars.isMouseOn;
        if (GDVars.displayMode = C_Video.VM_TANDY) and GDVars.isMouseOn then begin
          GDVars.displayStatusAndWaitProc('Sorry. Tandy doesn''t support mouse.');
          GDVars.isMouseOn := False
        end;
        Assign(cfgOut, cfgName); Rewrite(cfgOut);
        if GDVars.isMouseOn then begin
          GDVars.canClickParty := 1; GDVars.mouseButtons := 0; Mouse.InitMouse;
          if GDVars.isMouseOn then begin
            if GDVars.displayMode = C_Video.VM_CGA then GDVars.mouseCursorMask := @GDConsts.cursorMaskCga
            else GDVars.mouseCursorMask := @GDConsts.cursorMaskEga;
            Mouse.SetMouseCursor(0, 0, GDVars.mouseCursorMask); GDVars.isMouseScaled := True;
            Mouse.SetMouse(639, 100); Mouse.GetMouse(buttons, x, y);
            GDVars.isMouseScaled := (x >= 321) = False; GDVars.isJoystickOn := False; Mouse.ShowMouse;
            line[8] := 'M';
            GDVars.mouseX := 160; GDVars.mouseY := 100; GDVars.mouseOldX := 0; GDVars.mouseOldY := 0
          end
        end;
        if not GDVars.isMouseOn then begin
          line[8] := 'N';
          GDVars.isMouseOn := True; Mouse.HideMouse; GDVars.isMouseOn := False
        end;
        for i := 1 to 8 do WriteLn(cfgOut, line[i]);
        for i := 0 to 13 do WriteLn(cfgOut, '0');
        Close(cfgOut)
      end;
      1: begin
        GDVars.isJoystickOn := not GDVars.isJoystickOn;
        Assign(cfgOut, cfgName); Rewrite(cfgOut);
        if GDVars.isJoystickOn then begin
          InputCfg.CalibrateJoystickInWindow;
          if GDVars.isJoystickOn then begin
            line[8] := 'J';
            if GDVars.isJoystickOn then begin Mouse.HideMouse; GDVars.isMouseOn := False end
          end
        end;
        if not GDVars.isJoystickOn then begin
          line[8] := 'N';
          for i := 0 to 6 do begin
            GDVars.joystickCalibration[1].x[i] := 0; GDVars.joystickCalibration[1].y[i] := 0
          end
        end;
        for i := 1 to 8 do WriteLn(cfgOut, line[i]);
        for i := 0 to 6 do begin
          WriteLn(cfgOut, GDVars.joystickCalibration[1].x[i]);
          WriteLn(cfgOut, GDVars.joystickCalibration[1].y[i])
        end;
        Close(cfgOut)
      end;
      2: begin
        GDVars.isJoystickOn := False; Mouse.HideMouse; GDVars.isMouseOn := False;
        Assign(cfgOut, cfgName); Rewrite(cfgOut);
        line[8] := 'N';
        for i := 1 to 8 do WriteLn(cfgOut, line[i]);
        for i := 0 to 13 do WriteLn(cfgOut, '0');
        Close(cfgOut)
      end
    end else done := 1
  until done <> 0;
  MenuCore.FreeStringList(list)
end;

{ Calibrates joystick 1 in the text window, like Joystick.CalibrateJoystick: exits at once when Joystick.ProbeJoystick
  finds no stick; otherwise the center from 20 readings, then the upper-left and lower-right extremes with button 1
  down, and boundaries a third and two thirds of the way to the center. 20000 polls without a press, or a failed read,
  abort with "Unable to read joystick"; success enables the joystick. }
procedure CalibrateJoystickInWindow;
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
    ok := Byte(Joystick.ReadJoystick(1, x, y, buttons)); Inc(sumX, x); Inc(sumY, y)
  end;
  GDVars.joystickCalibration[1].x[3] := sumX div C_Joy.CALIBRATION_SAMPLES;
  GDVars.joystickCalibration[1].y[3] := sumY div C_Joy.CALIBRATION_SAMPLES;
  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme upper');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'left position and press button #1.');
    j := 0;
    repeat ok := Byte(Joystick.ReadJoystick(1, x, y, buttons)); Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22); TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000); Exit
    end;
    sumX := 65535; sumY := 65535;
    for GDVars.sharedLoopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin if x < sumX then sumX := x; if y < sumY then sumY := y end
      end else begin
        Border.ClearBox(1, 1, 38, 22); TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
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
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme lower');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'right position and press button #1.');
    j := 0;
    repeat ok := Byte(Joystick.ReadJoystick(1, x, y, buttons)); Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22); TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000); Exit
    end;
    sumX := 0; sumY := 0;
    for GDVars.sharedLoopIndex := 1 to C_Joy.CALIBRATION_SAMPLES do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin if x > sumX then sumX := x; if y > sumY then sumY := y end
      end else begin
        Border.ClearBox(1, 1, 38, 22); TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
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

begin end.
