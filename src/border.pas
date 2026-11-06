{ The screen frames and the rectangle clear. Each frame routine draws its edges and rules as 8x8 symbols, one per text
  cell, from the border tables (a symbol index each, added to FRAME_SYMBOL_BASE); ClearBox clears text cells in any
  display mode. Coordinates are text cells, 40 columns by 25 rows. Every frame routine sets GDVars.bigPicId to
  NO_BIG_PICTURE: no big picture is on screen. Its frame-symbol tables (borderTop .. borderCustomRight) are in
  GDConsts. }
{$O+,F+,I-,R-,S+,V-,B-,A+}
unit Border;
interface

{ Fills the text cells ulCol, ulRow to lrCol, lrRow (inclusive) with color 0, in any display mode.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Clears inside the main frame, rows 1 to 22, and draws the frame. }
procedure DrawWindowFrame;

{ The main frame with a rule at row 16, the divider at column 16 above it and the box around the 3D view, rows and
  columns 2 to 14. }
procedure DrawViewFrame;

{ The main frame with a rule at row 16, the text window below it. }
procedure DrawTextFrame;

{ DrawTextFrame's frame and rule, with edge accents at rows 15 and 17 too, clearing only rows 1 to 16. }
procedure DrawMemorizeFrame;

{ Clears rows 0 to 23 and draws the combat frame: columns 0, 22 and 39, rows 0 to 22. }
procedure DrawCombatFrame;

{ The main frame with a rule at row 2. }
procedure DrawTitleInset;

{ A frame whose edges run to row 24, with a rule at row 19. It clears rows 1 to 22 inside the edges before drawing and
  rows 20 to 23, below the rule, after. }
procedure DrawEndingFrame;

{ The main frame with rules at rows 8, 16 and 20 and a divider at column 19 from row 8 to 20: the character sheet's. }
procedure DrawSheetFrame;
implementation
uses C_Video, C_Pic, GDConsts, GDVars, Sym8x8, TextRend, Types;
const
  { the 8x8 symbol of border-table index 0 }
  FRAME_SYMBOL_BASE = 276;
  { The table indices of the plain edge pieces that flank a junction, beside the corners and either side of each rule
    and divider. }
  VERTICAL_ACCENT = 7;
  HORIZONTAL_ACCENT = 13;

procedure DrawWindowFrame;
var
  column: Byte;
  row: Byte;
begin
 Border.ClearBox(1, 1, 38, 22);
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 0, GDConsts.borderTop[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 for row := 0 to 23 do begin
  Sym8x8.Put8x8Sym(0, row, GDConsts.borderLeft[row] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(39, row, GDConsts.borderRight[row] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 23, GDConsts.borderBottom[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 { no big picture on screen now }
 GDVars.bigPicId := C_Pic.NO_BIG_PICTURE
end;

procedure DrawViewFrame;
var
  i: Byte;
  j: Byte;
begin
 Border.DrawWindowFrame;
 for i := 0 to 39 do Sym8x8.Put8x8Sym(i, 16, GDConsts.borderRule[i] + Border.FRAME_SYMBOL_BASE, False, False);
 for j := 0 to 16 do Sym8x8.Put8x8Sym(16, j, GDConsts.borderVertical[j] + Border.FRAME_SYMBOL_BASE, False, False);
 Sym8x8.Put8x8Sym(0, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 15, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 15, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 17, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 17, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(14, 16, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(18, 16, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(15, 16, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(17, 16, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(14, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(18, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(15, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(17, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 for i := 2 to 14 do begin
  Sym8x8.Put8x8Sym(i, 2, GDConsts.borderInnerTop[i] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(i, 14, GDConsts.borderInnerBottom[i] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for j := 2 to 14 do begin
  Sym8x8.Put8x8Sym(2, j, GDConsts.borderInnerLeft[j] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(14, j, GDConsts.borderInnerRight[j] + Border.FRAME_SYMBOL_BASE, False, False)
 end
end;

procedure DrawTextFrame;
var i: Byte;
begin
 Border.DrawWindowFrame;
 for i := 0 to 39 do Sym8x8.Put8x8Sym(i, 16, GDConsts.borderRule[i] + Border.FRAME_SYMBOL_BASE, False, False);
 Sym8x8.Put8x8Sym(0, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False)
end;

procedure DrawSheetFrame;
var
  column: Byte;
  row: Byte;
begin
 Border.DrawWindowFrame;
 for column := 0 to 39 do begin
  Sym8x8.Put8x8Sym(column, 8, GDConsts.borderRule[column] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(column, 16, GDConsts.borderRule[column] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(column, 20, GDConsts.borderRule[column] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for row := 8 to 20 do Sym8x8.Put8x8Sym(19, row, GDConsts.borderMenuVertical[row] + Border.FRAME_SYMBOL_BASE, False,
                                        False)
end;

procedure DrawMemorizeFrame;
var
  i: Byte;
  j: Byte;
begin
 Border.ClearBox(1, 1, 38, 16); GDVars.bigPicId := C_Pic.NO_BIG_PICTURE;
 for i := 0 to 39 do Sym8x8.Put8x8Sym(i, 0, GDConsts.borderTop[i] + Border.FRAME_SYMBOL_BASE, False, False);
 for j := 0 to 23 do begin
  Sym8x8.Put8x8Sym(0, j, GDConsts.borderLeft[j] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(39, j, GDConsts.borderRight[j] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for i := 0 to 39 do Sym8x8.Put8x8Sym(i, 23, GDConsts.borderBottom[i] + Border.FRAME_SYMBOL_BASE, False, False);
 for i := 0 to 39 do Sym8x8.Put8x8Sym(i, 16, GDConsts.borderRule[i] + Border.FRAME_SYMBOL_BASE, False, False);
 Sym8x8.Put8x8Sym(0, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 14, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 18, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 15, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 15, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(0, 17, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 17, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False)
end;

procedure DrawCombatFrame;
var
  column: Byte;
  row: Byte;
begin
 Border.ClearBox(0, 0, 39, 23); GDVars.bigPicId := C_Pic.NO_BIG_PICTURE;
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 0, GDConsts.borderTop[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 22, GDConsts.borderBottom[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 for row := 0 to 22 do begin
  Sym8x8.Put8x8Sym(0, row, GDConsts.borderCombatLeft[row] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(22, row, GDConsts.borderCombatMid[row] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(39, row, GDConsts.borderCombatRight[row] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 Sym8x8.Put8x8Sym(20, 22, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(24, 22, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(20, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(24, 0, Border.FRAME_SYMBOL_BASE + Border.HORIZONTAL_ACCENT, False, False)
end;

procedure DrawTitleInset;
var column: Byte;
begin
 Border.DrawWindowFrame;
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 2, GDConsts.borderRule[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 Sym8x8.Put8x8Sym(0, 4, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False);
 Sym8x8.Put8x8Sym(39, 4, Border.FRAME_SYMBOL_BASE + Border.VERTICAL_ACCENT, False, False)
end;

procedure DrawEndingFrame;
var
  column: Byte;
  row: Byte;
begin
 Border.ClearBox(1, 1, 38, 22);
 for column := 0 to 39 do begin
  Sym8x8.Put8x8Sym(column, 0, GDConsts.borderTop[column] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(column, 24, GDConsts.borderBottom[column] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for row := 0 to 24 do begin
  Sym8x8.Put8x8Sym(0, row, GDConsts.borderCustomLeft[row] + Border.FRAME_SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(39, row, GDConsts.borderCustomRight[row] + Border.FRAME_SYMBOL_BASE, False, False)
 end;
 for column := 0 to 39 do Sym8x8.Put8x8Sym(column, 19, GDConsts.borderRule[column] + Border.FRAME_SYMBOL_BASE, False,
                                           False);
 Border.ClearBox(1, 20, 38, 23); GDVars.bigPicId := C_Pic.NO_BIG_PICTURE
end;

{ Fills text cells ulCol, ulRow to lrCol, lrRow with color in the display mode's layout; EGA mode fills both of
  TextRend's pages. The CGA fill byte is GDConsts.attrTable indexed by color's GDConsts.cgaColorPat word, as in
  TextRend's rectangle clear; color 0, the one Border passes, gives 0.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(color Fill color.) }
procedure FillBox(ulCol, ulRow, lrCol, lrRow, color: Byte);
var
  firstRow: Word;
  lastRow: Word;
  firstByteColumn: Word;
  rowBytes: Word;
  row: Word;
  screenOff: Word;
  vgaRowLen: Word; fill: Byte;
begin
 case GDVars.displayMode of
  C_Video.VM_CGA: begin
   firstRow := ulRow * 4; lastRow := lrRow * 4 + 3; rowBytes := (lrCol - ulCol + 1) * 2;
   for row := firstRow to lastRow do begin
    FillChar(TextRend.cgaBank0.bytes[row][Word(ulCol) * 2], rowBytes, GDConsts.attrTable[GDConsts.cgaColorPat[color]]);
    FillChar(TextRend.cgaBank1.bytes[row][Word(ulCol) * 2], rowBytes, GDConsts.attrTable[GDConsts.cgaColorPat[color]])
   end
  end;
  C_Video.VM_EGA: begin
   TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, color);
   TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, color)
  end;
  C_Video.VM_VGA: begin
   screenOff := ulRow * 8 * 320 + ulCol * 8;
   vgaRowLen := (lrCol - ulCol + 1) * 8;
   for row := ulRow * 8 to (lrRow + 1) * 8 - 1 do begin
    FillChar(Types.PBytes(LongInt(C_Video.VGA_BASE) + screenOff)^, vgaRowLen, color); Inc(screenOff, 320)
   end
  end;
  C_Video.VM_TANDY: begin
   firstRow := ulRow * 2; lastRow := lrRow * 2 + 1; firstByteColumn := ulCol * 4;
   rowBytes := (lrCol - ulCol + 1) * 4; fill := color + (color shl 4);
   for row := firstRow to lastRow do begin
    FillChar(TextRend.tandyBank0[row][firstByteColumn], rowBytes, fill);
    FillChar(TextRend.tandyBank1[row][firstByteColumn], rowBytes, fill);
    FillChar(TextRend.tandyBank2[row][firstByteColumn], rowBytes, fill);
    FillChar(TextRend.tandyBank3[row][firstByteColumn], rowBytes, fill)
   end
  end
 end
end;

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin Border.FillBox(ulCol, ulRow, lrCol, lrRow, 0) end;
begin end.
