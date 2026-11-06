{ Music, for Intro's title sequence and EclVm's scripts: loads the music driver and a song from MUSIC.DAX and plays them
  through MusDrv. Its state is musicDriverImage, musicSongData, musicSongSize and GDVars.musicState. The unit's
  initialization puts StopMusic in GDVars.stopMusicProc, which Intro calls. }
{$O+,F+,I-,R-,S+,V-,B-,A+}
unit Music;

interface

{ Loads the driver and song songId and starts playback, unless sound is off. A missing MUSIC.DAX or song is reported on
  the status line.
  @param(songId The song's record in MUSIC.DAX.) }
procedure StartMusic(songId: Word);

{ Reports whether playback was active on entry. When the driver reports the song over, it stops playback but still
  answers True for this call.
  @returns(True while the song was playing on entry.) }
function MusicPlaying: Boolean;

{ Stops the driver and frees the driver image and song, if the music is playing. }
procedure StopMusic;

implementation

uses
  C_Sound, SoundDrv, DaxIo, MusDrv, GDConsts, GDVars, Types;

const
  { the MUSIC.DAX record that holds the driver }
  DRIVER_RECORD = 0;
  { GDVars.musicState values }
  STATE_STOPPED = 0;
  STATE_PLAYING = 2;

procedure StartMusic(songId: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  paragraph: Word;
  { the driver image's first paragraph boundary, which the driver runs at }
  aligned: Pointer;
  driverData: Types.PBytes;
  driverSize: Word;
begin
  SoundDrv.SoundCommand(255);
  if GDVars.soundMode = C_Sound.OFF then Exit;
  GetMem(GDVars.musicDriverImage, 19000);
  driverData := nil;
  DaxIo.LoadDax('MUSIC', '.dax', Music.DRIVER_RECORD, driverSize, driverData);
  if driverSize = 0 then begin
    FreeMem(GDVars.musicDriverImage, 19000);
    GDVars.displayStatusLineProc('No music.dax');
    Exit
  end;
  aligned := GDVars.musicDriverImage;
  FillChar(GDVars.musicDriverImage^, 19000, 0);
  while Lo(LongInt(aligned) and $F) <> 0 do Inc(LongInt(aligned));
  Move(driverData^, aligned^, driverSize);
  FreeMem(driverData, driverSize);
  GDVars.musicSongData := nil;
  DaxIo.LoadDax('MUSIC', '.dax', songId, GDVars.musicSongSize, GDVars.musicSongData);
  if GDVars.musicSongSize = 0 then begin
    FreeMem(GDVars.musicDriverImage, 19000);
    GDVars.displayStatusLineProc('Song not found');
    Exit
  end;
  SoundDrv.SoundCommand(255);
  MusDrv.StartDriver(LongInt(aligned), GDVars.musicSongData);
  MusDrv.StartPlayback;
  GDVars.musicState := Music.STATE_PLAYING
end;

procedure StopMusic;
begin
  if GDVars.musicState <> Music.STATE_PLAYING then Exit;
  MusDrv.StopHook;
  FreeMem(GDVars.musicSongData, GDVars.musicSongSize);
  FreeMem(GDVars.musicDriverImage, 19000);
  GDVars.musicState := Music.STATE_STOPPED
end;

function MusicPlaying: Boolean;
begin
  MusicPlaying := False;
  if GDVars.musicState <> Music.STATE_PLAYING then Exit;
  MusicPlaying := True;
  if MusDrv.PollDriver <> 0 then Exit;
  Music.StopMusic
end;

begin
  { @StopMusic is this overlay's resident trap stub, so the cell's callers may call it while the overlay is not
    loaded. }
  GDVars.stopMusicProc := Music.StopMusic
end.
