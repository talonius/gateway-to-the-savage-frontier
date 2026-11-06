{ Program entry. It reads GAME.CFG, loads the game, and shows the introduction unless the first command-line parameter
  is GDConsts.stingKey. It offers Play Demo, which answers itself after a timeout, and the copy protection (skipped in a
  demo or when the second parameter is the start-up password GDVars.commandText, which ModeInit sets), then loops: the
  main menu (skipped in a demo), the game loop, and the reset for the next game, offering Play Demo again after each
  demo. }
{$M 16384,0,655360}
{$F+,O-}
program FixMain;

uses
  Overlay,
  Dos,
  Crt,
  { the shared data }
  GDConsts, GDVars,
  ModeInit,
  GameBoot,
  SoundDrv,
  Music,
  TextRend,
  Border,
  Debug,
  EmptyB,
  Pathing,
  EmptyC,
  View3D,
  Portrait,
  MapView,
  MenuCore,
  Magic,
  Money,
  GameTime,
  ViewChar,
  Ending,
  GameInit,
  CharGen,
  CombatSt,
  Combat,
  PostCbt,
  Temple,
  CopyProt,
  EclVm,
  Intro,
  HeapErr,
  Config,
  MusDrv, C_Keys;

{$O Config}
{$O HeapErr}
{$O Intro}
{$O EclVm}
{$O Vault}
{$O CopyProt}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O DevMenu}
{$O GeoEdit}
{$O Camp}
{$O CharGen}
{$O SaveLoad}
{$O InputCfg}
{$O Ending}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O Magic}
{$O FxEngine}
{$O CharHlp}
{$O ClassCal}
{$O MenuCore}
{$O MapView}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O Debug}
{$O Border}
{$O Sym8x8}
{$O Blit}
{$O Raster}
{$O TextRend}
{$O Music}
{$O MusDrv}
{$O DaxIo}
{$O GameIo}
{$O Mouse}
{$O Joystick}
{$O SoundDrv}

const
  { the Play Demo menu's answer for Demo, and its answer when the time runs out }
  DEMO_KEY = 'D';

begin
  GDVars.superMode := 0;
  GDVars.sndState := 0;
  Config.LoadConfig;
  SoundDrv.SoundSuspend;
  if GDVars.soundOnFlag <> 0 then
    SoundDrv.SoundCommand(255);
  GameInit.InitializeGame;
  if GDVars.soundOnFlag = 0 then
    SoundDrv.SoundSuspend;
  SoundDrv.SoundCommand(0);
  SoundDrv.SoundSuspend;

  if ParamStr(1) <> GDConsts.stingKey then
    Intro.Introduction;

  GDVars.menuTimeout := 3000;
  GDVars.menuDefaultKey := DEMO_KEY;
  GDVars.menuResult := MenuCore.MenuHorizontal('Gateway v1.2 ', 'Play Demo', Crt.LightMagenta, Crt.LightGreen,
                                               Crt.White, False, False, GDVars.menuExt);
  GDVars.menuTimeout := 0;
  GDVars.menuDefaultKey := NONE;
  if GDVars.menuResult = DEMO_KEY then
    GDVars.demoMode := True;

  { Asked once, before the loop, and again only when a demo ends. }
  if (ParamStr(2) <> GDVars.commandText) and not GDVars.demoMode then
    CopyProt.CopyProtection;

  repeat
    GDVars.virtualDiskNumber := 2;
    if GDVars.demoMode then
      GDVars.gameDelay := 9;

    if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
    if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;

    if not GDVars.demoMode then
      CharGen.MainMenu;

    if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
    if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;

    View3D.SetView3DColors(GDVars.colorSkyCeiling, GDVars.wallColorA, GDVars.wallColorB, GDVars.wallColorC);

    if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
    if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;

    EclVm.GameLoop;
    Portrait.FreeAnimation(GDVars.animationData);

    if GDVars.soundOnFlag <> 0 then SoundDrv.SoundCommand(255);
    if GDVars.soundOnFlag = 0 then SoundDrv.SoundSuspend;

    GameInit.ResetGameState;

    if GDVars.demoMode then begin
      TextRend.ClearScreen;
      GDVars.menuTimeout := 1000;
      GDVars.menuDefaultKey := DEMO_KEY;
      GDVars.menuResult := MenuCore.MenuHorizontal('Gateway v1.2 ', 'Play Demo', Crt.LightMagenta, Crt.LightGreen,
                                                   Crt.White, False, False, GDVars.menuExt);
      GDVars.menuTimeout := 0;
      GDVars.menuDefaultKey := NONE;
      GDVars.demoMode := GDVars.menuResult = DEMO_KEY;
      if (ParamStr(2) <> GDVars.commandText) and not GDVars.demoMode then
        CopyProt.CopyProtection;
      SoundDrv.SoundCommand(0);
    end;
  until False;
end.
