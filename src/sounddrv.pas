{ Sound effects, played by the resident sound driver on INT 66h. SoundCommand copies one of the effects GameInit loads
  into GDVars.soundSamples to GDVars.soundBuffer and hands the driver GDVars.driverCommand with that effect's rate from
  soundSampleRates. SOUNDDRV.OBJ holds the driver calls: DriverPresent looks for the driver's "KERN" signature,
  DriverBusy asks whether it is still playing and DriverDispatch passes it a command. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit SoundDrv;

interface

{ Plays a sound effect, unless sound is off or no driver is present, after the driver finishes the one before.
  @param(id The effect, 2..12, which plays 3 and 6 as 9. Other ids play nothing: they include the 0 and 1 GameIo sends
    as it turns sound off and on, and the 255 the engine sends around its overlay calls.) }
procedure SoundCommand(id: Word);

{ Does nothing, though FixMain and EclVm call it, mostly while GDVars.soundOnFlag is clear. }
procedure SoundSuspend;

implementation

uses C_Sound, GDConsts, GDVars;

{$L SOUNDDRV.OBJ}

{ Hand the driver a command block.
  @param(commandOffset The block's offset in the data segment.) }
procedure DriverDispatch(commandOffset: Word); external;

{ Return whether the driver is still playing.
  @returns(True while it plays.) }
function DriverBusy: Boolean; external;

{ Return whether the sound driver is installed, by its "KERN" signature.
  @returns(True when it is.) }
function DriverPresent: Boolean; external;

procedure SoundCommand(id: Word);
var work: Pointer;
begin
  if GDVars.soundMode = C_Sound.OFF then Exit;
  if (id = 3) or (id = 6) then id := 9;
  if id <= 1 then Exit;
  if id >= 13 then Exit;
  if not SoundDrv.DriverPresent then Exit;
  while SoundDrv.DriverBusy do;
  FillChar(GDVars.driverCommand, SizeOf(GDVars.driverCommand), 0);
  FillChar(GDVars.soundBuffer^, 9000, 0);
  GDVars.driverCommand.sampleRate := GDConsts.soundSampleRates[id];
  GDVars.driverCommand.size := LongInt(GDVars.soundSamples[id].size);
  Move(GDVars.soundSamples[id].data^, GDVars.soundBuffer^, GDVars.soundSamples[id].size);
  work := GDVars.soundBuffer;
  Move(work, GDVars.driverCommand.data, SizeOf(work));
  SoundDrv.DriverDispatch(Ofs(GDVars.driverCommand))
end;

procedure SoundSuspend;
begin
end;

begin
end.
