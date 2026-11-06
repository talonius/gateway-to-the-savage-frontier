{ The Pascal half of the picture layer. It loads DAX pictures, decodes their color headers and pixels into the display
  mode's layout, shows pictures whole or masked, recolors them, fills rectangles into a picture for the deferred flush,
  and sets the video mode and palette registers through the video BIOS. Raster holds the per-mode blitters and the
  helpers called here.

  Its color tables (cgaColorFill .. egaMap) are in GDConsts; the span and screen row tables and the palette staging
  cells are in GDVars. Its initialization clears GDVars.paletteShown. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Blit;

interface

uses Types, C_Ega, C_Video, Raster, Dos, GDConsts, GDVars, DaxIo;

type
  { An 8-pixel chunk as stored in a picture: one byte per pixel. }
  TChunk = array[0..7] of Byte;
  { a pointer to a Types.TPaletteInfo }
  PPaletteInfo = ^TPaletteInfo;

{ Sets one EGA palette register through BIOS INT 10h function 10h. Colors 8..15 are raised by 8, which sets bit 4, the
  intensity bit of the 200-line EGA modes.
  @param(registerIndex Palette register to set.)
  @param(color Color for that register, 0..15.) }
procedure SetPaletteRegister(registerIndex, color: Byte);

{ Sets one Tandy palette register through BIOS INT 10h function 10h, storing the color unadjusted.
  @param(registerIndex Palette register to set.)
  @param(color Palette value to store.) }
procedure SetPaletteRegisterTandy(registerIndex, color: Byte);

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns to the mode that was current before the last SetVideoMode call. That call saves the mode it replaces, so two
  calls in a row toggle between two modes. }
procedure RestoreVideoMode;

{ Loads picture fileId of name.dax into a newly allocated picture in the display mode's layout, freeing any picture pic
  already holds. VGA mode copies the pixels straight in; the other modes decode them and map them through the picture's
  color header. pic is left nil when the record is missing, and a record with no pixels keeps only the header fields.
  @param(name Base file name, without the .dax extension.)
  @param(fileId Record to load from the file.)
  @param(hasMask True also allocates a mask of the pixels in transpColor, which is filled outside VGA mode.)
  @param(transpColor The transparent color, kept in the picture's mode3Extra.)
  @param(pic Receives the new picture; a picture it held is freed first.) }
procedure LoadPic(name: String; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);

{ Converts decoded pixels, a byte a pixel from imgData^[srcOff] on, into pic's frames in the display mode's layout
  through info's color map, and fills pic's mask where it has one, clearing the masked pixels in the data. CGA packs
  four pixels to a byte, EGA spreads eight pixels over four plane bytes, Tandy packs two pixels to a byte, and VGA
  copies the pixels unmapped.
  @param(imgData Decoded pixels.)
  @param(srcOff Offset in imgData of the first pixel.)
  @param(hasMask Unused.)
  @param(transpColor Color whose pixels the mask covers.)
  @param(pic Picture to fill, already allocated at its size; nothing happens if nil.)
  @param(info Color header whose map translates the pixels.) }
procedure ExpandPicFrames(imgData: Types.PBytes; srcOff: Word; hasMask: Boolean;
                          transpColor: Byte; pic: Types.PImgBuf; info: PPaletteInfo);

{ Copies the first frame of pic straight to video memory at a text cell, without clipping or transparency. VGA mode
  stages the picture's palette first; CGA and EGA skip a picture with no rows or columns.
  @param(screenX Left edge, in text columns.)
  @param(screenY Top edge, in text rows of eight scanlines.)
  @param(pic Picture to show; nothing happens if nil.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ Replaces each color fromColors[i] with toColors[i] in pic, for the pairs that differ, working on a copy that is
  written back at the end; VGA mode also moves the transparent color. Masked pixels stay clear. It does nothing in CGA
  mode.
  @param(fromColors Colors to replace, one for each of the 16 pairs.)
  @param(toColors Their replacements.)
  @param(frame The frame to recolor. Note: a negative value selects every frame for the copy, but the color loop then
    sees frame 0 and recolors and writes back only frame 0.)
  @param(isDithered True changes only about one pixel in four.)
  @param(pic Picture to recolor; nothing happens if nil.) }
procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);

{ Fills a width by height rectangle of pic with color, clipped to pic, and marks the rows it touched in the span tables
  for Raster.FlushView. Note: with y negative the fill runs one row past the visible part of the rectangle and is not
  clipped at the bottom.
  @param(x The rectangle's left column in 8-pixel cells; may be negative.)
  @param(y Its top scanline; may be negative.)
  @param(width Its width in 8-pixel cells.)
  @param(height Its height in scanlines.)
  @param(color Fill color.)
  @param(pic Picture to fill; nothing happens if nil.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; pic: Types.PImgBuf);

{ Plots one pixel on video page 0 through BIOS INT 10h function 0Ch.
  @param(x Pixel column.)
  @param(y Pixel row.)
  @param(color Color to plot.) }
procedure PlotViewPixel(x, y: Word; color: Byte);

{ Allocates dest and fills it with count decoded pixels, a byte a pixel, from data^[readOfs] on, advancing readOfs past
  them. Packed data holds two pixels to a byte, high nibble first; five-plane data is unpacked a row at a time by
  Raster.UnpackFivePlanes.
  @param(data Raw picture record.)
  @param(dest Receives the new pixel buffer of count bytes.)
  @param(readOfs Offset of the pixel data in data; advanced past it.)
  @param(count Number of pixels to decode.)
  @param(info Color header, whose flags say how the pixels are stored.)
  @param(width The row width in bytes of a plane, for five-plane data.) }
procedure DecodeImageData(data: Types.PBytes; var dest: Types.PBytes; var readOfs: Word;
                          count: Word; info: PPaletteInfo; width: Word);

{ Decodes the color header at data^[readOfs] into dest^ for the display mode, advancing readOfs past it. A first byte
  with none of the bits $CC set starts an older header, eight bytes of sixteen packed CGA colors with the identity as
  the EGA map; otherwise a flags byte says which of a CGA map, an EGA map and a 24-byte palette follow. CGA, EGA and
  Tandy modes build the color map from what is present, reducing palette colors 16..31 to the nearest of their colors;
  VGA mode keeps the palette. Note: the color reduction tests blue against minLevel a second time where maxLevel was
  meant.
  @param(data Raw picture record.)
  @param(readOfs Offset of the color header in data; advanced past it.)
  @param(dest Receives the decoded header.) }
procedure DecodePalette(data: Types.PBytes; var readOfs: Word; dest: PPaletteInfo);

{ Draws pic at text cell screenX, screenY through its mask, keeping the screen under the masked pixels; VGA mode stages
  the palette and skips the pixels in transpColor. Note: outside VGA mode a picture without a mask is shown whole, then
  still drawn through the nil mask.
  @param(screenX Left edge, in text columns.)
  @param(screenY Top edge, in text rows of eight scanlines.)
  @param(pic Picture to draw; nothing happens if nil.)
  @param(transpColor Transparent color, read in VGA mode.) }
procedure ShowPicMasked(screenX, screenY: Integer; pic: Types.PImgBuf; transpColor: Byte);

{ Draws picture fileId of name.dax straight to the screen a row at a time, without a picture buffer. Nothing is drawn
  when the record is missing or has no pixels.
  @param(name Base file name, without the .dax extension.)
  @param(fileId Record to draw.)
  @param(col The left edge, in 8-pixel cells; with row, -1 and -1 select the picture's own origin.)
  @param(row The top scanline.) }
procedure DisplaySpecialPic(name: String; fileId: Byte; col, row: Integer);

implementation

const
  { The color header's flags: a CGA and an EGA color map follow, the pixels are five bit planes rather than packed
    nibbles, and a 24-byte palette follows. }
  PAL_CGA_MAP = $01;
  PAL_EGA_MAP = $02;
  PAL_FIVE_PLANES = $04;
  PAL_HAS_PALETTE = $08;
  { INT 10h function: the palette registers, by subfunction in AL }
  BIOS_PALETTE = $10;
  { its subfunction: register BL takes color BH }
  BIOS_SET_PALETTE_REG = 0;
  { INT 10h function: plot color AL at column CX, row DX }
  BIOS_WRITE_PIXEL = $0C;

{ Returns the transparency mask of an 8-pixel chunk.
  @param(transpColor The color that is transparent.)
  @param(chunk The chunk's eight pixels, one byte each.)
  @returns(A bit set for each pixel equal to transpColor, bit 7 for chunk[0] down to bit 0 for chunk[7].) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
var
  mask: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  bit := $80;
  for i := 0 to 7 do begin
    if chunk[i] = transpColor then Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

{ Translates a color through a picture's color map. The map packs two colors per byte: even colors in the high nibble,
  odd colors in the low nibble.
  @param(color Color index, 0..15.)
  @param(map Color map of the picture.)
  @returns(The mapped color, 0..15.) }
function SrcNibble(color: Byte; map: Types.TPalette24): Byte;
begin
 if Odd(color) then SrcNibble := map[color div 2] and $F
 else SrcNibble := (map[color div 2] and $F0) shr 4
end;

procedure SetVideoMode(mode: Byte);
var
 { Unused in this version; see the other implementations of this routine. }
 oldMode: Word;
begin
 GDVars.savedVideoMode := GDVars.currentVideoMode;
 GDVars.interruptRegisters.AH := C_Video.BIOS_SET_VIDEO_MODE; GDVars.interruptRegisters.AL := mode;
 Intr($10, Registers(GDVars.interruptRegisters));
 GDVars.currentVideoMode := mode
end;

procedure RestoreVideoMode;
begin Blit.SetVideoMode(GDVars.savedVideoMode) end;

procedure DecodePalette(data: Types.PBytes; var readOfs: Word; dest: PPaletteInfo);

{ The 16-color value nearest a 4-bit RGB color: a gray by its level, else its strong channels and intensity. }
function RgbToColor16(red, green, blue: Byte): Byte;
var
  color: Byte;
  minLevel: Byte;
  maxLevel: Byte;
begin
 minLevel := red; maxLevel := red;
 if green < minLevel then minLevel := green;
 if blue < minLevel then minLevel := blue;
 if green > maxLevel then maxLevel := green;
 if blue > minLevel then minLevel := blue;
 color := 0;
 if ((maxLevel - red) div 4 = (maxLevel - blue) div 4) and ((maxLevel - red) div 4 = (maxLevel - green) div 4) then
  RgbToColor16 := GDConsts.paletteLevelMap[red div 4]
 else begin
  if blue - minLevel >= (maxLevel - minLevel) div 2 then Inc(color);
  if green - minLevel >= (maxLevel - minLevel) div 2 then Inc(color, 2);
  if red - minLevel >= (maxLevel - minLevel) div 2 then Inc(color, 4);
  if maxLevel >= 8 then Inc(color, 8);
  RgbToColor16 := color
 end
end;

{ The EGA color for picture color color: 0..15 unchanged, 16..31 from the palette's RGB triples. }
function MapColor16(color: Byte; palette: Types.TPalette24): Byte;
begin
 if color < 16 then MapColor16 := color
 else if color <= 23 then
  MapColor16 := RgbToColor16(palette[(color - 16) * 3] and $F, palette[(color - 16) * 3 + 1] and $F,
                             palette[(color - 16) * 3 + 2] and $F)
 else MapColor16 := RgbToColor16(palette[(color - 24) * 3] shr 4, palette[(color - 24) * 3 + 1] shr 4,
                                 palette[(color - 24) * 3 + 2] shr 4)
end;

{ MapColor16's color reduced to a CGA color, 0..3. }
function MapColor4(color: Byte; palette: Types.TPalette24): Byte;
begin
 if color < 16 then MapColor4 := (color and 6) div 2
 else if color <= 23 then
  MapColor4 := (RgbToColor16(palette[(color - 16) * 3] and $F, palette[(color - 16) * 3 + 1] and $F,
                             palette[(color - 16) * 3 + 2] and $F) and 6) div 2
 else MapColor4 := (RgbToColor16(palette[(color - 24) * 3] shr 4, palette[(color - 24) * 3 + 1] shr 4,
                                 palette[(color - 24) * 3 + 2] shr 4) and 6) div 2
end;

var
 i: Byte; packedMap: array[0..15] of Byte;
 palette: Types.TPalette24; headerEgaMap: Types.TMap32; headerCgaMap: Types.TMap32;
begin
 FillChar(dest^, SizeOf(Types.TPaletteInfo), 0); FillChar(palette, SizeOf(palette), 0);
 FillChar(headerEgaMap, SizeOf(headerEgaMap), 0); FillChar(headerCgaMap, SizeOf(headerCgaMap), 0);
 { A first byte with none of the bits $CC set starts an older header: eight bytes of 16 nibbles, the CGA map, with the
   identity as the EGA map. }
 if data^[readOfs] and $CC = 0 then begin
  dest^.flags := Blit.PAL_CGA_MAP or Blit.PAL_EGA_MAP; Move(data^[readOfs], packedMap, 8);
  for i := 0 to 15 do begin
   headerEgaMap[i] := i;
   if Odd(i) then headerCgaMap[i] := packedMap[i div 2] and $F
   else headerCgaMap[i] := (packedMap[i div 2] and $F0) shr 4
  end;
  Inc(readOfs, 8)
 end else begin
  dest^.flags := data^[readOfs]; Inc(readOfs);
  if dest^.flags and Blit.PAL_CGA_MAP <> 0 then begin
   Move(data^[readOfs], packedMap, 8);
   for i := 0 to 31 do
    headerCgaMap[i] := (packedMap[i div 4] shr ((i + i) and 6)) and 3;
   Inc(readOfs, 8)
  end;
  if dest^.flags and Blit.PAL_EGA_MAP <> 0 then begin
   Move(data^[readOfs], packedMap, 16);
   for i := 0 to 31 do
    headerEgaMap[i] := (packedMap[i div 2] shr ((i and 1) * 4)) and $F;
   Inc(readOfs, 16)
  end;
  if dest^.flags and Blit.PAL_HAS_PALETTE <> 0 then begin
   Move(data^[readOfs], palette, SizeOf(palette)); Inc(readOfs, 24)
  end
 end;
 case GDVars.displayMode of
  C_Video.VM_CGA: begin
     if dest^.flags and Blit.PAL_CGA_MAP <> 0 then dest^.map := headerCgaMap
     else if dest^.flags and Blit.PAL_EGA_MAP <> 0 then
      for i := 0 to 31 do dest^.map[i] := GDConsts.cgaMap[headerEgaMap[i]]
     else if dest^.flags and Blit.PAL_HAS_PALETTE <> 0 then begin
      for i := 0 to 15 do dest^.map[i] := GDConsts.cgaMap[i];
      for i := 16 to 31 do dest^.map[i] := MapColor4(i, palette)
     end else for i := 0 to 31 do dest^.map[i] := GDConsts.cgaMap[i];
     for i := 0 to 15 do dest^.palette[i] := (dest^.map[i + i] shl 4) + dest^.map[i + i + 1]
    end;
  C_Video.VM_EGA, C_Video.VM_TANDY: begin
       if dest^.flags and Blit.PAL_EGA_MAP <> 0 then dest^.map := headerEgaMap
       else if dest^.flags and Blit.PAL_HAS_PALETTE <> 0 then begin
        for i := 0 to 15 do dest^.map[i] := i;
        for i := 16 to 31 do dest^.map[i] := MapColor16(i, palette)
       end else for i := 0 to 31 do dest^.map[i] := GDConsts.egaMap[i]
      end;
  C_Video.VM_VGA: begin
     dest^.palette := palette;
     if dest^.flags and Blit.PAL_HAS_PALETTE <> 0 then dest^.vgaIndex := 255
    end
 end
end;

procedure DecodeImageData(data: Types.PBytes; var dest: Types.PBytes; var readOfs: Word;
                          count: Word; info: PPaletteInfo; width: Word);
var
 i: Word;
 { Unused in this version; see the other implementations of this routine. }
 chunk: array[1..8] of Byte;
begin
 GetMem(dest, count);
 if info^.flags and Blit.PAL_FIVE_PLANES = 0 then begin
  for i := 0 to count div 2 - 1 do begin
   dest^[i + i] := data^[i + readOfs] shr 4;
   dest^[i + i + 1] := data^[i + readOfs] and $F
  end;
  Inc(readOfs, count div 2)
 end else begin
  i := 0;
  while i < count do begin
   Raster.UnpackFivePlanes(@data^[readOfs], @dest^[i], width);
   Inc(i, width shl 3);
   Inc(readOfs, width * 5)
  end
 end
end;

{ VGA mode's decode: copies the pixels at src^[readOfs] into dest's frames, a byte a pixel, unpacking packed nibbles or
  five bit planes as info's flags say, and advances readOfs past them.
  @param(src Raw picture record.)
  @param(readOfs Offset of the pixel data in src; advanced past it.)
  @param(dest Picture to fill.)
  @param(info Color header, whose flags say how the pixels are stored.) }
procedure ExpandImageData(src: Types.PBytes; var readOfs: Word; dest: Types.PImgBuf; info: PPaletteInfo);
var
 frame: Byte;
 color: Byte;
 mask: Byte;
 byteIndex: Word;
 col: Word;
 { Unused in this version; see the other implementations of this routine. }
 inPos: Word;
 row: Word;
 outPos: Word;
begin
 with dest^ do begin
  outPos := 0;
  for frame := 1 to count do
   for row := 0 to height - 1 do begin
    if info^.flags and Blit.PAL_FIVE_PLANES = 0 then begin
     for col := 0 to width * 4 - 1 do begin
      data[outPos + col + col] := src^[col + readOfs] shr 4;
      data[outPos + col + col + 1] := src^[col + readOfs] and $F
     end;
     Inc(readOfs, width * 4)
    end else begin
     for col := 0 to width * 8 - 1 do begin
      mask := $80 shr (col and 7);
      byteIndex := col shr 3; color := 0;
      if src^[readOfs + byteIndex] and mask <> 0 then color := 1;
      if src^[readOfs + byteIndex + width] and mask <> 0 then Inc(color, 2);
      if src^[readOfs + byteIndex + width + width] and mask <> 0 then Inc(color, 4);
      if src^[readOfs + byteIndex + width + width + width] and mask <> 0 then Inc(color, 8);
      if src^[readOfs + byteIndex + width + width + width + width] and mask <> 0 then Inc(color, 16);
      data[outPos + col] := color
     end;
     Inc(readOfs, width * 5)
    end;
    Inc(outPos, width * 8)
   end
 end
end;

procedure LoadPic(name: String; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
var
 info: Types.TPaletteInfo;
 picHeight: Word;
 picWidth: Word;
 picOriginX: Word;
 picOriginY: Word; picCount: Byte;
 dataSize: Word;
 readOfs: Word;
 data: Types.PBytes; pixels: Types.PBytes;
 { Unused in this version; see the other implementations of this routine. }
 frame: Byte;
begin
 if pic <> nil then Raster.FreePic(pic);
 DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
 if dataSize = 0 then Exit;
 Move(data^[0], picHeight, SizeOf(picHeight)); Move(data^[2], picWidth, SizeOf(picWidth));
 Move(data^[4], picOriginX, SizeOf(picOriginX)); Move(data^[6], picOriginY, SizeOf(picOriginY));
 Move(data^[8], picCount, SizeOf(picCount));
 Raster.AllocPic(picHeight, picWidth, picCount, Byte(hasMask), pic);
 readOfs := 9; Blit.DecodePalette(Types.PBytes(data), readOfs, @info);
 with pic^ do begin
  originX := picOriginX; originY := picOriginY; mode3Extra := transpColor;
  palette := info.palette; currentFrame := info.vgaIndex
 end;
 if picHeight * picWidth * picCount = 0 then begin
  FreeMem(data, dataSize); Exit
 end;
 if GDVars.displayMode = C_Video.VM_VGA then begin
  Blit.ExpandImageData(Types.PBytes(data), readOfs, pic, @info);
  FreeMem(data, dataSize)
 end else begin
  Blit.DecodeImageData(Types.PBytes(data), pixels, readOfs, picHeight * picWidth * 8 * picCount, @info, picWidth);
  FreeMem(data, dataSize);
  Blit.ExpandPicFrames(pixels, 0, hasMask, transpColor, pic, @info);
  FreeMem(pixels, picHeight * picWidth * 8 * picCount)
 end
end;

procedure ExpandPicFrames(imgData: Types.PBytes; srcOff: Word; hasMask: Boolean;
                          transpColor: Byte; pic: Types.PImgBuf; info: PPaletteInfo);
var
 { Unused in this version; see the other implementations of this routine. }
 header: array[1..10] of Byte;
 chunk: TChunk; frame: Byte;
 x: Word;
 col: Word;
 row: Word;
 dstOff: Word;
 maskOff: Word;
 mask: Byte;
 k: Byte;
 j: Byte;
 bit: Byte;
 plane: Byte;
 color: Byte;
begin
 if pic = nil then Exit;
 with pic^ do begin
  dstOff := 0; maskOff := 0;
  case GDVars.displayMode of
   C_Video.VM_CGA: for frame := 1 to count do
      for row := 0 to height - 1 do
       for col := 0 to width - 1 do begin
        Move(imgData^[srcOff], chunk, SizeOf(chunk));
        if transp <> nil then begin
         mask := Blit.ComputeMask(transpColor, chunk); bit := $80;
         for j := 1 to 2 do begin
          for k := 4 to 7 do begin
           if bit and mask > 0 then
            transp^[maskOff] := transp^[maskOff] or GDConsts.cgaPositionBitmask[k];
           bit := bit shr 1
          end;
          Inc(maskOff)
         end
        end;
        for k := 0 to 3 do data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[info^.map[chunk[k]], k];
        if transp <> nil then data[dstOff] := data[dstOff] and not transp^[maskOff - 2];
        Inc(dstOff);
        for k := 4 to 7 do data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[info^.map[chunk[k]], k - 4];
        if transp <> nil then data[dstOff] := data[dstOff] and not transp^[maskOff - 1];
        Inc(dstOff); Inc(srcOff, 8)
       end;
   C_Video.VM_EGA: for frame := 1 to count do
      for row := 0 to height - 1 do
       for col := 0 to width - 1 do begin
        Move(imgData^[srcOff], chunk, SizeOf(chunk));
        if transp <> nil then FillChar(transp^[dstOff], 4, Blit.ComputeMask(transpColor, chunk));
        bit := $80;
        for k := 0 to 7 do begin
         color := info^.map[chunk[k]];
         for plane := 0 to 3 do
          if GDConsts.egaPlaneBit[plane] and color > 0 then
           data[dstOff + plane] := data[dstOff + plane] or bit;
         bit := bit shr 1
        end;
        if transp <> nil then
         for plane := 0 to 3 do data[dstOff + plane] := data[dstOff + plane] and not transp^[dstOff];
        Inc(dstOff, 4); Inc(srcOff, 8)
       end;
   C_Video.VM_TANDY: for frame := 1 to count do begin
      for x := 0 to frameSize - 1 do begin
       data[dstOff + x] := info^.map[imgData^[srcOff + x + x + 1]] + (info^.map[imgData^[srcOff + x + x]] shl 4);
       if transp <> nil then begin
        if imgData^[srcOff + x + x] = transpColor then transp^[dstOff + x] := $F0;
        if imgData^[srcOff + x + x + 1] = transpColor then Inc(transp^[dstOff + x], $F);
        data[dstOff + x] := data[dstOff + x] and not transp^[dstOff + x]
       end
      end;
      Inc(dstOff, frameSize); Inc(srcOff, frameSize + frameSize)
     end;
   C_Video.VM_VGA: for frame := 1 to count do begin
      x := 0;
      while x < frameSize do begin
       data[dstOff + x] := imgData^[srcOff + x]; Inc(x)
      end;
      Inc(dstOff, frameSize); Inc(srcOff, frameSize)
     end
  end
 end
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
 { Unused in this version; see the other implementations of this routine. }
 col: Integer;
 row: Integer; colOff: Word; firstRow: Word;
 { Unused in this version; see the other implementations of this routine. }
 colEnd: Word;
 lastRow: Word; rowBytes: Word; srcOff: Word;
 { Unused in this version; see the other implementations of this routine. }
 plane: Byte;
begin
 if pic = nil then Exit;
 with pic^ do case GDVars.displayMode of
  C_Video.VM_CGA: begin
     rowBytes := width * 2; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 2;
     if (height <> 0) and (width <> 0) then
      for row := firstRow to lastRow do begin
       Move(pic^.data[srcOff], Mem[GDVars.cgaRowSeg[row]:colOff], rowBytes);
       Inc(srcOff, rowBytes)
      end
    end;
  C_Video.VM_EGA: begin
     firstRow := screenY * 8; colOff := screenX;
     if (height <> 0) and (width <> 0) then
      Raster.ShowPicEga(@pic^.data, firstRow, height, colOff, width)
    end;
  C_Video.VM_TANDY: begin
     rowBytes := width * 4; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 4;
     for row := firstRow to lastRow do begin
      Move(pic^.data[srcOff], Mem[GDVars.tandyRowSeg[row]:colOff], rowBytes);
      Inc(srcOff, rowBytes)
     end
    end;
  C_Video.VM_VGA: begin
     GDVars.paletteWork := pic^.palette;
     GDVars.paletteFrame := pic^.currentFrame;
     Raster.PrepareVgaPalette;
     rowBytes := width * 8; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 8;
     for row := firstRow to lastRow do begin
      Move(pic^.data[srcOff], Mem[C_Video.DISPLAY_SEG:colOff + LongInt(320 * row)], rowBytes);
      Inc(srcOff, rowBytes)
     end
    end
 end
end;

procedure ShowPicMasked(screenX, screenY: Integer; pic: Types.PImgBuf; transpColor: Byte);
var
 col: Integer;
 row: Integer; colOff: Word; firstRow: Word; colEnd: Word; lastRow: Word; rowBytes: Word; srcOff: Word;
 plane: Byte;
 { Unused in this version; see the other implementations of this routine. }
 screenByte: Byte;
begin
 if pic = nil then Exit;
 if (GDVars.displayMode <> C_Video.VM_VGA) and (pic^.transp = nil) then Blit.ShowPic(screenX, screenY, pic);
 with pic^ do case GDVars.displayMode of
  C_Video.VM_CGA: begin
     if (pic^.height = 0) or (pic^.width = 0) then Exit;
     rowBytes := width * 2; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 2;
     colEnd := colOff + rowBytes - 1;
     for row := firstRow to lastRow do
      for col := colOff to colEnd do begin
       Mem[GDVars.cgaRowSeg[row]:col] := (Mem[GDVars.cgaRowSeg[row]:col] and pic^.transp^[srcOff])
        or pic^.data[srcOff]; Inc(srcOff)
      end
    end;
  C_Video.VM_EGA: begin
     if (pic^.height = 0) or (pic^.width = 0) then Exit;
     firstRow := screenY * 8; colOff := screenX; srcOff := 0;
     firstRow := screenY * 8; lastRow := firstRow + height - 1;
     colOff := screenX; colEnd := colOff + width - 1;
     Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_BIT_MASK_REG; Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
     for row := firstRow to lastRow do
      for col := colOff to colEnd do begin
       Port[C_Ega.GC_DATA_PORT] := pic^.transp^[srcOff] xor $FF;
       { The read loads the EGA latches, which keep the masked pixels. }
       screenByte := Mem[C_Video.DISPLAY_SEG:LongInt(GDVars.fbRowOfs[row]) + col];
       for plane := 0 to 3 do begin
        Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[plane];
        Mem[C_Video.DISPLAY_SEG:LongInt(GDVars.fbRowOfs[row]) + col] := pic^.data[srcOff]; Inc(srcOff)
       end
      end;
     Port[C_Ega.GC_DATA_PORT] := $FF; Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES
    end;
  C_Video.VM_TANDY: begin
     if (pic^.height = 0) or (pic^.width = 0) then Exit;
     rowBytes := width * 4; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 4;
     colEnd := colOff + rowBytes - 1;
     for row := firstRow to lastRow do
      for col := colOff to colEnd do begin
       Mem[GDVars.tandyRowSeg[row]:col] := (Mem[GDVars.tandyRowSeg[row]:col] and pic^.transp^[srcOff])
        or pic^.data[srcOff]; Inc(srcOff)
      end
    end;
  C_Video.VM_VGA: begin
     GDVars.paletteWork := pic^.palette;
     GDVars.paletteFrame := pic^.currentFrame;
     Raster.PrepareVgaPalette;
     if (pic^.height = 0) or (pic^.width = 0) then Exit;
     rowBytes := width * 8; srcOff := 0; firstRow := screenY * 8;
     lastRow := firstRow + height - 1; colOff := screenX * 8;
     colEnd := colOff + rowBytes - 1;
     for row := firstRow to lastRow do
      for col := colOff to colEnd do begin
       if pic^.data[srcOff] <> transpColor then
        Mem[C_Video.DISPLAY_SEG:320 * row + col] := pic^.data[srcOff];
       Inc(srcOff)
      end
    end
 end
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);
var
 srcOff: Word;
 dstOff: Word; nFrames: Byte;
 col: Word;
 row: Word; match: Byte;
 planeMask: array[0..3] of Byte; plane: Byte;
 { Unused in this version; see the other implementations of this routine. }
 cellByte: Byte;
 pixPos: Byte;
 rowBytes: Word; fromHigh: Byte; toHigh: Byte; pairIdx: Byte; scratchPic: Types.PImgBuf;
begin
 if pic = nil then Exit;
 if GDVars.displayMode = C_Video.VM_CGA then Exit;
 with pic^ do begin
  if frame < 0 then begin frame := 0; nFrames := count end else nFrames := 1;
  srcOff := frame * frameSize
 end;
 dstOff := 0;
 Raster.AllocPic(pic^.height, pic^.width, nFrames, 0, scratchPic);
 scratchPic^.palette := pic^.palette;
 scratchPic^.currentFrame := pic^.currentFrame;
 scratchPic^.mode3Extra := pic^.mode3Extra;
 Move(pic^.data[srcOff], scratchPic^.data[dstOff], scratchPic^.count * scratchPic^.frameSize);
 for pairIdx := 0 to 15 do begin
  with pic^ do begin
   if frame < 0 then begin frame := 0; nFrames := count end else nFrames := 1;
   srcOff := frame * frameSize
  end;
  dstOff := 0;
  if fromColors[pairIdx] <> toColors[pairIdx] then
   with scratchPic^ do case GDVars.displayMode of
    C_Video.VM_CGA: begin
       rowBytes := width * 2;
       for GDVars.sharedLoopIndex := frame to nFrames + frame - 1 do
        for row := 1 to height do for col := 1 to rowBytes do begin
         for pixPos := 0 to 3 do
          if pic^.data[srcOff] and GDConsts.cgaPositionBitmask[pixPos + 4] =
              GDConsts.cgaPixPos[Blit.SrcNibble(fromColors[pairIdx], palette), pixPos] then
           if not isDithered or isDithered and (Random(4) = 0) then
            data[dstOff] := data[dstOff] and not GDConsts.cgaPositionBitmask[pixPos + 4] or
              GDConsts.cgaPixPos[Blit.SrcNibble(toColors[pairIdx], palette), pixPos];
         if pic^.transp <> nil then
          data[dstOff] := data[dstOff] and not pic^.transp^[srcOff];
         Inc(srcOff); Inc(dstOff)
        end
      end;
    C_Video.VM_EGA: begin
       for plane := 0 to 3 do
        if fromColors[pairIdx] and GDConsts.egaPlaneBit[plane] > 0 then planeMask[plane] := 0
        else planeMask[plane] := $FF;
       for GDVars.sharedLoopIndex := frame to nFrames + frame - 1 do
        for row := 1 to height do for col := 1 to width do begin
         if isDithered then match := Random(256) and Random(256) else match := $FF;
         for plane := 0 to 3 do match := (pic^.data[plane + srcOff] xor planeMask[plane]) and match;
         for plane := 0 to 3 do
          if toColors[pairIdx] and GDConsts.egaPlaneBit[plane] > 0 then
           data[plane + dstOff] := data[plane + dstOff] or match
          else data[plane + dstOff] := data[plane + dstOff] and not match;
         if pic^.transp <> nil then begin
          data[dstOff] := data[dstOff] and not pic^.transp^[srcOff];
          data[dstOff + 1] := data[dstOff + 1] and not pic^.transp^[srcOff + 1];
          data[dstOff + 2] := data[dstOff + 2] and not pic^.transp^[srcOff + 2];
          data[dstOff + 3] := data[dstOff + 3] and not pic^.transp^[srcOff + 3]
         end;
         Inc(srcOff, 4); Inc(dstOff, 4)
        end
      end;
    C_Video.VM_TANDY: begin
       rowBytes := width * 4; fromHigh := fromColors[pairIdx] shl 4;
       toHigh := toColors[pairIdx] shl 4;
       for GDVars.sharedLoopIndex := frame to nFrames + frame - 1 do
        for row := 1 to height do for col := 1 to rowBytes do begin
         if pic^.data[srcOff] and $F0 = fromHigh then
          if not isDithered or isDithered and (Random(4) = 0) then
           data[dstOff] := data[dstOff] and $F or toHigh;
         if pic^.data[srcOff] and $F = fromColors[pairIdx] then
          if not isDithered or isDithered and (Random(4) = 0) then
           data[dstOff] := data[dstOff] and $F0 or toColors[pairIdx];
         if pic^.transp <> nil then
          data[dstOff] := data[dstOff] and not pic^.transp^[srcOff];
         Inc(srcOff); Inc(dstOff)
        end
      end;
    C_Video.VM_VGA: begin
       if fromColors[pairIdx] = pic^.mode3Extra then
        scratchPic^.mode3Extra := toColors[pairIdx];
       rowBytes := width * 8;
       for GDVars.sharedLoopIndex := frame to nFrames + frame - 1 do
        for row := 1 to height do for col := 1 to rowBytes do begin
         if pic^.data[srcOff] = fromColors[pairIdx] then
          if not isDithered or isDithered and (Random(4) = 0) then
           data[dstOff] := toColors[pairIdx];
         Inc(srcOff); Inc(dstOff)
        end
      end
   end
 end;
 with pic^ do begin
  Move(scratchPic^.data, data[frame * frameSize], nFrames * frameSize);
  mode3Extra := scratchPic^.mode3Extra
 end;
 Raster.FreePic(scratchPic)
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; pic: Types.PImgBuf);
var
 cellSize: Word;
 clipLeft: Word;
 clipRight: Word;
 clampedX: Word;
 rightMargin: Word;
 runLen: Word;
 lastRow: Word;
 dstOff: Word;
 row: Word;
 planeMask: array[0..3] of Byte; absRow: Word; screenOfs: Word; plane: Byte;
begin
 if pic = nil then Exit;
 if x < 0 then begin clipLeft := Abs(x); clampedX := 0 end
 else begin clipLeft := 0; clampedX := x end;
 if pic^.width < x + width then begin
  clipRight := x + width - pic^.width; rightMargin := 0
 end else begin clipRight := 0; rightMargin := pic^.width - (x + width) end;
 if y < 0 then begin
  dstOff := 0; absRow := 0; lastRow := height - Abs(y)
 end else begin
  absRow := y; dstOff := absRow * pic^.width; lastRow := height - 1;
  if pic^.height < y + height then lastRow := pic^.height - 1 - y
  else lastRow := height - 1
 end;
 case GDVars.displayMode of
  C_Video.VM_CGA, C_Video.VM_TANDY, C_Video.VM_VGA: begin
   case GDVars.displayMode of
    C_Video.VM_CGA: cellSize := 2;
    C_Video.VM_TANDY: cellSize := 4;
    C_Video.VM_VGA: cellSize := 8
   end;
   runLen := (width - clipLeft - clipRight) * cellSize;
   clampedX := clampedX * cellSize; rightMargin := rightMargin * cellSize; dstOff := dstOff * cellSize;
   screenOfs := clampedX;
   for row := 0 to lastRow do begin
    GDVars.spanActive[absRow] := 1; Inc(dstOff, clampedX);
    if GDVars.spanFirstOfs[absRow] > dstOff then begin
     GDVars.spanScreenOfs[absRow] := screenOfs; GDVars.spanFirstOfs[absRow] := dstOff
    end;
    case GDVars.displayMode of
     C_Video.VM_CGA: FillChar(pic^.data[dstOff], runLen,
                              GDConsts.cgaColorFill[Blit.SrcNibble(color, GDConsts.compositeMap)]);
     C_Video.VM_TANDY: FillChar(pic^.data[dstOff], runLen, GDConsts.tandyColorFill[color]);
     C_Video.VM_VGA: FillChar(pic^.data[dstOff], runLen, color)
    end;
    Inc(dstOff, runLen);
    if dstOff - 1 > GDVars.spanLastOfs[absRow] then GDVars.spanLastOfs[absRow] := dstOff - 1;
    Inc(dstOff, rightMargin); Inc(absRow)
   end
  end;
  C_Video.VM_EGA: begin
   screenOfs := clampedX; runLen := width - clipLeft - clipRight;
   clampedX := clampedX * 4; rightMargin := rightMargin * 4; dstOff := dstOff * 4;
   FillChar(planeMask, SizeOf(planeMask), 0);
   for plane := 0 to 3 do
    if GDConsts.egaPlaneBit[plane] and color > 0 then planeMask[plane] := $FF;
   for row := 0 to lastRow do begin
    GDVars.spanActive[absRow] := 1; Inc(dstOff, clampedX);
    if GDVars.spanFirstOfs[absRow] > dstOff then begin
     GDVars.spanScreenOfs[absRow] := screenOfs; GDVars.spanFirstOfs[absRow] := dstOff
    end;
    for GDVars.sharedLoopIndex := 1 to runLen do begin
     Move(planeMask, pic^.data[dstOff], SizeOf(planeMask)); Inc(dstOff, 4)
    end;
    if dstOff - 1 > GDVars.spanLastOfs[absRow] then GDVars.spanLastOfs[absRow] := dstOff - 1;
    Inc(dstOff, rightMargin); Inc(absRow)
   end
  end
 end
end;

procedure SetPaletteRegister(registerIndex, color: Byte);
begin
 GDVars.interruptRegisters.AH := Blit.BIOS_PALETTE; GDVars.interruptRegisters.AL := Blit.BIOS_SET_PALETTE_REG;
 if color < 8 then GDVars.interruptRegisters.BH := color
 else GDVars.interruptRegisters.BH := color + 8;
 GDVars.interruptRegisters.BL := registerIndex;
 Intr($10, Registers(GDVars.interruptRegisters))
end;

procedure SetPaletteRegisterTandy(registerIndex, color: Byte);
begin
 GDVars.interruptRegisters.AH := Blit.BIOS_PALETTE; GDVars.interruptRegisters.AL := Blit.BIOS_SET_PALETTE_REG;
 GDVars.interruptRegisters.BH := color;
 GDVars.interruptRegisters.BL := registerIndex;
 Intr($10, Registers(GDVars.interruptRegisters))
end;

procedure PlotViewPixel(x, y: Word; color: Byte);
begin
 GDVars.interruptRegisters.AH := Blit.BIOS_WRITE_PIXEL; GDVars.interruptRegisters.AL := color;
 GDVars.interruptRegisters.BH := 0;
 GDVars.interruptRegisters.CX := x; GDVars.interruptRegisters.DX := y;
 Intr($10, Registers(GDVars.interruptRegisters))
end;

{ Decodes one row like DecodeImageData, into dest^ without allocating it. Five-plane data takes count as cells (count*8
  pixels from count*5 bytes), packed nibbles as pixels (count div 2 bytes); RenderSpecialData passes the width in cells
  either way. Note: a packed row therefore decodes one pixel for each cell.
  @param(data Raw picture record.)
  @param(readOfs Offset of the row in data; advanced past it.)
  @param(dest Buffer for the decoded pixels.)
  @param(info Color header, whose flags say how the pixels are stored.)
  @param(count Row length, as above.) }
procedure DecodeSpecialRow(data: Types.PBytes; var readOfs: Word; dest: Types.PBytes; var info: Types.TPaletteInfo;
                           count: Word);
var
 i: Word;
 { Unused in this version; see the other implementations of this routine. }
 chunk: array[1..8] of Byte;
begin
 if info.flags and Blit.PAL_FIVE_PLANES = 0 then begin
  for i := 0 to count div 2 - 1 do begin
   dest^[i + i] := data^[i + readOfs] shr 4;
   dest^[i + i + 1] := data^[i + readOfs] and $F
  end;
  Inc(readOfs, count div 2)
 end else begin
  Raster.UnpackFivePlanes(
    @data^[readOfs], @dest^, count);
  Inc(readOfs, count + count + count + count + count)
 end
end;

{ DisplaySpecialPic's drawing: decodes each row into a line buffer, converts it to the display mode's layout through
  info's map and writes it to the screen; VGA mode stages the palette first and copies the rows unmapped.
  @param(data Raw picture record.)
  @param(readOfs Offset of the pixel data in data.)
  @param(info Decoded color header.)
  @param(col Left edge, in 8-pixel cells.)
  @param(row Top scanline.)
  @param(height Rows to draw.)
  @param(width Row width, in 8-pixel cells.) }
procedure RenderSpecialData(data: Types.PBytes; readOfs: Word; info: PPaletteInfo; col, row: Integer; height,
                            width: Word);
var
 lineBuf: array[0..319] of Byte; srcPos: Word; chunk: TChunk;
 dstByte: Word;
 colCtr: Word;
 rowCtr: Word;
 rowBytes: Word;
 dstPos: Word;
 { Unused in this version; see the other implementations of this routine. }
 mask: Byte;
 k: Byte;
 { Unused in this version; see the other implementations of this routine. }
 j: Byte;
 bit: Byte;
 plane: Byte;
 color: Byte;
 outBuf: array[0..159] of Byte;
begin
 case GDVars.displayMode of
  C_Video.VM_CGA: begin
   col := col * 2; rowBytes := width * 2;
   for rowCtr := 0 to height - 1 do begin
    Blit.DecodeSpecialRow(data, readOfs, Types.PBytes(@lineBuf), info^, width);
    FillChar(outBuf, rowBytes, 0); srcPos := 0; dstPos := 0;
    for colCtr := 0 to width - 1 do begin
     Move(lineBuf[srcPos], chunk, SizeOf(chunk));
     for k := 0 to 3 do outBuf[dstPos] := outBuf[dstPos] or GDConsts.cgaPixPos[info^.map[chunk[k]], k];
     Inc(dstPos);
     for k := 4 to 7 do outBuf[dstPos] := outBuf[dstPos] or GDConsts.cgaPixPos[info^.map[chunk[k]], k - 4];
     Inc(dstPos); Inc(srcPos, 8)
    end;
    Move(outBuf, Mem[GDVars.cgaRowSeg[rowCtr + row]:col], rowBytes)
   end
  end;
  C_Video.VM_EGA: begin
   rowBytes := width shl 2;
   for rowCtr := 0 to height - 1 do begin
    Blit.DecodeSpecialRow(data, readOfs, Types.PBytes(@lineBuf), info^, width);
    FillChar(outBuf, rowBytes, 0); dstPos := 0; srcPos := 0;
    for colCtr := 0 to width - 1 do begin
     Move(lineBuf[srcPos], chunk, SizeOf(chunk)); bit := $80;
     for k := 0 to 7 do begin
      color := info^.map[chunk[k]];
      for plane := 0 to 3 do
       if GDConsts.egaPlaneBit[plane] and color > 0 then
        outBuf[dstPos + plane] := outBuf[dstPos + plane] or bit;
      bit := bit shr 1
     end;
     Inc(dstPos, 4); Inc(srcPos, 8)
    end;
    Raster.WriteEgaCells(@outBuf, Ptr(C_Video.DISPLAY_SEG, (rowCtr + row) * 40 + col), width)
   end
  end;
  C_Video.VM_TANDY: begin
   rowBytes := width shl 2; col := col shl 2; srcPos := 0;
   for rowCtr := 0 to height - 1 do begin
    Blit.DecodeSpecialRow(data, readOfs, Types.PBytes(@lineBuf), info^, width);
    srcPos := 0; dstByte := 0;
    for colCtr := 0 to rowBytes - 1 do begin
     Mem[GDVars.tandyRowSeg[rowCtr + row]:col + dstByte] := info^.map[lineBuf[srcPos + 1]] +
       (info^.map[lineBuf[srcPos]] shl 4);
     Inc(dstByte); Inc(srcPos, 2)
    end
   end
  end;
  C_Video.VM_VGA: begin
   rowBytes := width shl 3; col := col shl 3;
   GDVars.paletteWork := info^.palette;
   GDVars.paletteFrame := info^.vgaIndex;
   Raster.PrepareVgaPalette;
   for rowCtr := 0 to height - 1 do begin
    Blit.DecodeSpecialRow(data, readOfs, Types.PBytes(@lineBuf), info^, width);
    Move(lineBuf, Types.PBytes(LongInt(C_Video.DISPLAY_SEG) * $10000 + LongInt(320 * (row + rowCtr)) + col)^[0],
         rowBytes)
   end
  end
 end
end;

procedure DisplaySpecialPic(name: String; fileId: Byte; col, row: Integer);
var
 info: Types.TPaletteInfo; height: Word; width: Word; count: Byte;
 dataSize: Word;
 readOfs: Word; data: Types.PBytes; originX: Word; originY: Word;
begin
 DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
 if dataSize = 0 then Exit;
 Move(data^[0], height, SizeOf(height)); Move(data^[2], width, SizeOf(width)); Move(data^[8], count, SizeOf(count));
 if (col = -1) and (row = -1) then begin
  Move(data^[4], originX, SizeOf(originX)); Move(data^[6], originY, SizeOf(originY));
  col := originX; row := originY shl 3
 end;
 readOfs := 9; Blit.DecodePalette(Types.PBytes(data), readOfs, @info);
 if height * width * count = 0 then FreeMem(data, dataSize)
 else begin
  Blit.RenderSpecialData(Types.PBytes(data), readOfs, @info, col, row, height, width);
  FreeMem(data, dataSize)
 end
end;

begin
 FillChar(GDVars.paletteShown, SizeOf(GDVars.paletteShown), 0)
end.
