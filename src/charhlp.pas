{ The character / item / combat helper hub: item load and management, the AC / HP / status draws, heal and bandage, and
  the numeric and name-string builders. }

{$O+,F+}
{$A+,S+}
unit CharHlp;

interface

uses Types, C_Status, C_Effect, C_Item, C_Class, C_Dir, C_Equip, C_Ifc, C_Msg, C_Pic, C_Race, C_Screen, C_Spell,
  C_Video, Crt, Pathing, CbtMap, Border, ClassCal, TextRend, Raster, SoundDrv, Portrait, MapView, Blit, MenuCore,
  GDConsts, GDVars, C_Keys, C_Gbvm;

type
  { the armor-class adjustments RecalcStats totals: 0 Dexterity, 1 shield, 2 pluses of armor-class-0 items, 3 best ring,
    4 best armor }
  TAcc5 = array[0..4] of ShortInt;

{ Build an item's display name in item^.name: with hdr, its Yes or No readied column; a '*' for a magic item (a plus, a
  save bonus or a curse) while a party member has Detect Magic; its quantity; then its identified name parts, the last
  first, with the plural on the right part when there are several. With draw the name is printed at x, y.
  @param(outS Unused.)
  @param(item The item.)
  @param(x Column to print at.)
  @param(y Row to print at.)
  @param(hdr True to start with the readied column.)
  @param(draw True to print the name.) }
procedure PrintItemString(outS: Pointer; item: Types.PItemRec; x, y: Byte; hdr, draw: Boolean);

{ Draw the party roster: the Name and AC HP headings, then each member's name (cur's highlighted, the others colored by
  DisplayCreatureName), armor class and hit points, and set the roster's click bounds. Nothing is drawn while a big
  picture is up.
  @param(cur The member to highlight.) }
procedure DisplayParty(cur: Types.PWork);

{ Print a creature's hit points right-aligned in three columns at x, y, in PrintHitPoints's colors.
  @param(p The creature.)
  @param(x Left column of the field.)
  @param(y Row.)
  @param(hurt True prints them in white.) }
procedure PrintHitPointsAligned(p: Types.PWork; x, y: Byte; hurt: Boolean);

{ Print a creature's armor class right-aligned in three columns at x, y, in PrintArmorClass's color; the callers print
  it under an 'AC' label.
  @param(p The creature.)
  @param(x Left column of the field.)
  @param(y Row.) }
procedure PrintArmorClassAligned(p: Types.PWork; x, y: Byte);

{ Draw a creature's combat panel, once each time GDVars.combatRedraw is set: its name, hit points and armor class (the
  armor class row kept in GDVars.curRow), its weapon's name, and its status when it is down, else the name of its first
  named effect, in red when it is down or helpless.
  @param(p The creature.) }
procedure CombatPrintCreatureInfo(p: Types.PWork);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(p The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(p: Types.PWork): Boolean;

{ Recompute a character's equipment-derived values: file each readied item in its equip slot (a second ring in the
  second ring slot, arrows and quarrels in their own) and count the items, hands and encumbrance, coins included; copy
  the base damage dice to the current ones; seed armor class, movement and THAC0 from the base values; add the dexterity
  armor class adjustment, the strength bonuses when no weapon is readied, and the weapon's adjustments (WeaponAdjust);
  let each readied item adjust movement and armor class; limit movement by encumbrance; and derive the armor class
  totals and the fighting level: the fighter level, with a restored dual-class one, for a character that has one, else
  1. Note: flagY is never set, so its encumbrance allowance never runs.
  @param(p The character.) }
procedure RecalcStats(p: Types.PWork);

{ Formats a number in decimal.
  @param(l The number.)
  @returns(Its decimal digits, with a minus sign when negative.) }
function Int32Str(l: LongInt): String;

{ Formats a number in decimal.
  @param(w The number.)
  @returns(Its decimal digits.) }
function Uint16Str(w: Word): String;

{ Formats a number in decimal.
  @param(b The number.)
  @returns(Its decimal digits.) }
function Uint8Str(b: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(p The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(p: Types.PWork): ShortInt;

{ Finds a creature's damage adjustment for its translated Strength, 0 when the creature takes no Strength bonus.
  @param(p The creature.)
  @returns(The adjustment.) }
function StrDamageAdjust(p: Types.PWork): ShortInt;

{ Finds a creature's weight allowance for its translated Strength, from -350 to 15000 encumbrance units.
  @param(p The creature.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(p: Types.PWork): Integer;

{ Mark the first memorized copy of a spell as cast: it takes the pending flag, to be memorized again.
  @param(p The caster.)
  @param(id The spell id.) }
procedure RemoveSpell(p: Types.PWork; id: Byte);

{ Unlink an item from a character's item list and dispose of it; a nil item, or one not in the list, is left alone.
  @param(p The character.)
  @param(item The item.) }
procedure RemoveItem(p: Types.PWork; item: Types.PItemRec);

{ Append a copy of an item to the end of a character's item list.
  @param(tgt The character.)
  @param(it The item to copy.) }
procedure AddItemCopy(tgt: Types.PWork; it: Types.PItemRec);

{ Append a copy of an item to the end of a character's item list and return the copy.
  @param(tgt The character.)
  @param(it The item to copy; receives the copy.) }
procedure AddItemCopyVar(tgt: Types.PWork; var it: Types.PItemRec);

{ Show a message on the screen's bottom row: clear the row, print s, pause, and clear it again.
  @param(s The message.) }
procedure PrintBottomLine(s: Types.TStr40);

{ Prints a creature's name with a message under it: in combat in the side panel from the given row on, elsewhere in the
  text window from row 17, or 18 while the border is off.
  @param(cr The creature.)
  @param(msg The message.)
  @param(row The panel row of the name, read in combat.)
  @param(pause When set, pauses and then clears the message area.) }
procedure PrintCreatureMessage(cr: Types.PWork; msg: String; row: Byte; pause: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Print a creature's name at x, y: light red when it is down, yellow when hostile, light magenta when it can train
  (CanLevelUp), else light cyan.
  @param(p The creature.)
  @param(x Column.)
  @param(y Row.)
  @param(tail True to add "'s".) }
procedure DisplayCreatureName(p: Types.PWork; x, y: Byte; tail: Boolean);

{ Copy one icon picture, GDVars.iconAnimation[imgIdx, imgHalf], into a frame of the missile sheet GDVars.moveIconSheet,
  pixels and mask, mirrored through a scratch picture when mirror is set; the sheet takes the icon's transparent color.
  @param(imgIdx Icon slot.)
  @param(imgHalf Which of the icon's two pictures.)
  @param(frame Sheet frame to fill.)
  @param(mirror Nonzero to mirror it.) }
procedure CopyIconFacing(imgIdx, imgHalf, frame, mirror: Byte);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(imgIdx The icon slot.) }
procedure BuildIconFacings(imgIdx: Byte);

{ Animate the missile sheet moving from arena cell x1, y1 to x2, y2 along Pathing's line between them, in thirds of a
  cell, cycling frames frames and waiting stepDelay milliseconds a drawn step; with no delay it draws only on cell
  edges. The view is centered on the midpoint when an end is out of view and the ends are within 6 cells of each other;
  when the line leaves the view, the rest is drawn back from the target end. A line of fewer than four steps is not
  drawn.
  @param(x1 Start column.)
  @param(y1 Start row.)
  @param(x2 End column.)
  @param(y2 End row.)
  @param(frames Frames in the cycle.)
  @param(stepDelay Milliseconds for each step.) }
procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; frames, stepDelay: Byte);

{ Shows a creature's name and a message with a damage or effect flash. In combat the flash frames are built, the
  creature scrolled into view, the sound played and the message printed; then the four frames flash on the creature,
  once more than the game's delay setting for an effect and once for damage, which then waits the text delay. Outside
  combat it prints the message with a pause.
  @param(cr The creature.)
  @param(b True for an effect, False for damage.)
  @param(s The message.) }
procedure PrintNameStringAnim(cr: Types.PWork; b: Boolean; s: String);

{ Tells whether a creature carries an effect.
  @param(p The creature.)
  @param(effId The effect.)
  @param(node Receives the matching effect node, or nil when there is none.)
  @returns(True when it carries the effect.) }
function HasEffect(p: Types.PWork; effId: Byte; var node: Types.PEffectRec): Boolean;

{ Takes damage off a creature's hit points and updates its status. Falling more than 9 below 0, or an animated creature
  reaching 0, is death; any other drop below 0 is dying (combat records how far below); exactly 0 is unconscious. A
  creature that is then not okay or animated is taken out of play with no hit points (in combat its side's count drops
  and its initiative is cleared); otherwise it keeps the hit points left.
  @param(cr The creature.)
  @param(dmg The damage.) }
procedure InflictDamage(cr: Types.PWork; dmg: Byte);

{ Prints 'is fully healed' or 'is partially healed' for a creature, and outside combat redraws the roster.
  @param(p The healed creature.) }
procedure AnnounceHealStatus(p: Types.PWork);

{ Tells whether a creature is on the party's side.
  @param(p The creature.)
  @returns(True when its hostile flag is 0.) }
function NotHostile(p: Types.PWork): Boolean;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table.
  @param(cr The creature at the center.)
  @param(a The range.)
  @returns(The number of targets kept.) }
function CountTargets(cr: Pointer; a: Byte): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(cr The creature measuring.)
  @param(target The creature to find.)
  @returns(The distance.) }
function CalcDistance(cr, target: Pointer): Byte;

{ End a combatant's turn: clear its initiative, cast spell, guard and movement.
  @param(p The combatant.)
  @returns(True.) }
function ClearGuard(p: Types.PWork): Boolean;

{ Ends a creature's round on guard, and says so.
  @param(p The creature.)
  @returns(True.) }
function Guard(p: Types.PWork): Boolean;

{ Return the current character's casting level for spell x by the spell's casting class, each class level counting its
  dual-class level when the dual-class abilities are restored: cleric spells the higher of the cleric level and the
  paladin level less 8; druid spells the ranger level less 7, at least 0; magic-user spells the higher of the magic-user
  level and the ranger level less 8; class 3 spells 12. A caster with no cleric or magic-user level, a paladin level
  below 9 and a ranger level below 8 casts at 6, and so does any spell but class 3 while GDVars.usingItem is set.
  @param(x The spell.)
  @returns(The casting level.) }
function GetCasterLevel(x: Byte): Byte;

{ Redraw the non-combat screen for the interface state: the main menu's frame; for a shop or the vault the view frame,
  the area picture or the portraits, the roster and the status line; in camp the view frame, camp picture 29, the roster
  and the status line; exploring, the view frame, the 3D view, the roster and the status line; looting, the view frame,
  picture 1 and the roster. GDVars.mapRedrawPending is set first. }
procedure DisplayNoncombatInterface;

{ Draw the status line: the party's map position (unless the zone hides the automap), its facing, the time as hh:mm, a
  '*' while debugging is on, and ' camping' in camp, else ' search' or ' in boat'. }
procedure PrintPositionAndTime;

{ Redraw the combat screen: the combat palette and frame, the combat picture in VGA mode, and the arena view around its
  current center. }
procedure DisplayCombatInterface;

{ Pick a party member from a 'Select' menu under the prompt q, the roster drawn with c highlighted: the down and up
  arrows step through the party, wrapping, and a click on the roster picks through GDVars.orderChar. It runs until a
  choice, Escape, E or S.
  @param(q The prompt.)
  @param(b True to offer Exit, which leaves c nil.)
  @param(c The member highlighted at the start; receives the pick.) }
procedure SelectChar(q: Types.TStr40; b: Boolean; var c: Types.PWork);

{ Tells whether a creature's readied weapon reaches beyond 1, thrown weapons included.
  @param(cr The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(cr: Types.PWork): Boolean;

{ Tells whether a creature's readied weapon is ranged and can be thrown with a Strength bonus.
  @param(cr The creature.)
  @returns(True for a throwable weapon.) }
function HasThrowableWeapon(cr: Types.PWork): Boolean;

{ Find what a creature's readied weapon fires: the weapon itself when thrown, its readied arrows or quarrels when it
  fires them. It fails underwater.
  @param(p The creature.)
  @param(it Receives the missile, or nil.)
  @returns(True when a missile was found or the weapon's properties are exactly 10.) }
function FindDamagingRangedWeapon(p: Types.PWork; var it: Pointer): Boolean;

{ Tells whether a creature has reached its race's level limit in a class. Fighter limits rise with high Strength, and a
  half-elf cleric stops at level 5; monsters, half-orcs and humans have no limit here.
  @param(w The creature.)
  @param(k The class.)
  @returns(True at the limit.) }
function AtLevelCap(w: Types.PWork; k: ShortInt): Boolean;

{ Allocates a zeroed item record and fills it from the parameters.
  @param(itemType The item type.)
  @param(firstNameId The first name part.)
  @param(secondNameId The second name part.)
  @param(thirdNameId The third name part.)
  @param(plus The magic bonus.)
  @param(saveBonus The saving-throw bonus.)
  @param(equipped Nonzero when readied.)
  @param(unidMask Bits of the name parts still unidentified.)
  @param(cursed Nonzero when cursed.)
  @param(weight The weight.)
  @param(quantity The quantity, 0 for a single item.)
  @param(value The value.)
  @param(charges The charges.)
  @param(effect The effect.)
  @param(special The special property.)
  @returns(The new item.) }
function MakeItem(itemType,
                  firstNameId, secondNameId, thirdNameId,
                  plus, saveBonus, equipped, unidMask, cursed: Byte; weight: Word; quantity: Byte; value: Word;
                  charges, effect, special: Byte): Types.PItemRec;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `bandage` set, the first dying
  member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(bandage Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(bandage: Boolean): Boolean;

{ Redraw cur's line of the party roster, its name highlighted when direct, and set the roster's click bounds. Nothing is
  drawn while a big picture is up.
  @param(cur The member.)
  @param(direct True to highlight the name.) }
procedure PrintMiscInfo(cur: Types.PWork; direct: Boolean);

implementation

const
  { GBVM zone 0: the game clock's minutes and tens of minutes digits }
  CLOCK_MINUTES = $4BC7;
  CLOCK_TEN_MINUTES = $4BC8;
  { GBVM zone 0: the party's boat flags, bit 0 set while the party is in a boat }
  BOAT_FLAGS = $4CF5;
  { TBaseItemRec.props' bit for a weapon that takes DexMissileAdjust's DEX missile to-hit adjustment (C_Item has the
    rest) }
  ITEM_PROP_DEX_MISSILE = $02;
  { the effect under which the item list marks magic items while a party member has it }
  EFF_DETECT_MAGIC = 5;

procedure WeaponAdjust(p: Types.PWork); forward;

procedure ArmorMoveAdjust(p: Types.PWork; item: Types.PItemRec); forward;

procedure AddItemArmorAdjust(p: Types.PWork; item: Types.PItemRec; var acc: TAcc5; var flagZ: Byte); forward;

procedure EncumbranceAdjust(p: Types.PWork); forward;

function TranslatedStrength(p: Types.PWork): Byte; forward;

function DexterityArmorAdjustment(p: Types.PWork): ShortInt; forward;

function StrToHitAdjust(p: Types.PWork): ShortInt; forward;

{ Return whether a character can train in any of its classes, cleric to thief: the next level's experience is positive
  and met, and neither the class level cap nor the racial limit blocks it.
  @param(p The character.)
  @returns(True when it can train.) }
function CanLevelUp(p: Types.PWork): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  capped: Byte;
  found: Boolean;
  classId: ShortInt;
  level: Byte;
  requiredExperience: LongInt;
begin
  found := False;
  classId := C_Class.CLERIC_LEVEL;
  while (classId <= C_Class.THIEF_LEVEL) and not found do begin
    if (p^.classLevels[classId] > 0) and (p^.classLevels[classId] < 40) then begin
      level := p^.classLevels[classId];
      requiredExperience := ClassCal.XpForLevel(Types.PWork(p), ShortInt(level) + 1, classId);
      found := not ClassCal.AtClassLevelCap(classId, level) and not CharHlp.AtLevelCap(p, classId) and
        (p^.experience >= requiredExperience) and (requiredExperience > 0);
    end;
    Inc(classId);
  end;
  CanLevelUp := found;
end;

{ Sets the readied weapon's THAC0 and damage. THAC0 starts from its base, plus the Dexterity missile adjustment for a
  missile weapon and the Strength to-hit bonus for a weapon that uses Strength, which also adds the Strength damage
  bonus. The damage modifier starts from the weapon's small-target modifier. The weapon's plus and its ammunition's plus
  (the readied quarrels or arrows it fires) are added to both the damage modifier and THAC0; an elf adds 1 more to THAC0
  alone with the bows and item types 36 and 37. The damage dice are the small-target dice. Does nothing without a
  readied weapon.
  @param(p The character.) }
procedure WeaponAdjust(p: Types.PWork);
var
  item: Types.PItemRec;
  typ: Byte;
  acc: ShortInt;
begin
  item := p^.equipped[C_Equip.WEAPON];
  if item = nil then Exit;
  typ := item^.itemType;
  p^.b[$199] := p^.b[$73];
  if (GDVars.baseItems[typ].props and CharHlp.ITEM_PROP_DEX_MISSILE) <> 0 then
    p^.b[$199] := p^.b[$199] + CharHlp.DexMissileAdjust(p);
  p^.b[$1A2] := GDVars.baseItems[typ].dmgSmMod;
  if (GDVars.baseItems[typ].props and C_Item.STRENGTH_BONUS) <> 0 then begin
    p^.b[$199] := p^.b[$199] + CharHlp.StrToHitAdjust(p);
    p^.b[$1A2] := ShortInt(p^.b[$1A2]) + CharHlp.StrDamageAdjust(p);
  end;
  acc := item^.plus;
  { USES_QUARRELS }
  if GDVars.baseItems[typ].props > $7F then
    if p^.equipped[C_Equip.BOLT] <> nil then
      acc := acc + p^.equipped[C_Equip.BOLT]^.plus;
  if (GDVars.baseItems[typ].props and C_Item.USES_ARROWS) > 0 then
    if p^.equipped[C_Equip.ARROW] <> nil then
      acc := acc + p^.equipped[C_Equip.ARROW]^.plus;
  p^.b[$1A2] := ShortInt(p^.b[$1A2]) + acc;
  if p^.b[$74] = 2 then
    { Note: the four named bows; the Heavy Crossbow after them also has bow props but is left out. }
    if ((item^.itemType > 40) and (item^.itemType < 45))
       or (item^.itemType = 37)
       or (item^.itemType = 36) then
      Inc(acc);
  p^.b[$199] := p^.b[$199] + acc;
  p^.b[$19E] := GDVars.baseItems[typ].dmgSmRolls;
  p^.b[$1A0] := GDVars.baseItems[typ].dmgSmDice;
end;

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(p The character.)
  @param(item A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(p: Types.PWork; item: Types.PItemRec);
begin
  if GDVars.baseItems[item^.itemType].slot = C_Equip.ARMOR then begin
    case item^.weight of
      0..150: p^.b[$1A5] := p^.b[$E4];
      151..399: p^.b[$1A5] := 9;
    else
      p^.b[$1A5] := 6;
    end;
    if item^.plus <> 0 then
      if p^.b[$1A5] <= 9 then
        p^.b[$1A5] := p^.b[$1A5] + 3;
  end;
end;

{ Folds one readied item into the armor-class adjustments. Only an item whose base armor value has bit 7 set counts; the
  low seven bits are its own armor class. A shield sets the shield slot to its armor class plus its plus. An item with
  armor class 0 adds its save bonus to the creature's and its plus to the slot of armor-class-0 items, except a ring,
  which raises the best-ring slot to its plus. Any other item keeps the best armor class plus plus in the armor slot,
  marking magical body armor when that new best is body armor with a positive plus.
  @param(p The creature.)
  @param(item The item.)
  @param(acc The adjustments: 0 Dexterity, 1 shield, 2 pluses of armor-class-0 items, 3 best ring, 4 best armor.)
  @param(flagZ Set when the best armor becomes magical body armor.) }
procedure AddItemArmorAdjust(p: Types.PWork; item: Types.PItemRec; var acc: TAcc5; var flagZ: Byte);
var
  code: Byte;
  slot: Byte;
begin
  code := GDVars.baseItems[item^.itemType].acDescr;
  if code <= $7F then Exit;
  code := code and $7F;
  slot := GDVars.baseItems[item^.itemType].slot;
  if slot = 1 then begin
    acc[1] := code + item^.plus;
    Exit;
  end;
  if code = 0 then begin
    if slot = C_Equip.FIRST_RING then begin
      if item^.plus > acc[3] then
        acc[3] := item^.plus;
    end else
      acc[2] := acc[2] + item^.plus;
    p^.b[$186] := ShortInt(p^.b[$186]) + item^.saveBonus;
  end else begin
    if code + item^.plus > acc[4] then begin
      acc[4] := code + item^.plus;
      if item^.plus > 0 then
        if slot = C_Equip.ARMOR then
          flagZ := 1;
    end;
  end;
end;

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(p The creature.) }
procedure EncumbranceAdjust(p: Types.PWork);
var
  v: Integer;
  r: Byte;
begin
  v := p^.encumbrance - CharHlp.WeightAllowance(p);
  if v < 0 then
    v := 0;
  case v of
    0..512: r := p^.b[$1A5];
    513..768: r := 9;
    769..1024: r := 6;
  else
    r := 3;
  end;
  if r < p^.b[$1A5] then
    p^.b[$1A5] := r;
end;

procedure PrintItemString(outS: Pointer; item: Types.PItemRec; x, y: Byte; hdr, draw: Boolean);
var
  i: Byte;
  mask: Byte;
  ec: Types.PEffectRec;
  detectMagic: Boolean;
  special: Boolean;
  pw: Types.PWork;
begin
  item^.name := '';
  if hdr then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   ';
  end;
  detectMagic := False;
  pw := GDVars.creatureList;
  while (pw <> nil) and (not detectMagic) do begin
    if CharHlp.HasEffect(pw, CharHlp.EFF_DETECT_MAGIC, ec) then
      detectMagic := True;
    pw := pw^.next;
  end;
  if detectMagic then begin
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  end;
  if item^.quantity > 0 then
    item^.name := item^.name + CharHlp.Uint8Str(item^.quantity) + ' ';
  mask := 0;
  for i := 1 to SizeOf(item^.nameIds) do
    if (item^.nameIds[i] <> 0) and ((item^.unidMask shr (SizeOf(item^.nameIds) - i)) and 1 = 0) then
      Inc(mask, 1 shl (i - 1));
  special := False;
  for i := SizeOf(item^.nameIds) downto 1 do
    if (mask shr (i - 1)) and 1 > 0 then begin
      item^.name := item^.name + GDConsts.itemNameComponents[item^.nameIds[i]];
      if (item^.quantity < 2) or special
         or (item^.nameIds[i] in [162..167]) then
        item^.name := item^.name + ' '
      else if ((1 shl (i - 1)) = mask)
           or ((i = 1) and (mask > 4) and (item^.itemType <> 86))
           or ((i = 2) and not Odd(mask))
           or ((i = 3) and (item^.itemType = 86))
           or
             ((item^.nameIds[3] <> 135) and
              ((item^.itemType = C_Item.ARROWS) or (item^.itemType = C_Item.QUARRELS)) and
              (item^.nameIds[3] <> 177)) then begin
        item^.name := item^.name + 's ';
        special := True;
      end else
        item^.name := item^.name + ' ';
    end;
  if draw then
    TextRend.DisplayString(x, y, LightGreen, Black, item^.name);
end;

procedure DisplayParty(cur: Types.PWork);
var
  head: Types.PWork;
  col: Byte;
  row: Byte;
begin
  if GDVars.bigPicId <> C_Pic.NO_BIG_PICTURE then
    Exit;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  GDVars.rosterLeft := col;
  GDVars.rosterTop := 4;
  GDVars.rosterRight := 38;
  GDVars.rosterBottom := 3;
  row := 2;
  TextRend.DisplayString(col, row, White, Black, 'Name');
  TextRend.DisplayString(33, row, White, Black, 'AC  HP');
  Inc(row, 2);
  head := GDVars.creatureList;
  while head <> nil do begin
    Inc(GDVars.rosterBottom);
    Border.ClearBox(col, row, 38, row);
    if head = cur then
      TextRend.DisplayString(col, row, White, Black, head^.name)
    else
      CharHlp.DisplayCreatureName(head, col, row, False);
    CharHlp.PrintArmorClassAligned(head, 32, row);
    CharHlp.PrintHitPointsAligned(head, 36, row, False);
    Inc(row);
    head := head^.next;
  end;
  if (row <= 11) or (GDVars.interfaceState <> C_Ifc.MAIN_MENU) then
    Border.ClearBox(col, row, 38, row);
end;

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(p The character.)
  @param(x Screen column.)
  @param(y Screen row.) }
procedure PrintArmorClass(p: Types.PWork; x, y: Byte);
var
  outStr: String;
  { Unused in this version; see the other implementations of this routine. }
  shift: array[0..1] of Byte;
begin
  outStr := CharHlp.Uint8Str(Abs(p^.acCur - 60));
  if p^.acCur > 60 then
    outStr := '-' + outStr;
  TextRend.DisplayString(x, y, LightGreen, Black, outStr);
end;

procedure PrintArmorClassAligned(p: Types.PWork; x, y: Byte);
var
  indent: Byte;
begin
  case p^.acCur of
    0..50, 61..69: begin
      indent := 1;
      TextRend.DisplayString(x, y, Black, Black, ' ');
    end;
    51..60: begin
      indent := 2;
      TextRend.DisplayString(x, y, Black, Black, '  ');
    end;
  else
    indent := 0;
  end;
  CharHlp.PrintArmorClass(p, x + indent, y);
end;

{ Prints a character's current hit points: yellow below maximum, light green at maximum, white when hurt is set.
  @param(p The character.)
  @param(x Screen column.)
  @param(y Screen row.)
  @param(hurt Prints in white.) }
procedure PrintHitPoints(p: Types.PWork; x, y: Byte; hurt: Boolean);
var
  color: Byte;
begin
  if p^.hpCur < p^.cbHpMax then
    color := Yellow
  else
    color := LightGreen;
  if hurt then
    color := White;
  TextRend.DisplayString(x, y, color, Black, CharHlp.Uint8Str(p^.hpCur));
end;

procedure PrintHitPointsAligned(p: Types.PWork; x, y: Byte; hurt: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  shift: Byte;
  indent: ShortInt;
begin
  case p^.hpCur of
    0..9: begin
      indent := 2;
      TextRend.DisplayString(x, y, Black, Black, '  ');
    end;
    10..99: begin
      indent := 1;
      TextRend.DisplayString(x, y, Black, Black, ' ');
    end;
  else
    indent := 0;
  end;
  CharHlp.PrintHitPoints(p, x + indent, y, hurt);
end;

procedure PrintMiscInfo(cur: Types.PWork; direct: Boolean);
var
  head: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  statusText: array[0..3] of Byte;
  col: Byte;
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  minuteText: array[0..1] of Byte;
  selected: Types.PWork;
begin
  if GDVars.bigPicId <> C_Pic.NO_BIG_PICTURE then
    Exit;
  selected := cur;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  GDVars.rosterLeft := col;
  GDVars.rosterTop := 4;
  GDVars.rosterRight := 38;
  GDVars.rosterBottom := 3;
  row := 4;
  head := GDVars.creatureList;
  while head <> nil do begin
    Inc(GDVars.rosterBottom);
    if head = selected then begin
      if direct then
        TextRend.DisplayString(col, row, White, Black, head^.name)
      else
        CharHlp.DisplayCreatureName(head, col, row, False);
      CharHlp.PrintArmorClassAligned(head, 32, row);
      CharHlp.PrintHitPointsAligned(head, 36, row, False);
    end;
    Inc(row);
    head := head^.next;
  end;
  if (row <= 11) or (GDVars.interfaceState <> C_Ifc.MAIN_MENU) then
    Border.ClearBox(col, row, 38, row);
end;

procedure CombatPrintCreatureInfo(p: Types.PWork);
var
  { Unused in this version; see the other implementations of this routine. }
  col2: Byte;
  row: Byte;
  msg: String;

  { The first of p's effects that has a name, in parentheses, or ''. }
  function EffectStatusString: String;
  var
    node: Types.PEffectRec;
    i: Byte;
  begin
    node := p^.effects;
    while node <> nil do begin
      for i := 1 to SizeOf(GDConsts.effectNameIds) do
        if GDConsts.effectNameIds[i] = node^.id then begin
          EffectStatusString := '(' + GDConsts.effectNames[i] + ')';
          Exit;
        end;
      node := node^.next;
    end;
    EffectStatusString := '';
  end;
begin
  if GDVars.combatRedraw <> 0 then begin
    GDVars.combatRedraw := 0;
    Border.ClearBox(23, 1, 38, 21);
    row := 1;
    CharHlp.PrintCreatureMessage(p, ' ', row, False);
    Inc(row);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'Hitpoints');
    CharHlp.PrintHitPoints(p, 33, row + 1, False);
    Inc(row, 2);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'AC');
    CharHlp.PrintArmorClass(p, 26, row + 1);
    GDVars.curRow := row + 1;
    if p^.equipped[C_Equip.WEAPON] <> nil then begin
      Inc(row, 2);
      col2 := 23;
      CharHlp.PrintItemString(p, p^.equipped[C_Equip.WEAPON], 0, 0, False, False);
      TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 2, LightGreen, Black, True,
                                    p^.equipped[C_Equip.WEAPON]^.name);
    end;
    row := GDVars.curRow + 1;
    msg := '';
    if p^.enabled = 0 then
      msg := GDConsts.statusNames[ShortInt(p^.status)]
    else
      msg := EffectStatusString;
    if msg <> '' then begin
      if CharHlp.IsHelpless(p) or (p^.enabled = 0) then
        TextRend.DisplayString(23, row + 1, LightRed, Black, msg)
      else
        TextRend.DisplayString(23, row + 1, White, Black, msg);
    end;
  end;
end;

function IsHelpless(p: Types.PWork): Boolean;
var
  i: Byte;
  node: Types.PEffectRec;
begin
  IsHelpless := False;
  for i := 1 to SizeOf(GDConsts.helplessFx) do
    if CharHlp.HasEffect(p, GDConsts.helplessFx[i], node) then
      IsHelpless := True;
end;

procedure RecalcStats(p: Types.PWork);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItemRec;
  flagZ: Byte;
  flagY: Byte;
  acc: TAcc5;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  magicBody: Byte;
  coinIndex: ShortInt;
  itemAc: Word;
  tblResult: Byte;
begin
  for i := 0 to SizeOf(p^.equipped) div SizeOf(p^.equipped[0]) - 1 do
    p^.equipped[i] := nil;
  flagY := 0;
  p^.b[$14C] := 0;
  item := p^.itemsAddr;
  p^.b[$185] := 0;
  p^.encumbrance := 0;
  GDVars.gEquipWeight := 0;
  while item <> nil do begin
    Inc(p^.b[$14C]);
    itemAc := item^.weight;
    if item^.quantity > 0 then
      itemAc := item^.quantity * itemAc;
    Inc(p^.encumbrance, itemAc);
    if item^.equipped <> 0 then begin
      Inc(GDVars.gEquipWeight, itemAc);
      tblResult := GDVars.baseItems[item^.itemType].slot;
      case tblResult of
        0..8:
          p^.equipped[ShortInt(tblResult)] := item;
        C_Equip.FIRST_RING:
          if p^.equipped[C_Equip.FIRST_RING] <> nil then begin
            if p^.equipped[C_Equip.SECOND_RING] = nil then
              p^.equipped[C_Equip.SECOND_RING] := item;
          end else
            p^.equipped[C_Equip.FIRST_RING] := item;
      end;
      if item^.itemType = C_Item.ARROWS then
        p^.equipped[C_Equip.ARROW] := item;
      if item^.itemType = C_Item.QUARRELS then
        p^.equipped[C_Equip.BOLT] := item;
      p^.b[$185] := p^.b[$185] + GDVars.baseItems[item^.itemType].hands;
    end;
    item := item^.next;
  end;
  for coinIndex := 0 to SizeOf(p^.coinsA) div SizeOf(p^.coinsA[0]) - 1 do
    p^.encumbrance := p^.coinsA[coinIndex] + p^.encumbrance;
  for j := 1 to SizeOf(p^.baseRolls) do begin
    p^.curRollsA[j] := p^.baseRolls[j];
    p^.curDiceA[j] := p^.baseDice[j];
    p^.curModA[j] := p^.baseMod[j];
  end;
  for k := 0 to SizeOf(acc) - 1 do
    acc[k] := 0;
  flagZ := 0;
  p^.b[$186] := 0;
  p^.b[$19A] := p^.b[$124];
  p^.b[$1A5] := p^.b[$E4];
  p^.b[$199] := p^.b[$73];
  acc[0] := CharHlp.DexterityArmorAdjustment(p);
  if p^.equipped[C_Equip.WEAPON] = nil then begin
    p^.b[$199] := p^.b[$199] + CharHlp.StrToHitAdjust(p);
    p^.b[$1A2] := ShortInt(p^.b[$1A2]) + CharHlp.StrDamageAdjust(p);
  end;
  CharHlp.WeaponAdjust(p);
  item := p^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(p, item);
      CharHlp.AddItemArmorAdjust(p, item, acc, flagZ);
    end;
    item := item^.next;
  end;
  if flagZ <> 0 then
    acc[3] := 0;
  if flagY <> 0 then begin
    if p^.encumbrance < 5000 then
      p^.encumbrance := 0
    else
      Dec(p^.encumbrance, 5000);
    if p^.encumbrance < GDVars.gEquipWeight then
      p^.encumbrance := GDVars.gEquipWeight;
  end;
  CharHlp.EncumbranceAdjust(p);
  if acc[4] < p^.b[$19A] then
    acc[4] := p^.b[$19A];
  p^.b[$19A] := 0;
  for k := 0 to SizeOf(acc) - 1 do
    p^.b[$19A] := p^.b[$19A] + acc[k];
  p^.b[$19B] := acc[4] + acc[2] + acc[3] - 2;
  if ((ShortInt(p^.b[$10B]) > 0) or
      ((ShortInt(p^.b[$113]) > 0) and (ClassCal.EarlierClassActive(Types.PWork(p)) <> 0)))
     and (ShortInt(p^.b[$74]) > 0) then
    p^.b[$DD] := ShortInt(p^.b[$10B])
      + ClassCal.EarlierClassActive(Types.PWork(p)) * ShortInt(p^.b[$113])
  else
    p^.b[$DD] := 1;
end;

function Uint8Str(b: Byte): String;
var
  s: String;
begin
  Str(b, s);
  Uint8Str := s;
end;

function Uint16Str(w: Word): String;
var
  s: String;
begin
  Str(w, s);
  Uint16Str := s;
end;

function Int32Str(l: LongInt): String;
var
  s: String;
begin
  Str(l, s);
  Int32Str := s;
end;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(p The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(p: Types.PWork): ShortInt;
var
  t: Byte;
begin
  t := p^.b[$17];
  case t of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := t - 7;
    15..18: DexterityArmorAdjustment := t - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust(p: Types.PWork): ShortInt;
var
  t: Byte;
begin
  t := p^.b[$17];
  case t of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := t - 6;
    16..18: DexMissileAdjust := t - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(p The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(p: Types.PWork): Byte;
begin
  case p^.strCur of
    0..17: TranslatedStrength := p^.strCur;
    18: case p^.exStrCur of
              0: TranslatedStrength := 18;
              1..50: TranslatedStrength := 19;
              51..75: TranslatedStrength := 20;
              76..90: TranslatedStrength := 21;
              91..99: TranslatedStrength := 22;
              100: TranslatedStrength := 23;
            end;
    19..25: TranslatedStrength := p^.strCur + 5;
  end;
end;

{ Computes the Strength to-hit bonus on TranslatedStrength's scale (-3 at 1..3 up to +7 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(p The creature.)
  @returns(The to-hit bonus.) }
function StrToHitAdjust(p: Types.PWork): ShortInt;
var
  s: Byte;
begin
  StrToHitAdjust := 0;
  s := CharHlp.TranslatedStrength(p);
  if p^.useStrength <> 0 then
    case s of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := s - 23;
    end;
end;

function StrDamageAdjust(p: Types.PWork): ShortInt;
var
  s: Byte;
begin
  StrDamageAdjust := 0;
  s := CharHlp.TranslatedStrength(p);
  if p^.useStrength <> 0 then
    case s of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := s - 16;
      20..29: StrDamageAdjust := s - 17;
      30: StrDamageAdjust := 14;
    end;
end;

function WeightAllowance(p: Types.PWork): Integer;
var
  s: Byte;
begin
  s := CharHlp.TranslatedStrength(p);
  case s of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (s - 17) * 250 + 500;
    22..26: WeightAllowance := (s - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (s - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell(p: Types.PWork; id: Byte);
var
  i: Byte;
begin
  i := 0;
  while i <= C_Spell.MEMORIZED_SPELL_SLOTS - 1 do begin
    if p^.memorizedSpells[i] = id then begin
      p^.memorizedSpells[i] := id or C_Spell.PENDING_FLAG;
      i := C_Spell.MEMORIZED_SPELL_SLOTS;
    end;
    Inc(i);
  end;
end;

procedure RemoveItem(p: Types.PWork; item: Types.PItemRec);
var
  cur: Types.PItemRec;
begin
  if item <> nil then begin
    cur := p^.itemsAddr;
    if cur = item then
      p^.itemsAddr := item^.next
    else
      while (cur <> nil) and (cur^.next <> item) do
        cur := cur^.next;
    if cur = nil then begin
    end else begin
      cur^.next := item^.next;
      Dispose(item);
    end;
  end;
end;

procedure AddItemCopyVar(tgt: Types.PWork; var it: Types.PItemRec);
var
  cur: Types.PItemRec;
  newItem: Types.PItemRec;
begin
  New(newItem);
  Move(it^, newItem^, SizeOf(newItem^));
  newItem^.next := nil;
  cur := tgt^.itemsAddr;
  if cur = nil then
    tgt^.itemsAddr := newItem
  else begin
    while cur^.next <> nil do
      cur := cur^.next;
    cur^.next := newItem;
  end;
  it := newItem;
end;

procedure AddItemCopy(tgt: Types.PWork; it: Types.PItemRec);
begin
  CharHlp.AddItemCopyVar(tgt, it);
end;

procedure PrintBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
  TextRend.DisplayString(0, C_Screen.STATUS_ROW, LightGreen, Black, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, C_Screen.STATUS_ROW, 39, C_Screen.STATUS_ROW);
end;

procedure PrintCreatureMessage(cr: Types.PWork; msg: String; row: Byte; pause: Boolean);
var
  col: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(cr, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, Black, True, msg);
  end else begin
    if GDVars.suppressDrawingBorderFlag <> 0 then
      col := 18
    else
      col := 17;
    Border.ClearBox(1, col, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, col + 1, False);
    TextRend.DisplayMessageWindow(1, col + 2, 38, 22, LightGreen, Black, True, msg);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure ClearMessageWindow;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(1, 18, 38, 22);
end;

procedure DisplayCreatureName(p: Types.PWork; x, y: Byte; tail: Boolean);
var
  color: Byte;
begin
  if p^.enabled = 0 then
    color := LightRed
  else if p^.hostile = 1 then
    color := Yellow
  else if CharHlp.CanLevelUp(p) then
    color := LightMagenta
  else
    color := LightCyan;
  TextRend.DisplayString(x, y, color, Black, p^.name);
  if tail then
    TextRend.DisplayString(x + Length(p^.name), y, color, Black, '''s');
end;

procedure CopyIconFacing(imgIdx, imgHalf, frame, mirror: Byte);
var
  pic: Types.PImgBuf;
  stride: Word;
begin
  stride := GDVars.moveIconSheet^.frameSize;
  if mirror <> 0 then begin
    Raster.AllocPic(24, 3, 1, 1, pic);
    Raster.MirrorPic(GDVars.iconAnimation[imgIdx, imgHalf], pic);
    Move(pic^.data, GDVars.moveIconSheet^.data[frame * stride], stride);
    if pic^.transp <> nil then
      Move(pic^.transp^, GDVars.moveIconSheet^.transp^[frame * stride], stride);
    GDVars.moveIconSheet^.mode3Extra := GDVars.iconAnimation[imgIdx, imgHalf]^.mode3Extra;
    Raster.FreePic(pic);
  end else begin
    Move(GDVars.iconAnimation[imgIdx, imgHalf]^.data, GDVars.moveIconSheet^.data[frame * stride], stride);
    if GDVars.iconAnimation[imgIdx, imgHalf]^.transp <> nil then
      Move(GDVars.iconAnimation[imgIdx, imgHalf]^.transp^, GDVars.moveIconSheet^.transp^[frame * stride], stride);
    GDVars.moveIconSheet^.mode3Extra := GDVars.iconAnimation[imgIdx, imgHalf]^.mode3Extra;
  end;
end;

procedure BuildIconFacings(imgIdx: Byte);
begin
  CharHlp.CopyIconFacing(imgIdx, 0, 0, 0);
  CharHlp.CopyIconFacing(imgIdx, 0, 1, 1);
  CharHlp.CopyIconFacing(imgIdx, 1, 2, 1);
  CharHlp.CopyIconFacing(imgIdx, 1, 3, 0);
end;

procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; frames, stepDelay: Byte);
var
  { the line's step directions }
  pathBuf: array[0..147] of Byte;
  { the line walk }
  seed: Types.TPathReq;
  { Unused in this version; see the other implementations of this routine. }
  boltLength: array[0..1] of Byte;
  { step index }
  i: Byte;
  { the last step drawn: the step count less 2 }
  lastStep: Byte;
  { the sheet frame drawn next }
  frameIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lastFrame: Byte;
  { 0 walks the line again once the view has moved }
  midFlag: Byte;
  { the walk left the view or reached its end }
  stop: Boolean;
  { the view's center cell }
  cellX: Integer;
  cellY: Integer;
  { Unused in this version; see the other implementations of this routine. }
  xCur: Integer;
  { Unused in this version; see the other implementations of this routine. }
  yCur: Integer;
  { the steps taken toward the next cell, in thirds }
  accX: Integer;
  accY: Integer;
  { the line's extent, in cells }
  deltaX: Integer;
  deltaY: Integer;
  { one step's direction }
  stepDX: Integer;
  stepDY: Integer;
  { the drawing position in the view, in thirds of a cell }
  pxX: Integer;
  pxY: Integer;
  { the shift that keeps a view centered on the target inside the arena }
  clX: Integer;
  clY: Integer;
begin
  xCur := x1;
  yCur := y1;
  FillChar(pathBuf, SizeOf(pathBuf), C_Dir.CENTER);
  FillChar(seed, SizeOf(seed), 0);
  i := 0;
  frameIdx := 0;
  seed.sx := x1 * 3;
  seed.sy := y1 * 3;
  seed.ex := x2 * 3;
  seed.ey := y2 * 3;
  Pathing.PathFind(seed);
  repeat
    stop := Byte(Pathing.NextPathStep(seed)) = 0;
    pathBuf[i] := seed.step;
    Inc(i);
  until stop;
  lastStep := i - 2;
  if (lastStep < 2) or (i < 2) then
    Exit;
  deltaX := x2 - x1;
  deltaY := y2 - y1;
  if (Byte(CbtMap.ViewCoordsValid(x1 - GDVars.combatArenaPtr^.ox, y1 - GDVars.combatArenaPtr^.oy)) = 0) or
      (Byte(CbtMap.ViewCoordsValid(x2 - GDVars.combatArenaPtr^.ox, y2 - GDVars.combatArenaPtr^.oy)) = 0) then begin
    if (Abs(deltaX) <= 6) and (Abs(deltaY) <= 6) then begin
      midFlag := 1;
      cellX := deltaX div 2 + x1;
      cellY := deltaY div 2 + y1;
    end else begin
      midFlag := 0;
      cellX := GDVars.combatArenaPtr^.ox + 3;
      cellY := GDVars.combatArenaPtr^.oy + 3;
    end;
  end else begin
    midFlag := 1;
    cellX := GDVars.combatArenaPtr^.ox + 3;
    cellY := GDVars.combatArenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(Byte(cellX), Byte(cellY), 255, C_Dir.CENTER);
  i := 0;
  accX := 0;
  accY := 0;
  repeat
    pxX := (x1 - GDVars.combatArenaPtr^.ox) * 3 + accX;
    pxY := (y1 - GDVars.combatArenaPtr^.oy) * 3 + accY;
    xCur := x1;
    yCur := y1;
    stop := False;
    repeat
      stepDX := GDConsts.dirDX[pathBuf[i]];
      stepDY := GDConsts.dirDY[pathBuf[i]];
      Inc(pxX, stepDX);
      Inc(pxY, stepDY);
      if (stepDelay > 0) or (pxX mod 3 = 0) or (pxY mod 3 = 0) then begin
        Raster.blitTileClipped(pxX, pxY, frameIdx, 5, GDVars.moveIconSheet, GDVars.viewBuf);
        Raster.FlushView;
        Delay(stepDelay);
        Raster.blitTileClipped(pxX, pxY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
        Inc(frameIdx);
        if frameIdx >= frames then
          frameIdx := 0;
      end;
      Inc(i);
      if (pxX < 0) or (pxX > 18) or (pxY < 0) or (pxY > 18) then
        stop := True;
      if (not stop) and (i < lastStep) then begin
        Inc(accX, stepDX);
        Inc(accY, stepDY);
        if Abs(accX) = 3 then begin
          Inc(x1, Pathing.SignOf(accX));
          Inc(cellX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(y1, Pathing.SignOf(accY));
          Inc(cellY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (i >= lastStep) or stop;
    if i < lastStep then begin
      clX := 0;
      clY := 0;
      accY := 0;
      accX := 0;
      x1 := x2;
      y1 := y2;
      xCur := x1;
      yCur := y1;
      if x2 + 3 > SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
        clX := x2 - (SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1)
      else if x2 < 3 then
        clX := 3 - x2;
      if y2 + 3 > SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1 then
        clY := y2 - (SizeOf(GDVars.combatArenaPtr^.cells) div SizeOf(GDVars.combatArenaPtr^.cells[0]) - 1)
      else if y2 < 3 then
        clY := 3 - y2;
      cellX := x2 + clX;
      cellY := y2 + clY;
      CbtMap.ScrollView(Byte(cellX), Byte(cellY), 255, C_Dir.CENTER);
      pxX := (x2 - GDVars.combatArenaPtr^.ox) * 3;
      pxY := (y2 - GDVars.combatArenaPtr^.oy) * 3;
      i := lastStep;
      stop := False;
      repeat
        stepDX := -GDConsts.dirDX[pathBuf[i]];
        stepDY := -GDConsts.dirDY[pathBuf[i]];
        Inc(pxX, stepDX);
        Inc(pxY, stepDY);
        if pxX > 18 then
          x1 := GDVars.combatArenaPtr^.ox + 6
        else if pxX < 0 then
          x1 := GDVars.combatArenaPtr^.ox;
        if pxY > 18 then
          y1 := GDVars.combatArenaPtr^.oy + 6
        else if pxY < 0 then
          y1 := GDVars.combatArenaPtr^.oy;
        if (pxX < 0) or (pxX > 18) or (pxY < 0) or (pxY > 18) then
          stop := True;
        if not stop then begin
          Inc(accX, stepDX);
          Inc(accY, stepDY);
          if Abs(accX) = 3 then begin
            Inc(x1, Pathing.SignOf(accX));
            Inc(cellX, Pathing.SignOf(accX));
            accX := 0;
          end;
          if Abs(accY) = 3 then begin
            Inc(y1, Pathing.SignOf(accY));
            Inc(cellY, Pathing.SignOf(accY));
            accY := 0;
          end;
          Dec(i);
        end;
      until stop;
    end else begin
      midFlag := 1;
      if Byte(CbtMap.ViewCoordsValid(x2 - GDVars.combatArenaPtr^.ox, y2 - GDVars.combatArenaPtr^.oy)) = 0 then
        CbtMap.ScrollView(Byte(x2), Byte(y2), 3, C_Dir.CENTER);
      pxX := (x2 - GDVars.combatArenaPtr^.ox) * 3;
      pxY := (y2 - GDVars.combatArenaPtr^.oy) * 3;
      Raster.blitTileClipped(pxX, pxY, frameIdx, 5, GDVars.moveIconSheet, GDVars.viewBuf);
      if stepDelay > 0 then begin
        Raster.FlushView;
        Delay(stepDelay);
        Raster.blitTileClipped(pxX, pxY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
      end;
    end;
  until midFlag <> 0;
  Raster.FlushView;
end;

procedure PrintNameStringAnim(cr: Types.PWork; b: Boolean; s: String);
var
  targetX: ShortInt;
  targetY: ShortInt;
  borderCol: Byte;
  j: Byte;
  i: Byte;
  frameDelay: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    if b then
      borderCol := 22
    else
      borderCol := 23;
    CharHlp.BuildIconFacings(borderCol);
    if Byte(CbtMap.CombatIconVisible(cr, 1)) = 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3,
                        C_Dir.CENTER);
    if b then
      SoundDrv.SoundCommand(4)
    else
      SoundDrv.SoundCommand(3);
    CharHlp.PrintCreatureMessage(cr, s, C_Msg.MESSAGE_ROW, False);
    if b then
      frameDelay := GDVars.gameDelay
    else
      frameDelay := 0;
    targetX := GDVars.creatureXCoordinate[CbtMap.CombatSlot(cr)] * 3;
    targetY := GDVars.creatureYCoordinate[CbtMap.CombatSlot(cr)] * 3;
    for i := 0 to frameDelay do
      for j := 0 to 3 do begin
        Raster.blitTileClipped(targetX, targetY, j, 5, GDVars.moveIconSheet, GDVars.viewBuf);
        Raster.FlushView;
        Delay(70);
        Raster.blitTileClipped(targetX, targetY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
      end;
    Raster.FlushView;
    if frameDelay = 0 then
      TextRend.PauseOnly;
  end else
    CharHlp.PrintCreatureMessage(cr, s, C_Msg.MESSAGE_ROW, True);
end;

function HasEffect(p: Types.PWork; effId: Byte; var node: Types.PEffectRec): Boolean;
var
  found: Boolean;
begin
  found := False;
  node := p^.effects;
  while (node <> nil) and (not found) do
    if node^.id = effId then
      found := True
    else
      node := node^.next;
  HasEffect := found;
end;

procedure InflictDamage(cr: Types.PWork; dmg: Byte);
var
  deficit: Byte;
  excess: Byte;
begin
  deficit := 0;
  excess := 0;
  if cr^.hpCur >= dmg then
    excess := cr^.hpCur - dmg
  else
    deficit := dmg - cr^.hpCur;
  if (deficit > 9) or ((excess = 0) and (cr^.status = C_Status.ANIMATED)) then
    cr^.status := C_Status.DEAD_STATUS
  else if deficit > 0 then begin
    cr^.status := C_Status.DYING;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      cr^.combatAddr^.overkill := deficit;
  end else if excess = 0 then
    cr^.status := C_Status.UNCONSCIOUS;
  if not (cr^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    cr^.enabled := 0;
    cr^.hpCur := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[cr^.hostile]);
      cr^.combatAddr^.initiative := 0;
    end;
  end else
    cr^.hpCur := excess;
end;

procedure AnnounceHealStatus(p: Types.PWork);
var
  s: String[40];
begin
  if p^.hpCur = p^.cbHpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintCreatureMessage(p, s, C_Msg.MESSAGE_ROW, True);
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

function NotHostile(p: Types.PWork): Boolean;
begin
  if p^.hostile = 0 then
    NotHostile := True
  else
    NotHostile := False;
end;

function CountTargets(cr: Pointer; a: Byte): Byte;
var
  cnt: Byte;
  keep: Byte;
  i: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), a,
                          255, CbtMap.GetIconSize(cr), Pointer(GDVars.combatArenaPtr));
  cnt := GDVars.targetCount;
  keep := 0;
  if cnt > 0 then begin
    for i := 1 to cnt do begin
      { keep the creature's enemies }
      if GDVars.creaturePtr[GDVars.combatTargetData[i].idx]^.fxHostile = Byte(CharHlp.NotHostile(cr)) then begin
        Inc(keep);
        Move(GDVars.combatTargetData[i], GDVars.combatTargetData[keep], SizeOf(Types.TCombatTarget));
      end;
    end;
    cnt := keep;
    GDVars.targetCount := keep;
  end;
  CountTargets := cnt;
  for i := 1 to cnt do
    GDVars.potentialTargetCreature[i] := GDVars.combatTargetData[i].idx;
end;

function CalcDistance(cr, target: Pointer): Byte;
var
  saved: array[0..764] of Byte;
  i: Byte;
begin
  Move(GDVars.combatTargetData[1], saved, SizeOf(GDVars.combatTargetData));
  GDVars.combatArenaPtr^.distMode := 1;
  Pathing.buildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255,
                          255, CbtMap.GetIconSize(cr), Pointer(GDVars.combatArenaPtr));
  GDVars.combatArenaPtr^.distMode := 0;
  i := 1;
  while (GDVars.creaturePtr[GDVars.combatTargetData[i].idx] <> target) and (i < GDVars.targetCount) do
    Inc(i);
  CalcDistance := GDVars.combatTargetData[i].dist div 2;
  Move(saved, GDVars.combatTargetData[1], SizeOf(GDVars.combatTargetData));
end;

function ClearGuard(p: Types.PWork): Boolean;
begin
  p^.combatAddr^.initiative := 0;
  p^.combatAddr^.spellCast := 0;
  p^.combatAddr^.guarding := 0;
  p^.combatAddr^.movement := 0;
  ClearGuard := True;
end;

function Guard(p: Types.PWork): Boolean;
begin
  Guard := CharHlp.ClearGuard(p);
  p^.combatAddr^.guarding := 1;
  CharHlp.PrintBottomLine('Guarding');
end;

function GetCasterLevel(x: Byte): Byte;
var
  a: ShortInt;
  b: ShortInt;
begin
  if (GDVars.curChar^.b[$109] = 0) and (GDVars.curChar^.b[$10E] = 0)
     and (ShortInt(GDVars.curChar^.b[$10C]) < 9)
     and (ShortInt(GDVars.curChar^.b[$10D]) < 8) then
    GetCasterLevel := 6
  else
    case Char(GDConsts.spellTable[x].castClass) of
      Chr(C_Spell.CLERIC_LIST): begin
           a := ShortInt(GDVars.curChar^.b[$109])
                + ShortInt(GDVars.curChar^.b[$111]) * ClassCal.EarlierClassActive(GDVars.curChar);
           b := ShortInt(GDVars.curChar^.b[$10C])
                + ShortInt(GDVars.curChar^.b[$114]) *
                  ClassCal.EarlierClassActive(GDVars.curChar) - 8;
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      Chr(C_Spell.DRUID_LIST): begin
           a := ShortInt(GDVars.curChar^.b[$10D])
                + ShortInt(GDVars.curChar^.b[$115]) *
                  ClassCal.EarlierClassActive(GDVars.curChar) - 7;
           if a > 0 then GetCasterLevel := a else GetCasterLevel := 0;
         end;
      Chr(C_Spell.MAGIC_USER_LIST): begin
           a := ShortInt(GDVars.curChar^.b[$10E])
                + ShortInt(GDVars.curChar^.b[$116]) * ClassCal.EarlierClassActive(GDVars.curChar);
           b := ShortInt(GDVars.curChar^.b[$10D])
                + ShortInt(GDVars.curChar^.b[$115]) *
                  ClassCal.EarlierClassActive(GDVars.curChar) - 8;
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      #3: GetCasterLevel := 12;
    end;
  if (GDVars.usingItem) and (GDConsts.spellTable[x].castClass <> 3) then
    GetCasterLevel := 6;
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.mapRedrawPending := 1;
  case Char(GDVars.interfaceState) of
    Chr(C_Ifc.MAIN_MENU): Border.DrawWindowFrame;
    Chr(C_Ifc.SHOP_TEMPLE), Chr(C_Ifc.IN_VAULT): begin
         Border.DrawViewFrame;
         if GDVars.picArcId <> C_Pic.NO_PICTURE then
           Portrait.displayImageBuf(3, 3, True, GDVars.animationData.frames[1].pic)
         else begin
           Portrait.loadPortraitBufs(GDVars.currentPortraitHead, GDVars.currentPortraitBody);
           Portrait.displayPortraitBufs(3, 3, True);
         end;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    Chr(C_Ifc.CAMPING): begin
         Border.DrawViewFrame;
         Portrait.loadAnimation('PIC', 29, 0, GDVars.animationData);
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    Chr(C_Ifc.EXPLORING): begin
         Border.DrawViewFrame;
         MapView.DisplayMapView;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
         GDVars.characterSelectionActive := 0;
       end;
    Chr(C_Ifc.LOOT): begin
         Border.DrawViewFrame;
         Portrait.loadAnimation('PIC', 1, 0, GDVars.animationData);
         CharHlp.DisplayParty(GDVars.curChar);
       end;
  end;
end;

procedure PrintPositionAndTime;
var
  mapX: Byte;
  mapY: Byte;
  hourStr: String[2];
  minuteStr: String[2];
  acc: String[40];
begin
  acc := '';
  mapX := GDVars.partyPos.mapX;
  mapY := GDVars.partyPos.mapY;
  hourStr := CharHlp.Uint16Str(GDVars.gbvmZone0Ptr^[C_Gbvm.CLOCK_HOURS]);
  if Length(hourStr) < 2 then
    hourStr := '0' + hourStr;
  minuteStr := CharHlp.Uint16Str(GDVars.gbvmZone0Ptr^[CharHlp.CLOCK_MINUTES] +
                                 GDVars.gbvmZone0Ptr^[CharHlp.CLOCK_TEN_MINUTES] * 10);
  if Length(minuteStr) < 2 then
    minuteStr := '0' + minuteStr;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.NO_AUTOMAP] = 0 then
    acc := CharHlp.Uint8Str(mapX) + ',' + CharHlp.Uint8Str(mapY) + ' ';
  acc := acc + GDConsts.dirNames[GDVars.partyPos.facing] + ' ';
  acc := acc + hourStr + ':' + minuteStr;
  if GDConsts.debugOn <> 0 then
    acc := acc + '*';
  if GDVars.interfaceState = C_Ifc.CAMPING then
    acc := acc + ' camping'
  else if (GDVars.gbvmZone1Ptr^[C_Gbvm.SEARCH_FLAGS] and 1) > 0 then
    acc := acc + ' search'
  else if (GDVars.gbvmZone0Ptr^[CharHlp.BOAT_FLAGS] and 1) <> 0 then
    acc := acc + ' in boat';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, Black, acc);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawCombatFrame;
  if GDVars.displayMode = C_Video.VM_VGA then
    Blit.ShowPic(1, 1, GDConsts.combatFramePic);
  CbtMap.ScrollView(GDVars.combatArenaPtr^.ox + 3, GDVars.combatArenaPtr^.oy + 3, 255, C_Dir.CENTER);
end;

procedure SelectChar(q: Types.TStr40; b: Boolean; var c: Types.PWork);
var
  flag2c: Byte;
  cursor: Types.PWork;
  prompt2: String[40];
  savedBusy: Byte;
begin
  savedBusy := GDVars.canClickParty;
  GDVars.orderState := 1;
  GDVars.orderChar := GDVars.curChar;
  GDVars.menuKey := ' ';
  prompt2 := 'Select';
  { The ' View' choice is never offered. }
  if False then
    prompt2 := ' View';
  if b then
    prompt2 := prompt2 + ' Exit';
  while not (Byte(GDVars.menuKey) in [Ord(C_Keys.NONE), Ord(C_Keys.ENTER), Ord(C_Keys.ESCAPE), Ord('E'),
                                       Ord('S')]) do begin
    CharHlp.DisplayParty(c);
    if (GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.LOOT) then
      flag2c := 1
    else
      flag2c := 0;
    GDVars.canClickParty := 1;
    GDVars.orderChar := c;
    GDVars.menuKey := MenuCore.MenuHorizontal(q + ' ', prompt2, LightMagenta, LightGreen, White, True,
                                                Boolean(flag2c), GDVars.extFlag);
    c := GDVars.orderChar;
    CharHlp.DisplayParty(c);
    cursor := GDVars.creatureList;
    while (cursor <> nil) and (cursor <> c) do
      cursor := cursor^.next;
    if cursor = nil then
      c := GDVars.creatureList;
    GDVars.canClickParty := savedBusy;
    cursor := c;
    if GDVars.extFlag then begin
      case GDVars.menuKey of
        C_Keys.DOWN: begin
               cursor := cursor^.next;
               if cursor = nil then
                 cursor := GDVars.creatureList;
             end;
        C_Keys.UP: begin
               if GDVars.isMouseClick then begin
                 if GDVars.orderState <> 0 then begin
                   if cursor = GDVars.orderChar then
                     GDVars.menuKey := 'S';
                   cursor := GDVars.orderChar;
                 end else begin
                   if cursor = GDVars.curChar then
                     GDVars.menuKey := 'S';
                   cursor := GDVars.curChar;
                 end;
               end else begin
                 cursor := GDVars.creatureList;
                 if c <> GDVars.creatureList then
                   while cursor^.next <> c do
                     cursor := cursor^.next
                 else
                   while cursor^.next <> nil do
                     cursor := cursor^.next;
               end;
             end;
      end;
    end else begin
      if b and ((GDVars.menuKey = 'E') or (GDVars.menuKey = C_Keys.NONE)) then
        cursor := nil;
    end;
    c := cursor;
  end;
  GDVars.orderState := 0;
end;

function HasRangedWeapon(cr: Types.PWork): Boolean;
begin
  if (cr^.equipped[C_Equip.WEAPON] <> nil)
     and (GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasThrowableWeapon(cr: Types.PWork): Boolean;
begin
  if CharHlp.HasRangedWeapon(cr) and
      ((GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].props and C_Item.THROWABLE) =
       C_Item.THROWABLE) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon(p: Types.PWork; var it: Pointer): Boolean;
var
  cur: Types.PItemRec;
  flags: Byte;
begin
  FindDamagingRangedWeapon := False;
  cur := p^.equipped[C_Equip.WEAPON];
  it := nil;
  flags := 0;
  if cur <> nil then begin
    flags := GDVars.baseItems[cur^.itemType].props;
    if (flags and C_Item.THROWN) <> 0 then
      it := cur;
    if (flags and C_Item.FIRES_AMMO) <> 0 then begin
      if (flags and C_Item.USES_ARROWS) <> 0 then
        it := p^.equipped[C_Equip.ARROW];
      if (flags and C_Item.USES_QUARRELS) <> 0 then
        it := p^.equipped[C_Equip.BOLT];
    end;
  end;
  if GDVars.gbvmZone0Ptr^[C_Gbvm.UNDERWATER] = 0 then
    if (it <> nil) or (flags = 10) then
      FindDamagingRangedWeapon := True;
end;

function AtLevelCap(w: Types.PWork; k: ShortInt): Boolean;
var
  lev: ShortInt;
begin
  AtLevelCap := False;
  with w^ do begin
    lev := classLevels[k];
    if lev > 0 then begin
      case Char(race) of
        Chr(C_Race.DWARF): if (k = C_Class.FIGHTER_LEVEL) and
          (((lev = 8) and (strCur = 17)) or ((lev = 7) and (strCur < 17))) then
             AtLevelCap := True;
        Chr(C_Race.ELF): if (k = C_Class.FIGHTER_LEVEL) and
          ((lev = 7) or ((lev = 6) and (strCur = 17)) or ((lev = 5) and (strCur < 17))) then
             AtLevelCap := True;
        Chr(C_Race.GNOME): if (k = C_Class.FIGHTER_LEVEL) and ((lev = 6) or ((lev = 5) and (strCur < 18))) then
             AtLevelCap := True;
        Chr(C_Race.HALF_ELF): if (k = C_Class.CLERIC_LEVEL) and (lev = 5) then
             AtLevelCap := True
           else if (k = C_Class.FIGHTER_LEVEL) and
             ((lev = 8) or ((lev = 7) and (strCur = 17)) or ((lev = 6) and (strCur < 17))) then
             AtLevelCap := True;
        Chr(C_Race.HALFLING): if (k = C_Class.FIGHTER_LEVEL) and
          ((lev = 6) or ((lev = 5) and (strCur = 17)) or ((lev = 4) and (strCur < 17))) then
             AtLevelCap := True;
      end;
    end;
  end;
end;

function MakeItem(itemType,
                  firstNameId, secondNameId, thirdNameId,
                  plus, saveBonus, equipped, unidMask, cursed: Byte; weight: Word; quantity: Byte; value: Word;
                  charges, effect, special: Byte): Types.PItemRec;
var
  p: Types.PItemRec;
begin
  New(p);
  FillChar(p^, SizeOf(p^), 0);
  p^.itemType := itemType;
  p^.nameIds[1] := firstNameId;
  p^.nameIds[2] := secondNameId;
  p^.nameIds[3] := thirdNameId;
  p^.plus := plus;
  p^.saveBonus := saveBonus;
  p^.equipped := equipped;
  p^.unidMask := unidMask;
  p^.cursed := cursed;
  p^.weight := weight;
  p^.quantity := quantity;
  p^.value := value;
  p^.charges := charges;
  p^.effect := effect;
  p^.special := special;
  MakeItem := p;
end;

function BandageDying(bandage: Boolean): Boolean;
var
  pw: Types.PWork;
  found: Boolean;
begin
  found := False;
  pw := GDVars.creatureList;
  while pw <> nil do begin
    if (pw^.combatAddr^.notPcNpc = 0) and (pw^.hostile = 0)
       and (pw^.status = C_Status.DYING) then begin
      found := True;
      if bandage then begin
        pw^.status := C_Status.UNCONSCIOUS;
        pw^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(pw, 'is bandaged', C_Msg.MESSAGE_ROW, True);
        bandage := False;
      end;
    end;
    pw := pw^.next;
  end;
  BandageDying := found;
end;

{ The initialization hooks DisplayParty and Uint8Str into GDVars. }
begin
  GDVars.displayPartyProc := CharHlp.DisplayParty;
  GDVars.uint8StrFunc := CharHlp.Uint8Str;
end.
