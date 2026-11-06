{ The camp menus. CampMainMenu is the Camp command's hub (EclVm calls it): Save, View, Magic, Rest, Alter and Fix. Magic
  casts, memorizes and scribes spells, lists the party's spell effects and rests for the spells being prepared; Alter
  reorders the party, drops a member, sets the game speed, changes a character's icon and sets the difficulty level; Fix
  rests the party and heals it with its clerics' cure spells, curing disease when a member knows Cure Disease.
  Memorizing and scribing mark a spell as pending by setting C_Spell.PENDING_FLAG in its id, and Rest completes the
  pending spells as the party rests; each menu offers to keep or discard the marks. NoncombatCastMenu is also Explore's
  Cast command, and DevMenu calls SortMemorizedSpells. Camp owns no storage: its state is in GDConsts, GDVars and GBVM
  bank 0. }
{$O+,F+,S+}
{$A+}
unit Camp;

interface

{ Run the camp menu: set the camp interface state, clear the rest clock, show the mission's end or the quest items
  found, discard the party's pending scribings and run the camp commands until Exit or an interrupted rest. On leaving,
  reload the saved picture if it is a PIC animation, discard the pending scribings again and restore the interface
  state.
  @param(interrupted Set when the script interrupts a rest.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Runs the noncombat Cast menu for the current character until no spell is picked, saying 'has no spells memorized' when
  the list is empty. Clears the remembered cast target on entry, and redraws the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;

implementation

uses Crt, GDConsts, GDVars, C_Keys, C_Effect, C_Ifc, C_Menu, C_Msg, C_Npc, C_Spell, GameTime, Magic,
  CharGen, ViewChar, MenuCore, TextRend, CharHlp, Border, FxEngine, GameIo, SaveLoad, Portrait, Types, C_Status, C_Gbvm;

const
  { GBVM zone 0: set when the module's mission is complete }
  MISSION_COMPLETE = $4D02;
  { CanDoSpellActivity's activities }
  ACT_CAST = 1;
  ACT_MEMORIZE = 2;
  ACT_SCRIBE = 3;

  { the spell id of Cure Disease }
  SPELL_CURE_DISEASE = 39;

  { as Display names it; also in GDConsts.diseaseEffects }
  EFF_HOT_FIRE_SHIELD = 50;

  { GDConsts.difficultyMenu's levels, in its order }
  DIFFICULTY_NOVICE = 0;
  DIFFICULTY_SQUIRE = 1;
  DIFFICULTY_VETERAN = 2;
  DIFFICULTY_ADEPT = 3;
  DIFFICULTY_CHAMPION = 4;

  { GDVars.gameDelay's slowest setting }
  MAX_GAME_DELAY = 9;

{ Works out a character's spell preparation time: 15 minutes per level of each pending spell, plus four hours when any
  spell is pending, or six when any pending spell is level 3 or higher. Pending memorizing and pending scribing
  (readable items only) both count. Stores the base hours (0, 4 or 6) in the character's record.
  @param(cr The character.)
  @returns(The preparation time in minutes.) }
function CampSpellPrepTime(cr: Types.PWork): Word;
var
  maxMem: Byte;
  maxScr: Byte;
  cntMem: Byte;
  cntScr: Byte;
  p: Types.PItemRec;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      lvl := GDConsts.spellTable[cr^.memorizedSpells[i] and C_Spell.ID_MASK].levelS;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := cr^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        if p^.spells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellTable[p^.spells[i] and C_Spell.ID_MASK].levelS;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then
    base := 4;
  if (maxMem > 2) or (maxScr > 2) then
    base := 6;
  cr^.prepBase := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Removes every pending memorize request of a character, zeroing the slot, and clears its preparation hours.
  @param(cr The character.) }
procedure ResetMemorize(cr: Types.PWork);
var
  i: Byte;
begin
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then
      cr^.memorizedSpells[i] := 0;
  cr^.prepBase := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(cr The character.) }
procedure ResetScribe(cr: Types.PWork);
var
  i: Byte;
  p: Types.PItemRec;
begin
  p := cr^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        p^.spells[i] := p^.spells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Clears every member's scribing marks. }
procedure ResetPartySpellActivities;
var
  character: Types.PWork;
begin
  character := GDVars.creatureList;
  while character <> nil do begin
    Camp.ResetScribe(character);
    character := character^.next;
  end;
end;

{ Return the current character's free spell slots of one level and spell class: its slots less the spells of that level
  and class it has memorized or pending. The parameters are ShortInt like the spell table's fields they are compared
  with.
  @param(spellLevel Spell level, 1..5.)
  @param(spellClass Spell class: the cleric, druid or magic-user list.)
  @returns(The free slots, 0 when the memorized spells fill them.) }
function SpellSlotsRemaining(spellLevel, spellClass: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
begin
  count := 0;
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
    if GDVars.curChar^.memorizedSpells[i] <> 0 then
      if (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].levelS = spellLevel) and
          (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].castClassS = spellClass) then
        Inc(count);
  if GDVars.curChar^.slots[spellClass, spellLevel] < count then
    SpellSlotsRemaining := 0
  else
    SpellSlotsRemaining := GDVars.curChar^.slots[spellClass, spellLevel] - count;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  message: Types.TStr40;
begin
  message := '';
  if (activity = Camp.ACT_CAST) and (GDVars.gbvmZone0Ptr^[C_Gbvm.ANTI_MAGIC] > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.enabled = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACT_CAST: message := message + 'cast any spells';
      Camp.ACT_MEMORIZE: message := message + 'memorize spells';
      Camp.ACT_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.curChar, message, C_Msg.MESSAGE_ROW, True);
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer;
  notEmpty: Boolean;
  needsRedraw: Boolean;
  { CastSpell's var result, unread }
  castSelected: Boolean;
  spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.castTargetPtr := nil;
  GDVars.horizChoice := 1;
  if Camp.CanDoSpellActivity(Camp.ACT_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> 0 then begin
        needsRedraw := True;
        Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        Magic.CastSpell(spellId, False, True, castSelected);
      end else begin
        if notEmpty then
          needsRedraw := True
        else
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no spells memorized', C_Msg.MESSAGE_ROW, True);
      end;
    until spellId = 0;
  end;
  if needsRedraw then
    CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's remaining spell slots for each class (cleric, druid, magic-user) and level 1..5. A level
  with no allowance is blank; a full level shows zero.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  slotStr: packed array[1..5, 0..2] of String[2];
  canDo: packed array[0..2] of Byte;
  typ: ShortInt;
  lvl: ShortInt;
  col: Byte;
  row: Byte;
  any: Boolean;
begin
  any := False;
  for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do begin
    canDo[typ] := 0;
    for lvl := 1 to SizeOf(slotStr) div SizeOf(slotStr[1]) do begin
      slotStr[lvl, typ] := CharHlp.Uint8Str(Camp.SpellSlotsRemaining(lvl, typ));
      if GDVars.curChar^.slots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'can memorize:', C_Msg.MESSAGE_ROW, False);
    row := 3;
    for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do begin
      if canDo[typ] <> 0 then begin
        case typ of
          C_Spell.CLERIC_LIST: s := '    Cleric Spells:';
          C_Spell.DRUID_LIST: s := '     Druid Spells:';
          C_Spell.MAGIC_USER_LIST: s := 'Magic-User Spells:';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, Black, s);
        col := 19;
        for lvl := 1 to SizeOf(slotStr) div SizeOf(slotStr[1]) do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, Black, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
    end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest time and redraws the
  position and time.
  @param(interrupted Receives True when the rest was interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PWork;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.creatureList;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.next;
  end;
  GDVars.restTime[3] := maxPrepMinutes div 60;
  GDVars.restTime[2] := (maxPrepMinutes - 60 * GDVars.restTime[3]) div 10;
  GDVars.restTime[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(True);
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  CharHlp.PrintPositionAndTime;
end;

procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 2 do
    for j := i to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
      if (GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) > (GDVars.curChar^.memorizedSpells[j] and
                                                           C_Spell.ID_MASK) then begin
        tmp := GDVars.curChar^.memorizedSpells[i];
        GDVars.curChar^.memorizedSpells[i] := GDVars.curChar^.memorizedSpells[j];
        GDVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Memorize: if spells are pending, offer to keep them, which ends the menu, or discard them. Then mark each spell picked
  from the spellbook as pending while a slot of its level and class is free, and offer the keep-or-discard choice again
  if the spellbook was shown. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_MEMORIZE) then begin
    GDConsts.isMemorizeActive := True;
    done := False;
    idx := -1;
    GDVars.horizChoice := 1;
    spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot memorize any spells', C_Msg.MESSAGE_ROW, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = 0 then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].levelS, GDConsts.spellTable[spellId].castClassS) >
          0 then begin
          i := 0;
          while GDVars.curChar^.memorizedSpells[i] <> 0 do
            Inc(i);
          GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Scribe: if scribings are pending, offer to keep them, which ends the menu, or discard them. Then mark each spell
  picked from the character's scrolls as pending on its scroll, unless the character knows it, is scribing it already or
  has no slot of its level and class, and offer the keep-or-discard choice again if the scrolls were shown. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  i: Byte;
  idx: Integer;
  p: Types.PItemRec;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = 0 then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no copyable scrolls', C_Msg.MESSAGE_ROW, True)
        else
          redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.known[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scribing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GDVars.curChar^.slots[GDConsts.spellTable[spellId].castClassS, GDConsts.spellTable[spellId].levelS] >
                0 then begin
              p := GDVars.curChar^.itemsAddr;
              while (p <> nil) and (found = False) do begin
                if Magic.ItemReadable(p) then begin
                  i := 1;
                  repeat
                    if p^.spells[i] = spellId then begin
                      p^.spells[i] := p^.spells[i] or C_Spell.PENDING_FLAG;
                      found := True;
                    end;
                    Inc(i);
                  until (i > SizeOf(p^.spells)) or found;
                end;
                p := p^.next;
              end;
            end else
              CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists the spell effects on each party member under the member's name. Spell effects show the name of the first spell
  (1..56) producing them, or 'Funky--<id>' when none does; other visible effects have fixed labels, and the rest are
  hidden. A member with none shows '<No Spell Effects>'. }
procedure CampDisplayMenu;
var
  effect: Types.PEffectRec;
  listHead: Types.PItemRec;
  listTail: Types.PItemRec;
  character: Types.PWork;
  effectId: Byte;
  spellIndex: Byte;
  { effects listed for this character }
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  effectNameFound: Boolean;
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: Types.TStr40;
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends a list node with the given text; isTitle marks a character-name heading. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TItemNode));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TItemNode));
  listTail := listHead;
  listTail^.inUse := 0;
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.creatureList;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effects;
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      case effectId of
        1, 2, 5, 8..12, 14, 16, 17, 19..25, 28, 29, 32..34,
        36..39, 41, 42, 45, 46, 49, 51..53:
          begin
            spellIndex := 1;
            effectNameFound := False;
            while (spellIndex <= 56) and (effectNameFound = False) do
              if GDConsts.spellTable[spellIndex].effectId = effectId then begin
                effectName := GDConsts.spellNames[spellIndex];
                effectNameFound := True;
              end else
                Inc(spellIndex);
            if effectNameFound = False then
              effectName := 'Funky--' + CharHlp.Uint8Str(effectId);
          end;
        4: effectName := 'Dispel Evil';
        7: effectName := 'Faerie Fire';
        27: effectName := 'Fumbling';
        31: effectName := 'Helpless';
        35: effectName := 'Confused';
        44: effectName := 'Cause Disease';
        50: effectName := 'Hot Fire Shield';
        54: effectName := 'Cold Fire Shield';
        55: effectName := 'Poisoned';
        59: effectName := 'Regenerating';
        61: effectName := 'Fire Resistance';
        63: effectName := 'Minor Globe of Invulnerability';
        68: effectName := 'enfeebled';
        69: effectName := 'invisible to animals';
        71: effectName := 'Invisible';
        72: effectName := 'Camouflaged';
        73: effectName := 'protected from dragon breath';
        77: effectName := 'berserk';
        89: effectName := 'Displaced';
      else
        displayEffect := False;
      end;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then
      AddToList(False, ' <No Spell Effects>');
    AddToList(False, ' ');
    character := character^.next;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame;
  choice := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, Types.PItemRec(listHead), True,
                                  viewNeedsRedraw, menuIndex, Types.PItemRec(listTail));
  MenuCore.FreeStringList(Types.PItemRec(listHead));
  CharHlp.DisplayNoncombatInterface;
end;

{ Magic: Cast, Memorize, Scribe, Display, Rest and Exit.
  @param(interrupted Set when a rest is interrupted, which ends the menu.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  c: Char;
  ext: Boolean;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    GDVars.canClickParty := 1;
    c := MenuCore.MenuHorizontal('', GDConsts.magicMenu, LightMagenta, LightGreen, White, True, True, ext);
    GDVars.canClickParty := 0;
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PWork;
  p: Types.PWork;
  tmp: Types.PWork;
begin
  p := GDVars.creatureList;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.next <> nil do
      p := p^.next;
  end else
    while p^.next <> GDVars.curChar do begin
      prev := p;
      p := p^.next;
    end;
  tmp := GDVars.curChar^.next;
  if GDVars.creatureList = GDVars.curChar then begin
    if tmp <> nil then
      GDVars.creatureList := tmp;
    p^.next := GDVars.curChar;
    GDVars.curChar^.next := nil;
  end else begin
    p^.next := tmp;
    GDVars.curChar^.next := p;
    if (p = GDVars.creatureList) or (prev = nil) then
      GDVars.creatureList := GDVars.curChar
    else
      prev^.next := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PWork;
  successor: Types.PWork;
begin
  predecessor := GDVars.creatureList;
  if predecessor <> GDVars.curChar then
    while predecessor^.next <> GDVars.curChar do
      predecessor := predecessor^.next;
  successor := GDVars.curChar^.next;
  if successor = nil then begin
    GDVars.curChar^.next := GDVars.creatureList;
    GDVars.creatureList := GDVars.curChar;
    predecessor^.next := successor;
  end else begin
    GDVars.curChar^.next := successor^.next;
    if GDVars.creatureList = GDVars.curChar then
      GDVars.creatureList := successor;
    if predecessor <> GDVars.curChar then
      predecessor^.next := successor;
    successor^.next := GDVars.curChar;
  end;
end;

{ Return a character's place in the party.
  @param(ch Character to look for.)
  @returns(Its place, from 1, or 0 if it is not in the party.) }
function PartyPosition(ch: Types.PWork): Byte;
var
  p: Types.PWork;
  position: Byte;
begin
  position := 1;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p = ch then begin
      PartyPosition := position;
      Exit;
    end;
    Inc(position);
    p := p^.next;
  end;
  PartyPosition := 0;
end;

{ Move the current character up or down the party to a character's place.
  @param(ch Character whose place the current character takes.) }
procedure OrderMoveTo(ch: Types.PWork);
var
  currentPos: Byte;
  targetPos: Byte;
begin
  targetPos := Camp.PartyPosition(ch);
  if targetPos = 0 then Exit;
  repeat
    currentPos := Camp.PartyPosition(GDVars.curChar);
    if (currentPos = 0) or (currentPos = targetPos) then Exit;
    if currentPos > targetPos then
      Camp.OrderMoveUp
    else
      Camp.OrderMoveDown;
  until False;
end;

{ Party Order: pick a character (Select), then move it with the up and down arrows (Place); Return, P or S switches
  between the two. When the menu returns with GDVars.orderChar changed (a click on the party roster), the current
  character moves to that character's place. }
procedure PartyOrderMenu;
var
  { GDConsts.orderMenus' index }
  selected: ShortInt;
  isExtendedKey: Boolean;
  choice: Char;
  savedCurChar: Types.PWork;
begin
  selected := 0;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    GDVars.canClickParty := 1;
    GDVars.orderState := selected;
    GDVars.orderChar := GDVars.curChar;
    savedCurChar := GDVars.curChar;
    choice := MenuCore.MenuHorizontal('Party Order: ', GDConsts.orderMenus[selected], LightMagenta, LightGreen, White,
                                      True, True, isExtendedKey);
    GDVars.canClickParty := 0;
    if (savedCurChar = GDVars.curChar) and (GDVars.orderChar <> GDVars.curChar) then begin
      Camp.OrderMoveTo(GDVars.orderChar);
      CharHlp.DisplayParty(GDVars.curChar);
      selected := 0;
    end;
    if isExtendedKey then begin
      if selected = 0 then begin
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayParty(GDVars.curChar);
      end else begin
        { the arrow keys, not a click }
        if not GDVars.isMouseClick then
          case choice of
            C_Keys.UP: Camp.OrderMoveUp;
            C_Keys.DOWN: Camp.OrderMoveDown;
          end;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else
      if choice in [C_Keys.ENTER, 'P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has been selected', C_Msg.MESSAGE_ROW, False)
        else
          CharHlp.ClearMessageWindow;
      end;
  end;
  GDVars.orderState := 0;
end;

{ Drops the current character from the party after confirmation, with a farewell that depends on whether it is enabled,
  and redraws the party. For the last party member it offers to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.next = nil) and (GDVars.curChar = GDVars.creatureList) then begin
    if MenuCore.YesNoMenuClear('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'will be gone', C_Msg.MESSAGE_ROW, False);
  if MenuCore.YesNoMenuClear('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'bids you farewell', C_Msg.MESSAGE_ROW, True)
    else
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'is dumped in a ditch', C_Msg.MESSAGE_ROW, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayParty(GDVars.curChar);
  end else
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'Breathes A sigh of relief', C_Msg.MESSAGE_ROW, True);
end;

{ Level: pick the difficulty from GDConsts.difficultyMenu, the current level preselected. }
procedure CampDifficultyMenu;
var
  difficulty: Byte;
begin
  difficulty := GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY];
  GDVars.horizChoice := difficulty + 1;
  GDVars.menuChecksum := C_Menu.KEEP_MENU_CHOICE;
  GDVars.canClickParty := 1;
  GDVars.menuKey := MenuCore.MenuHorizontal('', GDConsts.difficultyMenu, LightMagenta, LightGreen, White, False, True,
                                              GDVars.extFlag);
  GDVars.canClickParty := 0;
  if GDVars.extFlag then begin
    CharHlp.PrintMiscInfo(GDVars.curChar, False);
    ViewChar.SelectPrevNextChar(GDVars.menuKey);
    CharHlp.PrintMiscInfo(GDVars.curChar, True);
  end else
    case GDVars.menuKey of
      'N': difficulty := Camp.DIFFICULTY_NOVICE;
      'S': difficulty := Camp.DIFFICULTY_SQUIRE;
      'V': difficulty := Camp.DIFFICULTY_VETERAN;
      'A': difficulty := Camp.DIFFICULTY_ADEPT;
      'C': difficulty := Camp.DIFFICULTY_CHAMPION;
    end;
  GDVars.gbvmZone0Ptr^[C_Gbvm.DIFFICULTY] := difficulty;
end;

{ Adjusts the game delay, 0 (fastest) to 9 (slowest). Faster and Slower are offered only while the delay can move that
  way; the up arrow slows the game and the down arrow speeds it up. }
procedure CampSpeedMenu;
var
  choice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  repeat
    TextRend.DisplayString(1, 18, LightGreen, Black,
                           'Game Speed = ' + CharHlp.Uint8Str(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuText := '';
    if GDVars.gameDelay > 0 then
      menuText := menuText + ' Faster';
    if GDVars.gameDelay < Camp.MAX_GAME_DELAY then
      menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    choice := MenuCore.MenuHorizontal('Game Speed:', menuText, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then begin
      case choice of
        C_Keys.DOWN: if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        C_Keys.UP: if GDVars.gameDelay < Camp.MAX_GAME_DELAY then Inc(GDVars.gameDelay);
      end;
    end else
      case choice of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until choice in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Alter: Order, Drop, Speed, Icon (not for an NPC), Level and Exit. }
procedure CampAlterMenu;
var
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  toggleChoice: Char;
  isExtendedKey: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuText: Types.TStr40;
begin
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    GDVars.canClickParty := 1;
    choice := MenuCore.MenuHorizontal('', GDConsts.alterMenu, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    GDVars.canClickParty := 0;
    if isExtendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case choice of
        'O': Camp.PartyOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'L': Camp.CampDifficultyMenu;
        'I': if GDVars.curChar^.npc > C_Npc.MORALE_MASK then begin
               CharHlp.PrintBottomLine('Cannot change NPC Icon');
               TextRend.PauseOnly;
             end else begin
               CharGen.CustomizePortrait;
               CharHlp.DisplayNoncombatInterface;
             end;
      end;
  end;
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ Fix: rest and heal, at most four times, until the party has no lost hit points and no pending spells, or a rest is
  interrupted; with nothing to fix it says so and returns. A rest lasts as long as ComputeFixTime sets: the longest time
  a conscious member needs to memorize its cure spells again (4 or 6 hours, and 15, 60 or 75 minutes a slot), scaled
  down when the party's lost hit points are fewer than timeMin, plus the pending spells' and Cure Disease's time; with
  no cure slots and nothing pending, a day. After it the party heals by a roll of each memorized cure spell and of each
  cure spell slot, Cure Disease cures the party when a conscious member knows it, and the pending spells are completed.
  The rest clock is restored after each rest that is not interrupted. Note: ComputeFixTime's timeMin is not initialized.
  Note: the Nothing-to-fix test calls PartySpellPrepTime only when no hit points are lost (short-circuit evaluation), so
  with hit points lost the pending time is stale, or unset on the first try.
  @param(interrupted Set when a rest is interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);
var
  { hit points available to heal }
  healPool: Word;
  { The cure-spell counters hold the party's cleric slots at the three cure spells' levels (1, 4 and 5): its capacity,
    which ClassCal sets from level and Wisdom, not its free slots. }
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  savedRestTime: Types.TClock;
  { PartySpellPrepTime's result }
  prepTime: Word;
  tries: Byte;

  { Return whether a character's status is okay. }
  function CanCast(character: Types.PWork): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Adds a roll for each cure spell memorized by a conscious member to the healing pool. }
  procedure RollMemorizedCures;
  var
    rolledHealing: Word;
    spellIndex: Byte;
    character: Types.PWork;
  begin
    rolledHealing := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      if CanCast(character) then
        for spellIndex := 0 to C_Spell.MEMORIZED_SPELL_SLOTS - 1 do
          case character^.memorizedSpells[spellIndex] of
            C_Spell.CURE_LIGHT_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(1, 8));
            C_Spell.CURE_SERIOUS_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
            C_Spell.CURE_CRITICAL_WOUNDS: Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
          end;
      character := character^.next;
    end;
    Inc(healPool, rolledHealing);
  end;

  { Adds a cure roll for each cleric slot of levels 1, 4 and 5 counted by ComputeFixTime. }
  procedure RollCureSlots;
  var
    rolledHealing: Word;
    rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do
      Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do
      Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do
      Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { If a conscious member knows Cure Disease, remove every member's disease effects. }
  procedure CureStatuses;
  var
    ch: Types.PWork;
    { Unused in this version; see the other implementations of this routine. }
    cureMinutes: Word;
    { Unused in this version; see the other implementations of this routine. }
    hours: Word;
    { Unused in this version; see the other implementations of this routine. }
    removed: Byte;
    found: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    afflicted: Word;
  begin
    ch := GDVars.creatureList;
    found := False;
    while (ch <> nil) and (not found) do begin
      if CanCast(ch) and (ch^.known[Camp.SPELL_CURE_DISEASE] <> 0) then found := True;
      ch := ch^.next;
    end;
    if not found then Exit;
    ch := GDVars.creatureList;
    while ch <> nil do begin
      GDVars.targetCreaturePtr[1] := ch;
      removed := Byte(Magic.RemoveDiseaseEffects);
      ch := ch^.next;
    end;
    GDVars.effectLockFlag := 0;
  end;

  { Return whether a character has the diseased, strength-disease or hot-fire-shield effect. }
  function NeedsCureDisease(ch: Types.PWork): Boolean;
  var
    eff: Types.PEffectRec;
  begin
    NeedsCureDisease := False;
    if CharHlp.HasEffect(ch, C_Effect.DISEASED, eff) then NeedsCureDisease := True;
    if CharHlp.HasEffect(ch, C_Effect.DISEASE_STRENGTH, eff) then NeedsCureDisease := True;
    if CharHlp.HasEffect(ch, Camp.EFF_HOT_FIRE_SHIELD, eff) then NeedsCureDisease := True;
  end;

  { Return Cure Disease's minutes: 45 a sick member, shared among the conscious members who know it. }
  function CureDiseaseTime: Word;
  var
    ch: Types.PWork;
    curers: Byte;
    afflicted: Word;
  begin
    CureDiseaseTime := 0;
    ch := GDVars.creatureList;
    curers := 0;
    while ch <> nil do begin
      if CanCast(ch) and (ch^.known[Camp.SPELL_CURE_DISEASE] <> 0) then Inc(curers);
      ch := ch^.next;
    end;
    if curers = 0 then Exit;
    ch := GDVars.creatureList;
    afflicted := 0;
    while ch <> nil do begin
      if NeedsCureDisease(ch) then Inc(afflicted);
      ch := ch^.next;
    end;
    if afflicted = 0 then Exit;
    if curers >= afflicted then CureDiseaseTime := 45
    else CureDiseaseTime := ((afflicted - 1) div curers + 1) * 45;
  end;

  { Return the hit points the living party has lost. }
  function PartyHitPointsMissing: Word;
  var
    totalDamage: Word;
    character: Types.PWork;
    { Unused in this version; see the other implementations of this routine. }
    maxHitPoints: Word;
    { Unused in this version; see the other implementations of this routine. }
    hitPoints: Word;
  begin
    totalDamage := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      if character^.status <> C_Status.DEAD_STATUS then
        if character^.tpHpMax > character^.hpCur then
          Inc(totalDamage, character^.tpHpMax - character^.hpCur);
      character := character^.next;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Return the pending spells' minutes, 15 a level, of members okay, animated, unconscious or dying; set prepTime. }
  function PartySpellPrepTime: Word;
  var
    character: Types.PWork;
    itemSpellIndex: Byte;
    spellIndex: Byte;
    item: Types.PItemRec;
  begin
    prepTime := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      if character^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                               C_Status.DYING] then begin
        spellIndex := 0;
        while spellIndex <= C_Spell.MEMORIZED_SPELL_SLOTS - 1 do begin
          if character^.memorizedSpells[spellIndex] > C_Spell.ID_MASK then
            Inc(prepTime, GDConsts.spellTable[character^.memorizedSpells[spellIndex] and C_Spell.ID_MASK].levelS * 15);
          Inc(spellIndex);
        end;
        item := character^.itemsAddr;
        while item <> nil do begin
          if Magic.ItemReadable(item) then
            for itemSpellIndex := 1 to SizeOf(item^.spells) do
              if item^.spells[itemSpellIndex] > C_Spell.PENDING_FLAG then
                Inc(prepTime, GDConsts.spellTable[item^.spells[itemSpellIndex] and C_Spell.ID_MASK].levelS * 15);
          item := item^.next;
        end;
      end;
      character := character^.next;
    end;
    PartySpellPrepTime := prepTime;
  end;

  { Set the rest clock for memorizing the cure spells again, scaled by the lost hit points, plus the pending time. }
  procedure ComputeFixTime;
  var
    timeMin: Word;
    ch: Types.PWork;
    maxTime: Word;
    lightMinutes: Word;
    seriousMinutes: Word;
    criticalMinutes: Word;
    base: Word;
    { Unused in this version; see the other implementations of this routine. }
    reductionRatio: Word;
  begin
    ch := GDVars.creatureList;
    lightMinutes := 0;
    seriousMinutes := 0;
    criticalMinutes := 0;
    cureLightSlots := 0;
    cureSeriousSlots := 0;
    cureCriticalSlots := 0;
    maxTime := 0;
    while ch <> nil do begin
      base := 0;
      if CanCast(ch) then begin
        Inc(cureLightSlots, ch^.slots[C_Spell.CLERIC_LIST, 1]);
        lightMinutes := ch^.slots[C_Spell.CLERIC_LIST, 1] * 15;
        Inc(cureSeriousSlots, ch^.slots[C_Spell.CLERIC_LIST, 4]);
        seriousMinutes := ch^.slots[C_Spell.CLERIC_LIST, 4] * 60;
        Inc(cureCriticalSlots, ch^.slots[C_Spell.CLERIC_LIST, 5]);
        criticalMinutes := ch^.slots[C_Spell.CLERIC_LIST, 5] * 75;
      end;
      if lightMinutes > 0 then begin
        base := 240;
        Inc(timeMin, 27);
      end;
      if seriousMinutes + criticalMinutes > 0 then begin
        base := 360;
        if criticalMinutes > 0 then
          Inc(timeMin, 78)
        else
          Inc(timeMin, 34);
      end;
      Inc(base, lightMinutes + seriousMinutes + criticalMinutes);
      if maxTime < base then
        maxTime := base;
      ch := ch^.next;
    end;
    if maxTime = 0 then
      if prepTime = 0 then begin
        GDVars.restTime[4] := 1;
        Exit;
      end;
    if (timeMin <> 0) and (PartyHitPointsMissing < timeMin) then begin
      maxTime := LongInt(maxTime) * PartyHitPointsMissing div timeMin;
    end;
    Inc(maxTime, prepTime);
    Inc(maxTime, CureDiseaseTime);
    GDVars.restTime[3] := maxTime div 60;
    GDVars.restTime[2] := (maxTime - 60 * GDVars.restTime[3]) div 10;
    GDVars.restTime[1] := maxTime mod 10;
  end;

  { Spend healPool on the living members' lost hit points, in party order. }
  procedure HealParty;
  var
    character: Types.PWork;
    healingNeeded: Word;
    { Unused in this version; see the other implementations of this routine. }
    maxHitPoints: Word;
    { Unused in this version; see the other implementations of this routine. }
    hitPoints: Word;
  begin
    character := GDVars.creatureList;
    while character <> nil do begin
      if character^.status <> C_Status.DEAD_STATUS then
      if character^.tpHpMax > character^.hpCur then begin
        healingNeeded := character^.tpHpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, healingNeeded, False) then
            if healingNeeded <= healPool then
              Dec(healPool, healingNeeded);
      end;
      character := character^.next;
    end;
  end;

begin
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  interrupted := False;
  tries := 0;
  repeat
  healPool := 0;
  if (PartyHitPointsMissing = 0) and (PartySpellPrepTime = 0) and (CureDiseaseTime = 0) then begin
    CharHlp.PrintBottomLine('Nothing to fix');
    CharHlp.DisplayParty(GDVars.curChar);
    CharHlp.PrintPositionAndTime;
    Exit;
  end;
  RollMemorizedCures;
  savedRestTime := GDVars.restTime;
  ComputeFixTime;
  GDConsts.isMemorizeActive := False;
  GDConsts.isDiseaseQuiet := True;
  interrupted := GameTime.CampRest(False);
  GDConsts.isDiseaseQuiet := False;
  GDConsts.isMemorizeActive := True;
  if interrupted = False then begin
    CureStatuses;
    RollCureSlots;
    HealParty;
    CharHlp.DisplayParty(GDVars.curChar);
    CharHlp.PrintPositionAndTime;
    GameTime.FinishSpellPreparation;
    GDVars.restTime := savedRestTime;
  end;
  Inc(tries);
  until interrupted or (((PartyHitPointsMissing = 0) and (PartySpellPrepTime = 0)) or (tries >= 4));
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedIfc: Byte;
  c: Char;
  { ViewCharMenu's var result, unread }
  viewDone: Boolean;
  ext: Boolean;
begin
  savedIfc := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  GDVars.savedPictureName := GDVars.picArcName;
  GDVars.savedPictureId := GDVars.picArcId;
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  if GDVars.gbvmZone0Ptr^[Camp.MISSION_COMPLETE] <> 0 then
    TextRend.DisplayString(1, 17, LightGreen, Black, 'You have completed your mission.')
  else if (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] <> 0) or (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_RING] <> 0) then begin
    TextRend.DisplayString(1, 17, LightGreen, Black, 'The party has acquired the...');
    if GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_RING] <> 0 then
      TextRend.DisplayString(11, 18, White, Black, 'Ring of reversal');
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] and 1) <> 0 then
      TextRend.DisplayString(11, 19, White, Black, 'Statuette of the East');
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] and 2) <> 0 then
      TextRend.DisplayString(11, 20, White, Black, 'Statuette of the West');
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] and 4) <> 0 then
      TextRend.DisplayString(11, 21, White, Black, 'Statuette of the North');
    if (GDVars.gbvmZone0Ptr^[C_Gbvm.CAMP_STATUES] and 8) <> 0 then
      TextRend.DisplayString(11, 22, White, Black, 'Statuette of the South');
  end else
    TextRend.DisplayString(1, 18, LightGreen, Black, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  GDConsts.isMemorizeActive := True;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    GDVars.canClickParty := 1;
    GDConsts.canClickToView := True;
    c := MenuCore.MenuHorizontal('Camp:', GDConsts.campMenu, LightMagenta, LightGreen, White, True, True, ext);
    GDVars.canClickParty := 0;
    GDConsts.canClickToView := False;
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else begin
      Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
      case c of
        'S': begin
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenuClear('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': begin
               GDVars.horizChoice := 1;
               ViewChar.ViewCharMenu(viewDone);
             end;
        'M': begin
               GDVars.horizChoice := 1;
               Camp.CampMagicMenu(interrupted);
             end;
        'R': begin
               GDVars.horizChoice := 1;
               Camp.RestForSpellPrep(interrupted);
             end;
        'F': Camp.CampFixMenu(interrupted);
        'A': begin
               GDVars.horizChoice := 1;
               Camp.CampAlterMenu;
             end;
      end;
    end;
  end;
  if Copy(GDVars.savedPictureName, 1, 3) = 'PIC' then
    Portrait.LoadAnimation(GDVars.savedPictureName, GDVars.savedPictureId, 0, GDVars.animationData);
  Camp.ResetPartySpellActivities;
  GDVars.castTargetPtr := nil;
  GDVars.interfaceState := savedIfc;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
  GameIo.KbdNoop;
  GDConsts.isMemorizeActive := False;
end;

begin
end.
