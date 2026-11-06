{ Sound effects: GDVars.soundMode while sound is off. }
unit C_Sound;

interface

const
  { GDVars.soundMode while sound is off, which SoundDrv and Music then leave silent: Config sets it when the INT 66h
    vector is nil, and GameIo's Ctrl-S toggles it }
  OFF = 3;

implementation

end.
