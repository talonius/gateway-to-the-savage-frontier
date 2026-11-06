{ The 24x24 pictures: the terrain tiles of GDVars.tileSetImages, and the two-frame icons in GDVars.iconAnimation that
  stand for characters, creatures and effects. Every picture it loads has Black and DarkGray swapped by
  iconLoadRemapFrom and iconLoadRemapTo. The unit owns no storage. }
{$O+,F+,I+,R-,S+,V-,B-,A+}
unit MapTiles;

interface

{ Load record fileId of name and copy its nTiles tiles into the first tile set from tile slot on; a slot above 48 stops
  the game.
  @param(name The file's base name.)
  @param(fileId The record.)
  @param(slot The first tile slot filled.)
  @param(nTiles Tiles to copy.) }
procedure Load24x24Set(name: String; fileId, slot, nTiles: Byte);

{ Draws a 24x24 map tile into the view buffer at a character cell. Tiles 0..127 come from tile-set buffer 1, tiles 128
  and up from tile-set buffer 2.
  @param(col Character column.)
  @param(row Character row.)
  @param(tile Tile number.)
  @param(flag Drawing flags passed to the tile blitter; bit 0 draws through the mask.) }
procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);

{ Frees both frames of an icon animation slot.
  @param(animIdx The slot.) }
procedure FreeIconAnim(animIdx: Byte);

{ Load records fileId and fileId + 128 of name as icon animIdx's two frames. A CHEAD or CBODY name loses its last
  letter, and a T there adds 64 to both record numbers; ICON turns light magenta black; a name other than these and
  COMSPR goes through iconColorKeptTo, an identity table.
  @param(name The file's base name.)
  @param(fileId The first frame's record.)
  @param(animIdx The icon slot to fill.) }
procedure LoadIconAnim(name: String; fileId, animIdx: Byte);

{ Draws one frame of an icon animation into the view buffer, clipped, at three character cells per map cell, mirrored
  for facings past southeast. Nothing is drawn if the frame is not loaded.
  @param(col Map column.)
  @param(row Map row.)
  @param(facing Direction the icon faces.)
  @param(frame Frame to draw, 0 or 1.)
  @param(animIdx Animation slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

uses Types, Raster, Blit, GameIo, GDConsts, GDVars;

const
  { the highest slot Load24x24Set accepts }
  LAST_TILE_SLOT = 48;
  { a tile id's index; the high bit selects the second tile set }
  TILE_INDEX_MASK = $7F;
  { added to an icon's record number for its second frame }
  SECOND_FRAME_RECORD = 128;
  { added to both record numbers for a CHEAD or CBODY name ending in T }
  ALT_RECORD_OFFSET = 64;
  { DarkGray: the loaded pictures' transparent Black after the swap }
  SWAPPED_KEY_COLOR = 8;
  LAST_UNMIRRORED_FACING = 3;

{ Load a picture, swap Black and DarkGray in every frame, and make DarkGray its transparent color.
  @param(name The file's base name.)
  @param(fileId The record.)
  @param(flag True to build a mask.)
  @param(transpColor The transparent color to load with.)
  @param(pic Receives the picture.) }
procedure LoadRemappedPic(name: String; fileId: Byte; flag: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
var i: Byte;
begin
 Blit.LoadPic(name, fileId, flag, transpColor, Types.PImgBuf(pic));
 if pic <> nil then begin
  for i := 1 to pic^.count do
   Blit.RemapPic(GDConsts.iconLoadRemapFrom, GDConsts.iconLoadRemapTo, i - 1, False,
                 Types.PImgBuf(pic));
  pic^.mode3Extra := MapTiles.SWAPPED_KEY_COLOR
 end
end;

procedure Load24x24Set(name: String; fileId, slot, nTiles: Byte);
var pic: Types.PImgBuf; total: Word; destOfs: Word;
begin
 if slot > MapTiles.LAST_TILE_SLOT then begin
  Blit.RestoreVideoMode; WriteLn('Start range error in Load24x24Set');
  GameIo.ExitGame
 end;
 pic := nil; MapTiles.LoadRemappedPic(name, fileId, False, 0, pic);
 total := nTiles * pic^.frameSize; destOfs := slot * pic^.frameSize;
 if GDVars.tileSetImages[0] <> nil then Move(pic^.data, GDVars.tileSetImages[0]^.data[destOfs], total);
 Raster.FreePic(pic);
 GameIo.DrainKeys
end;

procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);
begin
 if tile > MapTiles.TILE_INDEX_MASK then
  Raster.BlitTileCell(col, row, tile and MapTiles.TILE_INDEX_MASK, flag, GDVars.tileSetImages[1], GDVars.viewBuf)
 else
  Raster.BlitTileCell(col, row, tile, flag, GDVars.tileSetImages[0], GDVars.viewBuf)
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Integer;
begin
 if GDVars.iconAnimation[animIdx, 0] <> nil then
   Raster.FreePic(GDVars.iconAnimation[animIdx, 0]);
 if GDVars.iconAnimation[animIdx, 1] <> nil then
   Raster.FreePic(GDVars.iconAnimation[animIdx, 1])
end;

procedure LoadIconAnim(name: String; fileId, animIdx: Byte);
var
  suffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
 if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
  if UpCase(name[Length(name)]) = 'T' then Inc(fileId, MapTiles.ALT_RECORD_OFFSET);
  name := Copy(name, 1, Length(name) - 1); suffix := '';
  MapTiles.LoadRemappedPic(name + suffix, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
  MapTiles.LoadRemappedPic(name + suffix, fileId + MapTiles.SECOND_FRAME_RECORD, True, 0,
                           GDVars.iconAnimation[animIdx, 1])
 end else if (name = 'COMSPR') or (name = 'ICON') then begin
  suffix := '';
  MapTiles.LoadRemappedPic(name + suffix, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
  MapTiles.LoadRemappedPic(name + suffix, fileId + MapTiles.SECOND_FRAME_RECORD, True, 0,
                           GDVars.iconAnimation[animIdx, 1]);
  if name = 'ICON' then begin
   Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                 GDVars.iconAnimation[animIdx, 0]);
   Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                 GDVars.iconAnimation[animIdx, 1])
  end
 end else begin
  { Note: the suffix is computed but never appended to name. }
  Str(GDVars.virtualDiskNumber, suffix);
  MapTiles.LoadRemappedPic(name, fileId, True, 0, GDVars.iconAnimation[animIdx, 0]);
  Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorKeptTo,
                0, False, GDVars.iconAnimation[animIdx, 0]);
  MapTiles.LoadRemappedPic(name, fileId + MapTiles.SECOND_FRAME_RECORD, True, 0, GDVars.iconAnimation[animIdx, 1]);
  Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorKeptTo,
                0, False, GDVars.iconAnimation[animIdx, 1])
 end;
 GameIo.DrainKeys
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var work: Types.PImgBuf;
begin
 if GDVars.iconAnimation[animIdx, frame] = nil then Exit;
 with GDVars.iconAnimation[animIdx, frame]^ do
  if facing > MapTiles.LAST_UNMIRRORED_FACING then begin
   Raster.AllocPic(height, width, 1, 1, work);
   work^.mode3Extra := GDVars.iconAnimation[animIdx, frame]^.mode3Extra;
   Raster.MirrorPic(GDVars.iconAnimation[animIdx, frame], work);
   Raster.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.viewBuf);
   Raster.FreePic(work)
  end else Raster.BlitTileClipped(col * 3, row * 3, 0, 1, GDVars.iconAnimation[animIdx, frame], GDVars.viewBuf)
end;

begin end.
