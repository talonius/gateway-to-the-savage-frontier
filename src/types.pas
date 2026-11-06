{ The character records, and the smaller record and table types the game units share.

  TWork is the in-memory work record of a party member or a monster, linked through `next`; the character, combat and
  camp overlays index it through a far pointer. Its variant cases are the vocabularies of the units that read it, each
  overlaying the same bytes.

  TCharRecord is the saved character; SaveLoad.ConvertPoolRecord unpacks it field by field into a TWork.

  TItemRec, TBaseItemRec, TSpellTabRec, TEffectRec and TCombatRec are the records those two point at or index. The unit
  is compiled with byte alignment, so no field is padded. }

{$A-}

unit Types;

interface

type
  { an item's identified name components }
  TItemNameIds = array[1..3] of Byte;

  { TItemRec -- one inventory item. Characters, placed treasure and monster items all use this shape; in memory the
    inventory is a linked list through `next`. }
  PItemRec = ^TItemRec;
  TItemRec = record
    name: string[40];
    { 0 for any item (string-list member) }
    inUse: Byte;
    { next item in inventory list }
    next: PItemRec;
    { base-item index (into baseItems) }
    itemType: Byte;
    { identified name components [1]=component 3, [2]=2, [3]=1 }
    nameIds: TItemNameIds;
    { magical bonus }
    plus: ShortInt;
    { saving throw bonus }
    saveBonus: ShortInt;
    { 0 = unequipped, 1 = equipped }
    equipped: Byte;
    { unidentified name components bitmask }
    unidMask: Byte;
    cursed: Byte;
    { weight in coins }
    weight: Word;
    { 0 = single, non-stacking }
    quantity: Byte;
    { value in gold pieces }
    value: Word;
    { Two views of the last three bytes: the item's charges, effect and special, and the Magic overlay's scroll-spell
      ids. }
    case Integer of
      { properties (scroll spells / charges) }
      0: (charges: Byte;
          { effect id }
          effect: Byte;
          { special-item id }
          special: Byte);
      { scroll-spell ids }
      1: (spells: array[1..3] of Byte);
  end;

  { An item's name, inUse and next: a menu string-list node, which carries only these and is allocated at this size. }
  TItemNode = record
    name: String[40];
    inUse: Byte;
    next: PItemRec;
  end;

  { TBaseItemRec -- one ITEMS.1 base item: sixteen bytes of rules, then eight more. ITEMS.1 holds a two-byte prefix and
    128 of these. }
  TBaseItemRec = record
    { equip slot }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice number }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged rate of fire x2 }
    rateOfFire: Byte;
    { AC adjustment descriptor }
    acDescr: Byte;
    { 0 slash / 1 pierce / 128 bash }
    wpnClass: Byte;
    { unused }
    weaponFlag: Byte;
    { damage vs small/medium: dice number }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { ranged range (exclusive) }
    range: Byte;
    { class usability bitmask }
    classMask: Byte;
    { weapon property bits, below }
    props: Byte;
    { unused }
    entryTail: Byte;
    { unused }
    gatewayExt: array[$10..$17] of Byte;
  end;

type
  { TSpellTabRec -- one row of the spell table, indexed by spell id. }
  TSpellTabRec = record
    case Integer of
      { case 0 -- the unsigned spelling, CombatAi's vocabulary with Magic's names where Magic reads the byte. }
      { 0 cleric / 1 druid / 2 mage }
      0: (castClass: Byte;
          { spell level = slot index }
          level: Byte;
          rangeBase: Byte;
          rangePerLevel: Byte;
          durBase: Byte;
          durPerLevel: Byte;
          { Magic tests it nonzero for a touch spell; CbtActs reads its low nibble as the kind of target, whose low 3
            bits are the area's radius for kinds 8 to 14 }
          touch: Byte;
          targeting: Byte;
          { Boolean spelling in case 2 }
          saveResult: Byte;
          saveType: Byte;
          { the effect the spell installs }
          effectId: Byte;
          { 0 = camp-only: CbtActs prints 'Camp Only Spell' on it }
          combatOk: Byte;
          { the casting time: CbtActs.CastSpellCombat takes a third of it off the caster's initiative }
          drainLevels: Byte;
          aiPriority: Byte;
          { nonzero for a spell aimed at enemies; 0 targets the caster or, for a cure, a wounded friend }
          offensive: Byte;
          aiRadius: Byte);
      { case 1 -- the signed spelling of the first two bytes, which Magic uses as subscripts. }
      1: (castClassS: ShortInt;
          levelS: ShortInt);
      { case 2 -- the Boolean spelling of saveResult, which Magic tests as a Boolean and passes to a Boolean
        parameter. }
      2: (saveEffectLead: array[$00..$07] of Byte;
          saveEffect: Boolean);
  end;

  { TEffectRec -- one active-effect node; a creature's effects are a linked list off TWork.effects. }
  PEffectRec = ^TEffectRec;
  TEffectRec = record
    { effect id }
    id: Byte;
    { Two views of the rest: the opaque pad and next, and the named duration, strength and onRemove. }
    case Integer of
      { opaque }
      0: (nextLead: array[0..3] of Byte;
          { next effect }
          next: PEffectRec);
      1: (duration: Word;
          strength: Byte;
          onRemove: Boolean;
          { the same as next }
          nextE: PEffectRec);
  end;

  { TCombatRec -- the combatant record TWork.combatAddr points at. CombatSt allocates and zero-fills one per creature.

    CombatSt sets notPcNpc to 1, once, for a creature past the party's size, and nothing clears it. PostCbt removes a
    creature on 1; CbtMap tests it for 0. }
  { forward: TCharRecord.nextCharAddr }
  PCharRecord = ^TCharRecord;
  { forward: TCombatRec.other }
  PWork = ^TWork;
  PCombatRec = ^TCombatRec;
  TCombatRec = record
    { spell being cast }
    spellCast: Byte;
    { may cast this round }
    castAllowed: Byte;
    { may use an item this round }
    itemUseAllowed: Byte;
    { signed; Combat.NextCreature compares it }
    initiative: ShortInt;
    attackPhase: Byte;
    { level-0 sweep count }
    sweepCount: Byte;
    { movement left this round }
    movement: Byte;
    { guarding flag }
    guarding: Byte;
    madeAttack: Byte;
    { facing 0..7 }
    direction: Byte;
    { opponent/target }
    other: PWork;
    { damage past 0 hp (dying) }
    overkill: Byte;
    attackerCount: Byte;
    { undead-turned flag }
    turned: Byte;
    usedTurnUndead: Byte;
    { flank-attack direction total }
    flankTotal: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    { AI movement stance (1..6) }
    aiStance: Byte;
  end;

  { a combat icon's six color pairs, copied as one block }
  TIcon6 = array[1..6] of Byte;

  { An ability score: its permanent value and its current (effective) value, which FxEngine recomputes from it. }
  TStatPair = record permanent: Byte; current: Byte; end;

  { TWork -- the work record. case 0 is the vocabulary most readers share; each further case carries the names and types
    of a unit whose view of some field differs. }
  TWork = record
    case Integer of
      { creature name }
      0: (name: String[15];
          { 6x ability cells }
          statCells: array[$10..$1B] of Byte;
          { the exceptional-STR percentage after items and effects, and the rolled one it is recomputed from }
          exStrCur: Byte;
          exStrBase: Byte;
          { memorized spells }
          memSpells: array[$1E..$71] of Byte;
          { base spell-prep timer }
          spellPrep: Byte;
          thac0Base: Byte;
          race: ShortInt;
          { single-class id }
          charClass: ShortInt;
          age: Word;
          { its first byte is hpMax }
          knownSpells: array[$78..$DC] of Byte;
          attackLevel: Byte;
          { icon dimensions }
          iconDim: Byte;
          { saving throws }
          saves: array[$DF..$E3] of Byte;
          { movement base }
          moveRate: Byte;
          { SaveLoad.ConvertPoolRecord fills both terrType and movementBase from the saved levelHighest. FxEngine and
            EffHndlr read terrType as terrain and PostCbt reads it as a level (levelHighest * 100, case 3); Magic
            compares movementBase with classLevels2[n], a level. }
          terrType: ShortInt;
          movementBase: ShortInt;
          thiefSkillsLead: array[$E7..$E8] of Byte;
          thiefSkills: array[$E9..$F1] of Byte;
          { far ptr effects }
          effects: PEffectRec;
          effectsTail: Byte;
          { party/NPC status }
          npc: Byte;
          npcTail: array[$F8..$FA] of Byte;
          { purse }
          coinsA: array[0..6] of Word;
          { per-class level }
          classLevels: array[0..7] of ShortInt;
          { per-class 2nd }
          classLevels2: array[0..7] of ShortInt;
          gender: ShortInt;
          charType: Byte;
          alignment: ShortInt;
          { attacks/round }
          attacks: Byte;
          useStrengthLead: array[$11D..$124] of Byte;
          { nonzero when strength adjusts the character's to-hit and damage }
          useStrength: Byte;
          useStrengthTail: Byte;
          experience: LongInt;
          { usable-class mask }
          classMask: Byte;
          classMaskTail: array[$12C..$135] of Byte;
          statBonus: array[0..5] of Byte;
          xpAward: Word;
          xpBonusPerHp: Byte;
          { the HEAD and BODY pictures of the character's portrait }
          portraitHead: Byte;
          portraitBody: Byte;
          { the head and body of the combat icon }
          iconHead: Byte;
          iconBody: Byte;
          { icon-anim slot 0..7 }
          orderNumber: Byte;
          { the combat icon's size, and its six color pairs }
          iconSize: Byte;
          iconColors: TIcon6;
          { the kinds of creature this one is, one bit each, which racial and ranger bonuses test }
          creatureTypeFlags: Byte;
          numberOfItems: Byte;
          { far ptr items }
          itemsAddr: PItemRec;
          { equipped slots }
          equipped: array[0..12] of PItemRec;
          handsEquipped: Byte;
          saveBonus: ShortInt;
          encumbrance: Word;
          { next member }
          next: PWork;
          { combatant rec }
          combatAddr: PCombatRec;
          diseaseCount: Byte;
          { flags the scripts set; FxEngine tests bit 3 of the first }
          scriptFlags: array[0..2] of Byte;
          status: Byte;
          enabled: Byte;
          hostile: ShortInt;
          quickfight: Byte;
          thac0Cur: Byte;
          acCur: Byte;
          { the armor class against attacks from behind }
          acBehind: Byte;
          { attacks this round with the main and the off hand }
          curAttacks: array[1..2] of Byte;
          curRolls: Byte;
          curRollsTail: Byte;
          curDice: Byte;
          curDiceTail: Byte;
          curMod: ShortInt;
          curModTail: Byte;
          hpCur: Byte;
          movementCur: Byte);
      { ---- case 2: the Magic overlay's vocabulary.  Names that agree with
             case 0 in the same place (name, race, movementBase, classLevels,
             classLevels2, charType, itemsAddr, status, hostile, hpCur) are not
             redeclared here; Magic reads those through case 0.  The cells Magic reads
             under its own names carry an mg prefix. ---- }
      2: (mgStrengthLead: array[$00..$10] of Byte;
          { the current strength }
          mgStrength: Byte;
          mgStrengthTail: Byte;
          { the current intelligence }
          mgIntelligence: Byte;
          mgIntelligenceTail: Byte;
          { the current wisdom }
          mgWisdom: Byte;
          mgWisdomTail: array[$16..$17] of Byte;
          { the constitution Raise Dead takes a point from }
          mgConstitution: Byte;
          mgConstitutionTail: array[$19..$1B] of Byte;
          mgExStrCur: Byte;
          mgExStrCurTail: Byte;
          memorizedSpells: array[0..83] of Byte;
          memorizedSpellsTail: array[$72..$74] of Byte;
          mgCharClass: Byte;
          mgCharClassTail: array[$76..$77] of Byte;
          spellsKnown: array[0..99] of Byte;
          spellsKnownTail: Byte;
          mgAttackLevel: Byte;
          iconDimensions: Byte;
          { saves }
          iconDimensionsTail: array[$DF..$E2] of Byte;
          { the saving throw against spells }
          mgSpellSave: Byte;
          mgSpellSaveTail: Byte;
          mgLevelHighest: ShortInt;
          mgLevelHighestTail: array[$E6..$158] of Byte;
          { equipped[2], the armor }
          mgArmor: PItemRec;
          mgArmorTail: array[$15D..$188] of Byte;
          { case 0's next }
          nextCharAddr: PWork;
          { case 0's combatAddr }
          combatLink: PCombatRec;
          combatLinkTail: array[$191..$195] of Byte;
          { case 0's enabled }
          mgEnabled: Byte;
          mgEnabledTail: array[$197..$1A5] of Byte);
      { ---- case 3: PostCbt's vocabulary. Names that agree in the same place
             (name, charClass, npc, coinsA, experience, xpAward, xpBonusPerHp,
             itemsAddr, combatAddr, status, enabled, hostile through case 0;
             memorizedSpells and nextCharAddr through case 2) are not
             redeclared. This branch carries PostCbt's own names: the cur stat
             cells, levelHighest, modified, pcGender, pcHpRolled and pcHpCur. ---- }
      3: (strCurLead: array[$00..$10] of Byte;
          { str cur }
          strCur: Byte;
          strCurTail: Byte;
          { int cur }
          intCur: Byte;
          intCurTail: Byte;
          { wis cur }
          wisCur: Byte;
          wisCurTail: Byte;
          { dex cur }
          dexCur: Byte;
          dexCurTail: array[$18..$E4] of Byte;
          { signed }
          levelHighest: ShortInt;
          levelHighestTail: array[$E6..$F7] of Byte;
          modified: Byte;
          modifiedTail: array[$F9..$118] of Byte;
          { case 0's gender, as a byte }
          pcGender: Byte;
          pcGenderTail: array[$11A..$12B] of Byte;
          pcHpRolled: Byte;
          pcHpRolledTail: array[$12D..$1A3] of Byte;
          { case 0's hpCur }
          pcHpCur: Byte;
          pcHpCurTail: Byte);
      { ---- case 4: SaveLoad's vocabulary, which LoadChar uses to unpack a saved or imported character. Names that
             agree with case 0 in the same place and type are reused (name, thac0Base, age, attackLevel, saves,
             moveRate, npc, charType, attacks, useStrength, experience, classMask, xpAward through orderNumber,
             numberOfItems, handsEquipped, encumbrance, status, enabled, quickfight, thac0Cur, curAttacks, hpCur,
             movementCur), and so are case 2's iconDimensions, case 3's modified, case 12's attacks2, case 13's
             drainedLevels and drainedHps and case 15's baseMod. The sl prefix marks a cell another case names with
             another type or place, and the class levels. ---- }
      4: (slStatsLead: array[$00..$0F] of Byte;
          { the ability scores, then the exceptional strength as [6] }
          slStats: array[0..6] of TStatPair;
          slRaceLead: array[$1E..$73] of Byte;
          slRace: Byte;
          slCharClass: Byte;
          hpMaxLead: array[$76..$77] of Byte;
          hpMax: Byte;
          slSpellsKnown: array[$79..$82] of Byte;
          knowsDetectMagic: Byte;
          knowsDetectMagicTail: array[$84..$89] of Byte;
          knowsReadMagic: Byte;
          knowsShield: Byte;
          knowsShieldTail: Byte;
          knowsSleep: Byte;
          knowsSleepTail: array[$8E..$9B] of Byte;
          knowsAnimateDead: Byte;
          slLevelHighestLead: array[$9D..$E4] of Byte;
          slLevelHighest: Byte;
          levelAtChange: Byte;
          slLevelUndeadLead: array[$E7..$E8] of Byte;
          slLevelUndead: Byte;
          slThiefSkills: array[1..8] of Byte;
          slEffectsAddr: Pointer;
          afterEffects: Byte;
          afterModifiedLead: array[$F7..$F8] of Byte;
          afterModified: Byte;
          beforeCoins: Byte;
          platinumLead: array[$FB..$102] of Byte;
          { ConvertPoolRecord stores 300 }
          platinum: Word;
          platinumTail: array[$105..$108] of Byte;
          slClericLevel: Byte;
          slDruidLevel: Byte;
          slFighterLevel: Byte;
          slPaladinLevel: Byte;
          slRangerLevel: Byte;
          { signed }
          slMageLevel: ShortInt;
          slThiefLevel: Byte;
          thiefLevelTail: array[$110..$118] of Byte;
          slGender: Byte;
          slAlignmentLead: Byte;
          slAlignment: Byte;
          slBaseRollsLead: array[$11C..$11D] of Byte;
          slBaseRolls: Byte;
          secondBaseRolls: Byte;
          slBaseDice: Byte;
          secondBaseDice: Byte;
          acBaseLead: array[$122..$123] of Byte;
          acBase: Byte;
          randomIdLead: Byte;
          { the id the creature's combat icon is loaded by: a monster's record number, a new character's random byte }
          randomId: Byte;
          hpRolledLead: array[$127..$12B] of Byte;
          hpRolled: Byte;
          clericSlots: array[1..3] of Byte;
          clericSlotsTail: array[$130..$135] of Byte;
          { [0] is the druid row's last cell; [1..3] are the magic-user slots }
          mageSlots: array[0..3] of Byte;
          iconSizeColorsLead: array[$13A..$143] of Byte;
          iconSizeColors: array[0..7] of Byte;
          slItemsAddrLead: Byte;
          slItemsAddr: Pointer;
          slEquipped: array[0..12] of Pointer;
          slSaveBonusLead: Byte;
          slSaveBonus: Byte;
          scriptFlagLead: array[$187..$191] of Byte;
          { MergeHillsfarRecord sets it }
          scriptFlag: Byte;
          slHostileLead: array[$193..$196] of Byte;
          slHostile: Byte;
          slAcCurLead: array[$198..$199] of Byte;
          slAcCur: array[0..1] of Byte;
          slCurRollsLead: array[$19C..$19D] of Byte;
          slCurRolls: array[1..2] of Byte;
          slCurDice: array[1..2] of Byte;
          slCurMod: array[1..2] of Byte;
          slCurModTail: array[$1A4..$1A5] of Byte);
      { ---- case 5: the spell-preparation fields. Names already in case 0 in
             the same place (effects, next, status, enabled, hpCur, name) are
             reused. Its known and slots are 0-based arrays that do not alias
             case 0's arrays.  Its mem has no reader (Camp reads case 2's
             memorizedSpells). ---- }
      5: (memLead: array[$00..$1D] of Byte;
          { memorized }
          mem: array[0..83] of Byte;
          { base spell-prep code }
          prepBase: Byte;
          prepBaseTail: array[$73..$77] of Byte;
          { known spells }
          known: array[0..121] of Byte;
          { its last byte is hpRolled }
          knownTail: array[$F2..$12C] of Byte;
          { slots starts at its first cell, just past hpRolled, and the level is 1-based so the subscript names the
            level. SaveLoad.ConvertPoolRecord copies the saved hpRolled as a scalar, then for each level 1 to 3 the
            saved cleric and mage bonus slots into level j of these rows. Rows are spell classes, as camp's 'Cleric
            Spells:' / 'Druid Spells:' / 'Magic-User Spells:' labels name them: 0 Cleric, 1 Druid, 2 Magic-User. }
          { [class,level] }
          slots: array[0..2, 1..5] of Byte;
          slotsTail: array[$13C..$14C] of Byte;
          { item/scroll list }
          items: Pointer;
          itemsTail: array[$151..$1A5] of Byte);
      { ---- case 6: GameTime's shape of two fields -- a signed spell-prep timer
             (case 0's spellPrep is Byte) and a 0-based known-spells array, which
             GameTime reads. ---- }
      6: (restSpellPrepLead: array[$00..$71] of Byte;
          { signed spell-prep timer }
          restSpellPrep: ShortInt;
          restSpellPrepTail: array[$73..$77] of Byte;
          { 0-based known spells }
          restKnown: array[0..100] of Byte;
          restKnownTail: array[$DD..$1A5] of Byte);
      { ---- case 7: EclMenu's divergent-shape fields. EclMenu reads most fields
             through case 0 (name, race, charClass, terrType, npc, coinsA,
             gender, alignment, xpAward, xpBonusPerHp, orderNumber, status,
             enabled, hostile, quickfight, hpCur, movementCur, itemsAddr,
             effects), case 2 (memorizedSpells, nextCharAddr) and case 3
             (intCur). These seven differ in place or structure: two cur stat
             cells not in case 3 (emConCur, emChaCur), a scalar inside case 0's
             saves, thiefSkills based one byte later than case 0's, two signed
             per-class views, and a scalar inside case 0's scriptFlags. ---- }
      7: (emConCurLead: array[$00..$18] of Byte;
          { con cur }
          emConCur: Byte;
          emConCurTail: Byte;
          { cha cur }
          emChaCur: Byte;
          emChaCurTail: array[$1C..$DF] of Byte;
          { the second saving throw, read by SpecialReadZ1 }
          emSecondSave: Byte;
          emSecondSaveTail: array[$E1..$E9] of Byte;
          { base-1 }
          emThiefSkills: array[1..8] of Byte;
          emThiefSkillsTail: array[$F2..$108] of Byte;
          emClassA: array[0..7] of ShortInt;
          emClassB: array[0..7] of ShortInt;
          emClassBTail: array[$119..$191] of Byte;
          { the first script flag byte, of which SpecialReadZ1 reads bit 0 }
          emScriptFlag: Byte;
          emScriptFlagTail: array[$193..$1A5] of Byte);
      { ---- case 8: FxEngine's vocabulary.
             Reuses case 0 (exStrCur, exStrBase, terrType, effects,
             npc, saveBonus, next, combatAddr, status, enabled,
             thac0Cur, acCur, hpCur), case 3 (pcHpRolled) and case 5
             (items). Carries FxEngine's divergent-shape/type fields: structured
             stat pairs, a Byte hpMax, 0-based saves, a Byte level at the class
             change, Byte per-class arrays and a Byte hostile. ---- }
      8: (fxStatsLead: array[$00..$0F] of Byte;
          { the ability scores }
          fxStats: array[0..5] of TStatPair;
          fxStatsTail: array[$1C..$77] of Byte;
          fxHpMax: Byte;
          fxHpMaxTail: array[$79..$DE] of Byte;
          { 0-based saving throws }
          fxSaves: array[0..4] of Byte;
          fxSavesTail: array[$E4..$E5] of Byte;
          { the level a dual-classed human had in the class it left; case 0's movementBase is ShortInt }
          fxLevelAtChange: Byte;
          fxLevelAtChangeTail: array[$E7..$108] of Byte;
          { Byte per-class }
          fxClassA: array[0..7] of Byte;
          { Byte per-class 2nd }
          fxClassB: array[0..7] of Byte;
          fxClassBTail: array[$119..$196] of Byte;
          { case 0's hostile is ShortInt }
          fxHostile: Byte;
          fxHostileTail: array[$198..$1A5] of Byte);
      { ---- case 9: EclVm's creature-record vocabulary. Its creature view
             reads case 0 and case 2 except for two fields whose shape
             diverges: hpMax is a scalar here (case 0 has it as the first byte
             of knownSpells) and thiefSkills is a 0-based array[0..8]. charClass
             reuses case 0 (it is only compared for equality, so its sign does
             not matter); npc, orderNumber, status, thac0Cur, acCur, hpCur,
             movementCur and enabled come through case 0 or 2; nextCharAddr
             through case 2; effects, itemsAddr, classLevels and classLevels2
             through case 0. ---- }
      9: (evMaxHpLead: array[$00..$77] of Byte;
          { scalar hpMax }
          evMaxHp: Byte;
          evMaxHpTail: array[$79..$E8] of Byte;
          { 0-based thief band }
          evThiefSkills: array[0..8] of Byte;
          evThiefSkillsTail: array[$F2..$1A5] of Byte);
      { ---- case 10: temple's creature-record vocabulary. Reuses case 0 for
             classLevels, itemsAddr, status, enabled and hpCur. Carries
             temple's four divergent-shape fields: a String[24] name view (case
             0 is String[15]; temple's concatenation needs the longer maximum),
             a scalar conCur (case 0 folds it into statCells), a scalar hpMax
             (case 0 has the first byte of knownSpells) and a scalar hpRolled
             (case 0 leaves it unnamed). ---- }
      { len byte + 24 chars }
      10: (tpName: String[24];
           { con cur }
           tpConCur: Byte;
           tpConCurTail: array[$1A..$77] of Byte;
           { scalar hpMax }
           tpHpMax: Byte;
           tpHpMaxTail: array[$79..$12B] of Byte;
           tpHpRolled: Byte;
           tpHpRolledTail: array[$12D..$1A5] of Byte);
      { ---- case 11: CombatAi's AI work-record vocabulary.
             Reuses case 0 (npc, classLevels, itemsAddr, equipped, handsEquipped,
             combatAddr, status, enabled, hostile, quickfight, hpCur), case 2
             (memorizedSpells, 0-based, and nextCharAddr) and case 3 (intCur).
             Carries CombatAi's divergent-shape/type scalars: two Byte views that
             case 0 declares ShortInt (caCharClass, caAlignment), a Byte hpMax
             (case 0 has the first byte of knownSpells and case 2 has none,
             hence the ca prefix), and the AI scalars case 0 folds into
             arrays (caLevelHighest, levelUndead, unarmedRollsA1,
             unarmedDiceA1, unarmedModA1, itemLimits). ---- }
      11: (caCharClassLead: array[$00..$74] of Byte;
           { case 0's charClass is ShortInt }
           caCharClass: Byte;
           caCharClassTail: array[$76..$77] of Byte;
           { scalar hpMax }
           caHpMax: Byte;
           caHpMaxTail: array[$79..$E4] of Byte;
           { the highest class level, which the AI's intelligence gate compares }
           caLevelHighest: ShortInt;
           caLevelHighestTail: array[$E6..$E8] of Byte;
           levelUndead: ShortInt;
           levelUndeadTail: array[$EA..$11A] of Byte;
           { case 0's alignment is ShortInt }
           caAlignment: Byte;
           caAlignmentTail: array[$11C..$11D] of Byte;
           unarmedRollsA1: Byte;
           unarmedRollsA1Tail: Byte;
           unarmedDiceA1: Byte;
           unarmedDiceA1Tail: Byte;
           unarmedModA1: ShortInt;
           unarmedModA1Tail: array[$123..$12A] of Byte;
           itemLimits: Byte;
           itemLimitsTail: array[$12C..$1A5] of Byte);
      { ---- case 12: CbtActs's combat-actions work-record vocabulary.
             Reuses case 0 (npc, classLevels, attacks, orderNumber, combatAddr,
             status, enabled, hostile, quickfight, hpCur, movementCur, iconDim),
             case 2 (nextCharAddr) and case 11 (levelUndead). Carries
             CbtActs's own divergent-shape/type fields: three Byte scalars whose
             names collide with a field of another type or place elsewhere
             (cbHpMax; cbAttackLevel -- case 0's attackLevel;
             cbLevelHighest -- case 3's levelHighest is ShortInt), a ShortInt
             cbOldThiefLevel, attacks2, the weapon and armor slots (cbWeapon,
             cbArmor), and the [1..2] main/off-hand cur-stat array views case 0
             folds into scalars (acCurArr, curAtt, curRollsA, curDiceA,
             curModA). ---- }
      12: (cbHpMaxLead: array[$00..$77] of Byte;
           cbHpMax: Byte;
           cbHpMaxTail: array[$79..$DC] of Byte;
           cbAttackLevel: Byte;
           cbAttackLevelTail: array[$DE..$E4] of Byte;
           { case 3's levelHighest is ShortInt }
           cbLevelHighest: Byte;
           cbLevelHighestTail: array[$E6..$116] of Byte;
           { the thief level a dual-classed human left, which multiplies a backstab (signed) }
           cbOldThiefLevel: ShortInt;
           cbOldThiefLevelTail: array[$118..$11C] of Byte;
           attacks2: Byte;
           attacks2Tail: array[$11E..$150] of Byte;
           { equipped[0], the weapon }
           cbWeapon: PItemRec;
           cbWeaponTail: array[$155..$158] of Byte;
           { equipped[2], the armor }
           cbArmor: PItemRec;
           cbArmorTail: array[$15D..$199] of Byte;
           { acCur, acBehind }
           acCurArr: array[0..1] of Byte;
           curAtt: array[1..2] of Byte;
           curRollsA: array[1..2] of Byte;
           curDiceA: array[1..2] of Byte;
           curModA: array[1..2] of ShortInt;
           curModATail: array[$1A4..$1A5] of Byte);
      { ---- case 13: CharGen's character-creation vocabulary. CharGen
             carries its whole layout here, with a cg prefix on the cells
             case 0 also names; the fields whose name, place and type match
             case 0 are padded over and reused (name, race, charClass, age,
             coinsA, gender, itemsAddr, next, combatAddr, hpCur). ---- }
      { name (reuse case 0) }
      13: (statLead: array[$00..$0F] of Byte;
           { the ability scores }
           stat: array[0..5] of TStatPair;
           { exceptional-STR pct }
           exStrPct: Byte;
           cgExStrBase: Byte;
           cgExStrBaseTail: array[$1E..$72] of Byte;
           cgThac0Base: Byte;
           { race/charClass/age }
           cgThac0BaseTail: array[$74..$77] of Byte;
           { hpMax, then the ready and known spells }
           clsFlags: array[0..100] of Byte;
           clsFlagsTail: Byte;
           cgIconDim: Byte;
           cgIconDimTail: array[$DF..$E3] of Byte;
           cgMoveRate: Byte;
           cgLevelHighest: ShortInt;
           cgLevelAtChange: ShortInt;
           { from the saved drainedLevels (loadGame) }
           drainedLevels: Byte;
           { from the saved drainedHps (loadGame) }
           drainedHps: Byte;
           drainedHpsTail: array[$E9..$F1] of Byte;
           { effect list head }
           effectsAddr: PEffectRec;
           effectsAddrTail: Byte;
           cgNpc: Byte;
           cgModified: Byte;
           { coinsA (reuse case 0) }
           cgModifiedTail: array[$F9..$108] of Byte;
           { per-class level }
           lvl: array[0..7] of ShortInt;
           { the levels of the classes a dual-classed human has left }
           cgOldClassLevels: array[0..7] of ShortInt;
           { gender (reuse case 0) }
           cgOldClassLevelsTail: Byte;
           cgCharType: Byte;
           cgAlignment: Byte;
           cgAttacks: Byte;
           cgAttacks2: Byte;
           cgBaseRolls: array[1..2] of Byte;
           cgBaseDice: array[1..2] of Byte;
           cgBaseMod: array[1..2] of ShortInt;
           cgAcBase: Byte;
           cgUseStrength: Byte;
           cgRandomId: Byte;
           { experience }
           exp: LongInt;
           cgClassMask: Byte;
           { training-HP accumulator }
           cgHpRolled: Byte;
           { [spell class, level] }
           cgSpellSlots: array[0..2, 1..5] of Byte;
           cgSpellSlotsTail: array[$13C..$142] of Byte;
           { icon-anim order number }
           orderNum: Byte;
           { the icon size, then its six color pairs }
           cgIconSizeColors: array[0..8] of Byte;
           cgIconSizeColorsTail: array[$14D..$190] of Byte;
           cgDiseaseCount: Byte;
           cgScriptFlags: array[0..2] of Byte;
           { drop-message discriminator }
           cgStatus: Byte;
           cgEnabled: Byte;
           cgEnabledTail: array[$197..$1A5] of Byte);
      { ---- case 14: ClassCal's class-calc vocabulary. Reuses name, race and
             attacks (case 0), known (case 5) and lvl (case 13). Carries
             ClassCal's own fields, including the ability scores (stats)
             and a nested variant after the class mask: the cleric and
             magic-user slot rows, and over them the druid row, whose first
             cell is cleric[5]. Its 0-based saves is clSaves. ---- }
      { name (reuse case 0) }
      14: (statsLead: array[$00..$0F] of Byte;
           { the ability scores }
           stats: array[0..5] of TStatPair;
           clMemorizedSpellsLead: array[$1C..$1D] of Byte;
           clMemorizedSpells: array[0..83] of Byte;
           clSpellPrep: Byte;
           { best THAC0 over the character's classes }
           levelHi: Byte;
           { race (reuse case 0) }
           levelHiTail: Byte;
           { the class ChangeClass switches to (case 0's charClass) }
           clCharClass: Byte;
           { known (reuse case 5); ClassCal does not use the rest }
           clCharClassTail: array[$76..$DE] of Byte;
           { 0-based saving throws }
           clSaves: array[0..4] of Byte;
           clSavesTail: Byte;
           { highest class level }
           clLevelHighest: ShortInt;
           { highest class level when the character dual-classed }
           clLevelAtChange: ShortInt;
           clLevelAtChangeTail: array[$E7..$E8] of Byte;
           { thief skills, from index 1 }
           thiefSk: array[0..8] of Byte;
           { lvl (reuse case 13) }
           thiefSkTail: array[$F2..$110] of Byte;
           { levels in the classes a dual-classed human has left }
           clOldClassLevels: array[0..7] of ShortInt;
           clOldClassLevelsTail: array[$119..$11A] of Byte;
           { the alignment ChangeClass checks }
           clAlignment: Byte;
           { attacks/useStrength (reuse case 0) }
           clAlignmentTail: array[$11C..$126] of Byte;
           { case 0's experience; zeroed when the character dual-classes }
           clExperience: LongInt;
           { usable-class bitmask }
           clClassMask: Byte;
           case Integer of
            { cleric spell slots by level }
            0: (cleric: array[0..5] of Byte;
                clericTail: array[$132..$135] of Byte;
                { magic-user spell slots by level }
                clMageSlots: array[0..5] of Byte;
                clMageSlotsTail: array[$13C..$14C] of Byte;
                { inventory list head }
                itemsHd: PItemRec;
                { equipped items }
                equip: array[0..12] of PItemRec;
                equipTail: array[$185..$1A5] of Byte);
            1: (clDruidSlotsLead: array[$12C..$130] of Byte;
                { druid spell slots a ranger gains }
                clDruidSlots: array[0..7] of Byte;
                clDruidSlotsTail: array[$139..$1A5] of Byte));

      { CharHlp's flat byte view: it reads fields by index into b and casts a signed one to ShortInt where it reads
        it. }
      1: (b: array[$00..$1A5] of Byte);

      { CharHlp.RecalcStats copies these three pairs with a variable index, which case 11's scalars cannot address; the
        destinations are case 12's curRollsA, curDiceA and curModA. }
      15: (baseRollsLead: array[$00..$11D] of Byte;
           baseRolls: array[1..2] of Byte;
           baseDice: array[1..2] of Byte;
           baseMod: array[1..2] of Byte;
           baseModTail: array[$124..$1A5] of Byte);

      { ViewChar's signed status, which it uses to index statusNames. }
      16: (statusSLead: array[$00..$194] of Byte;
           { signed status }
           statusS: ShortInt;
           statusSTail: array[$196..$1A5] of Byte);
  end;

  TCharRecord = record
    name: string[15];
    { the six ability scores, strength to charisma, indexed by C_Stat }
    abilities: array[0..5] of Byte;
    { exceptional strength (18/xx pct) }
    strExc: Byte;
    { currently memorized }
    memorizedSpells: array[0..20] of Byte;
    spellPrepTime: Byte;
    { base THAC0 }
    thac0Base: Byte;
    { race }
    race: ShortInt;
    { class, as C_Class's class values; signed }
    charClass: ShortInt;
    age: Word;
    { hit points maximum }
    hpMax: Byte;
    { spellbook flags, indexed by spell id }
    spellsKnown: array[1..56] of Byte;
    attackLevel: Byte;
    iconDimensions: Byte;
    { the saving throws: paralysis, petrification, wands, breath and spells; ConvertPoolRecord moves them to the work
      record's saves }
    saves: array[0..4] of Byte;
    movementBase: Byte;
    { highest single-class level }
    levelHighest: ShortInt;
    drainedLevels: Byte;
    drainedHps: Byte;
    { turn-undead level, signed }
    levelUndead: ShortInt;
    { pick pockets, open locks, find traps, move silently, hide, hear noise, climb walls and read languages }
    thiefSkills: array[1..8] of Byte;
    { far ptr to effects list }
    effectsAddr: PEffectRec;
    afterEffects: Byte;
    { party/NPC status (0 = PC, >=$80 = NPC) }
    npc: Byte;
    modified: Byte;
    afterModified: Byte;
    beforeCoins: Byte;
    { copper, silver, electrum, gold, platinum, gems and jewelry }
    coinsA: array[0..6] of Word;
    { cleric, druid, fighter, paladin, ranger, magic-user, thief and monk levels }
    classLevels: array[0..7] of ShortInt;
    { 0 male, 1 female }
    gender: Byte;
    charType: Byte;
    alignment: Byte;
    { attacks per round }
    attacks: Byte;
    attacks2: Byte;
    { unarmed dice rolls }
    unarmedRollsA: array[1..2] of Byte;
    { unarmed dice sides }
    unarmedDiceA: array[1..2] of Byte;
    { unarmed dmg mods }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    { strength to-hit/damage applies }
    useStrength: Byte;
    { identity byte (Random(256) at creation; dup-character detection) }
    randomId: Byte;
    experience: LongInt;
    itemLimits: Byte;
    hpRolled: Byte;
    { the bonus cleric slots by level, from Wisdom }
    clericSpells: array[1..3] of Byte;
    mageSpells: array[1..3] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    portraitHead: Byte;
    portraitBody: Byte;
    iconHead: Byte;
    iconBody: Byte;
    { icon-animation slot index (0..7) }
    orderNumber: Byte;
    iconSize: Byte;
    { packed color pairs: body, arm, leg, hair, shield and weapon }
    iconColors: TIcon6;
    numberOfItems: Byte;
    { far ptr to item list }
    itemsAddr: PItemRec;
    { weapon, shield, armor, gauntlets, helm, belt, robe, cloak, boots, two rings, arrows and quarrels }
    equipped: array[0..12] of PItemRec;
    handsEquipped: Byte;
    { accumulated save bonus (signed) }
    saveBonus: ShortInt;
    encumbrance: Word;
    { far ptr to next character }
    nextCharAddr: PCharRecord;
    { far ptr to combatant }
    combatAddr: PCombatRec;
    { a subrange, used as an index and in sets }
    status: 0..127;
    enabled: Byte;
    { team index }
    hostile: ShortInt;
    quickfight: Byte;
    { current THAC0 }
    thac0Cur: Byte;
    { current AC }
    acCur: Byte;
    acBehind: Byte;
    curAttacks: Byte;
    curAttacks2: Byte;
    { current dice rolls }
    curRollsA: array[1..2] of Byte;
    { current dice sides }
    curDiceA: array[1..2] of Byte;
    { current dmg mods }
    curModA: array[1..2] of ShortInt;
    { current hit points }
    hpCur: Byte;
    { current movement }
    movementCur: Byte;
  end;

type
  { Types the code units share with the storage they read. }
  PBytes = ^TBytes; TBytes = array[0..65000] of Byte;
  { 48 4-bit color levels, two a byte }
  TPalette24 = array[0..23] of Byte;
  { one of Blit.RemapPic's color lists }
  TColorTab = array[0..15] of Byte;
  { A picture in the display mode's layout: a header, then its frames. }
  PImgBuf = ^TImgBuf;
  TImgBuf = record
    height: Word;
    width: Word;
    originX: Word;
    originY: Word; count: Byte;
    palette: TPalette24; frameSize: Word; allocSize: Word;
    { the transparent color, which the VGA blits key on }
    mode3Extra: Byte;
    currentFrame: Word; transp: PBytes;
    data: array[0..32000] of Byte
  end;
  { a display color for each of a picture's 32 colors }
  TMap32 = array[0..31] of Byte;
  { A DAX picture's color header, as Blit.DecodePalette decodes it for the display mode. }
  TPaletteInfo = record
    { the header's Pal* bits }
    flags: Byte;
    map: TMap32;
    { VGA: the picture's palette; CGA: map as packed nibbles }
    palette: TPalette24;
    { VGA: 255 when the picture carries a palette }
    vgaIndex: Word
  end;
  { One frame of an animation: its display time, in tenths of a second, and its picture. }
  TAnimFrame = record
    delay: LongInt;
    pic: PImgBuf;
  end;
  { An animation: the frames loaded, the frame showing, from 1, and the frames. }
  TAnimRec = record
    count: Byte;
    current: Byte;
    frames: array[1..8] of TAnimFrame;
  end;

  { The seven money types: copper, silver, electrum, gold and platinum coins, then gems and jewelry. }
  TMoney = array[0..6] of LongInt;

  { a far pointer's offset and segment words }
  TPointerWords = record
    ofs: Word;
    seg: Word;
  end;

  { a time in clock digits, segments to years }
  TClock = array[0..6] of Word;

  { a GOSUB return address, stacked on the heap }
  PEclRet = ^TEclRet;
  TEclRet = record
    addr: Word;
    next: PEclRet;
  end;

  { The GBVM banks, each declared at its GBVM addresses so an address indexes it directly: three of words, and the
    script's bytes. }
  TZone0 = array[$4B00..$4EFF] of Word;
  PZone0 = ^TZone0;
  TZone1 = array[$7C00..$7FFF] of Word;
  PZone1 = ^TZone1;
  TZone2 = array[$7A00..$7BFF] of Word;
  PZone2 = ^TZone2;
  TZone3 = array[$8000..$9DFF] of Byte;
  PZone3 = ^TZone3;

  { which of an encounter's pictures are loaded: [0] its sprite, [1] its close-up }
  TMonFlags = array[0..1] of Boolean;

  { A WALLDEF wall set: five wall types of 156 cells each, the ten view slots' shapes laid end to end. }
  TWallDef = array[1..5, 0..155] of Byte;
  { three wall sets }
  TWallDefs = array[1..3] of TWallDef;
  { The wall sets in GDVars.wallGfx, two views of the same bytes: LoadWallSet copies and renumbers [set 1..3][wall type
    1..5][cell], and DrawWallSlice indexes [wall type 1..15][cell], 156 cells to a wall type, the ten view slots' shapes
    laid end to end (viewSlotGeom). }
  PWallGfx = ^TWallGfx;
  TWallGfx = record
    case Integer of
      0: (sets: TWallDefs);
      1: (slices: array[1..15, 0..155] of Byte);
  end;

  { A GEO map plane: one byte per cell, indexed [y, x]. }
  TGeoPlane = array[0..15, 0..15] of Byte;
  { A GEO map as View3D's Load3DMap copies it into GDVars.map3d. }
  TGeoMap = record
    { the north wall in the high nibble, the east wall in the low }
    wallsNE: TGeoPlane;
    { the south wall in the high nibble, the west wall in the low }
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    { two bits a side: west in bits 7..6, south 5..4, east 3..2, north 1..0 }
    barriers: TGeoPlane;
  end;
  PGeoMap = ^TGeoMap;

  { The game font, 8X8D1.DAX record 201: 177 glyphs of eight bytes, a byte to a row. }
  PFont = ^TFont;
  TFont = array[0..176] of array[0..7] of Byte;

  { a message or name line, and a longer line }
  TStr40 = String[40];
  TStr80 = String[80];

  TMessageProc = procedure(s: String);
  TNoArgProc = procedure;

  { TextRend.DisplayStatusAndWait }
  TStatusProc = procedure(s: String);

  { TextRend.LongToString }
  TLongToStringFunc = function(value: LongInt): String;

  { CharHlp.DisplayParty }
  TDisplayPartyProc = procedure(cur: PWork);

  { CharHlp.Uint8Str }
  TUint8StrFunc = function(value: Byte): String;

  { an effect's handler, which FxEngine calls by effect id: the creature, the effect node or item, and whether the
    effect is being removed }
  TEffectHandler = procedure(cr: PWork; p: Pointer; removed: Boolean);
  { a spell's handler }
  TSpellProc = procedure;
  { the cast-target menu: Magic's out of combat, CbtActs' in combat }
  TTargetMenuProc = procedure(spell: Byte; b: Boolean; var sel: Boolean);
  { the cast-target menu, then the spell handlers by spell id }
  TSpellFps = record
    targetMenu: TTargetMenuProc;
    spells: array[1..100] of TSpellProc;
  end;

  { TArenaNode -- a node of the two cloud lists GDVars holds: linkedListStinkingPtr (Stinking Cloud, four cells) and
    cloudkillList (Cloudkill, nine cells). Magic builds each node, EffHndlr frees one when its cloud ends, and Combat
    frees both lists after the battle. under and exists hold nine cells, the Cloudkill's extent: EffClearCloudkill and
    SpellCloudkill index them 1..9, and the Stinking Cloud code uses the first four. Magic writes idx and
    EffClearStinkingCloud matches on it (as hi); SpellDispelMagic tests and sets resolved. The variant cases give each
    reader its own names for the same bytes; next is named in case 0 alone, and the first field is the owning creature
    in each. }
  PArenaNode = ^TArenaNode;
  TArenaNode = record
    case Byte of
      { case 0 -- the names Magic's cloud code, EffHndlr's Cloudkill code and Combat's teardown use. }
      { owner/caster }
      0: (caster: PWork;
          { next node }
          next: PArenaNode;
          { saved tiles }
          under: array[1..9] of Byte;
          { per-cell live }
          exists: array[1..9] of Byte;
          { origin column }
          ulX: ShortInt;
          { origin row }
          ulY: ShortInt;
          { match key, unsigned }
          idx: Byte;
          { one-shot flag: Magic tests it for 0 as a guard and sets it to 1 when the caster did not resist, so the node
            is visited at most once }
          resolved: Byte);
      { case 1 -- FxEngine's arena-search vocabulary. }
      { the same as caster }
      1: (data: PWork;
          { the same as next }
          dataTail: array[$04..$07] of Byte;
          { the same as under }
          cellLiveLead: array[$08..$10] of Byte;
          { the same as exists }
          cellLive: array[1..9] of Byte;
          { the same as ulX }
          cellX: ShortInt;
          { the same as ulY }
          cellY: ShortInt);
      { case 2 -- EffHndlr's stink-cloud vocabulary. }
      { the same as caster }
      2: (owner: PWork;
          { the same as next }
          ownerTail: array[$04..$07] of Byte;
          { the same as under }
          saved: array[1..9] of Byte;
          { the same as exists }
          active: array[1..9] of Byte;
          { the same as ulX }
          baseCol: ShortInt;
          { the same as ulY }
          baseRow: ShortInt;
          { the same as idx }
          hi: Byte);
  end;

  { one class's row of experienceSpellsClass: the experience each level needs and the spell slots it adds, by spell
    level }
  TClassXpRow = record
    xpNeeded: array[2..12] of LongInt;
    slotGains: array[2..12, 1..5] of Byte;
  end;
  TXpTable = array[0..7] of TClassXpRow;

  { One line walk: its start and end cells, the error term, the absolute deltas, the current cell, the step signs, the
    doubled distance walked and the facing of the last step. }
  TPathReq = record
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    err: Integer;
    adx: Integer;
    ady: Integer;
    cx: Integer;
    cy: Integer;
    stepX: Integer;
    stepY: Integer;
    dist: Byte;
    step: Byte;
  end;

  { one CopyProt challenge: where in the journal its answer word stands }
  TJournalChallenge = record
    pageNum: Byte;
    lineNum: Byte;
    wordNum: Byte;
  end;

  { one combat placement row's valid column range }
  TBandRec = record
    lo: ShortInt;
    hi: ShortInt;
  end;

  { one main-menu command: its text and whether it is offered }
  TMenuItem = record
    name: String[40];
    enabled: Byte;
  end;

  { one random magic item: its three name components, weight, value, and the three words whose low bytes Money stores in
    the item's spells[1..3] }
  TRandomItemTemplate = record
    nameIds: array[1..3] of Word;
    weight: Word;
    value: Word;
    properties: array[1..3] of Word;
  end;

  { the ten 3D view slots' rectangles: first cell in a WALLDEF slice (the running sum of the earlier slots' cols * rows,
    156 cells in all), width and height in symbol cells, and base column and row in the 11-by-11 view }
  TViewSlotGeom = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;

  { one combat terrain id's rules: the movement cost multiplier, 255 impassable; the clearance a line walk starts with
    and the height it is compared against; and the terrain's icon }
  TTerrainEntry = record
    cost: Byte;
    clearance: Byte;
    blocking: Byte;
    tileId: Byte;
  end;

  { one icon cell's offset from a combatant's cell }
  TIconDelta = record
    dx: ShortInt;
    dy: ShortInt;
  end;

  { one race's attribute limits, [0] male and [1] female where they differ (CharGen's and SaveLoad's type). Strength is
    gendered; every other column is a single byte. The columns run in stat order STR, INT, WIS, DEX, CON, CHA, and
    SaveLoad.ConvertPoolRecord's clamp loop walks them in that order, stats[i] against column i. }
  TRaceLim = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    exStrMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;

  { a starting age: the years before the dice roll, and the dice }
  TRuleAge = record
    base: Word;
    num: Byte;
    sides: Byte;
  end;

  { a class's starting-gold dice }
  TRuleGold = record
    num: Byte;
    sides: Byte;
  end;

  { an INT 33h function 9 cursor: the AND mask, then the XOR mask }
  TMouseCursor = record
    screenMask: array[0..15] of Word;
    cursorMask: array[0..15] of Word;
  end;

  { the Dos.Intr register block, laid out as Dos.Registers (Types uses no unit) }
  TInterruptRegisters = record
    case Integer of
      0: (ax: Word; bx: Word; cx: Word; dx: Word; bp: Word; si: Word; di: Word; ds: Word; es: Word; flags: Word);
      1: (al: Byte; ah: Byte; bl: Byte; bh: Byte; cl: Byte; ch: Byte; dl: Byte; dh: Byte);
  end;

  { a combatant's place in the combat arena: its cell, the combat slot CombatSt gives it, and its icon footprint, zero
    while it is out of play }
  TArenaLoc = record
    x: ShortInt;
    y: ShortInt;
    slotIndex: Byte;
    size: Byte;
  end;

  { The combat arena: the view's top-left arena cell, the cursor's visibility and icon size, the flag with which a line
    of sight crosses any terrain (Pathing's and CbtActs' distMode), and each cell's terrain id, [row, column]. }
  PArena = ^TArena;
  TArena = record
    { unused }
    oxLead: array[1..2] of Byte;
    ox: ShortInt;
    oy: ShortInt;
    cursorOn: Boolean;
    cursorSize: Byte;
    distMode: Byte;
    cells: array[0..24, 0..49] of Byte;
  end;

  { Where the party stands and what it faces. GameInit clears the five fields together, and SaveLoad saves and loads
    them as one block. }
  TPartyPosition = record
    { the party's map column }
    mapX: ShortInt;
    { the party's map row }
    mapY: ShortInt;
    { the party's facing, clockwise from north }
    facing: Byte;
    { the wall in front of the party }
    wallAhead: Byte;
    { the event at the party's cell }
    eventAtCell: Byte;
  end;

  { a creature downed in combat: the creature, its corpse cell, and the terrain saved from under it }
  TDownedRec = record
    cr: PWork;
    x: ShortInt;
    y: ShortInt;
    under: Byte;
  end;

  { one potential target of the acting creature: its combat slot, its doubled walk distance and the facing toward it }
  TCombatTarget = record
    idx: Byte;
    dist: Byte;
    dir: Byte;
  end;

  { one cached wall set: the WALLDEF id loaded in the slot and the 8x8 symbol slot stamped for it, -1 each when the slot
    is invalid }
  TWallSetCacheSlot = record
    wallDefId: Integer;
    symbolSlot: Integer;
  end;

  { one cached HEAD or BODY picture: its DAX id, $FF when invalid, and its picture buffer }
  TPortraitCacheSlot = record
    pictureId: Byte;
    pic: Pointer;
  end;

  { a joystick axis's readings: 0 the low stop, 3 the center, 6 the high stop; and one stick's calibration }
  TJoyAxis = array[0..6] of Word;
  TJoyCal = record
    x: TJoyAxis;
    y: TJoyAxis;
  end;

  { a loaded sound effect: its size and its data }
  TSoundSample = record
    size: Word;
    data: PBytes;
  end;

  { the command block SoundDrv hands the sound driver: the effect's buffer and size, a reserved field SoundDrv clears,
    and the rate to play it at }
  TSoundDriverCommand = record
    data: Pointer;
    size: Word;
    reserved: LongInt;
    { Hz: SBLASTER divides 1000000 by it; IBMSND, TANSLTL and ADLIB the 1193180 Hz timer clock }
    sampleRate: Word;
  end;

type
  { Config's work variables. }
  TConfigVars = record
    { each one-letter line read back from GAME.CFG }
    key: Char;
    { the menu number read, and its loop index }
    choice: Byte;
    { GAME.CFG }
    gameCfg: Text;
    { unused }
    spareBeforeIoResult: array[0..304] of Byte;
    { the IOResult cleared after changing to the game directory }
    ioResult: Word;
  end;
  THillsfarRec = record
    header: array[$00..$03] of Byte;
    { C-string name }
    name4: array[0..15] of Char;
    { stat 0 seed }
    strength: Byte;
    { stat 6 seed }
    strExc: Byte;
    { stats 1..5 }
    otherAbilities: array[$16..$1B] of Byte;
    alignment: Byte;
    { start-item count A }
    chimeCharges: Byte;
    age: Word;
    hpCur: Byte;
    hpMax: Byte;
    afterHpMax: Byte;
    { start-item count B }
    wandCharges: Byte;
    beforeScriptFlag: array[$24..$25] of Byte;
    { MergeHillsfarRecord sets scriptFlag when it is nonzero }
    setsScriptFlag: Byte;
    beforeGold: Byte;
    { money, in gold }
    gold: LongInt;
    gender: Byte;
    { race }
    race: Byte;
    experience: LongInt;
    afterExperience: array[$32..$34] of Byte;
    { class nibble }
    classCode: Byte;
    afterClassCode: array[$36..$85] of Byte;
    { start-item count C }
    ringCharges: Byte;
    { start-item count D }
    healingPotions: Byte;
    beforeClassFlags: array[$88..$B6] of Byte;
    isCleric: Byte;
    isMage: Byte;
    isFighter: Byte;
    isThief: Byte;
    recordTail: Byte;
  end;

implementation

end.
