{ The display: the adapters GDVars.displayMode names, the video BIOS's set-mode function, and display memory. }
unit C_Video;

interface

const
  { GDVars.displayMode's values }
  VM_CGA = 0;
  VM_EGA = 1;
  VM_TANDY = 2;
  VM_VGA = 3;
  { the video BIOS function, in AH, that sets the mode in AL }
  BIOS_SET_VIDEO_MODE = 0;
  { the segment of EGA and VGA display memory }
  DISPLAY_SEG = $A000;
  { VGA display memory as a far pointer }
  VGA_BASE = $A0000000;
  { the CGA and Tandy screen banks: CGA's even and odd rows in banks 0 and 1, Tandy's four row banks }
  GFX_BANK0_SEG = $B800;
  GFX_BANK1_SEG = $BA00;
  GFX_BANK2_SEG = $BC00;
  GFX_BANK3_SEG = $BE00;

implementation

end.
