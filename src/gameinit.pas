{ The second stage of start-up and the reset for a new game. InitializeGame, which FixMain calls once, sets up the mouse
  and joystick, allocates the four GBVM banks, the font, the 3D wall graphics and map and the picture buffers, fills the
  screen-row address tables for the display mode, clears the game state to its defaults, loads the font, the 8x8
  symbols, the combat icons and frames, the sky backdrops, ITEMS.1, the combat tile sets and the sound effects, and
  installs the spell and effect handlers. ResetGameState, which FixMain and CharGen call for a new game, clears the
  banks and the game state again without allocating or loading anything. Both leave the party at 7, 13; InitializeGame
  faces it north, ResetGameState east. All the state is in GDConsts and GDVars. }
{$O+,F+,I-,S+}
{$A+}
unit GameInit;

interface

{ Sets up the mouse and joystick, allocates the GBVM banks, the font, the 3D buffers and the picture buffers, fills the
  screen-row tables, sets the game state to its defaults and loads the start-up graphics, items and sounds. FixMain
  calls it once. }
procedure InitializeGame;

{ Clears the GBVM banks and the game state for a new game, without allocating or loading anything. }
procedure ResetGameState;

implementation

uses Types, C_Dir, C_Ifc, C_Pic, C_Video, Crt, GDConsts, GDVars, Blit, Raster, Mouse,
  TextRend, MapTiles, DaxIo, MenuCore, Sym8x8,
  SaveLoad, Camp, GeoEdit, Explore,
  EffHndlr, Magic, GameIo, C_Gbvm;

const
  { the party's start cell }
  START_X = 7;
  START_Y = 13;

var
  { BIOS keyboard shift and toggle flags. }
  biosKbdFlags: Byte absolute $0040:$0017;

{ Loads sound effects 2 to 12 but 3 and 6 into GDVars.soundSamples when the INT 66h sound driver is installed; a missing
  one ends the game. }
procedure LoadSoundDefs;
var idx: Byte;
begin
  FillChar(GDVars.soundSamples, SizeOf(GDVars.soundSamples), 0);
  if GDConsts.int66Vector <> nil then begin
    GetMem(GDVars.soundBuffer, 9000);
    for idx := 2 to 12 do with GDVars.soundSamples[idx] do
      if idx <> 3 then if idx <> 6 then begin
        DaxIo.LoadDax('zounds', '.dax', idx, size, data);
        if size = 0 then begin
          TextRend.DisplayAndPause(White, Black, 'unable to load sound ' + GDVars.longToStringFunc(idx));
          GameIo.ExitGame
        end
      end
  end;
end;

{ Clears MenuCore's click state, sets the difficulty to 2 (Veteran) and clears the 3D map and wall graphics. }
procedure InitAuxState;
begin
  GDVars.arenaMoveActive := 0; GDVars.manualAimActive := 0; GDVars.partyClickMode := 0;
  GDVars.isMouseClick := False; GDVars.clickPending := 0; GDVars.unreadBeforeJoyClick := 0;
  GDVars.priorChar := nil;
  GDVars.combatMouseMode := 0; GDVars.verticalMenuActive := False;
  GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] := 2;
  GDVars.orderState := 0; GDVars.combatDisabled := 0; GDVars.remapPending := 0;
  FillChar(GDVars.map3d^, SizeOf(Types.TGeoMap), 0); FillChar(GDVars.wallGfx^, SizeOf(Types.TWallGfx), 0)
end;

procedure InitializeGame;
begin
  GDVars.virtualDiskNumber := 1;
  GDVars.savedKeyboardFlags := biosKbdFlags;
  Randomize;
  if GDVars.isMouseOn then begin
    GDVars.canClickParty := 1;
    GDVars.mouseButtons := 0;
    GDVars.mouseInitState := 0;
    Mouse.InitMouse;
    if GDVars.isMouseOn then begin
      GDVars.isMouseScaled := True;
      if GDVars.displayMode = C_Video.VM_CGA then
        GDVars.mouseCursorMask := @GDConsts.cursorMaskCga
      else
        GDVars.mouseCursorMask := @GDConsts.cursorMaskEga;
      Mouse.SetMouseCursor(0, 0, GDVars.mouseCursorMask);
      { the probe: an x read back below 321 leaves isMouseScaled set, and SetMouse doubles x from then on }
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.mouseProbeButtons, GDVars.mouseProbeX, GDVars.mouseProbeY);
      GDVars.isMouseScaled := (GDVars.mouseProbeX >= 321) = False;
    end;
    { the screen's center }
    GDVars.mouseX := 160;
    GDVars.mouseY := 100;
    Mouse.SetMouse(GDVars.mouseX, GDVars.mouseY);
    GDVars.mouseOldX := 0;
    GDVars.mouseOldY := 0;
  end;
  if GDVars.isJoystickOn then begin
    GDVars.joystickCenterX := 160;
    GDVars.joystickCenterY := 100;
  end;
  GetMem(GDVars.gbvmZone0Ptr, SizeOf(Types.TZone0));
  GetMem(GDVars.gbvmZone1Ptr, SizeOf(Types.TZone1));
  GetMem(GDVars.gbvmZone2Ptr, SizeOf(Types.TZone2));
  GetMem(GDVars.gbvmScriptPtr, SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, SizeOf(Types.TFont));
  GetMem(GDVars.wallGfx, SizeOf(Types.TWallGfx));
  GetMem(GDVars.map3d, SizeOf(Types.TGeoMap));
  FillChar(GDVars.map3d^, SizeOf(Types.TGeoMap), 0);
  FillChar(GDVars.wallGfx^, SizeOf(Types.TWallGfx), 0);
  Raster.AllocPic(8, 1, 1, 0, GDVars.current8x8SymbolPtr);
  Raster.AllocPic(8, 1, 1, 0, GDVars.cursorImageBuffer);
  FillChar(GDVars.cursorImageBuffer^.data, GDVars.cursorImageBuffer^.frameSize, $FF);
  { the 168 by 168 view }
  Raster.AllocPic(168, 21, 1, 0, GDVars.viewBuf);
  { a 24 by 24 cell }
  Raster.AllocPic(24, 3, 1, 0, GDVars.saveUnder);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  for GDVars.gi2 := 0 to 199 do case GDVars.displayMode of
    C_Video.VM_CGA: if Odd(GDVars.gi2) then GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 +
      C_Video.GFX_BANK1_SEG
           else GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 + C_Video.GFX_BANK0_SEG;
    C_Video.VM_EGA: GDVars.fbRowOfs[GDVars.gi2] := GDVars.gi2 * 40;
    C_Video.VM_TANDY: case GDVars.gi2 mod 4 of
              0: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK0_SEG;
              1: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK1_SEG;
              2: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK2_SEG;
              3: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK3_SEG
            end;
    C_Video.VM_VGA: GDVars.vgaRowOfs[GDVars.gi2] := GDVars.gi2 * 320
  end;
  FillChar(GDVars.symbolSetPtrs, SizeOf(GDVars.symbolSetPtrs), 0);
  FillChar(GDVars.tileSetImages, SizeOf(GDVars.tileSetImages), 0);
  Raster.AllocPic(24, 3, 48, 0, GDVars.tileSetImages[0]);
  FillChar(GDVars.gbvmZone0Ptr^, SizeOf(Types.TZone0), 0);
  GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] := 1;
  GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := 0;
  FillChar(GDVars.gbvmZone1Ptr^, SizeOf(Types.TZone1), 0);
  FillChar(GDVars.gbvmZone2Ptr^, SizeOf(Types.TZone2), 0);
  FillChar(GDVars.gbvmScriptPtr^, SizeOf(Types.TZone3), 0);
  FillChar(GDVars.iconAnimation, SizeOf(GDVars.iconAnimation), 0);
  for GDVars.gi2 := 1 to 2 do begin
    GDVars.portraitCache[GDVars.gi2].pictureId := C_Pic.NO_PICTURE;
    GDVars.portraitCache[GDVars.gi2].pic := nil;
  end;
  FillChar(GDVars.animationData, SizeOf(GDVars.animationData), 0);
  GDVars.bigPicBuf := nil;
  GDVars.treasureItems := nil;
  FillChar(GDVars.partyPos, SizeOf(GDVars.partyPos), 0);
  GDVars.partyPos.mapX := GameInit.START_X;
  GDVars.partyPos.mapY := GameInit.START_Y;
  GDVars.partyPos.facing := C_Dir.NORTH;
  FillChar(GDVars.doorOpeningBoolean, SizeOf(GDVars.doorOpeningBoolean), 1);
  GDVars.wallSetCache[1].wallDefId := 0;
  GDVars.wallSetCache[1].symbolSlot := 1;
  for GDVars.gi2 := 2 to 3 do begin
    GDVars.wallSetCache[GDVars.gi2].wallDefId := -1;
    GDVars.wallSetCache[GDVars.gi2].symbolSlot := -1;
  end;
  GDVars.portraitsFlag := 1;
  GDVars.monsterPicturesFlag := 1;
  GDConsts.debugOn := 0;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSavedGameFlag := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.eclScriptInstructionPtr := $8000;
  GDVars.gameDelay := 4;
  GDVars.demoMode := False;
  GDVars.previousVirtualDisk := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.vertTop := 1;
  GDVars.duelFlag := False;
  GDVars.suppressDrawingBorderFlag := 0;
  GDVars.searchModeFlag := 0;
  GDVars.ecl3dClearFlag := 0;
  GDVars.protNewLine := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := False;
  GDVars.suppressingInsertDiskFlag := 0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPictureName[0] := #0;
  GDVars.picArcId := C_Pic.NO_PICTURE;
  GDVars.savedPictureId := C_Pic.NO_PICTURE;
  GDVars.recentlySavedGameFlag := 0;
  GDVars.ceilFloorColorSel := 232;
  GDVars.wallColorSel := 219;
  GDVars.currentlyEclOpcodeFlag := 0;
  GDVars.combatMapVisible := 1;
  GDVars.bigPicId := C_Pic.NO_BIG_PICTURE;
  GDVars.initFlag1 := 0;
  GDVars.initFlag2 := 0;
  GDVars.isAutoTraining := False;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.EXPLORING;
  GDVars.savedInterfaceState := C_Ifc.MAIN_MENU;
  GDVars.soundOnFlag := 1;
  GDVars.overrideEffectFlag := 0;
  GDVars.skyImage0 := nil;
  GDVars.skyImage1 := nil;
  GDVars.skyImage2 := nil;
  GDVars.victoryStartFlag := 0;
  if GDVars.displayMode = C_Video.VM_VGA then Raster.SetDefaultPalette;
  GDVars.musicState := 0;
  TextRend.LoadGameFont;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  for GDVars.gi2 := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.gi2, GDVars.gi2 + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  Blit.LoadPic('COMSPR', 255, False, 0, GDConsts.combatFramePic);
  Blit.LoadPic('COMSPR', 254, False, 0, GDConsts.viewFramePic);
  if GDVars.displayMode <> C_Video.VM_CGA then begin
    Blit.LoadPic('sky', 250, True, C_Pic.KEY_COLOR, GDVars.skyImage0);
    Blit.LoadPic('sky', 251, True, C_Pic.KEY_COLOR, GDVars.skyImage1);
    Blit.LoadPic('sky', 252, True, C_Pic.KEY_COLOR, GDVars.skyImage2);
  end;
  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS.1', GDConsts.insertDiskDrive[GDVars.virtualDiskNumber], #0,
                                        GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  BlockRead(GDVars.itemsFile, GDVars.baseItems, SizeOf(GDVars.baseItems), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;
  MapTiles.Load24x24Set('DungCom', 1, 0, 25);
  GDVars.combatTilesLoaded := 1;
  MapTiles.Load24x24Set('RandCom', 1, 34, 6);
  GameInit.LoadSoundDefs;
  GameInit.InitAuxState;
  if ParamStr(1) = 'Super' then GDVars.superMode := 1;
  GDVars.superModeCopy := GDVars.superMode;
  GDVars.eclStack := nil;
end;

procedure ResetGameState;
begin
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  FillChar(GDVars.gbvmZone0Ptr^, SizeOf(Types.TZone0), 0);
  GDVars.gbvmZone0Ptr^[C_Gbvm.IN_DUNGEON] := 1;
  GDVars.gbvmZone0Ptr^[C_Gbvm.PREV_SCRIPT] := 0;
  FillChar(GDVars.gbvmZone1Ptr^, SizeOf(Types.TZone1), 0);
  FillChar(GDVars.gbvmZone2Ptr^, SizeOf(Types.TZone2), 0);
  FillChar(GDVars.gbvmScriptPtr^, SizeOf(Types.TZone3), 0);
  FillChar(GDVars.partyPos, SizeOf(GDVars.partyPos), 0);
  GDVars.partyPos.mapX := GameInit.START_X;
  GDVars.partyPos.mapY := GameInit.START_Y;
  GDVars.partyPos.facing := C_Dir.EAST;
  FillChar(GDVars.doorOpeningBoolean, SizeOf(GDVars.doorOpeningBoolean), 1);
  GDVars.wallSetCache[1].wallDefId := 0;
  GDVars.wallSetCache[1].symbolSlot := 1;
  for GDVars.gi2 := 2 to 3 do begin
    GDVars.wallSetCache[GDVars.gi2].wallDefId := -1;
    GDVars.wallSetCache[GDVars.gi2].symbolSlot := -1;
  end;
  GDConsts.debugOn := 0;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSavedGameFlag := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.eclScriptInstructionPtr := $8000;
  GDVars.gameDelay := 4;
  GDVars.virtualDiskNumber := 1;
  GDVars.previousVirtualDisk := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.vertTop := 1;
  GDVars.duelFlag := False;
  GDVars.suppressDrawingBorderFlag := 0;
  GDVars.searchModeFlag := 0;
  GDVars.ecl3dClearFlag := 0;
  GDVars.protNewLine := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := False;
  GDVars.suppressingInsertDiskFlag := 0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPictureName[0] := #0;
  GDVars.picArcId := C_Pic.NO_PICTURE;
  GDVars.savedPictureId := C_Pic.NO_PICTURE;
  GDVars.recentlySavedGameFlag := 0;
  GDVars.ceilFloorColorSel := 232;
  GDVars.wallColorSel := 219;
  GDVars.currentlyEclOpcodeFlag := 0;
  GDVars.combatMapVisible := 1;
  GDVars.bigPicId := C_Pic.NO_BIG_PICTURE;
  GDVars.initFlag1 := 0;
  GDVars.initFlag2 := 0;
  GDVars.isAutoTraining := False;
  MenuCore.ClearBottomLine;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.EXPLORING;
  GDVars.savedInterfaceState := C_Ifc.MAIN_MENU;
  GDVars.soundOnFlag := 1;
  GDVars.overrideEffectFlag := 0;
  GDVars.victoryStartFlag := 0;
  GameInit.InitAuxState;
end;

begin
end.
