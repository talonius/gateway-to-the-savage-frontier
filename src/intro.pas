{ The title sequence: five TITLE pictures, each held for a few seconds or until a key, with the title music when
  GAME.CFG turns it on. A key during the first hold skips the rest. }
{$O+,F+}
{$A+}
{$S+}
unit Intro;

interface

{ Plays the title sequence unless GDVars.fullIntroFlag is clear. The last picture stays up for 20 seconds or, with the
  music on, until the song ends, a key cutting either short; a sequence played to the end then stops the music through
  GDVars.stopMusicProc. }
procedure Introduction;

implementation

uses Types, GDConsts, GDVars, GameIo, Music, TextRend, Blit, Raster;

const
  TITLE_SONG = 1;

{ Clears pending mouse and key input and starts the next hold's clock. }
procedure ResetDelay;
begin
  GameIo.WaitMouseRelease;
  GameIo.DrainKeys;
  GDVars.introStartTicks := TextRend.GetTicks;
end;

{ Waits until `seconds` after the last ResetDelay or a key, records in introInterrupted which one ended the wait, and
  resets the clock.
  @param(seconds The wait, in seconds.) }
procedure DelayOrKey(seconds: Word);
var deadline: LongInt;
begin
  deadline := GDVars.introStartTicks + 100 * seconds;
  repeat until GameIo.InputPending or (TextRend.GetTicks >= deadline);
  if GameIo.InputPending then GDVars.introInterrupted := True else GDVars.introInterrupted := False;
  Intro.ResetDelay;
end;

procedure Introduction;
var pic: Types.PImgBuf;
begin
  TextRend.ClearScreen;
  if GDVars.fullIntroFlag = 0 then Exit;
  pic := nil;
  Blit.LoadPic('title', 1, False, 0, pic);
  TextRend.ClearScreen;
  Blit.ShowPic(0, 0, pic);
  Intro.ResetDelay;
  Blit.LoadPic('title', 2, False, 0, pic);
  Intro.DelayOrKey(3);
  if GDVars.introInterrupted then begin
    TextRend.ClearScreen;
    Raster.FreePic(pic);
    Exit;
  end;
  TextRend.ClearScreen;
  Blit.ShowPic(0, 0, pic);
  Raster.FreePic(pic);
  if GDVars.isMusicEnabled then
    Music.StartMusic(Intro.TITLE_SONG);
  Blit.LoadPic('title', 3, False, 0, pic);
  Intro.DelayOrKey(3);
  TextRend.ClearScreen;
  Blit.ShowPic(0, 0, pic);
  Blit.LoadPic('title', 4, False, 0, pic);
  Intro.DelayOrKey(10);
  TextRend.ClearScreen;
  Blit.ShowPic(0, 0, pic);
  Blit.LoadPic('title', 5, False, 0, pic);
  Intro.DelayOrKey(20);
  TextRend.ClearScreen;
  Blit.ShowPic(0, 0, pic);
  Raster.FreePic(pic);
  if not GDVars.isMusicEnabled then
    Intro.DelayOrKey(20)
  else begin
    repeat until GameIo.InputPending or (not Music.MusicPlaying);
    Intro.ResetDelay;
  end;
  TextRend.ClearScreen;
  GDVars.stopMusicProc;
end;

begin
end.
