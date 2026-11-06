{ Character creation and the party menu: race, gender, class, alignment and age, the best-of-six stat roll, first-level
  HP and starting money, name entry, portrait and icon customization, training, and add / drop / remove. }

{$O+,F+}
{$A+}
{$S+}
{$V-}
unit CharGen;

interface

uses Types, C_Effect, C_Class, C_Ifc, C_Npc, C_Race, C_Spell, C_Stat, C_Video, Crt, GDConsts, GDVars, C_Keys, Blit,
  Border, CharHlp, ClassCal, CbtMap, FxEngine, GameInit, InputCfg, GameIo, MapTiles, MenuCore, Raster, SaveLoad,
  TextRend, ViewChar, Mouse, C_Gbvm;

type
  { an alignment as AddCharacterMenu's evil tests read it }
  TAlignNN = 0..127;
  { a race or a class as a case selector, for the cases that pick ranges of them }
  TOrdIdx = (oi0, oi1, oi2, oi3, oi4, oi5, oi6, oi7, oi8,
             oi9, oi10, oi11, oi12, oi13, oi14, oi15, oi16);

{ The party menu: draw the party roster and the commands the party's state allows (GDConsts.menuItems), and run them
  until Begin or a quit: Create, Modify, Drop, Icon, Train, Human (a new class), View, Add, Remove, Load, Save, Begin,
  input configuration and Exit. With more than 11 commands it hides input configuration, then Icon, then Save. Exit asks
  again when the party is unsaved, and a No there saves instead of quitting. A Remove that empties the party resets the
  game state and runs the post-load procedure. }
procedure MainMenu;

{ Unlinks the current character from the party roster and frees it. Its predecessor, or else the roster head, becomes
  the current character. A character that is not in the roster is left untouched.
  @param(suppressSizeDec True leaves the party size alone.)
  @param(freeAnim True also frees the character's icon animation.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ The icon editor for the current character: show its old and new icons, and change the head and body pictures (Parts),
  the colors of the icon's parts (not in CGA) and its size, each change kept with Keep or undone with Exit, until the
  icon is accepted ('Is this icon ok?'). An NPC cannot be changed. }
procedure CustomizePortrait;

{ Train the current character. Unless sting mode is on, it must be conscious and, outside auto training and a victory
  start, someone must pay 1000 gp. Each class below its racial and class level limits whose next level's experience is
  met can train; outside auto training only the class needing the most experience trains, after a confirmation, and exp
  is held below the level after it. The trained classes go up a level, drained levels are restored, a new mage level (or
  a ranger past level 8) learns a spell from the menu, and hit points are rolled with the constitution bonus when
  cgLevelHighest is above cgLevelAtChange. GDVars.isAutoTraining trains silently for character creation and picks the
  starting mage spells; GDVars.stingMode trains for free, at any trainer and with any experience. Note: picking the
  class needing the most experience reads every class at the level of the last class scanned. }
procedure TrainingMenu;

{ Return a character's constitution hit-point bonus, summed over its classes below their bonus level cap
  (GDConsts.maxClassLevels): the table bonus, plus 1..5 at constitution 17..25 for a single-class fighter, paladin or
  ranger, with the running sum doubled for a first-level ranger.
  @param(cr The character.)
  @returns(The bonus, which may be negative.) }
function ConHpBonus(cr: Types.PWork): ShortInt;

implementation

const
  { Types.TWork.charClass's value for a fighter }
  CLASS_FIGHTER = 2;

procedure CreateCharacterMenu; forward;

procedure AddCharacterMenu; forward;

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

function HpMaximum(cr: Types.PWork): Byte; forward;

function HpMinimum(cr: Types.PWork): Byte; forward;

function RollFirstLevelHp(cr: Types.PWork; mask: Byte): Byte; forward;

{ Frees a creature record with its combat record, items and effects.
  @param(cr The creature; nil on return.) }
procedure FreeCreature(var cr: Types.PWork);
var
  hold: Types.PItemRec;
  it: Types.PItemRec;
  holdE: Types.PEffectRec;
  eff: Types.PEffectRec;
begin
  with cr^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    it := itemsAddr;
    while it <> nil do begin
      hold := it;
      it := it^.next;
      FreeMem(hold, SizeOf(Types.TItemRec));
    end;
    eff := effectsAddr;
    while eff <> nil do begin
      holdE := eff;
      eff := eff^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  FreeMem(cr, SizeOf(Types.TWork));
  cr := nil;
end;

{ Run the 'Select Exit' menu under query until a character is chosen (a click on the roster, or Select for the current
  one) or the menu is left; the arrow keys step through the party. The chosen character is current.
  @param(query The menu's prompt.)
  @returns(True when a character was chosen.) }
function SelectCharacter(query: String): Boolean;
var
  savedMouse: Byte;
  ch: Char;
  ext: Boolean;
begin
  savedMouse := GDVars.canClickParty;
  GDVars.canClickParty := 1;
  repeat
    GDVars.canClickParty := 1;
    GDVars.orderState := 1;
    GDVars.orderChar := nil;
    ch := MenuCore.MenuHorizontal(query, 'Select Exit', LightMagenta, LightGreen, White, True, False, ext);
    GDVars.canClickParty := 0;
    if GDVars.orderChar <> nil then begin
      CharHlp.PrintMiscInfo(GDVars.curChar, False);
      GDVars.curChar := GDVars.orderChar;
      CharHlp.PrintMiscInfo(GDVars.curChar, True);
      ch := 'S';
    end else if ext then begin
      CharHlp.PrintMiscInfo(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.PrintMiscInfo(GDVars.curChar, True);
    end;
  until (not ext) and (ch in [C_Keys.NONE, 'E', 'S']);
  CharHlp.PrintMiscInfo(GDVars.curChar, True);
  SelectCharacter := ch = 'S';
  GDVars.canClickParty := savedMouse;
  GDVars.orderState := 0;
end;

{ Lets the player pick a character with the prompt 'Pick Character '.
  @returns(True when a character was chosen.) }
function PickCharacterDefault: Boolean;
begin
  PickCharacterDefault := CharGen.SelectCharacter('Pick Character ');
end;

{ Count the party's player characters, not NPCs.
  @returns(The count.) }
function ActivePartyCount: Byte;
var count: Byte; cr: Types.PWork;
begin
  cr := GDVars.creatureList;
  count := 0;
  while cr <> nil do begin
    if cr^.cgNpc < C_Npc.NON_PLAYER then Inc(count);
    cr := cr^.next;
  end;
  ActivePartyCount := count;
end;

function ClassConAdj(cls: Byte): ShortInt; forward;

procedure MainMenu;
var
  i: Byte;
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  extendedKey: Byte;
  { the menu's redraw flag, and ViewCharMenu's result }
  ext2: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  savedChoices: array[1..8] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  promptText: Byte;
  { the commands shown }
  n: ShortInt;
  redraw: Boolean;
  head: Types.PItemRec;
  sel: Types.PItemRec;
  p: Types.PItemRec;
  cnt: Integer;
  bottomRow: Byte;

  { Count the enabled commands into n. }
  procedure CountEnabled;
  var j: Byte;
  begin
    n := 0;
    for j := 0 to 13 do
      if GDConsts.menuItems[j].enabled <> 0 then Inc(n);
  end;
begin
  GDVars.savedInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
  redraw := True;
  GDVars.stingMode := 0;
  cnt := 0;
  while True do begin
    if redraw then begin
      Border.DrawWindowFrame;
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayParty(Pointer(GDVars.curChar));
        GDConsts.menuItems[1].enabled := 1;
        GDConsts.menuItems[2].enabled := 1;
        GDConsts.menuItems[3].enabled := 1;
        GDConsts.menuItems[4].enabled := Ord(GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] > 0);
        GDConsts.menuItems[5].enabled := Ord((GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] > 0) or (GDVars.stingMode <> 0));
        GDConsts.menuItems[6].enabled := 1;
        GDConsts.menuItems[8].enabled := 1;
        GDConsts.menuItems[9].enabled := 0;
        GDConsts.menuItems[10].enabled := 1;
        GDConsts.menuItems[11].enabled := 1;
        GDConsts.menuItems[13].enabled := 1;
      end else begin
        GDConsts.menuItems[1].enabled := 0;
        GDConsts.menuItems[2].enabled := 0;
        GDConsts.menuItems[3].enabled := 0;
        GDConsts.menuItems[4].enabled := 0;
        GDConsts.menuItems[5].enabled := 0;
        GDConsts.menuItems[6].enabled := 0;
        GDConsts.menuItems[8].enabled := 0;
        GDConsts.menuItems[9].enabled := 1;
        GDConsts.menuItems[10].enabled := 0;
        GDConsts.menuItems[11].enabled := 0;
        GDConsts.menuItems[13].enabled := 1;
      end;
      GDConsts.menuItems[12].enabled := 1;
      GDConsts.menuItems[7].enabled := Ord(CharGen.ActivePartyCount < 6);
      CountEnabled;
      if n > 11 then begin
        GDConsts.menuItems[12].enabled := 0;
        CountEnabled;
      end;
      if n > 11 then begin
        GDConsts.menuItems[3].enabled := 0;
        CountEnabled;
      end;
      if n > 11 then begin
        GDConsts.menuItems[10].enabled := 0;
        CountEnabled;
      end;
      MenuCore.AllocStringList(n, head);
      p := head;
      for i := 0 to 13 do
        if GDConsts.menuItems[i].enabled <> 0 then begin
          p^.name := GDConsts.menuItems[i].name;
          p := p^.next;
        end;
    end;
    ext2 := True;
    GDVars.partyRepeat := 0;
    GDVars.canClickParty := 1;
    bottomRow := 22 - n + 1;
    if bottomRow > 15 then bottomRow := 15;
    if bottomRow < 12 then bottomRow := 12;
    ch := MenuCore.MenuVertical('Choose a FUNCTION ', 'Select ', LightMagenta, LightGreen, White, 9, bottomRow, 38, 22,
                                head, False, ext2, cnt, sel);
    GDVars.canClickParty := 0;
    ch := sel^.name[1];
    if GDVars.partyRepeat <> 0 then
      if ch in ['A', 'B', 'C', 'E', 'L', 'S'] then ch := 'V';
    if redraw then MenuCore.FreeStringList(head);
    if not (ch in ['E', 'S']) then
      GDVars.recentlySavedGameFlag := 0;
      case ch of
        'C':
          if GDConsts.menuItems[0].enabled <> 0 then CharGen.CreateCharacterMenu;
        'M':
          if GDConsts.menuItems[1].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then CharGen.ModifyCharacterMenu;
        'D':
          if GDConsts.menuItems[2].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then CharGen.DropCharacterMenu;
        'I':
          if GDConsts.menuItems[3].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then CharGen.CustomizePortrait;
        'T':
          if GDConsts.menuItems[4].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then CharGen.TrainingMenu;
        'H':
          if GDConsts.menuItems[5].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then
              ClassCal.ChangeClass(Pointer(GDVars.curChar));
        'V':
          if GDConsts.menuItems[6].enabled <> 0 then
            if (GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault then ViewChar.ViewCharMenu(ext2);
        'A':
          if GDConsts.menuItems[7].enabled <> 0 then CharGen.AddCharacterMenu;
        'R':
          if (GDConsts.menuItems[8].enabled <> 0) and
              ((GDVars.partyRepeat <> 0) or CharGen.PickCharacterDefault) then begin
            if GDVars.curChar^.cgNpc < C_Npc.NON_PLAYER then begin
              SaveLoad.SaveChar(Types.PCharRecord(GDVars.curChar), '');
              CharGen.RemoveCreature(False, True);
            end else
              CharGen.DropCharacterMenu;
            if GDVars.creatureList = nil then begin
              GameInit.ResetGameState;
              GDVars.virtualDiskNumber := 2;
              GDVars.eclScript := 1;
              GDVars.finishNewEclProc;
              GDVars.savedInterfaceState := C_Ifc.EXPLORING;
              GDVars.interfaceState := C_Ifc.MAIN_MENU;
            end;
          end;
        'L':
          if GDConsts.menuItems[9].enabled <> 0 then SaveLoad.LoadGame;
        'S':
          if (GDConsts.menuItems[10].enabled <> 0) and (GDVars.creatureList <> nil) then begin
            GDVars.interfaceState := GDVars.savedInterfaceState;
            SaveLoad.SaveGame;
            GDVars.interfaceState := C_Ifc.MAIN_MENU;
          end;
        'B':
          if GDConsts.menuItems[11].enabled <> 0 then begin
            GDVars.canClickParty := 1;
            if (GDVars.creatureList <> nil) or (GDVars.demoMode) then begin
              GDVars.interfaceState := GDVars.savedInterfaceState;
              GDVars.interfaceState := C_Ifc.EXPLORING;
              CharHlp.DisplayNoncombatInterface;
              GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] := 0;
              GameIo.KbdNoop;
              Exit;
            end;
          end;
        'i':
          if GDConsts.menuItems[12].enabled <> 0 then InputCfg.InputConfigMenu;
        'E':
          if GDConsts.menuItems[13].enabled <> 0 then begin
            ch := MenuCore.YesNoMenuClear('Quit to DOS ', Yellow, LightGreen, White);
            if ch = 'Y' then
            begin
              if (GDVars.creatureList <> nil) and (GDVars.recentlySavedGameFlag = 0) then begin
                ch := MenuCore.YesNoMenuClear('Game NOT saved.  Quit anyway? ', Yellow, LightGreen, White);
                if ch = 'N' then SaveLoad.SaveGame;
              end;
              if ch = 'Y' then GameIo.ExitGame;
            end;
          end;
      end;
  end;
end;

{ The character-creation pipeline -- race, gender, class and alignment picks, age, the best-of-six stat roll with its
  aging and race/class clamps, first-level HP and starting gold, the TrainingMenu review loop behind 'Reroll stats?',
  then name, portrait and save. }
procedure CreateCharacterMenu;
var
  cr: Types.PWork;
  { the current character, restored at the end }
  savedCur: Types.PWork;
  { the pick menu's list }
  list: Types.PItemRec;
  m: Types.PItemRec;
  sel: Integer;
  slot: Byte;
  { the rolls of one stat }
  j: ShortInt;
  roll: Byte;
  ch: Char;
  { the race list's row }
  k: ShortInt;
  g: ShortInt;
  cls: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  statIndex: Byte;
  { the stat rolled }
  i: ShortInt;
  { the choices a table allows }
  cnt: Byte;
  conB: Integer;
  { Unused in this version; see the other implementations of this routine. }
  classCount: Byte;
  clsCount: Byte;
  hpTotal: Byte;
  addExit: Boolean;
  redraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  haveLevelText: Byte;
  { a level is already on the line }
  keepFlag: Boolean;
  { the class levels, shown for the review }
  line: String[40];
  { the zone's training mask, restored after the review }
  savedPanel: Byte;
begin
  GetMem(cr, SizeOf(Types.TWork));
  FillChar(cr^, SizeOf(Types.TWork), 0);
  with cr^ do begin
    for slot := 1 to 6 do
      cgIconSizeColors[slot] := GDConsts.defIconCol[slot] + (GDConsts.defIconCol[slot] + 8) * 16;
    cgAcBase := 50;
    cgThac0Base := 40;
    cgStatus := 0;
    cgEnabled := 1;
    cgIconDim := 1;
    cgRandomId := Random(256);
    orderNum := 10;
  end;
  { ---- race ---------------------------------------------------------- }
  MenuCore.AllocStringList(7, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 1 to 7 do
    case TOrdIdx(k) of
      oi1..oi5: begin
              m := Types.PItemRec(MenuCore.FindListMember(k, Types.PItemRec(list)));
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
      { half-orc (6) row skipped }
      oi7: begin
              m := MenuCore.FindListMember(k - 1, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
    end;
  m := list;
  sel := 1;
  redraw := True;
  addExit := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(Types.TWork));
      Exit;
    end;
  { the menu's Select }
  until ch = 'S';
  if sel = 6 then
    { the sixth row is Human }
    Inc(sel);
  with cr^ do begin
    race := sel;
    case Char(race) of
      Chr(C_Race.HALFLING): begin
           cgIconSizeColors[0] := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
         end;
      Chr(C_Race.DWARF): begin
           cgIconSizeColors[0] := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_THAC0, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_ARMOR_CLASS_VS_GIANTS, 0, 255, False);
         end;
      Chr(C_Race.GNOME): begin
           cgIconSizeColors[0] := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.GNOME_THAC0, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.DWARF_ARMOR_CLASS_VS_GIANTS, 0, 255, False);
           FxEngine.AddEffect(Pointer(cr), C_Effect.GNOME_ARMOR_CLASS_BONUS, 0, 255, False);
         end;
      Chr(C_Race.ELF): begin
           cgIconSizeColors[0] := 2;
           FxEngine.AddEffect(Pointer(cr), C_Effect.ELF_RESISTANCE, 0, 255, False);
         end;
      Chr(C_Race.HALF_ELF): begin
           cgIconSizeColors[0] := 2;
           FxEngine.AddEffect(Pointer(cr), C_Effect.HALF_ELF_RESISTANCE, 0, 255, False);
         end;
    else
      { human }
      cgIconSizeColors[0] := 2;
    end;
  end;
  { ---- gender -------------------------------------------------------- }
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GDConsts.genderNames[g];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(Types.TWork));
      Exit;
    end;
  until ch = 'S';
  cr^.gender := sel - 1;
  MenuCore.FreeStringList(list);
  { ---- class -------------------------------------------------------- }
  cnt := GDConsts.classesByRace[cr^.race, 0];
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.classNames[GDConsts.classesByRace[cr^.race, slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(Types.TWork));
      Exit;
    end;
  until ch = 'S';
  with cr^ do begin
    exp := 3000;
    charClass := GDConsts.classesByRace[race, sel];
    cgLevelHighest := 1;
    case TOrdIdx(charClass) of
      oi0..oi2: lvl[charClass] := 1;
      oi5..oi7: lvl[charClass] := 1;
      oi3: begin
           cr^.cgDiseaseCount := 1;
           lvl[C_Class.PALADIN_LEVEL] := 1;
           FxEngine.AddEffect(Pointer(cr), C_Effect.PROTECTION_FROM_EVIL, 0, 255, False);
         end;
      oi4: begin
           lvl[C_Class.RANGER_LEVEL] := 1;
           FxEngine.AddEffect(Pointer(cr), 134, 0, 255, False);
         end;
      oi8: begin lvl[C_Class.CLERIC_LEVEL] := 1; lvl[C_Class.FIGHTER_LEVEL] := 1; exp := exp div 2; end;
      oi9: begin lvl[C_Class.CLERIC_LEVEL] := 1; lvl[C_Class.FIGHTER_LEVEL] := 1; lvl[C_Class.MAGE_LEVEL] := 1; exp
          := exp div 3; end;
      oi10: begin
            lvl[C_Class.CLERIC_LEVEL] := 1;
            lvl[C_Class.RANGER_LEVEL] := 1;
            FxEngine.AddEffect(Pointer(cr), 134, 0, 255, False);
            exp := exp div 2;
          end;
      oi11: begin lvl[C_Class.CLERIC_LEVEL] := 1; lvl[C_Class.MAGE_LEVEL] := 1; exp := exp div 2; end;
      oi12: begin lvl[C_Class.CLERIC_LEVEL] := 1; lvl[C_Class.THIEF_LEVEL] := 1; exp := exp div 2; end;
      oi13: begin lvl[C_Class.FIGHTER_LEVEL] := 1; lvl[C_Class.MAGE_LEVEL] := 1; exp := exp div 2; end;
      oi14: begin lvl[C_Class.FIGHTER_LEVEL] := 1; lvl[C_Class.THIEF_LEVEL] := 1; exp := exp div 2; end;
      oi15: begin lvl[C_Class.FIGHTER_LEVEL] := 1; lvl[C_Class.MAGE_LEVEL] := 1; lvl[C_Class.THIEF_LEVEL] := 1; exp
          := exp div 3; end;
      oi16: begin lvl[C_Class.MAGE_LEVEL] := 1; lvl[C_Class.THIEF_LEVEL] := 1; exp := exp div 2; end;
    end;
    if lvl[C_Class.THIEF_LEVEL] > 0 then ClassCal.RecalcThiefSkills(Pointer(cr));
    cgClassMask := 0;
    cgThac0Base := 0;
    for cls := 0 to 7 do
      if lvl[cls] > 0 then begin
        if GDConsts.thac0Tbl[cls, lvl[cls]] > cgThac0Base then
          cgThac0Base := GDConsts.thac0Tbl[cls, lvl[cls]];
        Inc(cgClassMask, GDConsts.createClassBits[cls]);
      end;
  end;
  ClassCal.RecalcSaves(Pointer(cr));
  MenuCore.FreeStringList(list);
  { ---- alignment ---------------------------------------------------- }
  cnt := GDConsts.alignmentsAllowedClass[cr^.charClass, 0];
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.alignNames[GDConsts.alignmentsAllowedClass[cr^.charClass, slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw, sel,
                                m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      FreeMem(cr, SizeOf(Types.TWork));
      Exit;
    end;
  until ch = 'S';
  cr^.cgAlignment := GDConsts.alignmentsAllowedClass[cr^.charClass, sel];
  MenuCore.FreeStringList(list);
  { ---- age ---------------------------------------------------------- }
  if cr^.charClass <= 7 then
    with GDConsts.startingAge[cr^.race, cr^.charClass] do
      cr^.age := FxEngine.RollDice(num, sides) + base
  else
    with cr^ do
      case Char(charClass) of
        #8: age := GDConsts.startingAge[race, 0].base +
          GDConsts.startingAge[race, 0].sides * GDConsts.startingAge[race, 0].num;
        #9: age := GDConsts.startingAge[race, 0].base +
          GDConsts.startingAge[race, 0].sides * GDConsts.startingAge[race, 0].num;
        #11: age := GDConsts.startingAge[race, 0].base +
          GDConsts.startingAge[race, 0].sides * GDConsts.startingAge[race, 0].num;
        #12: age := GDConsts.startingAge[race, 0].base +
          GDConsts.startingAge[race, 0].sides * GDConsts.startingAge[race, 0].num;
        #13: age := GDConsts.startingAge[race, 5].base +
          GDConsts.startingAge[race, 5].sides * GDConsts.startingAge[race, 5].num;
        #14: age := GDConsts.startingAge[race, 2].base +
          GDConsts.startingAge[race, 2].sides * GDConsts.startingAge[race, 2].num;
        #15: age := GDConsts.startingAge[race, 5].base +
          GDConsts.startingAge[race, 5].sides * GDConsts.startingAge[race, 5].num;
        #16: age := GDConsts.startingAge[race, 5].base +
          GDConsts.startingAge[race, 5].sides * GDConsts.startingAge[race, 5].num;
        #10: age := GDConsts.startingAge[race, 0].base +
          GDConsts.startingAge[race, 0].sides * GDConsts.startingAge[race, 0].num;
      end;
  { ---- stat roll ---------------------------------------------------- }
  savedCur := GDVars.curChar;
  GDVars.curChar := cr;
  ViewChar.DisplayChar;
  repeat
    for cls := 0 to 7 do
      if GDVars.curChar^.lvl[cls] > 0 then GDVars.curChar^.lvl[cls] := 1;
    cr^.exStrPct := 0;
    for i := 0 to 5 do begin
      cr^.stat[i].current := 0;
      for j := 1 to 6 do begin
        roll := FxEngine.RollDice(3, 6) + 1;
        { Note: k is the race loop's counter, not race, and reads 7 here }
        case Char(k) of
          #1: case Char(i) of #4: Inc(roll); #5: Dec(roll) end;
          #2: case Char(i) of #3: Inc(roll); #4: Dec(roll) end;
          #5: case Char(i) of #0: Dec(roll); #3: Inc(roll) end;
          #6: case Char(i) of #0: Inc(roll); #4: Inc(roll); #5: Dec(roll, 2) end;
        end;
        if cr^.stat[i].current < roll then cr^.stat[i].current := roll;
      end;
      with cr^ do
        case Char(i) of
          { STR }
          #0: begin
               if (stat[i].current > 0) and (GDConsts.ageCategoryRace[race, 1] < age) then Inc(stat[i].current);
               if (stat[i].current > 0) and (GDConsts.ageCategoryRace[race, 2] < age) then Dec(stat[i].current);
               if (stat[i].current > 0) and (GDConsts.ageCategoryRace[race, 3] < age) then Dec(stat[i].current, 2);
               if (stat[i].current > 0) and (GDConsts.ageCategoryRace[race, 4] < age) then Dec(stat[i].current);
               if stat[i].current < GDConsts.raceLim[race].strMin[gender] then stat[i].current :=
                   GDConsts.raceLim[race].strMin[gender];
               if stat[i].current > GDConsts.raceLim[race].strMax[gender] then stat[i].current :=
                   GDConsts.raceLim[race].strMax[gender];
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
               if stat[C_Stat.STRENGTH].current = 18 then
                 if (lvl[C_Class.FIGHTER_LEVEL] > 0) or (lvl[C_Class.RANGER_LEVEL] > 0) or
                     (lvl[C_Class.PALADIN_LEVEL] > 0) then begin
                   exStrPct := Random(100) + 1;
                   if GDConsts.raceLim[race].exStrMax[gender] < exStrPct then
                     exStrPct := GDConsts.raceLim[race].exStrMax[gender];
                 end;
             end;
          { INT }
          #1: begin
               if GDConsts.ageCategoryRace[race, 2] < age then Inc(stat[i].current);
               if GDConsts.ageCategoryRace[race, 4] < age then Inc(stat[i].current);
               if stat[i].current < GDConsts.raceLim[race].intMin then stat[i].current := GDConsts.raceLim[race].intMin;
               if stat[i].current > GDConsts.raceLim[race].intMax then stat[i].current := GDConsts.raceLim[race].intMax;
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
             end;
          { WIS }
          #2: begin
               if GDConsts.ageCategoryRace[race, 1] >= age then Dec(stat[i].current);
               if GDConsts.ageCategoryRace[race, 2] < age then Inc(stat[i].current);
               if GDConsts.ageCategoryRace[race, 3] < age then Inc(stat[i].current);
               if GDConsts.ageCategoryRace[race, 4] < age then Inc(stat[i].current);
               if stat[i].current < GDConsts.raceLim[race].wisMin then stat[i].current := GDConsts.raceLim[race].wisMin;
               if stat[i].current > GDConsts.raceLim[race].wisMax then stat[i].current := GDConsts.raceLim[race].wisMax;
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
               if (stat[i].current < 13) and (charClass in [8, 9, 10, 11, 12]) then stat[i].current := 13;
             end;
          { DEX }
          #3: begin
               if GDConsts.ageCategoryRace[race, 3] < age then Dec(stat[i].current, 2);
               if GDConsts.ageCategoryRace[race, 4] < age then Dec(stat[i].current);
               if stat[i].current < GDConsts.raceLim[race].dexMin then stat[i].current := GDConsts.raceLim[race].dexMin;
               if stat[i].current > GDConsts.raceLim[race].dexMax then stat[i].current := GDConsts.raceLim[race].dexMax;
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
             end;
          { CON }
          #4: begin
               if GDConsts.ageCategoryRace[race, 2] < age then Dec(stat[i].current);
               if GDConsts.ageCategoryRace[race, 3] < age then Dec(stat[i].current);
               if GDConsts.ageCategoryRace[race, 4] < age then Dec(stat[i].current);
               if stat[i].current < GDConsts.raceLim[race].conMin then stat[i].current := GDConsts.raceLim[race].conMin;
               if stat[i].current > GDConsts.raceLim[race].conMax then stat[i].current := GDConsts.raceLim[race].conMax;
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
             end;
          { CHA }
          #5: begin
               if stat[i].current < GDConsts.raceLim[race].chaMin then stat[i].current := GDConsts.raceLim[race].chaMin;
               if stat[i].current > GDConsts.raceLim[race].chaMax then stat[i].current := GDConsts.raceLim[race].chaMax;
               if stat[i].current < GDConsts.minimumStatisticsClass[charClass,
                                                                    i] then stat[i].current :=
                                                                  GDConsts.minimumStatisticsClass[charClass, i];
             end;
        end;
      ViewChar.PrintStat(i, Boolean(0));
    end;
    with cr^ do begin
      hpCur := clsFlags[0];
      cgAttacks := 2;
      cgBaseRolls[1] := 1;
      cgBaseDice[1] := 2;
      cgUseStrength := 1;
      cgMoveRate := 12;
      hpTotal := 0;
      clsCount := 0;
      FillChar(slots, SizeOf(slots), 0);
      for cls := 0 to 7 do
        if lvl[cls] > 0 then begin
          case Char(cls) of
            #0: cgSpellSlots[0, 1] := 1;
            #5: cgSpellSlots[2, 1] := 1;
          end;
          Inc(hpTotal, FxEngine.RollDice(GDConsts.startingGoldClass[cls].num, GDConsts.startingGoldClass[cls].sides));
          case Char(cls) of
            #0: begin
                 ClassCal.RecalcClericSlots(Pointer(cr), Boolean(0));
                 for slot := 1 to 100 do
                   with GDConsts.spellTable[slot] do
                     if (castClass = C_Spell.CLERIC_LIST) and (level = 1) then clsFlags[slot] := 1;
               end;
            #5: begin
                 clsFlags[C_Spell.DETECT_MAGIC_MAGE] := 1;
                 clsFlags[C_Spell.READ_MAGIC] := 1;
                 clsFlags[C_Spell.ENLARGE] := 1;
                 clsFlags[C_Spell.SLEEP] := 1;
               end;
          end;
          Inc(clsCount);
        end;
      coinsA[4] := 35;
      cgHpRolled := CharGen.RollFirstLevelHp(cr, 255);
      clsFlags[0] := cgHpRolled;
      conB := CharGen.ConHpBonus(cr);
      if conB < 0 then begin
        if clsFlags[0] > Abs(conB) + clsCount then
          clsFlags[0] := (clsFlags[0] + conB) div clsCount
        else
          clsFlags[0] := 1;
      end else
        clsFlags[0] := (clsFlags[0] + conB) div clsCount;
      hpCur := clsFlags[0];
      cgHpRolled := cgHpRolled div clsCount;
    end;
    savedPanel := Byte(GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK]);
    GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] := 255;
    GDVars.characterMenuDone := 0;
    GDVars.isAutoTraining := True;
    repeat
      CharGen.TrainingMenu;
    until GDVars.characterMenuDone <> 0;
    GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK] := savedPanel;
    GDVars.isAutoTraining := False;
    keepFlag := False;
    line := '';
    for cls := 0 to 7 do
      if (GDVars.curChar^.lvl[cls] > 0) or
          ((GDVars.curChar^.cgOldClassLevels[cls] < ClassCal.CurrentDualClassLevel(Pointer(GDVars.curChar))) and
           (GDVars.curChar^.cgOldClassLevels[cls] > 0)) then begin
        if keepFlag then line := line + '/';
        line := line + CharHlp.Uint8Str(GDVars.curChar^.lvl[cls] + GDVars.curChar^.cgOldClassLevels[cls]);
        keepFlag := True;
      end;
    TextRend.DisplayString(7, 7, White, Black, line);
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenuClear('Reroll stats? ', LightMagenta, LightGreen, White);
  until ch = 'N';
  { ---- name + portrait + save --------------------------------------- }
  ViewChar.DisplayChar;
  repeat
    cr^.name := TextRend.ReadString('Character name: ', LightMagenta, Black, 15);
  until cr^.name <> '';
  CharGen.CustomizePortrait;
  for i := 0 to 5 do
    cr^.stat[i].permanent := cr^.stat[i].current;
  cr^.cgExStrBase := cr^.exStrPct;
  ch := MenuCore.YesNoMenu('Save ' + cr^.name + '? ', LightMagenta, LightGreen, White);
  if ch = 'N' then
  begin
    FreeMem(cr, SizeOf(Types.TWork));
    GDVars.curChar := savedCur;
  end else begin
    SaveLoad.SaveChar(Types.PCharRecord(cr), '');
    FreeMem(cr, SizeOf(Types.TWork));
    GDVars.curChar := savedCur;
  end;
end;

{ Computes the current character's Constitution hit-point adjustment for a class: -2 at Constitution 3, -1 at 4 to 6, 0
  at 7 to 14, +1 at 15, +2 at 16, and at 17 to 19 the Constitution less 14 for fighters, rangers and paladins or +2 for
  others. Note: a Constitution outside 3 to 19 leaves the result undefined.
  @param(cls The class level index.)
  @returns(The hit-point adjustment per level.) }
function ClassConAdj(cls: Byte): ShortInt;
var
  r: ShortInt;
begin
  case GDVars.curChar^.stat[C_Stat.CONSTITUTION].current of
    3: r := -2;
    4..6: r := -1;
    7..14: r := 0;
    15: r := 1;
    16: r := 2;
    17..19: if (cls = C_Class.FIGHTER_LEVEL) or (cls = C_Class.RANGER_LEVEL) or
                (cls = C_Class.PALADIN_LEVEL) then
              r := GDVars.curChar^.stat[C_Stat.CONSTITUTION].current - 14
            else
              r := 2;
  end;
  ClassConAdj := r;
end;

{ Drop the current character from the party. Two-stage yes/no confirm ('Drop <name> forever? ' then 'Are you sure? ');
  on confirm the message forks on cgEnabled ('You drop <name>.' vs '<name> bids you farewell.'), the character's files
  are deleted and it is unlinked through RemoveCreature; on any 'N' the character "breathes a sigh of relief".
  DisplayParty repaints in every path. }
procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
begin
  if GDVars.curChar <> nil then
    with GDVars.curChar^ do begin
      if (MenuCore.YesNoMenuClear('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y') and
          (MenuCore.YesNoMenuClear('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
      begin
        if cgEnabled = 0 then
          CharHlp.PrintBottomLine('You drop ' + name + '.')
        else
          CharHlp.PrintBottomLine(name + ' bids you farewell.');
        SaveLoad.DeleteCharacterFiles(GDVars.curChar);
        CharGen.RemoveCreature(False, True);
      end else
        CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
    end;
  CharHlp.DisplayParty(Pointer(GDVars.curChar));
end;

{ The arrow-key editor for a character's stats, hit points and name, with its nested DisplayModifyField. Only a
  character whose exp is 0, 3000, 1000 or 1500 and whose cgLevelAtChange is 0 can be edited. 'E' or Escape restores the
  backup taken on entry; 'K' keeps the edit and rederives cgHpRolled from the per-class con adjustment (ClassConAdj). }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..5] of Byte;
  savedStr: Byte;
  { the hit points restored on Exit; Keep reuses it for the constitution adjustment }
  savedHp: Byte;
  { the name restored on Exit }
  savedName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  cls: ShortInt;
  { the stat edited, and the stats' loop index }
  sIdx: ShortInt;
  ch: Char;
  { the key read is an extended key }
  ext: Boolean;
  { the field edited: 0..5 the stats, 6 the hit points, 7 the name }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cursorColumn: array[0..7] of Byte;
  { the name cursor's column }
  namePos: Byte;
  { a loop counter, and Keep's count of classes }
  count: Byte;
  mouseA: Integer;
  mouseB: Integer;
  mouseC: Integer;

  { Redraw the field row, highlighted when active. }
  procedure DisplayModifyField(active: Byte);
  begin
    case row of
      0..5: ViewChar.PrintStat(row, Boolean(active));
      6: CharHlp.PrintHitPointsAligned(Pointer(GDVars.curChar), 32, 3, Boolean(active));
      7: if active <> 0 then begin
              TextRend.PrintSpaces(Length(GDVars.curChar^.name) + 1, 1, Black, 2);
              if Length(GDVars.curChar^.name) > 0 then
                TextRend.DisplayString(1, 1, White, Black, GDVars.curChar^.name);
              if (namePos > Length(GDVars.curChar^.name)) or (GDVars.curChar^.name[namePos] = ' ') then
                TextRend.DisplayString(namePos, 1, White, Black, '@')
              else
                TextRend.DisplayString(namePos, 1, Black, White, Chr(Ord(GDVars.curChar^.name[namePos])));
            end else begin
              if Length(GDVars.curChar^.name) > 0 then
                TextRend.DisplayString(1, 1, LightGreen, Black, GDVars.curChar^.name);
              TextRend.PrintSpaces(Length(GDVars.curChar^.name) + 1, 1, Black, 2);
            end;
    end;
  end;

  { Put c at the name cursor and advance it, while the cursor is below column 15. }
  procedure InsertName(c: Char);
  begin
    if namePos < 15 then begin
      GDVars.curChar^.name[namePos] := c;
      Inc(namePos);
      if Length(GDVars.curChar^.name) < namePos - 1 then
        GDVars.curChar^.name[0] := Chr(namePos - 1);
    end;
  end;

begin
  { only a new character can be modified }
  if not (((GDVars.curChar^.exp = 0) or (GDVars.curChar^.exp = 3000) or (GDVars.curChar^.exp = 1000) or
           (GDVars.curChar^.exp = 1500)) and (GDVars.curChar^.cgLevelAtChange = 0)) then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow, Black);
    Exit;
  end;

  { keep what Exit restores }
  ViewChar.DisplayChar;
  for sIdx := 0 to 5 do
    savedStats[sIdx] := GDVars.curChar^.stat[sIdx].current;
  savedStr := GDVars.curChar^.exStrPct;
  savedHp := GDVars.curChar^.clsFlags[0];
  savedName := GDVars.curChar^.name;

  namePos := Length(GDVars.curChar^.name) + 1;
  row := 7;
  DisplayModifyField(0);
  row := 0;
  DisplayModifyField(1);

  with GDVars.curChar^ do begin
  repeat
    GameIo.WaitMouseRelease;
    GDVars.modifyRow := row;
    if row = 7 then begin
      repeat
        Mouse.GetMouse(mouseA, mouseB, mouseC)
      until mouseA = 0;
      repeat until GameIo.InputPending;
      ch := GameIo.ReadGameKey;
      if ch = C_Keys.NONE then begin
        ch := GameIo.ReadGameKey;
        ext := True;
      end else begin
        ext := False;
        if ch = C_Keys.ESCAPE then ch := C_Keys.NONE;
      end;
      repeat
        Mouse.GetMouse(mouseA, mouseB, mouseC)
      until mouseA = 0;
    end else begin
      GDVars.clickPending := 1;
      ch := MenuCore.MenuHorizontal('Modify: ', 'Keep Add Subtract Exit', LightMagenta, LightGreen, White, True, False,
                                    ext);
      GDVars.clickPending := 0;
    end;
    if GDVars.modifyRow <> row then
      DisplayModifyField(0);
    row := GDVars.modifyRow;
    if (not ext) and (row = 7) and (ch in [' '..'z']) then begin
      InsertName(ch);
      ext := True;
    end else if ext then begin
      case ch of
      C_Keys.DELETE_KEY:
        if (row = 7) and (Length(GDVars.curChar^.name) > 0) then begin
          if namePos >= Length(GDVars.curChar^.name) then begin
            Dec(GDVars.curChar^.name[0]);
            namePos := Length(GDVars.curChar^.name) + 1;
          end else begin
            for count := namePos to Length(GDVars.curChar^.name) - 1 do
              GDVars.curChar^.name[count] := GDVars.curChar^.name[count + 1];
            Dec(GDVars.curChar^.name[0]);
          end;
        end;
      C_Keys.DOWN: begin
          DisplayModifyField(0);
          Inc(row);
          if row > 7 then row := 0;
        end;
      C_Keys.UP: begin
          DisplayModifyField(0);
          Dec(row);
          if row = 255 then row := 7;
        end;
      C_Keys.LEFT:
        if row = 7 then
          if namePos > 1 then
            Dec(namePos)
          else
            namePos := Length(GDVars.curChar^.name) + 1;
      C_Keys.RIGHT:
        if row = 7 then
          if namePos < Length(GDVars.curChar^.name) + 1 then
            Inc(namePos)
          else
            namePos := 1;
      end;
    end else begin
      case ch of
      C_Keys.ENTER: begin
          DisplayModifyField(0);
          Inc(row);
          if row > 7 then row := 0;
        end;
      C_Keys.BACKSPACE:
        if (namePos > 1) and (row > 6) then begin
          for count := namePos to Length(GDVars.curChar^.name) do
            GDVars.curChar^.name[count - 1] := GDVars.curChar^.name[count];
          Dec(GDVars.curChar^.name[0]);
          Dec(namePos);
          if namePos > Length(GDVars.curChar^.name) + 1 then
            namePos := Length(GDVars.curChar^.name) + 1;
        end;
      'S':
        if row < 6 then begin
          { lower the stat, no lower than the race and class allow }
          sIdx := row;
          dec(stat[sIdx].current);
          case Char(sIdx) of
            #0: begin
                 if exStrPct > 0 then begin
                   dec(exStrPct);
                   inc(stat[sIdx].current);
                 end else begin
                   if stat[sIdx].current < GDConsts.raceLim[race].strMin[gender] then
                     stat[sIdx].current := GDConsts.raceLim[race].strMin[gender];
                 end;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][0] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][0];
               end;
            #1: begin
                 if stat[sIdx].current < GDConsts.raceLim[race].intMin then
                   stat[sIdx].current := GDConsts.raceLim[race].intMin;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][1] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][1];
               end;
            #2: begin
                 if stat[sIdx].current < GDConsts.raceLim[race].wisMin then
                   stat[sIdx].current := GDConsts.raceLim[race].wisMin;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][2] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][2];
                 if cgSpellSlots[0, 1] > 0 then cgSpellSlots[0, 1] := 1;
               end;
            #3: begin
                 if stat[sIdx].current < GDConsts.raceLim[race].dexMin then
                   stat[sIdx].current := GDConsts.raceLim[race].dexMin;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][3] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][3];
               end;
            #4: begin
                 if stat[sIdx].current < GDConsts.raceLim[race].conMin then
                   stat[sIdx].current := GDConsts.raceLim[race].conMin;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][4] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][4];
                 if CharGen.HpMaximum(GDVars.curChar) < clsFlags[0] then
                   clsFlags[0] := CharGen.HpMaximum(GDVars.curChar);
                 hpCur := clsFlags[0];
                 row := 6;
                 DisplayModifyField(0);
                 row := 4;
               end;
            #5: begin
                 if stat[sIdx].current < GDConsts.raceLim[race].chaMin then
                   stat[sIdx].current := GDConsts.raceLim[race].chaMin;
                 if stat[sIdx].current < GDConsts.minimumStatisticsClass[charClass][5] then
                   stat[sIdx].current := GDConsts.minimumStatisticsClass[charClass][5];
               end;
          end;
        end else if row = 6 then begin
          dec(clsFlags[0]);
          if CharGen.HpMinimum(GDVars.curChar) > clsFlags[0] then
            clsFlags[0] := CharGen.HpMinimum(GDVars.curChar);
          hpCur := clsFlags[0];
        end;
      'A':
        if row < 6 then begin
          { raise the stat, no higher than the race allows }
          sIdx := row;
          inc(stat[sIdx].current);
          case Char(sIdx) of
            #0: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].strMax[gender] then begin
                   if stat[sIdx].current > 18 then
                     if (lvl[C_Class.FIGHTER_LEVEL] > 0) or (lvl[C_Class.PALADIN_LEVEL] > 0) or
                         (lvl[C_Class.RANGER_LEVEL] > 0) then
                       if GDConsts.raceLim[race].exStrMax[gender] > exStrPct then
                         inc(exStrPct);
                   stat[sIdx].current := GDConsts.raceLim[race].strMax[gender];
                 end;
               end;
            #1: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].intMax then
                   stat[sIdx].current := GDConsts.raceLim[race].intMax;
               end;
            #2: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].wisMax then
                   stat[sIdx].current := GDConsts.raceLim[race].wisMax;
                 if cgSpellSlots[0, 1] > 0 then cgSpellSlots[0, 1] := 1;
               end;
            #3: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].dexMax then
                   stat[sIdx].current := GDConsts.raceLim[race].dexMax;
               end;
            #4: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].conMax then
                   stat[sIdx].current := GDConsts.raceLim[race].conMax;
                 if CharGen.HpMinimum(GDVars.curChar) > clsFlags[0] then
                   clsFlags[0] := CharGen.HpMinimum(GDVars.curChar);
                 hpCur := clsFlags[0];
                 row := 6;
                 DisplayModifyField(0);
                 row := 4;
               end;
            #5: begin
                 if stat[sIdx].current > GDConsts.raceLim[race].chaMax then
                   stat[sIdx].current := GDConsts.raceLim[race].chaMax;
               end;
          end;
        end else if row = 6 then begin
          inc(clsFlags[0]);
          if CharGen.HpMaximum(GDVars.curChar) < clsFlags[0] then
            clsFlags[0] := CharGen.HpMaximum(GDVars.curChar);
          hpCur := clsFlags[0];
        end;
      'E', C_Keys.NONE: begin
          for sIdx := 0 to 5 do
            GDVars.curChar^.stat[sIdx].current := savedStats[sIdx];
          GDVars.curChar^.exStrPct := savedStr;
          GDVars.curChar^.clsFlags[0] := savedHp;
          GDVars.curChar^.hpCur := clsFlags[0];
          GDVars.curChar^.name := savedName;
          CharHlp.RecalcStats(Pointer(GDVars.curChar));
          Exit;
        end;
      end;
    end;
    CharHlp.RecalcStats(Pointer(GDVars.curChar));
    ViewChar.PrintCombatStats;
    DisplayModifyField(1);
  until (not ext) and (ch = 'K') and (row <> 7);
  end;

  { Keep: commit the stats and rederive the rolled hit points }
  if Length(GDVars.curChar^.name) = 0 then
    GDVars.curChar^.name := ' ';
  ClassCal.RecalcClericSlots(Pointer(GDVars.curChar), Boolean(1));
  GDVars.curChar^.cgModified := 1;
  with GDVars.curChar^ do begin
    savedHp := 0;
    count := 0;
    for cls := 0 to 7 do begin
      if lvl[cls] > 0 then begin
        if Byte(lvl[cls]) < GDConsts.maxClassLevels[cls] then begin
          if cls = C_Class.RANGER_LEVEL then
            Inc(savedHp, CharGen.ClassConAdj(cls) * (lvl[cls] + 1))
          else
            Inc(savedHp, CharGen.ClassConAdj(cls) * lvl[cls]);
        end else
          Inc(savedHp, CharGen.ClassConAdj(cls) * (GDConsts.maxClassLevels[cls] - 1));
        inc(count);
      end;
    end;
    savedHp := savedHp div count;
    cgHpRolled := clsFlags[0] - savedHp;
  end;
  for sIdx := 0 to 5 do
    GDVars.curChar^.stat[sIdx].permanent := GDVars.curChar^.stat[sIdx].current;
  GDVars.curChar^.cgExStrBase := GDVars.curChar^.exStrPct;
end;

{ Lists the saved characters and adds the chosen ones to the party until Exit or the party is full (six player
  characters or eight members). A character already listed with a star, already in the party, a paladin joining evil
  members, a fourth ranger, or an evil character joining a paladin is refused, the last three with a message. Note: the
  flag that offers Exit is never set, so whether Exit is offered depends on whatever the local held. }
procedure AddCharacterMenu;
var
  { saved-game name list (menu display) }
  displayList: Types.PItemRec;
  { parallel saved-record list (load source) }
  recordList: Types.PItemRec;
  { MenuCore.MenuVertical selected display node }
  cur: Types.PItemRec;
  { record fetched by index for loading }
  selRec: Types.PItemRec;
  { the candidate }
  newChar: Types.PWork;
  { party-scan cursor }
  scan: Types.PWork;
  { MenuCore.MenuVertical selection index }
  selIdx: Integer;
  { menu key }
  ch: Char;
  { MenuCore.MenuVertical addExit, passed uninitialized }
  addExit: Boolean;
  { MenuCore.MenuVertical redraw flag }
  redraw: Boolean;
  { count of savable party members }
  realCount: Byte;
  { count of rangers in party }
  rangerCount: Byte;
  { an evil party member is present }
  evilFlag: Byte;
  { a paladin is present }
  paladinFlag: Byte;
  { name of the paladin found (for the warning) }
  existName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
begin
  evilFlag := 0;
  paladinFlag := 0;
  rangerCount := 0;
  Border.ClearBox(1, 1, 38, 22);
  ch := 'G';
  case ch of
    'G': GDVars.characterImportMode := 0;
    'P': GDVars.characterImportMode := 1;
    'H': GDVars.characterImportMode := 2;
    'E', C_Keys.NONE: Exit;
  end;
  SaveLoad.LoadCharlist(displayList, recordList);
  if displayList = nil then Exit;
  selIdx := 0;
  cur := displayList;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('Add a character: ', 'Add ', LightMagenta, LightGreen, White, 1, 2, 38, 22,
                                Types.PItemRec(displayList), addExit, redraw, selIdx, Types.PItemRec(cur));
    if (ch = C_Keys.ENTER) or (ch = 'A') then
      if cur^.name[1] <> '*' then
      begin
        MenuCore.ClearBottomLine;
        GetMem(newChar, SizeOf(Types.TWork));
        selRec := Types.PItemRec(MenuCore.FindListMember(selIdx, Types.PItemRec(recordList)));
        SaveLoad.LoadChar(selRec^.name, Types.PCharRecord(newChar), False, True);
        cur^.name := '* ' + cur^.name;
        realCount := 0;
        if GDVars.creatureList = nil then begin
          GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] := 0;
          SaveLoad.AddCharToParty(Types.PCharRecord(newChar));
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          scan := GDVars.creatureList;
          rangerCount := 0;
          { stops at the end of the party, or at the candidate when it is already in it }
          while (scan <> nil) and ((scan^.name <> newChar^.name) or (scan^.cgRandomId <> newChar^.cgRandomId)) do begin
            if scan^.cgNpc < C_Npc.NON_PLAYER then Inc(realCount);
            if scan^.lvl[C_Class.RANGER_LEVEL] > 0 then Inc(rangerCount);
            if Byte((TAlignNN(scan^.cgAlignment) + 1) mod 3) = 0 then evilFlag := 1;
            if scan^.lvl[C_Class.PALADIN_LEVEL] > 0 then begin
              paladinFlag := 1;
              existName := scan^.name;
            end;
            scan := scan^.next;
          end;
          { not in the party already, room for it, and no paladin, ranger or evil conflict }
          if (scan = nil) and
              (((newChar^.cgNpc < C_Npc.NON_PLAYER) and (realCount < 6)) or
               ((newChar^.cgNpc > C_Npc.MORALE_MASK) and (GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] < 8))) and
              not ((newChar^.lvl[C_Class.PALADIN_LEVEL] <> 0) and (evilFlag <> 0)) and
              not ((newChar^.lvl[C_Class.RANGER_LEVEL] <> 0) and (rangerCount >= 3)) and
              not ((Byte((TAlignNN(newChar^.cgAlignment) + 1) mod 3) = 0) and (paladinFlag <> 0)) then begin
            SaveLoad.AddCharToParty(Types.PCharRecord(newChar));
            SaveLoad.LoadCharIconAnim(True);
            if newChar^.cgNpc < C_Npc.NON_PLAYER then Inc(realCount);
          end else begin
            { strip the '* ' mark, show the blocking reason, free the candidate. }
            Delete(cur^.name, 1, 2);
            if (newChar^.lvl[C_Class.PALADIN_LEVEL] > 0) and (evilFlag <> 0) then begin
              CharHlp.PrintBottomLine('paladins will not join evil characters');
              TextRend.PauseOnly;
            end else if (newChar^.lvl[C_Class.RANGER_LEVEL] > 0) and (rangerCount > 2) then
              CharHlp.PrintBottomLine('too many rangers in party')
            else if (Byte((TAlignNN(newChar^.cgAlignment) + 1) mod 3) = 0) and (paladinFlag <> 0) then
              CharHlp.PrintBottomLine(existName + ' will tolerate no evil!');
            FreeMem(newChar, SizeOf(Types.TWork));
          end;
        end;
      end;
  until (ch = 'E') or (ch = C_Keys.NONE) or (realCount > 5) or (GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE] > 7);
  MenuCore.FreeStringList(Types.PItemRec(displayList));
end;

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PWork;
begin
  if GDVars.creatureList = nil then Exit;
  prev := GDVars.creatureList;
  if prev <> GDVars.curChar then begin
    while (prev^.next <> GDVars.curChar) and (prev^.next <> nil) do
      prev := prev^.next;
    if prev^.next <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.orderNum);
      prev^.next := GDVars.curChar^.next;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.orderNum);
    GDVars.creatureList := GDVars.curChar^.next;
    prev := GDVars.curChar^.next;
    CharGen.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]);
  end;
  if GDVars.curChar = nil then
    GDVars.curChar := GDVars.creatureList;
end;

procedure CustomizePortrait;
var
  { Unused in this version; see the other implementations of this routine. }
  extendedKey: Byte;
  { menu key }
  ch: Char;
  { MenuHorizontal extended flag }
  escFlag: Boolean;
  savedHead: Byte;
  savedBody: Byte;
  savedIcon: Byte;
  savedOrder: Byte;
  state: Byte;
  { size-name label temp }
  sizeName: String[5];
  { Unused in this version; see the other implementations of this routine. }
  colorIndex: Byte;
  { saved icon-color block }
  iconData: Types.TIcon6;
  { color part index }
  partIdx: Byte;
  { 0 = Hair, 1 = Face }
  colorMode: Byte;
  { low nibble }
  sizeVal: Byte;
  { high nibble }
  colVal: Byte;
  { state to return to }
  retState: Byte;
  { saved sub-select key }
  subKey: Char;

  { Redraw one icon cell at (row,col); outside CGA it adds the two extra frame boxes. }
  procedure ShowIconFrames(row, col: Byte);
  begin
    if GDVars.displayMode = C_Video.VM_CGA then
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 3, GDVars.viewBuf)
    else begin
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 0, GDVars.viewBuf);
      Raster.BlitTileClipped(row * 3, col * 3, 0, 0, GDVars.iconAnimation[25, 0], GDVars.viewBuf);
      Raster.BlitTileClipped((row + 3) * 3, col * 3, 0, 0, GDVars.iconAnimation[25, 0], GDVars.viewBuf);
    end;
    MapTiles.DrawIconAnimSprite(row, col, 0, 0, 12);
    MapTiles.DrawIconAnimSprite(row + 3, col, 0, 1, 12);
    Raster.FlushView;
  end;

  { Copy icon source's pictures to icon destination and, when rebuild, recolor them with the character's colors. }
  procedure CopyIconPics(source, destination, rebuild: Byte);
  var
    i: Byte;
    grid1: Types.TColorTab;
    grid2: Types.TColorTab;
    cnt: Word;
  begin
    cnt := GDVars.iconAnimation[destination, 0]^.frameSize;
    Move(GDVars.iconAnimation[source, 0]^.data, GDVars.iconAnimation[destination, 0]^.data,
         GDVars.iconAnimation[destination, 0]^.frameSize);
    Move(GDVars.iconAnimation[source, 1]^.data, GDVars.iconAnimation[destination, 1]^.data,
         GDVars.iconAnimation[destination, 1]^.frameSize);
    if GDVars.displayMode <> C_Video.VM_VGA then begin
      Move(GDVars.iconAnimation[source, 0]^.transp^, GDVars.iconAnimation[destination, 0]^.transp^, cnt);
      Move(GDVars.iconAnimation[source, 1]^.transp^, GDVars.iconAnimation[destination, 1]^.transp^, cnt);
    end;
    if rebuild <> 0 then
      with GDVars.curChar^ do begin
        for i := 0 to 15 do begin
          grid1[i] := i;
          grid2[i] := i;
        end;
        for i := 1 to 6 do begin
          grid2[GDConsts.defIconCol[i]] := cgIconSizeColors[i] and $F;
          grid2[GDConsts.defIconCol[i] + 8] := (cgIconSizeColors[i] and $F0) shr 4;
        end;
        Blit.RemapPic(grid1, grid2, 0, False, GDVars.iconAnimation[destination, 0]);
        Blit.RemapPic(grid1, grid2, 0, False, GDVars.iconAnimation[destination, 1]);
      end;
  end;

begin
  if GDVars.curChar^.cgNpc >= C_Npc.NON_PLAYER then begin
    CharHlp.PrintBottomLine(GDVars.curChar^.name + ' cannot be changed.');
    Exit;
  end;
  Border.DrawWindowFrame;
  CbtMap.SetCombatPalette;
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with GDVars.curChar^ do begin
    state := 1;
    iconData := iconColors;
    savedOrder := orderNum;
    orderNum := 12;
    SaveLoad.LoadCharIconAnim(False);
    orderNum := savedOrder;
    savedHead := iconHead;
    savedBody := iconBody;
    savedIcon := cgIconSizeColors[0];
    CopyIconPics(orderNum, 12, 1);
    ShowIconFrames(1, 2);
    TextRend.DisplayString(8, 6, White, Black, 'old');
    TextRend.DisplayString(3, 10, White, Black, 'ready   action');
    TextRend.DisplayString(8, 12, White, Black, 'new');
    TextRend.DisplayString(3, 16, White, Black, 'ready   action');
    repeat
      ShowIconFrames(1, 4);
      sizeName := '';
      if state = 4 then begin
        if cgIconSizeColors[0] = 2 then
          sizeName := 'Small'
        else
          sizeName := 'Large';
      end;
      ch := MenuCore.MenuHorizontal('', sizeName + GDConsts.iconMenus[state], LightMagenta, LightGreen, White, False,
                                    False, escFlag);
      if not escFlag then
        case state of
          1: begin
               retState := 1;
               case ch of
                 'P': state := 2;
                 '1': if GDVars.displayMode = C_Video.VM_CGA then
                        TextRend.PrintAndPause('Sorry, not in CGA', Yellow, Black)
                      else begin
                        state := 3;
                        colorMode := 0;
                        Delete(GDConsts.iconMenus[3], 13, 4);
                        Insert('Hair', GDConsts.iconMenus[3], 13);
                      end;
                 '2': if GDVars.displayMode = C_Video.VM_CGA then
                        TextRend.PrintAndPause('Sorry, not in CGA', Yellow, Black)
                      else begin
                        state := 3;
                        colorMode := 1;
                        Delete(GDConsts.iconMenus[3], 13, 4);
                        Insert('Face', GDConsts.iconMenus[3], 13);
                      end;
                 'S': state := 4;
               end;
             end;
          2: begin
               retState := 2;
               if ch in [C_Keys.NONE, 'E'] then
                 state := 1
               else begin
                 subKey := ch;
                 state := 5;
               end;
             end;
          3: begin
               retState := 3;
               case ch of
                 'W': partIdx := 6;
                 'B': partIdx := 1;
                 'H': partIdx := 4;
                 'F': partIdx := 4;
                 'S': partIdx := 5;
                 'A': partIdx := 2;
                 'L': partIdx := 3;
               else
                 partIdx := 1;
               end;
               if ch in [C_Keys.NONE, 'E'] then
                 state := 1
               else
                 state := 5;
             end;
          4: begin
               case ch of
                 'L': begin cgIconSizeColors[0] := 2; SaveLoad.LoadCharIconAnim(False); end;
                 'S': begin cgIconSizeColors[0] := 1; SaveLoad.LoadCharIconAnim(False); end;
                 'K': begin savedIcon := cgIconSizeColors[0]; state := 1; ch := ' '; end;
                 'E', C_Keys.NONE: begin cgIconSizeColors[0] := savedIcon; state := 1; ch := ' '; end;
               end;
               SaveLoad.LoadCharIconAnim(False);
             end;
          5: case retState of
               2: case subKey of
                    'H':
                      begin
                        case ch of
                          'P': if iconHead > 0 then
                                 Dec(iconHead)
                               else
                                 iconHead := 13;
                          'N': if iconHead < 13 then
                                 Inc(iconHead)
                               else
                                 iconHead := 0;
                          'K': begin
                                 with GDVars.curChar^ do
                                   savedHead := iconHead;
                                 state := retState;
                                 ch := ' ';
                               end;
                          'E', C_Keys.NONE: begin
                                     iconHead := savedHead;
                                     state := retState;
                                     ch := ' ';
                                   end;
                        end;
                        SaveLoad.LoadCharIconAnim(False);
                      end;
                    'W':
                      begin
                        case ch of
                          'P': if iconBody > 0 then
                                 Dec(iconBody)
                               else
                                 iconBody := 31;
                          'N': if iconBody < 31 then
                                 Inc(iconBody)
                               else
                                 iconBody := 0;
                          'K': begin
                                 with GDVars.curChar^ do
                                   savedBody := iconBody;
                                 state := retState;
                                 ch := ' ';
                               end;
                          'E', C_Keys.NONE: begin
                                     iconBody := savedBody;
                                     state := retState;
                                     ch := ' ';
                                   end;
                        end;
                        SaveLoad.LoadCharIconAnim(False);
                      end;
                  end;
               3: begin
                    sizeVal := cgIconSizeColors[partIdx] and $F;
                    colVal := (cgIconSizeColors[partIdx] and $F0) shr 4;
                    case ch of
                      'N': begin
                             if colorMode <> 0 then
                               colVal := (colVal + 1) mod 16
                             else
                               sizeVal := (sizeVal + 1) mod 16;
                             cgIconSizeColors[partIdx] := (colVal shl 4) + sizeVal;
                           end;
                      'P': begin
                             if colorMode <> 0 then
                               colVal := (colVal - 1) and $F
                             else
                               sizeVal := (sizeVal - 1) and $F;
                             cgIconSizeColors[partIdx] := (colVal shl 4) + sizeVal;
                           end;
                      'K': begin
                             iconData := iconColors;
                             state := retState;
                             ch := ' ';
                           end;
                      'E', C_Keys.NONE: begin
                                 iconColors := iconData;
                                 state := retState;
                                 ch := ' ';
                               end;
                    end;
                  end;
             end;
        end;
      CopyIconPics(orderNum, 12, 1);
    until (retState = 1) and (ch in [C_Keys.NONE, 'E']);
    iconHead := savedHead;
    iconBody := savedBody;
    cgIconSizeColors[0] := savedIcon;
    iconColors := iconData;
    CopyIconPics(orderNum, 12, 1);
    CopyIconPics(12, orderNum, 0);
    end;
    MenuCore.ClearBottomLine;
    MapTiles.freeIconAnim(12);
    ch := MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White);
  until ch = 'Y';
  CbtMap.SetNoncombatPalette;
end;

function ConHpBonus(cr: Types.PWork): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
begin
  bonus := 0;
  with cr^ do
    for cls := 0 to 7 do
      if lvl[cls] > 0 then
        if Byte(cr^.lvl[cls]) < GDConsts.maxClassLevels[cls] then begin
          Inc(bonus, GDConsts.conBonusTbl[stat[C_Stat.CONSTITUTION].current]);
          if (charClass = CharGen.CLASS_FIGHTER) or (charClass = C_Class.PALADIN) or
              (charClass = C_Class.RANGER) then
            case stat[C_Stat.CONSTITUTION].current of
              17: Inc(bonus);
              18: Inc(bonus, 2);
              19, 20: Inc(bonus, 3);
              21..23: Inc(bonus, 4);
              24, 25: Inc(bonus, 5);
            end;
          if (cls = C_Class.RANGER_LEVEL) and (lvl[cls] = 1) then
            bonus := bonus * 2;
        end;
  ConHpBonus := bonus;
end;

{ Works out the lowest maximum hit points a character may have: one per level in each class, plus 1 for a ranger or a
  monk, plus the Constitution bonus, divided by the class count; 1 when a negative bonus would leave too little.
  @param(cr The character.)
  @returns(The lowest maximum.) }
function HpMinimum(cr: Types.PWork): Byte;
var
  clsCount: Byte;
  conB: ShortInt;
  sum: Byte;
  cls: ShortInt;
begin
  with cr^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if lvl[cls] > 0 then begin
        Inc(sum, lvl[cls]);
        Inc(clsCount);
        case Char(cls) of
          #4: Inc(sum);
          #7: Inc(sum);
        end;
      end;
  end;
  conB := CharGen.ConHpBonus(cr);
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1;
  end else
    sum := (sum + conB) div clsCount;
  HpMinimum := sum;
end;

{ Return the highest maximum hit points a character's levels allow: for each class below its bonus level cap, its hit
  die plus the constitution adjustment (ClassConAdj) for each level, one more level for a ranger or monk; at or above
  the cap, a fixed figure from the levels over it. The sum is divided by the number of classes. Note: a class at or
  above its cap replaces the sum so far.
  @param(cr The character.)
  @returns(The highest maximum.) }
function HpMaximum(cr: Types.PWork): Byte;
var
  clsCount: Byte;
  sum: Byte;
  conAdj: ShortInt;
  cls: ShortInt;
  overCap: Byte;
begin
  with cr^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if lvl[cls] > 0 then begin
        conAdj := CharGen.ClassConAdj(cls);
        if Byte(lvl[cls]) < GDConsts.maxClassLevels[cls] then begin
          Inc(clsCount);
          case Char(cls) of
            #0: Inc(sum, (conAdj + 8) * lvl[cls]);
            #1: Inc(sum, (conAdj + 8) * lvl[cls]);
            #2: Inc(sum, (conAdj + 10) * lvl[cls]);
            #3: Inc(sum, (conAdj + 10) * lvl[cls]);
            #4: Inc(sum, (conAdj + 8) * (lvl[cls] + 1));
            #5: Inc(sum, (conAdj + 4) * lvl[cls]);
            #6: Inc(sum, (conAdj + 6) * lvl[cls]);
            #7: Inc(sum, (conAdj + 4) * (lvl[cls] + 1));
          end;
        end else begin
          Inc(clsCount);
          overCap := lvl[cls] - GDConsts.maxClassLevels[cls] + 1;
          case Char(cls) of
            #0: sum := overCap * 2 + 72;
            #1: sum := 112;
            #2, #3: sum := overCap * 3 + 90;
            #4: sum := overCap * 2 + 88;
            #5: sum := overCap + 44;
            #6: sum := overCap * 2 + 60;
            #7: sum := 72;
          end;
        end;
      end;
  end;
  sum := sum div clsCount;
  HpMaximum := sum;
end;

{ Roll the hit dice of each of a character's classes in mask: below its bonus level cap, the class's dice twice keeping
  the higher (one die past level 1); at or above it, a fixed figure. Note: the fixed figure replaces the sum so far.
  @param(cr The character.)
  @param(mask Class bits of the classes to roll for.)
  @returns(The hit points rolled.) }
function RollFirstLevelHp(cr: Types.PWork; mask: Byte): Byte;
var
  roll1: Byte;
  roll2: Byte;
  sum: Byte;
  diceCount: Byte;
  cls: ShortInt;
begin
  sum := 0;
  for cls := 0 to 7 do
    if cr^.lvl[cls] > 0 then
      if GDConsts.classBits[cls] and mask > 0 then
        if Byte(cr^.lvl[cls]) < GDConsts.maxClassLevels[cls] then begin
          diceCount := GDConsts.hpDice[cls];
          if cr^.lvl[cls] > 1 then
            diceCount := 1;
          roll1 := FxEngine.RollDice(diceCount, GDConsts.hpSides[cls]);
          roll2 := FxEngine.RollDice(diceCount, GDConsts.hpSides[cls]);
          if roll2 > roll1 then
            roll1 := roll2;
          Inc(sum, roll1);
        end else
          case Char(cls) of
            #2, #3: sum := 3;
            #4, #0, #6: sum := 2;
            #5: sum := 1;
          end;
  RollFirstLevelHp := sum;
end;

{ Take gp gold pieces' worth of coins from a character: working in units of 1/200 gp, take each coin type in turn from
  the smallest, one coin more than needed, then give back the overshoot from platinum down.
  @param(gp The amount in gold pieces.)
  @param(cr The character paying.) }
procedure TakeCoins(gp: LongInt; cr: Types.PWork);
var
  amt: Word;
  i: ShortInt;
begin
  gp := gp * 200;
  i := 0;
  with cr^ do begin
    while gp > 0 do begin
      amt := gp div GDConsts.coinValues[i] + 1;
      if coinsA[i] < amt then
        amt := coinsA[i];
      Dec(gp, amt * GDConsts.coinValues[i]);
      Dec(coinsA[i], amt);
      i := Succ(i);
    end;
    if gp < 0 then begin
      gp := Abs(gp);
      i := 4;
      while (gp > 0) and (i in [0..4]) do begin
        amt := gp div GDConsts.coinValues[i];
        Dec(gp, amt * GDConsts.coinValues[i]);
        Inc(coinsA[i], amt);
        i := Pred(i);
      end;
    end;
  end;
end;

procedure TrainingMenu;
var
  { the class is at its level limit }
  atLimit: Boolean;
  { the experience the trainee is held at: one below the level after the next }
  bestXp: LongInt;
  { a level's experience }
  xpTmp: LongInt;
  { the classes that can train now }
  maskA: Byte;
  { the character's classes }
  maskB: Byte;
  { the classes trained: those of maskA this trainer teaches, or all of them in sting mode }
  trainHere: Byte;
  { the character's classes, counted }
  classCount: Byte;
  { the hit points rolled }
  hpTotal: Integer;
  { the hit points gained per class }
  avgHp: Integer;
  { the damage carried over: the maximum less hpCur }
  hpDelta: Byte;
  { class index }
  i: ShortInt;
  { the constitution hit-point bonus }
  conBonusV: Integer;
  { display row }
  row: Byte;
  { the magic-user level before training }
  oldLvl5: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  oldLvl4: ShortInt;
  { the class's level }
  curLvl: ShortInt;
  { the spell picked }
  selResult: Byte;
  sentinel: Integer;
  selIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  trainedClass: Byte;
  { classes this trainer teaches }
  trainableHere: Byte;
  { the most experience a trainable class's next level needs }
  bestXp2: LongInt;
  { the class that needs it }
  bestClass: ShortInt;
  payer: Types.PWork;
  trainee: Types.PWork;
begin
  if (GDVars.curChar^.cgStatus <> 0) and (GDVars.stingMode = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow, Black);
    Exit;
  end;
  trainee := GDVars.curChar;
  if (GDVars.stingMode = 0) and (not GDVars.isAutoTraining) and (GDVars.victoryStartFlag = 0) then begin
    while ViewChar.CreatureCoinValueInGold(GDVars.curChar) < 1000 do begin
      TextRend.PrintAndPause('Training costs 1000 gp.', Yellow, Black);
      if not CharGen.SelectCharacter('Who pays 1000 gp ') then Exit;
    end;
  end;
  payer := GDVars.curChar;
  GDVars.curChar := trainee;

  maskA := 0;
  maskB := 0;
  bestXp := 0;
  trainableHere := Lo(GDVars.gbvmZone1Ptr^[C_Gbvm.TRAIN_MASK]);

  with GDVars.curChar^ do begin
    bestXp := 0;
    for i := 0 to 7 do
      if lvl[i] > 0 then begin
        Inc(maskB, GDConsts.classBits[i]);
        atLimit := False;
        curLvl := lvl[i];
        atLimit := ClassCal.AtClassLevelCap(i, curLvl);
        case Char(race) of
          #1: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 9)
                  or ((curLvl = 8) and (stat[C_Stat.STRENGTH].current = 17))
                  or ((curLvl = 7) and (stat[C_Stat.STRENGTH].current < 17)) then atLimit := True;
          #2: begin
               if i = C_Class.FIGHTER_LEVEL then
                 if (curLvl = 7)
                    or ((curLvl = 6) and (stat[C_Stat.STRENGTH].current = 17))
                    or ((curLvl = 5) and (stat[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE_LEVEL then
                 if (curLvl = 11)
                    or ((curLvl = 9) and (stat[C_Stat.INTELLIGENCE].current < 17))
                    or ((curLvl = 10) and (stat[C_Stat.INTELLIGENCE].current = 17)) then atLimit := True;
             end;
          #3: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 6)
                  or ((curLvl = 5) and (stat[C_Stat.STRENGTH].current < 18)) then atLimit := True;
          #4: if (i = C_Class.CLERIC_LEVEL) and (curLvl = 5) then atLimit := True
             else begin
               if (i = C_Class.FIGHTER_LEVEL) or (i = C_Class.RANGER_LEVEL) then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stat[C_Stat.STRENGTH].current = 17))
                    or ((curLvl = 6) and (stat[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE_LEVEL then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stat[C_Stat.INTELLIGENCE].current = 17))
                    or ((curLvl = 6) and (stat[C_Stat.INTELLIGENCE].current < 17)) then atLimit := True;
             end;
          #5: if i = C_Class.FIGHTER_LEVEL then
               if (curLvl = 6)
                  or ((curLvl = 5) and (stat[C_Stat.STRENGTH].current = 17))
                  or ((curLvl = 4) and (stat[C_Stat.STRENGTH].current < 17)) then atLimit := True;
        end;
        if not atLimit then
          if (GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)] <= exp) or (GDVars.stingMode <> 0) then
            if GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)] > 0 then begin
              if GDVars.stingMode <> 0 then
                if GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)] > 0 then
                  if GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)] > exp then
                    exp := GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)];
              Inc(maskA, GDConsts.classBits[i]);
              xpTmp := GDConsts.experienceSpellsClass[i].xpNeeded[Succ(Succ(curLvl))];
              if (xpTmp > 0) and (exp >= xpTmp) and (xpTmp > bestXp) then
                bestXp := xpTmp - 1;
            end;
      end;

    if not GDVars.isAutoTraining then begin
      bestXp2 := 0;
      xpTmp := 0;
      for i := 0 to 7 do
        if (GDConsts.classBits[i] and maskA) <> 0 then
          if GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)] > bestXp2 then begin
            bestXp2 := GDConsts.experienceSpellsClass[i].xpNeeded[Succ(curLvl)];
            bestClass := i;
          end;
      if bestXp2 > 0 then begin
        maskA := GDConsts.classBits[bestClass];
        xpTmp := GDConsts.experienceSpellsClass[bestClass].xpNeeded[Succ(Succ(curLvl))];
        if (xpTmp > 0) and (exp >= xpTmp) and (xpTmp > bestXp) then
          bestXp := xpTmp - 1;
      end;
    end;

    if (bestXp > 0) and (not GDVars.isAutoTraining) then
      exp := bestXp;

    if GDVars.stingMode = 0 then begin
      if ((maskB and trainableHere) = 0) and (not GDVars.isAutoTraining) then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow, Black);
        Exit;
      end else if (maskA and trainableHere) = 0 then begin
        GDVars.characterMenuDone := 1;
        if not GDVars.isAutoTraining then
          TextRend.PrintAndPause('Not Enough Experience', Yellow, Black);
        Exit;
      end;
    end;

    if GDVars.stingMode = 0 then trainHere := maskA and trainableHere
    else trainHere := maskA;

    if not GDVars.isAutoTraining then begin
      Border.ClearBox(1, 1, 38, 22);
      row := 4;
      CharHlp.DisplayCreatureName(Pointer(GDVars.curChar), 4, row, Boolean(0));
      TextRend.DisplayString(Length(name) + 4, row, LightGreen, Black, ' will become:');
      for i := 0 to 7 do
        if lvl[i] > 0 then
          if (GDConsts.classBits[i] and trainHere) > 0 then begin
            Inc(row);
            if row = 5 then
              TextRend.DisplayString(6, row, LightGreen, Black,
                            '    a level ' + CharHlp.Uint8Str(lvl[i] + 1) + ' ' + GDConsts.classNames[i])
            else
              TextRend.DisplayString(6, row, LightGreen, Black,
                            'and a level ' + CharHlp.Uint8Str(lvl[i] + 1) + ' ' + GDConsts.classNames[i]);
          end;
      if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then Exit;
      CharHlp.PrintBottomLine('Congratulations...');
      if (GDVars.stingMode = 0) and (GDVars.victoryStartFlag = 0) then
        CharGen.TakeCoins(1000, payer);
    end;

    classCount := 0;
    oldLvl5 := lvl[C_Class.MAGE_LEVEL];
    oldLvl4 := lvl[C_Class.RANGER_LEVEL];
    cgClassMask := 0;
    for i := 0 to 7 do
      if lvl[i] > 0 then begin
        Inc(classCount);
        if (GDConsts.classBits[i] and trainHere) > 0 then begin
          Inc(lvl[i]);
          if drainedLevels > 0 then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;

    ClassCal.RecalcClassStats(Pointer(GDVars.curChar));

    if not GDVars.isAutoTraining then
      if (lvl[C_Class.MAGE_LEVEL] > oldLvl5) or (lvl[C_Class.RANGER_LEVEL] > 8) then begin
        sentinel := -1;
        repeat
          selResult := ViewChar.SpellMenu(4, 4, sentinel, Boolean(selIdx));
        until (selResult > 0) or (selIdx = 0);
        if selResult > 0 then
          clsFlags[selResult] := 1;
      end;

    if GDVars.isAutoTraining then
      case Char(lvl[C_Class.MAGE_LEVEL]) of
        #2: clsFlags[15] := 1;
        #3: begin clsFlags[34] := 1; clsFlags[10] := 1; end;
        #4: clsFlags[31] := 1;
        #5: clsFlags[47] := 1;
      end;

    if cgLevelHighest > cgLevelAtChange then begin
      hpTotal := CharGen.RollFirstLevelHp(GDVars.curChar, trainHere);
      avgHp := hpTotal div classCount;
      if avgHp = 0 then avgHp := 1;
      Inc(cgHpRolled, avgHp);
      conBonusV := CharGen.ConHpBonus(GDVars.curChar);
      avgHp := (hpTotal + conBonusV) div classCount;
      if avgHp < 1 then avgHp := 1;
      hpDelta := clsFlags[0] - hpCur;
      Inc(clsFlags[0], avgHp);
      hpCur := clsFlags[0] - hpDelta;
    end;
  end;
end;

begin
end.
