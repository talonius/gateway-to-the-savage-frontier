{ Interface states: the values of GDVars.interfaceState, which tell the shared menus and displays which screen the party
  is on. }
unit C_Ifc;

interface

const
  { CharGen's main menu }
  MAIN_MENU = 0;
  { a shop or a temple }
  SHOP_TEMPLE = 1;
  CAMPING = 2;
  { exploring: the 3D view or the overland map }
  EXPLORING = 3;
  IN_COMBAT = 4;
  { the treasure menus after a combat }
  LOOT = 5;
  IN_VAULT = 7;

implementation

end.
