@echo off
rem ===================================================================
rem  Gateway to the Savage Frontier v1.2 -- THE WHOLE-IMAGE BUILD. Run from
rem  e:\src by gametools/build.sh, which mounts:
rem     C: games   D: the compiler   E: this tree   F: TASM   G: EXEPACK
rem  TPC takes its default switches from e:\src\TPC.CFG, which is tracked;
rem  units override them with {$...} directives.
rem
rem  Every output goes to e:\obj: each .OBJ and .TPU, FIXMAIN.EXE and
rem  FIXMAIN.MAP, and the two files SSI shipped under their shipped names,
rem  GAME.OVR and the EXEPACK'd GAME.EXE. FIXMAIN.EXE stays beside them
rem  as the packer's input.
rem
rem  This build's outputs are deleted first: DOS REN refuses an existing
rem  target, and a stale output would score as this build's. build.sh
rem  has already wiped every .TPU and .OBJ out of e:\src and e:\obj.
rem ===================================================================
if exist e:\obj\FIXMAIN.EXE del e:\obj\FIXMAIN.EXE
if exist e:\obj\FIXMAIN.OVR del e:\obj\FIXMAIN.OVR
if exist e:\obj\FIXMAIN.MAP del e:\obj\FIXMAIN.MAP
if exist e:\obj\GAME.EXE del e:\obj\GAME.EXE
if exist e:\obj\GAME.OVR del e:\obj\GAME.OVR
f:\tasm joystick,..\obj\joystick >> e:\build\logs\TASM.OUT
f:\tasm kbdcore,..\obj\kbdcore >> e:\build\logs\TASM.OUT
f:\tasm mcremap,..\obj\mcremap >> e:\build\logs\TASM.OUT
f:\tasm raster,..\obj\raster >> e:\build\logs\TASM.OUT
f:\tasm sounddrv,..\obj\sounddrv >> e:\build\logs\TASM.OUT
f:\tasm textrend,..\obj\textrend >> e:\build\logs\TASM.OUT
path d:\
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT
rem  TPC names the overlay after the root; SSI shipped it as GAME.OVR.
ren e:\obj\FIXMAIN.OVR GAME.OVR
g:\exepack e:\obj\FIXMAIN.EXE e:\obj\GAME.EXE > e:\build\logs\PACK.OUT
