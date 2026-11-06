{ The game's two error handlers, which the unit's initialization installs: HeapErrorHandler as System's HeapError, and
  ReportError at the head of the ExitProc chain, whose previous head it keeps in savedExitProc. Both act only once
  GDConsts.isFontLoaded shows the game's interface is up. }
{$O+,F+,I-,S+,A+}
unit HeapErr;

interface

{ Makes the player save before an out-of-memory exit. Once the interface is up it repeats 'Time to save your game' and
  the save menu until a save succeeds, then quits the game.
  @param(size The size of the failed allocation; for 0 it returns at once, leaving the result unset.)
  @returns(1, so the failed allocation returns nil, while the interface is not up.) }
function HeapErrorHandler(size: Word): Integer;

{ Restores the previous ExitProc. After a runtime error with the interface up, shows the error on the status line in
  place of the runtime's message, waits for a key and quits the game. }
procedure ReportError;

implementation

uses GDConsts, GDVars, GameIo, TextRend, SaveLoad, Crt;

function HeapErrorHandler(size: Word): Integer;
begin
  if size = 0 then Exit;
  if not GDConsts.isFontLoaded then HeapErrorHandler := 1
  else begin
    repeat
      TextRend.DisplayAndPause(Yellow, Black, 'Time to save your game');
      SaveLoad.SaveGame
    until GDVars.recentlySavedGameFlag <> 0;
    GameIo.ExitGame
  end
end;

procedure ReportError;
begin
  ExitProc := GDVars.savedExitProc;
  if GDConsts.isFontLoaded and (ErrorAddr <> nil) then begin
    { the runtime error for a failed GAME.OVR read }
    if ExitCode = 209 then begin
      GDVars.displayStatusAndWaitProc('Error reading Disk 2. Check install.')
    end else
      GDVars.displayStatusAndWaitProc('Internal error #' + GDVars.longToStringFunc(ExitCode));
    ErrorAddr := nil;
    GameIo.ExitGame
  end
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
  GDVars.savedExitProc := ExitProc;
  ExitProc := @HeapErr.ReportError
end.
