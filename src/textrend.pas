{ The text renderer. It loads the 8x8 game font (LoadGameFont) and draws its glyphs in whichever display mode is set
  (GDVars.displayMode: CGA, EGA, Tandy or VGA) through the four glyph blitters in textrend.asm, one character cell at a
  time (RenderChar). On that it builds strings (DisplayString, DisplayStringClipped), the word-wrapping, paging message
  window (DisplayMessageWindow), the bottom-line prompts and pauses (ReadString, DisplayAndPause, PrintAndPause,
  PauseOnly), the status line, and screen and rectangle clearing (ClearScreen, ClearRect), with the EGA page set-up
  those need. Its initialization installs DisplayStatusLine, DisplayStatusAndWait, LongToString and RenderChar in
  GDVars' hook cells. }
{$O+,F+,S+,A+}
unit TextRend;

interface

uses Crt, Dos, GDConsts, GDVars, C_Keys, C_Ega, C_Ifc, C_Screen, C_Video, DaxIo, GameIo, Types;

type
  { A CGA bank: 100 rows of 80 bytes, which TextRend clears as 40 words a row and Border fills as bytes. }
  TCgaBank = record
    case Integer of
      0: (bytes: array[0..99, 0..79] of Byte);
      1: (words: array[0..99, 0..39] of Word);
  end;
  { a Tandy bank: 50 rows of 160 bytes }
  TTandyBank = array[0..49, 0..159] of Byte;

var
  { the CGA banks, the even and the odd rows, and the four Tandy banks }
  cgaBank0: TCgaBank absolute C_Video.GFX_BANK0_SEG:$0000;
  cgaBank1: TCgaBank absolute C_Video.GFX_BANK1_SEG:$0000;
  tandyBank0: TTandyBank absolute C_Video.GFX_BANK0_SEG:$0000;
  tandyBank1: TTandyBank absolute C_Video.GFX_BANK1_SEG:$0000;
  tandyBank2: TTandyBank absolute C_Video.GFX_BANK2_SEG:$0000;
  tandyBank3: TTandyBank absolute C_Video.GFX_BANK3_SEG:$0000;

{ Shows an EGA page (video BIOS function 5) and records its segment as the current page.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Records an EGA page's segment as the other page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  the other page back at the page number saved for it.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Load the 8x8 game font, 8X8D1.DAX record 201, into GDVars.gameFont and set GDConsts.isFontLoaded; on failure restore
  the saved video mode and report it. }
procedure LoadGameFont;

{ Draw source from cell col, row, a character a cell; RenderChar drops cells off the screen.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayString(col, row, fg, bg: Byte; source: String);

{ Draw count copies of a glyph from cell col, row in fg on bg: for isAscii, ch upper-cased mod 64; otherwise glyph ch.
  Nothing is drawn off the 40x25 screen or before the font is loaded.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(count The number of copies.)
  @param(ch The character or glyph number.)
  @param(isAscii Nonzero when ch is a character.) }
procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);

{ Clip the text to the columns left of 39 and display it.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayStringClipped(col, row, fg, bg: Byte; source: String);

{ Word-wrap source into the window from the text cursor (GDVars.curCol, curRow), clearing the window first when
  clearFirst; #10 starts a line, #12 a page, and a full window waits for a key.
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(clearFirst True to clear the window first.)
  @param(source The text.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);

{ Blanks a run of cells; nothing happens when the first cell is off the screen.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The color to blank to.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Prompt on the bottom line and read up to maxLen characters, upper-cased; Enter or Escape ends the input, and so does
  demo mode.
  @param(query The prompt.)
  @param(fg The prompt's color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most characters read.)
  @returns(The input, upper-cased.) }
function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;

{ Show msg on the bottom line until a key is pressed, then clear the line.
  @param(fg The text color.)
  @param(bg The background color.)
  @param(msg The message.) }
procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clear the whole screen in the display mode, both pages in EGA. }
procedure ClearScreen;

{ Shows a message on the bottom row for the game-speed pause (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(fg The text color.)
  @param(bg The background color.) }
procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);

{ Wait by the game delay, 220 ms longer outside combat. }
procedure PauseOnly;

{ Clears a rectangle of character cells to color 0.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Move the text cursor to column 1 of the next row, clearing GDVars.protNewLine; both arms do the same. }
procedure AdvanceTextCursor;

{ Show msg in light green on the cleared bottom line.
  @param(msg The message.) }
procedure DisplayStatusLine(msg: String);

{ Show msg on the status line, discard waiting keys and wait for one, read straight from Crt.
  @param(msg The message.) }
procedure DisplayStatusAndWait(msg: String);

{ Converts a number to decimal text.
  @param(value The number.)
  @returns(The text.) }
function LongToString(value: LongInt): String;

implementation

const
  { INT 10h function: show display page AL }
  BIOS_SET_ACTIVE_PAGE = $05;

var
  vgaScreen: array[0..63999] of Byte absolute C_Video.DISPLAY_SEG:$0000;

{$F-}
{$L TEXTREND.OBJ}
{ Draws one character cell on CGA from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure CgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{ Draws one character cell on EGA from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure EgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{ Draws one character cell on Tandy from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure TandyGlyph(col, row: Word; fg, bg, charIdx: Byte); external;

{ Draws one character cell on VGA from the glyph rows RenderChar staged in GDVars.glyphBits.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(charIdx Unused.) }
procedure VgaGlyph(col, row: Word; fg, bg, charIdx: Byte); external;
{$F+}

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;
begin
  Port[C_Ega.GC_ADDR_PORT] := 0; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 1; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 2; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 3; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 4; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 5; Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 7; Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_BIT_MASK_REG; Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG; Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.interruptRegisters.ah := TextRend.BIOS_SET_ACTIVE_PAGE; GDVars.interruptRegisters.al := page;
  Intr($10, Registers(GDVars.interruptRegisters));
  GDVars.egaCurPage := C_Video.DISPLAY_SEG + (Word(page) shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := C_Video.DISPLAY_SEG + (Word(page) shl 9);
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  off: Word;
  rows: Word;
  i: Word;
begin
  savedPage := GDVars.otherEgaPage;
  off := Word(ulRow) * 40 * 8 + ulCol;
  rows := (lrRow - ulRow + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page); TextRend.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := 5; Port[C_Ega.GC_DATA_PORT] := 2;
  for i := 0 to rows do begin
    FillChar(Mem[GDVars.egaOtherPage:off], lrCol - ulCol + 1, color);
    Inc(off, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := 5; Port[C_Ega.GC_DATA_PORT] := 0;
  GDVars.otherEgaPage := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.otherEgaPage);
end;

procedure LoadGameFont;
var
  size: Word;
  data: Types.PBytes;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, size, data);
  if size = 0 then begin
    { restore the saved BIOS video mode before reporting the failure }
    GDVars.interruptRegisters.ah := C_Video.BIOS_SET_VIDEO_MODE;
    GDVars.interruptRegisters.al := GDVars.savedVideoMode;
    Intr($10, Registers(GDVars.interruptRegisters));
    Writeln('Cannot load character set');
  end else begin
    Move(data^, GDVars.gameFont^, size);
    FreeMem(data, size);
    GDConsts.isFontLoaded := True;
  end;
end;

procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);
var
  i: Byte;
  idx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  cnt: Word;
  { Unused in this version; see the other implementations of this routine. }
  colBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaWord: Word;
  { Unused in this version; see the other implementations of this routine. }
  tandyPx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bank: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outerRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  plane: Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if isAscii <> 0 then idx := Ord(UpCase(Chr(ch))) mod 64 else idx := ch;
  Move(GDVars.gameFont^[idx], GDVars.glyphBits, SizeOf(GDVars.glyphBits));
  case GDVars.displayMode of
    C_Video.VM_CGA: for i := 1 to count do begin
         TextRend.CgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Video.VM_EGA: for i := 1 to count do begin
         TextRend.EgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Video.VM_TANDY: for i := 1 to count do begin
         TextRend.TandyGlyph(col, row, fg, bg, idx); Inc(col)
       end;
    C_Video.VM_VGA: for i := 1 to count do begin
         TextRend.VgaGlyph(col, row, fg, bg, idx); Inc(col)
       end;
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  { Note: col and row are Bytes, so the lower-bound tests are always false. }
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, color, count, 32, 1);
end;

procedure DisplayString(col, row, fg, bg: Byte; source: String);
var
  len: Byte;
  i: Byte;
begin
  if (col > 39) or (row > 39) then Exit;
  len := Length(source);
  for i := 1 to len do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1); Inc(col)
  end;
end;

procedure DisplayStringClipped(col, row, fg, bg: Byte; source: String);
begin
  TextRend.DisplayString(col, row, fg, bg, Copy(source, 1, 39 - col));
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);
var
  width: Byte;
  len: Byte;
  idx: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Draw source from idx through lineEnd at the text cursor, advancing both. }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, fg, bg, 1, Ord(source[idx]), 1);
      Inc(idx); Inc(GDVars.curCol);
    end;
  end;

  { Skip idx past spaces. }
  procedure FindNewIndex;
  begin
    while (idx <= len) and (source[idx] = ' ') do Inc(idx);
  end;

  { Wait for a key, then clear the window and put the text cursor at its top left. }
  procedure PageWindow;
  begin
    GDVars.curCol := ulCol; GDVars.curRow := ulRow;
    TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
  end;

  { Set lineEnd to the last character of the word at idx, with its trailing space, within the width. }
  procedure FindLineEnd;
  begin
    lineEnd := idx;
    while (idx - lineEnd + 1 < width) and (lineEnd <= len) and (source[lineEnd] <> ' ') and
        not (source[lineEnd] in [#10, #12]) do
      Inc(lineEnd);
    if (lineEnd <= len) and (source[lineEnd] = ' ') then Inc(lineEnd);
    Dec(lineEnd);
  end;
begin
  if (ulCol > 39) or (ulRow > 24) or (lrCol > 39) or (lrRow > 24) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol; GDVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow); GDVars.curCol := ulCol; GDVars.curRow := ulRow;
  end;
  idx := 1; len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    if source[idx] = #10 then begin
      Inc(idx); GDVars.curCol := ulCol; Inc(GDVars.curRow);
      if (GDVars.curRow > lrRow) and (idx <= len) then PageWindow;
    end else if source[idx] = #12 then begin
      Inc(idx); PageWindow;
    end else begin
      FindLineEnd;
      if lineEnd - idx + GDVars.curCol >= lrCol then begin
        if GDVars.curCol <= lrCol then begin
          if (lineEnd - idx + GDVars.curCol = lrCol + 1) and (source[lineEnd] = ' ') then Dec(lineEnd);
        end;
        if lineEnd - idx + GDVars.curCol = lrCol then begin
          PrintCharInWindow; GDVars.curCol := ulCol; Inc(GDVars.curRow); FindNewIndex;
        end else begin
          GDVars.curCol := ulCol; Inc(GDVars.curRow); FindNewIndex; PrintCharInWindow;
        end;
        if (GDVars.curRow > lrRow) and (idx < len) then begin
          PageWindow; PrintCharInWindow;
        end;
      end else PrintCharInWindow;
    end;
  until idx > len;
  if GDVars.curCol > lrCol then begin GDVars.curCol := ulCol; Inc(GDVars.curRow) end;
end;

function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  reply: String;
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  key2: Char;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, query);
  col := Length(query);
  GameIo.WaitMouseRelease;
  TextRend.DisplayString(col + 1, C_Screen.STATUS_ROW, White, Black, '@');
  reply := '';
  repeat
    key := GameIo.ReadGameKey;
    case key of
      #0: key2 := GameIo.ReadGameKey;
      #32..#122: if Length(reply) < maxLen then begin
        reply := reply + key; Inc(col);
        TextRend.DisplayString(col, C_Screen.STATUS_ROW, White, Black, key + '@')
      end;
      C_Keys.BACKSPACE: if Length(reply) > 0 then begin
        reply := Copy(reply, 1, Length(reply) - 1); Dec(col);
        TextRend.DisplayString(col + 1, C_Screen.STATUS_ROW, White, Black, '@ ')
      end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE) or GDVars.demoMode;
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  for col := 1 to Length(reply) do reply[col] := UpCase(reply[col]);
  ReadString := reply;
end;

procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, msg);
  GameIo.WaitMouseRelease;
  c := GameIo.ReadGameKey;
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
end;

function GetTicks: LongInt;
var
  h: Word;
  m: Word;
  s: Word;
  hs: Word;
begin
  GetTime(h, m, s, hs);
  GetTicks := LongInt(h) * 360000 + LongInt(m) * 6000 + LongInt(s) * 100 + hs;
end;

procedure ClearScreen;
begin
  case GDVars.displayMode of
    C_Video.VM_CGA: begin
         { the odd-line bank first }
         FillChar(cgaBank1, SizeOf(cgaBank1), 0);
         FillChar(cgaBank0, SizeOf(cgaBank0), 0);
       end;
    C_Video.VM_EGA: begin
         TextRend.FillRectEga(0, 0, 39, 24, 0, 0);
         TextRend.FillRectEga(0, 0, 39, 24, 1, 0);
       end;
    C_Video.VM_VGA: FillChar(vgaScreen, SizeOf(vgaScreen), 0);
    C_Video.VM_TANDY: begin
         FillChar(tandyBank0, SizeOf(tandyBank0), 0); FillChar(tandyBank1, SizeOf(tandyBank1), 0);
         FillChar(tandyBank2, SizeOf(tandyBank2), 0); FillChar(tandyBank3, SizeOf(tandyBank3), 0)
       end;
  end;
end;

procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);
begin
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, fg, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, C_Screen.STATUS_ROW, Black, 40);
end;

procedure PauseOnly;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then Delay(Word(GDVars.gameDelay) * 100)
  else Delay(Word(GDVars.gameDelay) * 100 + 220)
end;

{ Fill a character-cell rectangle with a color in any display mode. ClearRect, its only caller, passes signed
  coordinates, but this body takes them as Bytes. The CGA fill indexes attrTable by cgaColorPat's pattern word; with
  ClearRect's color 0 that gives 0.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(color The color.) }
procedure FillRect(ulCol, ulRow, lrCol, lrRow, color: Byte);
var
  y0: Word;
  yEnd: Word;
  x0: Word;
  count: Word;
  i: Word;
  videoOff: Word;
  scratch: Word;
  colorPat: Byte;
begin
  case GDVars.displayMode of
    C_Video.VM_CGA: begin
      y0 := ulRow * 4; yEnd := lrRow * 4 + 3;
      count := (lrCol - ulCol + 1) * 2;
      for i := y0 to yEnd do begin
        FillChar(cgaBank0.words[i][ulCol], count, GDConsts.attrTable[GDConsts.cgaColorPat[color]]);
        FillChar(cgaBank1.words[i][ulCol], count, GDConsts.attrTable[GDConsts.cgaColorPat[color]]);
      end;
    end;
    C_Video.VM_EGA: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, color);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, color);
    end;
    C_Video.VM_VGA: begin
      videoOff := Word(ulRow) * 8 * 320 + Word(ulCol) * 8;
      scratch := (lrCol - ulCol + 1) * 8;
      for i := ulRow * 8 to (lrRow + 1) * 8 - 1 do begin
        FillChar(Types.PBytes(C_Video.VGA_BASE + LongInt(videoOff))^, scratch, color);
        Inc(videoOff, 320);
      end;
    end;
    C_Video.VM_TANDY: begin
      y0 := ulRow * 2; yEnd := lrRow * 2 + 1;
      x0 := ulCol * 4; count := (lrCol - ulCol + 1) * 4;
      colorPat := color + (color shl 4);
      for i := y0 to yEnd do begin
        FillChar(tandyBank0[i][x0], count, colorPat);
        FillChar(tandyBank1[i][x0], count, colorPat);
        FillChar(tandyBank2[i][x0], count, colorPat);
        FillChar(tandyBank3[i][x0], count, colorPat);
      end;
    end;
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin TextRend.FillRect(ulCol, ulRow, lrCol, lrRow, 0) end;

procedure AdvanceTextCursor;
begin
  if GDVars.protNewLine <> 0 then begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
    GDVars.protNewLine := 0;
  end else begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
  end;
end;

procedure DisplayStatusLine(msg: String);
begin
  TextRend.ClearRect(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, msg)
end;

procedure DisplayStatusAndWait(msg: String);
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  TextRend.DisplayStatusLine(msg);
  while KeyPressed do c := ReadKey;
  c := ReadKey
end;

function LongToString(value: LongInt): String;
var s: String;
begin Str(value, s); LongToString := s end;

begin
  GDVars.displayStatusLineProc := TextRend.DisplayStatusLine;
  GDVars.displayStatusAndWaitProc := TextRend.DisplayStatusAndWait;
  GDVars.longToStringFunc := TextRend.LongToString;
  GDVars.renderCharProc := @TextRend.RenderChar;
end.
