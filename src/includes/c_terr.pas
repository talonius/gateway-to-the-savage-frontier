{ Arena terrain values with the TERRAIN_ prefix. }
unit C_Terr;

interface

const
  { the cells under a Cloudkill and under a Stinking Cloud; the cloud keeps the terrain beneath }
  TERRAIN_CLOUDKILL = 28;
  TERRAIN_STINK_CLOUD = 30;
  { the marker a downed creature leaves on its cell }
  TERRAIN_CORPSE = 31;
  { a terrain movement cost no move can pay }
  TERRAIN_IMPASSABLE = 255;

implementation

end.
