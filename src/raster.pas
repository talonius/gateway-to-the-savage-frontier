{ The per-mode picture layer. It draws tiles into pictures, flushes the view picture's dirty spans to the screen,
  mirrors and allocates pictures, and wraps the picture helpers Blit calls (ShowPicEga, WriteEgaCells,
  UnpackFivePlanes). The tile blitters, the VGA palette upload, the EGA row flush and those helpers are hand assembly in
  RASTER.ASM, linked below by the $L directive.

  It owns no storage: the view picture, the save-under buffer, the deferred-render span tables, the screen row tables
  and the palette staging cells are in GDVars. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Raster;

interface

uses Types, C_Video, GDConsts, GDVars;

{ Copies the rows of the view picture drawn since the last flush to the screen, in the display mode's layout, then marks
  every row clean. A dirty row's span runs from picture byte spanFirstOfs to spanLastOfs and lands at screen byte
  spanScreenOfs of that row. }
procedure FlushView;

{ Draws tile tileIdx of gfx into dest at cell screenX, screenY.
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(flag Bit 0 asks for the masked draw, taken when gfx has a mask and always in VGA mode.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Draws a tile that may hang off dest's edges.
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx The frame of gfx to draw.)
  @param(flag Bit 0 asks for the masked draw; only then does bit 2 save the covered pixels into GDVars.saveUnder first.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Copies src into dst mirrored left to right, with its mask, palette and frame.
  @param(src The picture mirrored.)
  @param(dst Receives the mirror; it must be as large as src.) }
procedure MirrorPic(src, dst: Types.PImgBuf);

{ Blit's ShowPic in EGA mode: height rows from screen row screenRow on, each width cells of four interleaved plane
  bytes, to byte column destOff of the screen.
  @param(data The picture rows.)
  @param(screenRow The first screen row.)
  @param(height The number of rows.)
  @param(destOff The byte column on the screen.)
  @param(width The cells a row.) }
procedure ShowPicEga(data: Pointer; screenRow, height, destOff, width: Word);

{ Loads one VGA DAC entry through the video BIOS; CbtMap calls it.
  @param(index The DAC entry.)
  @param(red The red level.)
  @param(green The green level.)
  @param(blue The blue level.) }
procedure SetPaletteEntry(index: Word; red, green, blue: Byte);

{ Loads DAC entries 16 and 17, the two colors no picture palette overrides. }
procedure SetDefaultPalette;

{ Allocates a zero-filled picture: the header, then the frames at the mode's bytes per 8-pixel row (CGA 2, VGA 8, EGA
  and Tandy 4).
  @param(height The picture's height in scanlines.)
  @param(width The picture's width in 8-pixel columns.)
  @param(count The number of frames.)
  @param(flag Bit 0 also allocates a zero-filled mask the size of the frames, outside VGA mode.)
  @param(pic Receives the picture.) }
procedure AllocPic(height, width: Word; count, flag: Byte; var pic: Types.PImgBuf);

{ Releases an image buffer and its transparency mask, if any, and sets the pointer to nil. Does nothing if the pointer
  is already nil.
  @param(pic Buffer to free; nil on return.) }
procedure FreePic(var pic: Types.PImgBuf);

{ When a picture palette is staged (GDVars.paletteWork, with a nonzero GDVars.paletteFrame) and differs from the one
  last shown, loads it into DAC entries 18..31. }
procedure PrepareVgaPalette;

{ Blit's bit-plane unpack: five planes of count bytes each, back to back at src, become count*8 bytes of color 0..31 at
  dst.
  @param(src The five planes.)
  @param(dst Receives the pixels.)
  @param(count The bytes a plane.) }
procedure UnpackFivePlanes(src, dst: Pointer; count: Word);

{ Writes count cells of four interleaved plane bytes to EGA memory at dst, one byte a plane; Blit writes a decoded
  picture row with it.
  @param(src The cells.)
  @param(dst The EGA address.)
  @param(count The number of cells.) }
procedure WriteEgaCells(src, dst: Pointer; count: Word);

implementation

const
  { the view starts eight scanlines down }
  VIEW_TOP = 8;
  { The view starts one 8-pixel column in from the screen's left: that column's bytes. }
  VIEW_LEFT_CGA = 2;
  VIEW_LEFT_TANDY = 4;
  VIEW_LEFT_VGA = 8;

{$L RASTER.OBJ}
{$F-}
{ Draws tile tileIdx of gfx whole into a CGA picture (two bytes a cell) at a character cell, and marks the scanlines it
  touches dirty for FlushView.
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellCga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitCellCga through the tile's mask.
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellCgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a CGA buffer (two bytes per cell) at a character-cell position, clipped against the
  buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedCga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ BlitCellCga for an EGA picture (four bytes a cell).
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitCellEga through the tile's mask.
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitClippedCga for an EGA picture (four bytes a cell). Note: an opaque frame cut at the left or right edge is drawn
  with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx The frame of gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitClippedEga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ BlitCellCga for a Tandy picture (four bytes a cell).
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitCellTandy through the tile's mask.
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitClippedCga for a Tandy picture (four bytes a cell). Note: an opaque frame cut at the left or right edge is drawn
  with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx The frame of gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitClippedTandy(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                           dest: Types.PImgBuf); external;

{ BlitCellCga for a VGA picture (eight bytes a cell).
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellVga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ BlitCellVga skipping the tile's pixels of the transparent color.
  @param(transpColor The transparent color.)
  @param(screenX The cell column.)
  @param(screenY The cell row, of eight scanlines.)
  @param(tileIdx The frame of gfx to draw.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitCellVgaKeyed(transpColor: Byte; screenX, screenY: Integer; tileIdx: Byte; gfx,
                           dest: Types.PImgBuf); external;

{ BlitClippedCga for a VGA picture (eight bytes a cell), keyed on the transparent color instead of a mask. Note: an
  opaque frame cut at the left or right edge is drawn with its rows out of step.
  @param(transpColor The transparent color.)
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx The frame of gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source picture.)
  @param(dest Picture drawn into.) }
procedure BlitClippedVga(transpColor: Byte; under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte;
                         gfx, dest: Types.PImgBuf); external;

{ PrepareVgaPalette's body: when a picture palette is staged and differs from the one last shown, expands its 4-bit
  levels (the bytes' low nibbles, then their high nibbles) into GDVars.dacTable and programs DAC entries 18..31 once
  vertical retrace is active. }
procedure PrepareVgaPaletteImpl; external;

procedure SetPaletteEntry; external;

procedure SetDefaultPalette; external;

{ FlushView's EGA path: writes each dirty view row's span plane by plane into the shadow page, then latch-copies it to
  the visible page in write mode 1. It leaves the span tables for FlushView to reset.
  @param(data The view picture's pixels, four interleaved plane bytes a cell.) }
procedure FlushEga(data: Types.PBytes); external;

{ ShowPicEga's body.
  @param(data The picture rows.)
  @param(screenRow The first screen row.)
  @param(height The number of rows.)
  @param(destOff The byte column on the screen.)
  @param(width The cells a row.) }
procedure ShowPicEgaImpl(data: Pointer; screenRow, height, destOff, width: Word); external;

{ WriteEgaCells' body.
  @param(src The cells.)
  @param(dst The EGA address.)
  @param(count The number of cells.) }
procedure WriteEgaCellsImpl(src, dst: Pointer; count: Word); external;

{ UnpackFivePlanes' body. The plane offsets are summed in a byte register, so count*4 must stay below 100h.
  @param(src The five planes.)
  @param(dst Receives the pixels.)
  @param(count The bytes a plane.) }
procedure UnpackFivePlanesImpl(src, dst: Pointer; count: Word); external;
{$F+}

procedure WriteEgaCells(src, dst: Pointer; count: Word);
begin Raster.WriteEgaCellsImpl(src, dst, count) end;

procedure UnpackFivePlanes(src, dst: Pointer; count: Word);
begin Raster.UnpackFivePlanesImpl(src, dst, count) end;

procedure PrepareVgaPalette; begin Raster.PrepareVgaPaletteImpl end;

procedure ShowPicEga(data: Pointer; screenRow, height, destOff, width: Word);
begin Raster.ShowPicEgaImpl(data, screenRow, height, destOff, width) end;

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Word;
  useMask: Boolean;
begin
  useMask := (flag and 1 <> 0) and ((gfx^.transp <> nil) or (GDVars.displayMode = C_Video.VM_VGA));
  case GDVars.displayMode of
   C_Video.VM_CGA: if useMask then Raster.BlitCellCgaMasked(screenX, screenY, tileIdx, gfx, dest)
      else Raster.BlitCellCga(screenX, screenY, tileIdx, gfx, dest);
   C_Video.VM_EGA: if useMask then Raster.BlitCellEgaMasked(screenX, screenY, tileIdx, gfx, dest)
      else Raster.BlitCellEga(screenX, screenY, tileIdx, gfx, dest);
   C_Video.VM_TANDY: if useMask then Raster.BlitCellTandyMasked(screenX, screenY, tileIdx, gfx, dest)
      else Raster.BlitCellTandy(screenX, screenY, tileIdx, gfx, dest);
   C_Video.VM_VGA: begin
      if useMask then Raster.BlitCellVgaKeyed(gfx^.mode3Extra, screenX, screenY, tileIdx, gfx, dest)
      else Raster.BlitCellVga(screenX, screenY, tileIdx, gfx, dest);
      dest^.palette := gfx^.palette;
      dest^.currentFrame := gfx^.currentFrame
     end
  end;
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
begin
  case GDVars.displayMode of
   C_Video.VM_CGA: Raster.BlitClippedCga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
   C_Video.VM_EGA: Raster.BlitClippedEga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
   C_Video.VM_TANDY: Raster.BlitClippedTandy(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
   C_Video.VM_VGA: begin
      Raster.BlitClippedVga(gfx^.mode3Extra, GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
      dest^.palette := gfx^.palette;
      dest^.currentFrame := gfx^.currentFrame
     end
  end;
end;

procedure FlushView;
var row: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  dstBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  plane: Word;
  { Unused in this version; see the other implementations of this routine. }
  spanBuf: array[1..256] of Byte;
begin
 case GDVars.displayMode of
  C_Video.VM_CGA: for row := 0 to SizeOf(GDVars.spanActive) - 1 do
     if GDVars.spanActive[row] <> 0 then
      Move(GDVars.viewBuf^.data[GDVars.spanFirstOfs[row]],
           Mem[GDVars.cgaRowSeg[row + Raster.VIEW_TOP]:GDVars.spanScreenOfs[row] + Raster.VIEW_LEFT_CGA],
           GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
  C_Video.VM_EGA: Raster.FlushEga(@GDVars.viewBuf^.data);
  C_Video.VM_TANDY: for row := 0 to SizeOf(GDVars.spanActive) - 1 do
     if GDVars.spanActive[row] <> 0 then
      Move(GDVars.viewBuf^.data[GDVars.spanFirstOfs[row]],
           Mem[GDVars.tandyRowSeg[row + Raster.VIEW_TOP]:GDVars.spanScreenOfs[row] + Raster.VIEW_LEFT_TANDY],
           GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
  C_Video.VM_VGA: begin
     GDVars.paletteWork := GDVars.viewBuf^.palette;
     GDVars.paletteFrame := GDVars.viewBuf^.currentFrame;
     Raster.PrepareVgaPalette;
     for row := 0 to SizeOf(GDVars.spanActive) - 1 do
      if GDVars.spanActive[row] <> 0 then
       Move(GDVars.viewBuf^.data[GDVars.spanFirstOfs[row]],
            Pointer(LongInt(C_Video.DISPLAY_SEG) shl 16 + (row + Raster.VIEW_TOP) * 320 + GDVars.spanScreenOfs[row] +
                    Raster.VIEW_LEFT_VGA)^, GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1)
    end
 end;
 FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
 { a clean row is marked $FFFF }
 FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
 FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0)
end;

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte; var mirrored: Byte;
begin mirrored := value shl 7; Inc(mirrored, (value and 2) shl 5); Inc(mirrored, (value and 4) shl 3);
 Inc(mirrored, (value and 8) shl 1); Inc(mirrored, (value and $10) shr 1); Inc(mirrored, (value and $20) shr 3);
 Inc(mirrored, (value and $40) shr 5); Inc(mirrored, (value and $80) shr 7); MirrorBits := mirrored end;

{ Reverses the order of the eight 2-bit CGA pixels packed in a word, reflecting them left to right.
  @param(value Two CGA pixel bytes of one cell.)
  @returns(The word with its pixel order reversed.) }
function MirrorPairs(value: Word): Word; var mirrored: Word;
begin mirrored := (value and GDConsts.cgaPositionBitmask[7]) shl 14;
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[6]) shl 10);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[5]) shl 6);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[4]) shl 2);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[3]) shr 2);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[2]) shr 6);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[1]) shr 10);
 Inc(mirrored, (value and GDConsts.cgaPositionBitmask[0]) shr 14);
 MirrorPairs := mirrored end;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte; var mirrored: Byte;
begin mirrored := value shl 4; Inc(mirrored, (value and $F0) shr 4); MirrorNibbles := mirrored end;

procedure MirrorPic(src, dst: Types.PImgBuf);
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word; plane: Byte; cell: Word;
begin
 if (src = nil) or (dst = nil) then Exit;
 with src^ do begin
  Move(palette, dst^.palette, SizeOf(Types.TPalette24));
  dst^.currentFrame := currentFrame;
  case GDVars.displayMode of
   C_Video.VM_CGA: begin
      rowBytes := width * 2; srcOff := rowBytes - 2; dstOff := 0;
      for row := 1 to height do begin
       rowStart := dstOff;
       for col := 0 to width - 1 do begin
        Move(data[srcOff - dstOff + rowStart], cell, SizeOf(cell));
        cell := Raster.MirrorPairs(cell); Move(cell, dst^.data[dstOff], SizeOf(cell));
        if transp <> nil then begin
         Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
         cell := Raster.MirrorPairs(cell); Move(cell, dst^.transp^[dstOff], SizeOf(cell))
        end;
        Inc(dstOff, 2)
       end;
       Inc(srcOff, rowBytes)
      end
     end;
   C_Video.VM_EGA: begin
      rowBytes := width * 4; srcOff := rowBytes - 4; dstOff := 0;
      for row := 1 to height do begin
       rowStart := dstOff;
       for col := 1 to width do begin
        for plane := 0 to 3 do begin
         dst^.data[dstOff + plane] := Raster.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
         if transp <>
             nil then dst^.transp^[dstOff + plane] := Raster.MirrorBits(transp^[srcOff - dstOff + rowStart + plane])
        end;
        Inc(dstOff, 4)
       end;
       Inc(srcOff, rowBytes)
      end
     end;
   C_Video.VM_TANDY: begin
      rowBytes := width * 4; srcOff := rowBytes - 1; dstOff := 0;
      for row := 1 to height do begin
       rowStart := dstOff;
       for col := 1 to rowBytes do begin
        dst^.data[dstOff] := Raster.MirrorNibbles(data[srcOff - dstOff + rowStart]);
        if transp <> nil then dst^.transp^[dstOff] := Raster.MirrorNibbles(transp^[srcOff - dstOff + rowStart]);
        Inc(dstOff)
       end;
       Inc(srcOff, rowBytes)
      end
     end;
   C_Video.VM_VGA: begin
      rowBytes := width * 8; srcOff := rowBytes - 1; dstOff := 0;
      for row := 1 to height do begin
       rowStart := dstOff;
       for col := 1 to rowBytes do begin
        dst^.data[dstOff] := data[srcOff - dstOff + rowStart]; Inc(dstOff)
       end;
       Inc(srcOff, rowBytes)
      end
     end
  end
 end
end;

procedure AllocPic(height, width: Word; count, flag: Byte; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
  { a frame's bytes per 8 pixels of a scanline in the display mode }
  cellSize: Byte;
begin
 case GDVars.displayMode of C_Video.VM_CGA: cellSize := 2; C_Video.VM_VGA: cellSize := 8 else cellSize := 4 end;
 frameSize := height * width * cellSize; totalSize := frameSize * count;
 { the frames, the picture's header and one byte more }
 GetMem(pic, totalSize + (SizeOf(pic^) - SizeOf(pic^.data) + 1));
 FillChar(pic^, totalSize + (SizeOf(pic^) - SizeOf(pic^.data) + 1), 0);
 pic^.height := height; pic^.width := width; pic^.frameSize := frameSize;
 pic^.count := count; pic^.allocSize := totalSize + (SizeOf(pic^) - SizeOf(pic^.data) + 1);
 if (flag and 1 > 0) and (GDVars.displayMode <> C_Video.VM_VGA) then begin
  GetMem(pic^.transp, totalSize); FillChar(pic^.transp^, totalSize, 0)
 end
end;

procedure FreePic(var pic: Types.PImgBuf);
{ Unused in this version; see the other implementations of this routine. }
var allocationSize: Word;
begin
 if pic = nil then Exit;
 with pic^ do begin
  allocSize := count * frameSize;
  if transp <> nil then FreeMem(transp, allocSize);
  FreeMem(pic, allocSize + (SizeOf(pic^) - SizeOf(pic^.data) + 1))
 end;
 pic := nil
end;

begin end.
