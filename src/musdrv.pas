{ The interface to the music driver. Music loads the driver from MUSIC.DAX into a paragraph-aligned buffer, hands it to
  StartDriver with the song, and then starts, polls and stops it through this unit. Every call goes through DriverCall
  with a driver function code. The unit saves the PC speaker's gate when it starts the driver and restores it when it
  stops it. Its state is sndSavedGate, sndState, sndEntry, sndSong, sndResult and sndArgs. }
{$O+,F+}
{$S+}
{$A+}
unit MusDrv;

interface

uses GDConsts, GDVars, Types;

{ Start the driver and give it the song: mark the driver started, save the speaker gate and call driver function 0 with
  the song's offset and segment. The driver is entered like a .COM program, at DRIVER_ENTRY_OFFSET in a segment sixteen
  paragraphs below its image.
  @param(codeAddress The driver image's paragraph-aligned address, as a LongInt; a misaligned address halts the
    program.)
  @param(songPtr The song data.) }
procedure StartDriver(codeAddress: LongInt; songPtr: Pointer);

{ Start the song: driver function 1. }
procedure StartPlayback;

{ Poll the driver: driver function 2.
  @returns(The driver's status; Music stops the song when it is 0.) }
function PollDriver: Byte;

{ Stops the driver if it is started: marks it stopped, restores the speaker gate and calls driver function 3. }
procedure StopHook;

implementation

const
  { system control port B; its low bits gate the PC speaker }
  SPEAKER_PORT = $61;
  { sndState: no driver started }
  SOUND_MODE_NONE = 0;
  { sndState: the loaded driver started }
  SOUND_MODE_LOADED = 2;
  DRIVER_FUNCTION_INITIALIZE = 0;
  DRIVER_FUNCTION_START = 1;
  DRIVER_FUNCTION_POLL = 2;
  DRIVER_FUNCTION_STOP = 3;
  { the .COM-style entry offset }
  DRIVER_ENTRY_OFFSET = $100;

type
  TDriverEntry = function(segment, offset, func: Word): Integer;

{ Calls the driver's dispatch entry with a function code and a far argument; returns its status. Codes used: 0 install
  (StartDriver), 1 start (StartPlayback), 2 poll (PollDriver), 3 stop (StopHook).
  @param(func Driver function code.)
  @param(offset Offset of the far argument.)
  @param(segment Segment of the far argument.)
  @returns(The driver's status.) }
function DriverCall(func, offset, segment: Word): Integer;
begin
  DriverCall := TDriverEntry(GDVars.sndEntry)(segment, offset, func);
end;

procedure StartDriver(codeAddress: LongInt; songPtr: Pointer);
begin
  GDVars.sndState := MusDrv.SOUND_MODE_LOADED;
  GDVars.sndSavedGate := Port[MusDrv.SPEAKER_PORT];
  if Lo(codeAddress and $0F) <> 0 then
    Halt(0);
  { fold the offset's paragraphs into the segment }
  Inc(codeAddress, (codeAddress and $FFF0) shl 12);
  codeAddress := codeAddress and $FFFF0000;
  Inc(codeAddress, MusDrv.DRIVER_ENTRY_OFFSET);
  Dec(codeAddress, MusDrv.DRIVER_ENTRY_OFFSET shl 12);
  GDVars.sndEntry := Pointer(codeAddress);
  Move(songPtr, GDVars.sndSong, SizeOf(Pointer));
  GDVars.sndArgs[0] := Types.TPointerWords(GDVars.sndSong).ofs;
  GDVars.sndArgs[1] := Types.TPointerWords(GDVars.sndSong).seg;
  GDVars.sndResult := MusDrv.DriverCall(MusDrv.DRIVER_FUNCTION_INITIALIZE, GDVars.sndArgs[0], GDVars.sndArgs[1]);
end;

procedure StartPlayback;
begin
  GDVars.sndResult := MusDrv.DriverCall(MusDrv.DRIVER_FUNCTION_START, 0, 0);
end;

function PollDriver: Byte;
begin
  GDVars.sndResult := MusDrv.DriverCall(MusDrv.DRIVER_FUNCTION_POLL, 0, 0);
  PollDriver := GDVars.sndResult;
end;

procedure StopHook;
begin
  if GDVars.sndState = MusDrv.SOUND_MODE_LOADED then begin
    GDVars.sndState := MusDrv.SOUND_MODE_NONE;
    Port[MusDrv.SPEAKER_PORT] := GDVars.sndSavedGate;
    GDVars.sndResult := MusDrv.DriverCall(MusDrv.DRIVER_FUNCTION_STOP, 0, 0);
  end;
end;

begin
end.
