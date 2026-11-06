{ The victory ending. EclVm's PROGRAM opcode calls WinGame for program 8. }
{$O+,F+}
{$A+}
{$S+}
unit Ending;

interface

{ Frees the current animation and portraits, then shows the six BIGPIC ending pictures, each with a four-line caption
  and a wait for a key, and clears the screen. }
procedure WinGame;

implementation

uses Types, C_Pic, GDConsts, GDVars, Border, Blit, Raster, Portrait, DaxIo, GameIo, TextRend, Crt;

{ Discards any keys already typed, then waits for one. }
procedure WaitForKey;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  while GameIo.InputPending do
    ch := GameIo.ReadGameKey;
  ch := GameIo.ReadGameKey;
end;

procedure WinGame;
var pic: Types.PImgBuf;
begin
  Portrait.FreeAnimation(GDVars.animationData);
  Portrait.FreePortraitBufs;
  GameIo.KbdNoop;
  DaxIo.PushState(1);
  GameIo.DrainKeys;
  Border.DrawEndingFrame;
  Blit.DisplaySpecialPic('bigpic', 126, 1, 8);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'The Ring of Reversal is placed atop');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'the tiny pyramid, and a mighty crack');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'of thunder echoes across the parched');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'streets of dead Ascore.  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(1, 20, 38, 23);
  Blit.DisplaySpecialPic('bigpic', 127, 1, 8);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'Blinding beams of light lance through');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'the ancient stones in all directions.');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'At the plaza''s edge your enemies stop');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'and stare in amazement.  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(1, 20, 38, 23);
  pic := nil;
  Blit.LoadPic('bigpic', 128, True, C_Pic.KEY_COLOR, Types.PImgBuf(pic));
  Blit.ShowPicMasked(1, 1, Types.PImgBuf(pic), C_Pic.KEY_COLOR);
  Raster.FreePic(pic);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'The light bathes the cliffs and desert');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'sands, calling to legions of ferocious');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'monsters!  The massed forces that sur-');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'round you stand in their way.  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(1, 20, 38, 23);
  Blit.LoadPic('bigpic', 129, True, C_Pic.KEY_COLOR, Types.PImgBuf(pic));
  Blit.ShowPicMasked(1, 9, Types.PImgBuf(pic), C_Pic.KEY_COLOR);
  Raster.FreePic(pic);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'In a storm of fangs and claws and');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'fire, the leaderless Zhentarim armies');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'are slaughtered in the monsters'' quest');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'for the single glowing light!  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(1, 20, 38, 23);
  Blit.LoadPic('bigpic', 130, True, C_Pic.KEY_COLOR, Types.PImgBuf(pic));
  Blit.ShowPicMasked(26, 1, Types.PImgBuf(pic), C_Pic.KEY_COLOR);
  Raster.FreePic(pic);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'To tell of your escape would fill an');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'entire evening, as good fortune guides');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'you through the carnage to safe haven');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'in the cliffs above Ascore!  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(1, 20, 38, 23);
  Blit.LoadPic('bigpic', 131, True, C_Pic.KEY_COLOR, Types.PImgBuf(pic));
  Blit.ShowPicMasked(20, 9, Types.PImgBuf(pic), C_Pic.KEY_COLOR);
  Raster.FreePic(pic);
  TextRend.DisplayString(1, 20, LightGreen, Black, 'As you return to Yartar, word of your');
  TextRend.DisplayString(1, 21, LightGreen, Black, 'exploits preceds you. In every town');
  TextRend.DisplayString(1, 22, LightGreen, Black, 'along the way people cheer and wave');
  TextRend.DisplayString(1, 23, LightGreen, Black, 'when the party marches by!  (More)');
  Ending.WaitForKey;
  TextRend.ClearRect(0, 0, 39, 24);
end;
begin end.
