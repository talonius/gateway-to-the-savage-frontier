{ Start-up configuration: FixMain calls LoadConfig before it loads the game. LoadConfig clears demo mode and changes to
  the game's directory. When GameBoot has marked GAME.CFG stale, it then asks for the save path, music (unless an unset
  local reads #4) and alternate input, calibrating the joystick if it is chosen, and writes the file again. It then
  reads GAME.CFG into the shared data: the adapter, which sets the video mode, the save directory, the introduction
  letter, the game directory, music, the input device and the joystick calibration. Last it turns sound off when no INT
  66h sound driver is installed. Its work variables are configVars. }
{$O+,F+,I-,V-}
{$A-}
{$S-}
unit Config;

interface

{ Writes GAME.CFG when it is stale, then reads it and applies it. Note: musicChoice is never assigned, so whether the
  music question is asked rests on a stale stack byte; #4 skips the question and writes music off. }
procedure LoadConfig;

implementation

uses C_Sound, C_Video, Crt, Dos, GameBoot, Joystick, Blit, TextRend, GDConsts, GDVars;

const
  { INT 10h function: AL returns the current mode }
  BIOS_GET_VIDEO_MODE = $0F;
  { the BIOS modes Blit.SetVideoMode sets for each adapter }
  { 320x200, 4 colors }
  VIDEO_MODE_CGA = $04;
  { 320x200, 16 colors, Tandy 1000 }
  VIDEO_MODE_TANDY = $09;
  { 320x200, 16 colors }
  VIDEO_MODE_EGA = $0D;
  { 320x200, 256 colors }
  VIDEO_MODE_VGA = $13;
  { GDVars.soundMode while the INT 66h driver plays effects }
  SOUND_MODE_DRIVER = 2;

procedure LoadConfig;
var
  { #4 skips the music question; never assigned }
  musicChoice: Char;
begin
  GDVars.demoMode := False;
  ChDir(GDVars.exeDir);
  GDVars.configVars.ioResult := IOResult;
  GDVars.promptDrive := GDVars.disk3Dir[1];
  if GDVars.isConfigStale then begin
    Assign(GDVars.configVars.gameCfg, GDVars.exeDir + 'game.cfg');
    Rewrite(GDVars.configVars.gameCfg);
    if IOResult <> 0 then begin
      ClrScr;
      WriteLn('Sorry, disks cannot be write-protected.');
      Halt(1)
    end;
    WriteLn(GDVars.configVars.gameCfg, GDVars.cfgChar);
    WriteLn(GDVars.configVars.gameCfg);
    repeat
      ClrScr;
      Write('PATH FOR SAVE DATA (Example "C:\ADD\SAVE"): ');
      GDVars.saveDir := GDVars.disk3Dir + 'SAVE';
      GameBoot.EditPathLine(GDVars.saveDir);
      GameBoot.EnsureTrailingBackslash(GDVars.saveDir)
    until Length(GDVars.saveDir) >= 4;
    WriteLn(GDVars.configVars.gameCfg, GDVars.saveDir);
    WriteLn(GDVars.configVars.gameCfg, 'F');
    WriteLn(GDVars.configVars.gameCfg, GDVars.disk3Dir);
    WriteLn(GDVars.configVars.gameCfg, GDVars.disk2Dir);
    if musicChoice = #4 then
      GDVars.configVars.choice := 2
    else begin
      ClrScr;
      Write('Music ([1] On [2] Off):  ');
      GDVars.configVars.choice := GameBoot.ReadChoice(1, 2)
    end;
    case GDVars.configVars.choice of
      1: WriteLn(GDVars.configVars.gameCfg, 'N');
      2: WriteLn(GDVars.configVars.gameCfg, 'F')
    end;
    GDVars.isJoystickOn := False;
    ClrScr;
    Write('ALTERNATE INPUT TYPE ([1] Joystick  [2] Mouse  [3] Neither):');
    GDVars.configVars.choice := GameBoot.ReadChoice(1, 3);
    case GDVars.configVars.choice of
      1: begin
        WriteLn(GDVars.configVars.gameCfg, 'J'); GDVars.isJoystickOn := True;
        Joystick.CalibrateJoystick
      end;
      2: WriteLn(GDVars.configVars.gameCfg, 'M');
      3: WriteLn(GDVars.configVars.gameCfg, 'N')
    end;
    for GDVars.configVars.choice := 0 to 6 do begin
      WriteLn(GDVars.configVars.gameCfg, GDVars.joystickCalibration[1].x[GDVars.configVars.choice]);
      WriteLn(GDVars.configVars.gameCfg, GDVars.joystickCalibration[1].y[GDVars.configVars.choice])
    end;
    Close(GDVars.configVars.gameCfg)
  end;

  Assign(GDVars.configVars.gameCfg, GDVars.exeDir + 'game.cfg');
  Reset(GDVars.configVars.gameCfg);
  ReadLn(GDVars.configVars.gameCfg, GDVars.configVars.key);
  GDVars.interruptRegisters.ah := Config.BIOS_GET_VIDEO_MODE;
  Intr($10, Registers(GDVars.interruptRegisters));
  GDVars.savedVideoMode := GDVars.interruptRegisters.al;
  GDVars.currentVideoMode := GDVars.savedVideoMode;
  case GDVars.configVars.key of
    'E': begin
      GDVars.displayMode := C_Video.VM_EGA;
      Blit.SetVideoMode(Config.VIDEO_MODE_EGA);
      GDVars.currentlyDisplayedEga := 0;
      GDVars.otherEgaPage := 0;
      TextRend.SetupEgaCurrentPage(GDVars.currentlyDisplayedEga);
      TextRend.SetupEgaOtherPage(GDVars.otherEgaPage)
    end;
    'T': begin GDVars.displayMode := C_Video.VM_TANDY; Blit.SetVideoMode(Config.VIDEO_MODE_TANDY) end;
    'C': begin GDVars.displayMode := C_Video.VM_CGA; Blit.SetVideoMode(Config.VIDEO_MODE_CGA) end;
    'V': begin GDVars.displayMode := C_Video.VM_VGA; Blit.SetVideoMode(Config.VIDEO_MODE_VGA) end
  end;
  ReadLn(GDVars.configVars.gameCfg);
  GDVars.soundMode := Config.SOUND_MODE_DRIVER;
  ReadLn(GDVars.configVars.gameCfg, GDVars.saveDir);
  { the title sequence: 'F' plays it, 'S' plays it and sets super mode, any other letter skips it }
  ReadLn(GDVars.configVars.gameCfg, GDVars.configVars.key);
  GDVars.fullIntroFlag := 0;
  if GDVars.configVars.key = 'S' then begin GDVars.superMode := 1; GDVars.fullIntroFlag := 1 end
  else if GDVars.configVars.key = 'F' then GDVars.fullIntroFlag := 1;
  ReadLn(GDVars.configVars.gameCfg, GDVars.currentDir);
  GameBoot.EnsureTrailingBackslash(GDVars.currentDir);
  if Length(GDVars.currentDir) >= 4 then
    GDVars.currentDir := Copy(GDVars.currentDir, 1, Length(GDVars.currentDir) - 1);
  ReadLn(GDVars.configVars.gameCfg);
  ReadLn(GDVars.configVars.gameCfg, GDVars.configVars.key);
  if GDVars.configVars.key = 'N' then GDVars.isMusicEnabled := True else GDVars.isMusicEnabled := False;
  ReadLn(GDVars.configVars.gameCfg, GDVars.configVars.key);
  case GDVars.configVars.key of
    'J': begin GDVars.isJoystickOn := True; GDVars.isMouseOn := False end;
    'M': begin GDVars.isMouseOn := True; GDVars.isJoystickOn := False end;
    'N': begin GDVars.isMouseOn := False; GDVars.isJoystickOn := False end
  end;
  for GDVars.configVars.choice := 0 to 6 do begin
    ReadLn(GDVars.configVars.gameCfg, GDVars.joystickCalibration[1].x[GDVars.configVars.choice]);
    ReadLn(GDVars.configVars.gameCfg, GDVars.joystickCalibration[1].y[GDVars.configVars.choice])
  end;
  Close(GDVars.configVars.gameCfg);
  GDVars.soundSaved := C_Sound.OFF;
  if GDConsts.int66Vector = nil then GDVars.soundMode := C_Sound.OFF
  else GDVars.soundMode := Config.SOUND_MODE_DRIVER
end;

begin end.
