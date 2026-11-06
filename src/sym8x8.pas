{ The 8x8 graphics symbols: Load8x8Set loads a symbol set from 8X8D.DAX into GDVars.symbolSetPtrs, and Put8x8Sym draws
  one symbol, either into the view buffer, GDVars.viewBuf, or through the current-symbol buffer,
  GDVars.current8x8SymbolPtr, straight to the screen. Border and View3D draw through it; GameInit and View3D load the
  sets. The unit owns no storage.

  Symbols map to sets through eleven bands, and the file is named with the bare '8x8d', without a disk digit. }
{$O+,F+}
{$S+}
{$A+}
unit Sym8x8;

interface

{ Load record fileId of 8X8D.DAX into symbol set setId, transparent in light magenta. A setId above 4 does nothing; a
  failed load reports the record, waits for a key and quits the game.
  @param(fileId The record.)
  @param(setId The symbol set, 0..4.) }
procedure Load8x8Set(fileId, setId: Byte);

{ Draw one symbol at 8x8 cell col, row. The bands repeat sets 0 to 3 at higher numbers, and each arm subtracts its
  band's first number. 0, 296, 552, 808 and every number above 1063 are in no band.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(symbol A symbol number in one of the eleven bands; Put8x8Sym finds its set and its index in the set. A number
    in no band reports the error, waits for a key and quits the game.)
  @param(inCombat True to composite the symbol into the view buffer, False to show it on the screen through the
    current-symbol buffer.)
  @param(masked Passed to Raster.BlitTileCell as its flag when compositing: True blits through the tile's transparency
    mask.) }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, masked: Boolean);

implementation

uses Types, C_Pic, Raster, Blit, GameIo, GDConsts, GDVars;

procedure Load8x8Set(fileId, setId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  diskDigit: String[1];
  { written by Str and never read }
  fileIdText: String[3];
  { Unused in this version; see the other implementations of this routine. }
  setSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if setId in [0..SizeOf(GDVars.symbolSetPtrs) div SizeOf(GDVars.symbolSetPtrs[0]) - 1] then begin
    Str(fileId, fileIdText);
    Blit.LoadPic('8x8d', fileId, True, C_Pic.KEY_COLOR, GDVars.symbolSetPtrs[setId]);
    if GDVars.symbolSetPtrs[setId] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load ', fileId, ' from 8x8D');
      ch := GameIo.ReadGameKey;
      Blit.RestoreVideoMode;
      GameIo.ExitGame;
    end;
    GameIo.DrainKeys;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, masked: Boolean);
var
  setIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  case symbol of
    1..45: begin setIdx := 0; Dec(symbol); end;
    46..115: begin setIdx := 1; Dec(symbol, 46); end;
    116..185: begin setIdx := 2; Dec(symbol, 116); end;
    186..255: begin setIdx := 3; Dec(symbol, 186); end;
    256..295: begin setIdx := 4; Dec(symbol, 256); end;
    297..341: begin setIdx := 0; Dec(symbol, 297); end;
    342..551: begin setIdx := 1; Dec(symbol, 342); end;
    553..597: begin setIdx := 0; Dec(symbol, 553); end;
    598..807: begin setIdx := 2; Dec(symbol, 598); end;
    809..853: begin setIdx := 0; Dec(symbol, 809); end;
    854..1063: begin setIdx := 3; Dec(symbol, 854); end;
  else begin
      Blit.RestoreVideoMode;
      WriteLn('Bad symbol number in Put8x8Symbol.');
      ch := GameIo.ReadGameKey;
      GameIo.ExitGame;
    end;
  end;
  if GDVars.symbolSetPtrs[setIdx] <> nil then begin
    if inCombat then
      Raster.BlitTileCell(col, row, Byte(symbol), Byte(masked), GDVars.symbolSetPtrs[setIdx], GDVars.viewBuf)
    else begin
      with GDVars.symbolSetPtrs[setIdx]^ do
        Move(data[symbol * frameSize], GDVars.current8x8SymbolPtr^.data, frameSize);
      Blit.ShowPic(col, row, GDVars.current8x8SymbolPtr);
    end;
  end;
end;

begin
end.
