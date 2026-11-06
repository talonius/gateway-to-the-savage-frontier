{ Keyboard, mouse and joystick input, the hotkeys, and the game's exit. The private RawPending and RawKey keep a
  two-byte key queue, queuedKeyCount and queuedKeyBytes, fed by the BIOS calls in kbdcore.asm; an extended key is queued
  as #0 then its scan code. ReadGameKey takes a key, or a button or joystick zone from the device in use, and runs the
  hotkeys before it answers: Ctrl-S switches sound off and on, Ctrl-D switches logging to debug.txt, Ctrl-Z walks the
  creature list while logging, and Ctrl-C ends the game through ExitGame. The unit owns no state. }
{$F+,O+,S+,I+,R-,V-,B-}
{$A-}
unit GameIo;

interface

{ Ends the game at once: resets the mouse, restores GDVars.soundMode, passes SoundDrv.SoundCommand the 255 control
  (which plays nothing), restores GDVars.savedVideoMode, closes debug.txt while logging, undoes GameBoot's Tandy heap
  reserve (GameBoot.AdjustHeap), and halts. }
procedure ExitGame;

{ Waits for a key or, while a mouse or joystick is in use, for a button (Enter or Escape) or a joystick zone (the scan
  code joystickDirectionKeys gives); in the demo with neither in use and no key waiting it answers #0 at once. Runs the
  hotkeys, and sets GDVars.isMouseClick when the mouse took a button.
  @returns(The key, #0 for an extended key whose scan code the next call returns, or #0 in the demo.) }
function ReadGameKey: Char;

{ Tells whether input is waiting.
  @returns(True when a key is waiting, a mouse button is down, or -- without a mouse -- a joystick button is down or the
    stick is out of the center.) }
function InputPending: Boolean;

{ Discards every waiting key. }
procedure DrainKeys;

{ Reads and discards one waiting input through ReadGameKey, so its control-key commands still work. }
procedure DiscardPendingKeys;

{ Waits until no mouse button is down, while the mouse is in use. }
procedure WaitMouseRelease;

{ Does nothing; Camp, CharGen, Ending, Explore, PostCbt, Shop, Temple and Vault call it. }
procedure KbdNoop;

implementation

uses Dos, GDConsts, GDVars, C_Keys, C_Joy, C_Sound, C_Video, Types, Joystick, Mouse, SoundDrv, GameBoot;

const
  KEY_CTRL_C = #3;
  KEY_CTRL_D = #4;
  KEY_CTRL_S = #19;
  KEY_CTRL_Z = #26;
  { a mouse's left button, or a joystick's button 1 }
  FIRST_BUTTON = 1;
  { a mouse's right button, or a joystick's button 2 }
  SECOND_BUTTON = 2;

{$L KBDCORE.OBJ}

{ Read a key through the BIOS.
  @returns(Its scan code in the high byte and its ASCII code in the low byte.) }
function BiosRead: Word; near; external;

{ Return whether the BIOS has a key waiting.
  @returns(True when a key waits.) }
function BiosPending: Boolean; near; external;

{ Refills the key queue from the BIOS when it is empty. Scan code 161, and 86 with '.', become Delete (83); 243 and 244
  become 76 and 77; the cursor keypad's scan codes and 130 are queued as extended keys whatever ASCII the BIOS gave.
  @returns(True when a key is queued.) }
function RawPending: Boolean;
var
  work: record
    { unused }
    keyLead: Byte;
    key: Word;
    { unused }
    keyTail: Byte
  end;
begin
  RawPending := True;
  if GDConsts.queuedKeyCount = 0 then begin
    repeat
    RawPending := False;
    if not GameIo.BiosPending then Exit; work.key := GameIo.BiosRead; GDConsts.queuedKeyCount := 1;
    GDVars.queuedKeyBytes[1] := Byte(work.key and $FF);
    GDVars.queuedKeyBytes[2] := Byte(work.key shr 8);
    if (GDVars.queuedKeyBytes[2] = 161) or
        ((GDVars.queuedKeyBytes[2] = 86) and
         (GDVars.queuedKeyBytes[1] = Ord('.'))) then GDVars.queuedKeyBytes[2] := Ord(C_Keys.DELETE_KEY);
    if GDVars.queuedKeyBytes[2] in [243, 244] then
      GDVars.queuedKeyBytes[2] := GDVars.queuedKeyBytes[2] + 76 - 243;
    if GDVars.queuedKeyBytes[2] in [Ord(C_Keys.HOME), Ord(C_Keys.UP), Ord(C_Keys.PAGE_UP), Ord(C_Keys.LEFT), 76,
                             Ord(C_Keys.RIGHT), Ord(C_Keys.END_KEY), Ord(C_Keys.DOWN), Ord(C_Keys.PAGE_DOWN),
                             Ord(C_Keys.DELETE_KEY), 130] then
      GDVars.queuedKeyBytes[1] := 0;
    if GDVars.queuedKeyBytes[1] = 0 then begin
      GDVars.queuedKeyBytes[1] := GDVars.queuedKeyBytes[2]; GDVars.queuedKeyBytes[2] := 0;
      GDConsts.queuedKeyCount := 2
    end else begin GDVars.queuedKeyBytes[2] := 255; GDConsts.queuedKeyCount := 1 end;
    until GDConsts.queuedKeyCount <> 0;
    RawPending := True
  end;
end;

{ Waits for a key and takes the next byte from the queue.
  @returns(The key byte.) }
function RawKey: Char;
begin
  while not GameIo.RawPending do;
  RawKey := Char(GDVars.queuedKeyBytes[GDConsts.queuedKeyCount]);
  GDConsts.queuedKeyCount := GDConsts.queuedKeyCount - 1
end;

procedure ExitGame;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  Mouse.ResetMouse;
  GDVars.soundMode := GDVars.soundSaved;
  SoundDrv.SoundCommand(255);
  GDVars.interruptRegisters.ah := C_Video.BIOS_SET_VIDEO_MODE;
  GDVars.interruptRegisters.al := GDVars.savedVideoMode;
  Intr($10, Registers(GDVars.interruptRegisters));
  if GDConsts.debugOn <> 0 then Close(GDVars.debugFile);
  GameBoot.AdjustHeap; Halt(0)
end;

{ Does nothing; in debug mode the game-key reader's Ctrl-Z handler calls it for each creature in the party list.
  @param(creature Unused.) }
procedure DumpWhoList(creature: Types.PWork);
var
  { Unused in this version; see the other implementations of this routine. }
  cur: Pointer;
begin end;

function ReadGameKey: Char;
var c: Char; creature: Types.PWork;
    device: record done: Byte; zone: Byte; button: Integer end;
    { Unused in this version; see the other implementations of this routine. }
    buttonState: Word;

  { Wait for a key, a joystick zone (queued as its arrow key) or a button (Enter or Escape). }
  procedure TranslateJoystick;
  begin
    device.button := 0; device.done := 0;
    while not (GameIo.RawPending or (device.done <> 0)) do begin
      Joystick.GetJoystick(device.button, device.zone);
      if (device.zone < C_Joy.NO_ZONE) or Boolean(device.button <> 0) then begin
        if device.zone < C_Joy.NO_ZONE then begin
          GDConsts.queuedKeyCount := 2;
          GDVars.queuedKeyBytes[1] := Byte(GDConsts.joystickDirectionKeys[device.zone]);
          GDVars.queuedKeyBytes[2] := 0; c := #0
        end else case device.button of GameIo.FIRST_BUTTON: c := C_Keys.ENTER; GameIo.SECOND_BUTTON: c :=
            C_Keys.ESCAPE end;
        device.done := 1
      end
    end
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    device.button := 0; device.done := 0;
    while not (GameIo.RawPending or (device.done <> 0)) do begin
      Mouse.GetMouse(device.button, GDVars.mouseX, GDVars.mouseY);
      if device.button <> 0 then begin
        case device.button of GameIo.FIRST_BUTTON: c := C_Keys.ENTER; GameIo.SECOND_BUTTON: c := C_Keys.ESCAPE end;
        GDVars.isMouseClick := True; device.done := 1
      end
    end
  end;
begin
  GDVars.isMouseClick := False;
  if GameIo.RawPending then c := GameIo.RawKey
  else if GDVars.isJoystickOn or GDVars.isMouseOn then begin
    if GDVars.isMouseOn then TranslateMouse else TranslateJoystick;
    if GameIo.RawPending then c := GameIo.RawKey
  end else if GDVars.demoMode then c := #0 else c := GameIo.RawKey;
  { sound off, or back on when the mode it left was 1 or 2 }
  if c = GameIo.KEY_CTRL_S then
    if GDVars.soundMode <> C_Sound.OFF then begin
      GDVars.soundSaved := GDVars.soundMode;
      SoundDrv.SoundCommand(0);
      GDVars.soundMode := C_Sound.OFF
    end else if GDVars.soundSaved in [1, 2] then begin
      GDVars.soundMode := GDVars.soundSaved;
      SoundDrv.SoundCommand(1)
    end;
  case c of
    GameIo.KEY_CTRL_D: begin
      GDConsts.debugOn := Ord(GDConsts.debugOn = 0);
      if GDConsts.debugOn <> 0 then begin
        Assign(GDVars.debugFile, 'debug.txt'); Rewrite(GDVars.debugFile)
      end else Close(GDVars.debugFile)
    end;
    GameIo.KEY_CTRL_Z: if GDConsts.debugOn <> 0 then begin
      creature := GDVars.creatureList;
      while creature <> nil do begin GameIo.DumpWhoList(creature); creature := creature^.next end
    end;
    GameIo.KEY_CTRL_C: GameIo.ExitGame
  end;
  ReadGameKey := c
end;

function InputPending: Boolean;
var
  device: record
    zone: Byte;
    button: Integer;
    { unused }
    buttonTail: Byte
  end;
begin
  InputPending := GameIo.RawPending;
  if GDVars.isJoystickOn or GDVars.isMouseOn then
    if GDVars.isMouseOn then begin
      Mouse.GetMouse(device.button, GDVars.mouseX, GDVars.mouseY);
      InputPending := GameIo.RawPending or Boolean(device.button <> 0)
    end else begin
      Joystick.GetJoystick(device.button, device.zone);
      InputPending := GameIo.RawPending or Boolean(device.button > 0) or Boolean(device.zone < C_Joy.NO_ZONE)
    end
end;

procedure DrainKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  while GameIo.RawPending do c := GameIo.RawKey
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  if GameIo.InputPending then c := GameIo.ReadGameKey
end;

procedure WaitMouseRelease; var x: Integer; y: Integer; buttons: Integer;
begin
  if not GDVars.isMouseOn then Exit;
  repeat Mouse.GetMouse(buttons, x, y) until buttons = 0
end;

procedure KbdNoop; begin end;
begin end.
