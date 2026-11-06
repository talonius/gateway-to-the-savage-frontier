{ Menu key values. Enter, Escape and Backspace are ASCII; the arrow, Home, End, Page Up, Page Down and Delete keys are
  BIOS extended scan codes, returned with the menu routines' extended-key flag set. NONE is a menu's no-selection
  result. }
unit C_Keys;

interface

const
  NONE = #0;
  BACKSPACE = #8;
  ENTER = #13;
  ESCAPE = #27;
  HOME = #71;
  UP = #72;
  PAGE_UP = #73;
  LEFT = #75;
  RIGHT = #77;
  END_KEY = #79;
  DOWN = #80;
  PAGE_DOWN = #81;
  DELETE_KEY = #83;

implementation

end.
