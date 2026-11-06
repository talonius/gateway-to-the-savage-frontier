{ Sets the start-up password, GDVars.commandText, to the item-name component 'Wooden'. When the second command-line
  parameter matches it, FixMain skips the copy protection and Explore's A key toggles the automap where the area forbids
  it. The unit has no routines: its initialization, which runs between Crt's and GameBoot's, is the whole of it. }
{$F+,S+}
unit ModeInit;

interface

implementation

uses GDConsts, GDVars;

const
  { GDConsts.itemNameComponents' 'Wooden' }
  WOODEN_COMPONENT = 252;

begin
  GDVars.commandText := GDConsts.itemNameComponents[ModeInit.WOODEN_COMPONENT];
end.
