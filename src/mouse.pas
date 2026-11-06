{ The INT 33h mouse driver calls: each stages a driver function in GDVars.interruptRegisters and calls the interrupt.
  InitMouse detects the driver; while GDVars.isMouseOn is False the other calls leave the driver alone (GetMouse still
  clears its button result). The unit owns no state. }
{$F+,O+,S+,R-,V-,B-,I-}
unit Mouse;

interface

{ Resets the mouse driver through INT 33h; when a driver answers, marks the mouse present and records the button count,
  otherwise marks it absent. }
procedure InitMouse;

{ Shows the mouse cursor. Does nothing without a mouse. }
procedure ShowMouse;

{ Hides the mouse cursor. Does nothing without a mouse. }
procedure HideMouse;

{ Reads the pointer (function 3).
  @param(buttons The driver's button bits; 0 while GDVars.isMouseOn is False.)
  @param(x The driver's x, halved unless GDVars.isMouseScaled.)
  @param(y The driver's y.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the mouse cursor, doubling the column unless the mouse's scale flag is set. Does nothing without a mouse.
  @param(x Column.)
  @param(y Row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor shape and hot spot. Does nothing without a mouse.
  @param(hotX Hot spot column within the cursor.)
  @param(hotY Hot spot row within the cursor.)
  @param(mask Screen and cursor masks of the shape.) }
procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);

{ Resets the mouse driver's software state. Does nothing without a mouse. }
procedure ResetMouse;

implementation

uses Dos, GDConsts, GDVars;

const
  { the mouse driver's functions, staged in AX }
  { detects and resets the driver: AX returns $FFFF when one is present, BX its buttons }
  DRIVER_RESET = $00;
  { shows the cursor }
  DRIVER_SHOW_CURSOR = $01;
  { hides the cursor }
  DRIVER_HIDE_CURSOR = $02;
  { returns the buttons in BX, x in CX and y in DX }
  DRIVER_GET_STATE = $03;
  { moves the cursor to x in CX, y in DX }
  DRIVER_SET_POSITION = $04;
  { sets the cursor shape: hot spot in BX and CX, masks at ES:DX }
  DRIVER_SET_CURSOR = $09;
  { the driver's software reset }
  DRIVER_SOFT_RESET = $21;

var
  { GDVars' register block as the Dos.Registers that Dos.Intr takes (its type, Types.TInterruptRegisters, cannot name
    Dos.Registers, because Types uses no unit) }
  regs: Registers absolute GDVars.interruptRegisters;

procedure InitMouse;
begin
  regs.AX := Mouse.DRIVER_RESET;
  Intr($33, regs);
  if regs.AX = $FFFF then begin
    GDVars.mouseButtons := regs.BX;
    GDVars.isMouseOn := True;
  end else
    GDVars.isMouseOn := False;
end;

procedure ShowMouse;
begin
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_SHOW_CURSOR;
  Intr($33, regs);
end;

procedure HideMouse;
begin
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_HIDE_CURSOR;
  Intr($33, regs);
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  buttons := 0;
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_GET_STATE;
  Intr($33, regs);
  buttons := regs.BX;
  x := regs.CX;
  if not GDVars.isMouseScaled then x := x div 2;
  y := regs.DX;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_SET_POSITION;
  if not GDVars.isMouseScaled then x := x shl 1;
  regs.CX := x;
  regs.DX := y;
  Intr($33, regs);
end;

procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);
begin
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_SET_CURSOR;
  regs.BX := hotX;
  regs.CX := hotY;
  regs.ES := Seg(mask^);
  regs.DX := Ofs(mask^);
  Intr($33, regs);
end;

procedure ResetMouse;
begin
  if not GDVars.isMouseOn then Exit;
  regs.AX := Mouse.DRIVER_SOFT_RESET;
  Intr($33, regs);
end;

begin
end.
