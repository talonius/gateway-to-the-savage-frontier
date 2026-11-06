{ Pictures in the view window. LoadAnimation loads a PIC-style animation from a DAX archive, frame by frame (PIC and
  FINAL frames after the first are XOR deltas against it); LoadPortraitBufs and DisplayPortraitBufs load and show a
  character's HEAD and BODY pictures; Show3DSprite draws a sprite into the 3D view; DisplayBigPic draws a BIGPIC. Its
  color remaps are in GDConsts; the animation record, the portrait cache, the loaded archive's name and id and the big
  picture's id are in GDVars. }
{$O+,F+,I+,R-,S+,V-,B-,A+}
unit Portrait;

interface
uses Types, C_Pic, C_Screen, C_Video, Raster, Crt, GDConsts, GDVars, Blit, Border, TextRend, DaxIo, GameIo, C_Gbvm;
type
 TStr8 = String[8];

{ Draws pic at text cell col, row: through the view picture when anim is set or zone 0's picture-fade flag is, recolored
  by viewPicRemapFrom/To in the latter case, and straight to the screen otherwise. A nil pic draws nothing.
  @param(col The text column.)
  @param(row The text row.)
  @param(anim True to draw through the view picture.)
  @param(pic The picture, or nil.) }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

{ Loads animation picId of name.dax into a, unless it is the one loaded already, freeing the animation and the portraits
  first. At most six frames load, and only the first of a PIC or FINAL archive while GDVars.portraitsFlag is 0. A frame
  that finds less than $F3C bytes of heap is not loaded, and the frames after it are read from its unskipped pixel data.
  @param(name The archive's base name.)
  @param(picId $FF loads nothing.)
  @param(transp Bit 0 gives each frame a mask of color 0 and, outside CGA mode, recolors it by animRemapFrom/To.)
  @param(a Receives the animation.) }
procedure LoadAnimation(name: TStr8; picId, transp: Byte; var a: Types.TAnimRec);

{ Frees each frame of an animation record, clears the record and forgets the last loaded picture.
  @param(a The animation record.) }
procedure FreeAnimation(var a: Types.TAnimRec);

{ Draws the loaded portrait head straight to the screen at a character cell and, when asked, the body five character
  rows below it.
  @param(col Character column of the head.)
  @param(row Character row of the head.)
  @param(both True to draw the body as well, False for the head alone.) }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

{ Frees the current animation and loads HEAD picture headId and BODY picture bodyId into the portrait cache, each unless
  it is cached already or its id is $FF.
  @param(headId The HEAD picture, or $FF.)
  @param(bodyId The BODY picture, or $FF.) }
procedure LoadPortraitBufs(headId, bodyId: Byte);

{ Draws a 3D sprite frame transparently into the view buffer at its origin and flushes the view. A distance outside 1 to
  3 restores the video mode, prints an error and exits to DOS.
  @param(dist The view distance, 1 to 3, which is also the frame drawn.)
  @param(a The sprite's animation record; a missing frame draws nothing.) }
procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);

{ Draws BIGPIC id: at the picture's own origin when zone 0's big-picture-at-origin flag is 1, which it then clears, and
  otherwise under DrawTextFrame's frame at text column 1, scanline 8.
  @param(id The BIGPIC record.) }
procedure DisplayBigPic(id: Byte);

{ Frees the cached HEAD and BODY pictures and marks both slots empty. }
procedure FreePortraitBufs;
implementation
const
 { GDVars.portraitCache's slots }
 HEAD_SLOT = 1;
 BODY_SLOT = 2;
 { the most frames LoadAnimation keeps of an animation }
 MAX_FRAMES = 6;
 { GBVM zone 0: 1 draws the next big picture at the screen's origin; DisplayBigPic clears it }
 BIG_PIC_AT_ORIGIN = $4CF8;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
 if pic <> nil then
  if (GDVars.gbvmZone0Ptr^[C_Gbvm.PICTURE_FADE] > 0) or anim then begin
   if GDVars.gbvmZone0Ptr^[C_Gbvm.PICTURE_FADE] > 0 then
     Blit.RemapPic(GDConsts.viewPicRemapFrom, GDConsts.viewPicRemapTo, 0, True, pic);
   Raster.BlitTileClipped(col - 1, row - 1, 0, 0, pic, GDVars.viewBuf);
   Raster.FlushView
  end else Blit.ShowPic(col, row, pic)
end;

{ Draws a HEAD picture at text cell col, row, first reporting a nil one on the status line.
  @param(col The text column.)
  @param(row The text row.)
  @param(pic The picture.) }
procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);
begin
 if pic = nil then GDVars.displayStatusLineProc('head = nil');
 Portrait.DisplayImageBuf(col, row, False, pic)
end;

{ Draws a BODY picture five rows below text cell col, row, first reporting a nil one on the status line.
  @param(col The text column.)
  @param(row The head's text row.)
  @param(pic The picture.) }
procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);
begin
 if pic = nil then GDVars.displayStatusLineProc('body = nil');
 Portrait.DisplayImageBuf(col, row + 5, False, pic)
end;

procedure LoadAnimation(name: TStr8; picId, transp: Byte; var a: Types.TAnimRec);
var
 sz: Word; buf: Types.PBytes; readOfs: Word; f: Byte; h: Word; w: Word; diskCh: String[1]; xorBuf: Types.PBytes;
 j: Word;
 planeSz: Word; isPic: Boolean; gotXor: Boolean; loaded: Byte; data: Types.PBytes;
 info: Types.TPaletteInfo;
 firstInfo: Types.TPaletteInfo;
begin
 if ((name = GDVars.picArcName) and (picId = GDVars.picArcId)) or (picId = C_Pic.NO_PICTURE) then Exit;
 if GDVars.portraitsFlag <> 0 then begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, 'Loading...Please Wait')
 end;
 Portrait.FreeAnimation(a); Portrait.FreePortraitBufs; GDVars.picArcName := name; GDVars.picArcId := picId;
 isPic := (name = 'PIC') or (name = 'FINAL'); Str(LongInt(GDVars.virtualDiskNumber), diskCh);
 DaxIo.LoadDax(name, '.dax', picId, sz, buf);
 if sz = 0 then begin TextRend.DisplayAndPause(Yellow, Black, 'PIC not found'); Exit end;
 readOfs := 0; gotXor := False;
 with a do begin
  count := buf^[readOfs]; if count > Portrait.MAX_FRAMES then count := Portrait.MAX_FRAMES;
  Inc(readOfs); current := 1; loaded := 0;
  if (GDVars.portraitsFlag = 0) and isPic then count := 1;
  for f := 1 to count do begin
   Move(buf^[readOfs], frames[f].delay, SizeOf(frames[f].delay)); Inc(readOfs, 4);
   Move(buf^[readOfs], h, SizeOf(h)); Inc(readOfs, 2); Move(buf^[readOfs], w, SizeOf(w)); Inc(readOfs, 2);
   if MaxAvail >= 3900 then begin
    Inc(loaded);
    Raster.AllocPic(h, w, 1, transp, frames[f].pic);
    with frames[f].pic^ do begin
     Move(buf^[readOfs], originX, SizeOf(originX)); Inc(readOfs, 2);
     Move(buf^[readOfs], originY, SizeOf(originY)); Inc(readOfs, 3);
     Blit.DecodePalette(buf, readOfs, @info);
     { A later frame whose header carries only the five-plane flag takes the first frame's. }
     if f = 1 then firstInfo := info
     else if info.flags = $04 then info := firstInfo;
     palette := info.palette; currentFrame := info.vgaIndex
    end;
    planeSz := h * w * 8;
    Blit.DecodeImageData(buf, data, readOfs, planeSz, @info, w);
    if isPic then
     if f = 1 then begin
      GetMem(xorBuf, planeSz); Move(data^, xorBuf^, planeSz); gotXor := True
     end else
      for j := 0 to planeSz - 1 do data^[j] := data^[j] xor xorBuf^[j];
    Blit.ExpandPicFrames(data, 0, Boolean(transp), 0, frames[f].pic, @info);
    FreeMem(data, planeSz);
    if (transp and 1 > 0) and (GDVars.displayMode <> C_Video.VM_CGA) then
     Blit.RemapPic(GDConsts.animRemapFrom, GDConsts.animRemapTo, 0, False,
                   frames[f].pic);
   end else count := 1
  end;
  count := loaded
 end;
 if isPic and gotXor then FreeMem(xorBuf, planeSz);
 FreeMem(buf, sz);
 if GDVars.portraitsFlag <> 0 then TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40)
end;

procedure FreeAnimation(var a: Types.TAnimRec);
begin
 with a do for GDVars.sharedLoopIndex := 1 to count do
   Raster.FreePic(frames[GDVars.sharedLoopIndex].pic);
 FillChar(a, SizeOf(a), 0); GDVars.picArcName[0] := #0; GDVars.picArcId := C_Pic.NO_PICTURE
end;

procedure FreePortraitBufs;
begin
 Raster.FreePic(Types.PImgBuf(GDVars.portraitCache[Portrait.HEAD_SLOT].pic));
 Raster.FreePic(Types.PImgBuf(GDVars.portraitCache[Portrait.BODY_SLOT].pic));
 GDVars.portraitCache[Portrait.HEAD_SLOT].pictureId := C_Pic.NO_PICTURE;
 GDVars.portraitCache[Portrait.BODY_SLOT].pictureId := C_Pic.NO_PICTURE
end;

procedure LoadPortraitBufs(headId, bodyId: Byte);
var diskCh: String[1];
begin
 Portrait.FreeAnimation(GDVars.animationData); Str(LongInt(GDVars.virtualDiskNumber), diskCh);
 if headId <> C_Pic.NO_PICTURE then
  if (GDVars.portraitCache[Portrait.HEAD_SLOT].pictureId = C_Pic.NO_PICTURE) or
      (GDVars.portraitCache[Portrait.HEAD_SLOT].pictureId <> headId) then begin
   Blit.LoadPic('HEAD', headId, False, 0, Types.PImgBuf(GDVars.portraitCache[Portrait.HEAD_SLOT].pic));
   if GDVars.portraitCache[Portrait.HEAD_SLOT].pic =
       nil then TextRend.DisplayAndPause(Yellow, Black, 'head not found');
   GDVars.portraitCache[Portrait.HEAD_SLOT].pictureId := headId
  end;
 if bodyId <> C_Pic.NO_PICTURE then
  if (GDVars.portraitCache[Portrait.BODY_SLOT].pictureId = C_Pic.NO_PICTURE) or
      (GDVars.portraitCache[Portrait.BODY_SLOT].pictureId <> bodyId) then begin
   Blit.LoadPic('BODY', bodyId, False, 0, Types.PImgBuf(GDVars.portraitCache[Portrait.BODY_SLOT].pic));
   { Note: the message says head for the body too. }
   if GDVars.portraitCache[Portrait.BODY_SLOT].pic =
       nil then TextRend.DisplayAndPause(Yellow, Black, 'head not found');
   GDVars.portraitCache[Portrait.BODY_SLOT].pictureId := bodyId
  end
end;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
 if both then begin
  Portrait.DisplayPortraitHead(col, row, GDVars.portraitCache[Portrait.HEAD_SLOT].pic);
  Portrait.DisplayPortraitBody(col, row, GDVars.portraitCache[Portrait.BODY_SLOT].pic)
 end else Portrait.DisplayImageBuf(col, row, False, GDVars.portraitCache[Portrait.HEAD_SLOT].pic)
end;

procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);
begin
 if (dist < 1) or (dist > 3) then begin
  Blit.RestoreVideoMode; WriteLn('Illegal range in Show3DSprite.');
  GameIo.ExitGame
 end;
 if a.frames[dist].pic <> nil then with a.frames[dist].pic^ do
  Raster.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, a.frames[dist].pic, GDVars.viewBuf)
 else Exit;
 Raster.FlushView
end;

procedure DisplayBigPic(id: Byte);
{ Unused in this version; see the other implementations of this routine. }
var picSize: Word;
begin
 if GDVars.gbvmZone0Ptr^[Portrait.BIG_PIC_AT_ORIGIN] = 1 then begin
  Blit.DisplaySpecialPic('bigpic', id, -1, -1); GDVars.gbvmZone0Ptr^[Portrait.BIG_PIC_AT_ORIGIN] := 0
 end else begin
  Border.DrawTextFrame; Blit.DisplaySpecialPic('bigpic', id, 1, 8)
 end;
 GDVars.bigPicId := id
end;
begin end.
