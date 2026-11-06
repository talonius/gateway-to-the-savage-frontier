{ Resting, the game clock and spell preparation. AdvanceTime moves the world clock (GBVM words GBVM_CLOCK.., seven
  digits from segments to years, GDConsts.unitScale giving each digit's radix) and ages the party's timed effects by the
  same span. CampRest runs a rest: in five-minute ticks it counts GDVars.restTime down and the world clock up, heals the
  party a point a day, completes pending memorizations and scribings, and lets the module's script interrupt it at
  random; the interactive call first offers the rest-time menu. FinishSpellPreparation, which Camp calls after Fix's
  rest, completes every pending memorization and scribing at once. Its state is in GDConsts (isMemorizeActive,
  isRestTimeShown) and GDVars. }
{$O+,F+}
{$A+}
{$S+}
unit GameTime;

interface

uses Types, C_Gbvm, C_Ifc, C_Msg, C_Spell, Crt, GDConsts, GDVars, C_Keys, FxEngine, CharHlp, MenuCore,
  TextRend, GameIo, Magic;

{ Advances the game clock one unit at a time, carrying each component into the next, then ages the party's timed effects
  by the same span.
  @param(amount Number of units.)
  @param(tUnit Clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days, 5 months, 6 years.) }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ Run a rest until GDVars.restTime runs out, the player stops it or the script interrupts it.
  @param(interactive True to show the rest-time menu and clock and to let a key press stop the rest.)
  @returns(True when the script's random interruption ended the rest.) }
function CampRest(interactive: Boolean): Boolean;

{ Complete every creature's pending scribings and memorizations at once, without the rest clock. }
procedure FinishSpellPreparation;

implementation

const
  { the GBVM cell of the world clock's first digit, in bank 0 }
  GBVM_CLOCK = $4BC6;
  MAX_REST_DAYS = 99;

{ Age the flagged creatures' effects by count units of tUnit, in steps of at most ten minutes, removing each effect that
  runs out. In camp only the creatures whose effFlags entry is set are aged, and nothing happens if none is; elsewhere
  every flag is set first. A creature's flag stays set while any of its effects has time left, and GDVars.newEclFlag
  stops the aging.
  @param(count Units to age by.)
  @param(tUnit The clock digit counted.) }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  found: Boolean;
  next: Types.PEffectRec;
  e: Types.PEffectRec;
begin
  if GDVars.interfaceState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GDVars.gbvmZone1Ptr^[C_Gbvm.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  while u > 1 do begin
    total := GDConsts.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if GDVars.effFlags[i] <> 0 then begin
        GDVars.effFlags[i] := 0;
        e := cur^.effects;
        while (e <> nil) and (GDVars.newEclFlag = 0) do begin
          next := e^.next;
          if e^.duration <> 0 then begin
            if step < e^.duration then begin
              Dec(e^.duration, step);
              GDVars.effFlags[i] := 1;
            end else
              FxEngine.RemoveEffect(cur, e^.id, e);
          end;
          e := cur^.effects;
          while (e <> nil) and (e <> next) do
            e := e^.next;
        end;
        e := cur^.effects;
        while e <> nil do begin
          if e^.duration > 0 then GDVars.effFlags[i] := 1;
          e := e^.next;
        end;
      end;
      Inc(i);
      cur := cur^.next;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Carries each clock component that has reached its limit into the next one, once per component. A year component at its
  limit is left as it is, and each party member ages by a year instead.
  @param(clock The clock to normalize.) }
procedure ValidateClock(var clock: Types.TClock);
var
  i: ShortInt;
  cur: Types.PWork;
begin
  for i := 0 to 6 do
    if clock[i] >= GDConsts.unitScale[i] then
      if i <> 6 then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.unitScale[i];
      end else begin
        cur := GDVars.creatureList;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.next;
        end;
      end;
end;

{ Normalizes the rest time, folds its months into days and caps it at 99 days. }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restTime);
  if GDVars.restTime[5] > 0 then begin
    Inc(GDVars.restTime[4], GDConsts.unitScale[4] * GDVars.restTime[5]);
    GDVars.restTime[5] := 0;
    if GDVars.restTime[4] > GameTime.MAX_REST_DAYS then GDVars.restTime[4] := GameTime.MAX_REST_DAYS;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.gbvmZone0Ptr^[GameTime.GBVM_CLOCK + i];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock);
  end;
  for i := 0 to 6 do
    GDVars.gbvmZone0Ptr^[GameTime.GBVM_CLOCK + i] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Takes a span off the rest time, borrowing from the larger components as needed; when there is nothing left to borrow,
  the rest time is cleared. Nothing happens when no days, hours or minutes are left.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.restTime[4] <> 0) or (GDVars.restTime[3] <> 0) or (GDVars.restTime[2] <> 0) or
      (GDVars.restTime[1] <> 0) then begin
    while count > GDVars.restTime[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.restTime[j] = 0) and (j < 5) do
        j := Succ(j);
      if j = 5 then begin
        FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.restTime[k]);
          Inc(GDVars.restTime[Pred(k)], GDConsts.unitScale[Pred(k)]);
        end;
    end;
    Dec(GDVars.restTime[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ Formats a number with at least two digits, keeping the first two.
  @param(v The number.)
  @returns(The digits, with a leading zero below 10.) }
function TwoDigitStr(v: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.Uint8Str(v);
  if v < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Shows the rest time as days, hours and minutes on the message line, the selected field in white.
  @param(hl Clock component shown in white: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(hl: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := LightGreen;
  colors[hl] := White;
  TextRend.DisplayString(1, 17, LightGreen, Black, 'Rest Time:');
  x := 11;
  for i := 4 downto 3 do begin
    TextRend.DisplayString(x + 1, 17, colors[i], Black, GameTime.TwoDigitStr(GDVars.restTime[i]));
    TextRend.DisplayString(x + 1 + 2, 17, LightGreen, Black, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayString(x + 1, 17, colors[2], Black,
                         GameTime.TwoDigitStr(10 * GDVars.restTime[2] + GDVars.restTime[1]));
end;

{ The rest-time menu: Days, Hours and Mins select a digit, and a second press or Add adds one to it (five minutes for
  Mins); Subtract takes one off; the up and down arrows are Add and Subtract.
  @returns(True when the player picks Rest or presses Enter.) }
function CampRestMenu: Boolean;
var
  ext: Boolean;
  ch: Char;
  sel: ShortInt;

  { Add one to the selected digit, five minutes for Mins. }
  procedure AddRestTime;
  begin
    if sel = 2 then
      Inc(GDVars.restTime[1], 5)
    else
      Inc(GDVars.restTime[sel]);
    GameTime.ValidateRestTime;
  end;

begin
  CampRestMenu := False;
  sel := 2;
  repeat
    GameTime.DisplayRestTime(sel);
    ch := MenuCore.MenuHorizontal('', 'Rest Days Hours Mins Add Subtract Exit', LightMagenta, LightGreen, White, True,
                                  False, ext);
    if ext then
      case ch of
        C_Keys.UP: ch := 'A';
        C_Keys.DOWN: ch := 'S';
      else
        { no menu key }
        ch := 'X';
      end;
    if ch = C_Keys.ENTER then ch := 'R';
    case ch of
      'R': CampRestMenu := True;
      'D': if sel <> 4 then sel := 4 else AddRestTime;
      'H': if sel <> 3 then sel := 3 else AddRestTime;
      'M': if sel <> 2 then sel := 2 else AddRestTime;
      'A': AddRestTime;
      'S': begin
             if sel = 2 then
               GameTime.DecrementRestTime(5, 1)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until ch in [C_Keys.NONE, 'E', 'R'];
end;

{ Count a rest tick toward the day's healing; each 288 five-minute ticks (a day) restore a hit point to every creature
  and say so. showTime redraws the rest clock first and is kept in isRestTimeShown for the spell notices.
  @param(showTime True to redraw the rest clock first.) }
procedure CheckRestingHeal(showTime: Boolean);
var
  healed: Boolean;
  cur: Types.PWork;
begin
  GDConsts.isRestTimeShown := showTime;
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(cur, 1, False) then healed := True;
      cur := cur^.next;
    end;
    if showTime then GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, Black, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(GDVars.curChar);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Find the creature's first memorized-spell slot (of 81) still being memorized. When done is already True, return that
  spell's level; otherwise finish the memorization, announce it and set done. Nothing happens outside Camp's memorize
  menus (isMemorizeActive).
  @returns(The pending spell's level, or 0.)
  @param(cr The creature.)
  @param(done True to look the spell up only; set when a memorization is finished.) }
function CheckMemorizeDone(cr: Types.PWork; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  if (cr^.enabled = 0) or not GDConsts.isMemorizeActive then begin
    CheckMemorizeDone := 0;
    Exit;
  end;
  lvl := 0;
  i := 0;
  while (i <= C_Spell.MEMORIZED_SPELL_SLOTS - 1) and (lvl = 0) do begin
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then
      if done then
        lvl := GDConsts.spellTable[cr^.memorizedSpells[i] and C_Spell.ID_MASK].level
      else begin
        Dec(cr^.memorizedSpells[i], C_Spell.PENDING_FLAG);
        if GDConsts.isRestTimeShown then
          GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(Pointer(cr), 'has memorized', cr^.memorizedSpells[i]);
        done := True;
      end;
    Inc(i);
  end;
  CheckMemorizeDone := lvl;
end;

{ Find the first spell being scribed from one of the creature's readable scrolls. When done is already True, return that
  spell's level; otherwise make the spell known, take it off the scroll, announce it and set done. Nothing happens
  outside Camp's memorize menus.
  @returns(The pending spell's level, or 0.)
  @param(cr The creature.)
  @param(done True to look the spell up only; set when a scribing is finished.) }
function CheckScribeDone(cr: Types.PWork; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  it: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
begin
  lvl := 0;
  if (cr^.enabled = 0) or not GDConsts.isMemorizeActive then begin
    CheckScribeDone := 0;
    Exit;
  end;
  found := False;
  it := cr^.itemsAddr;
  while (it <> nil) and (lvl = 0) do begin
    j := 1;
    if Magic.ItemReadable(it) then
      while (j <= SizeOf(it^.spells)) and (lvl = 0) do begin
        if it^.spells[j] > C_Spell.PENDING_FLAG then begin
          found := True;
          if done then
            lvl := GDConsts.spellTable[it^.spells[j] and C_Spell.ID_MASK].level
          else begin
            sp := it^.spells[j] and C_Spell.ID_MASK;
            cr^.restKnown[sp] := 1;
            Magic.RemoveSpellFromScroll(cr, it, sp);
            if GDConsts.isRestTimeShown then
              GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(Pointer(cr), 'has scribed', sp);
            done := True;
          end;
        end;
        Inc(j);
      end;
    it := it^.next;
  end;
  CheckScribeDone := lvl;
end;

procedure FinishSpellPreparation;
var
  cur: Types.PWork;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  lvl: Byte;
begin
  GDConsts.isRestTimeShown := False;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    repeat
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      lvl := GameTime.CheckMemorizeDone(cur, done);
    until not done;
    cur := cur^.next;
  end;
end;

{ Counts down each party member's spell-preparation timer; when it runs out and the member's preparation wait is over,
  the next spell being scribed or else memorized is finished and the timer restarts at three times the following spell's
  level. }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PWork;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    if GDVars.prepTimers[i] > 0 then
      Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (cur^.restSpellPrep = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimers[i] := lvl * 3;
    end;
    cur := cur^.next;
    Inc(i);
  end;
end;

{ Counts rest steps; every twelfth step, each party member's preparation wait drops by one, and when it reaches zero the
  member's spell-preparation timer starts at three times the level of the next spell to scribe or memorize.
  @param(tick The step counter, kept by the caller.) }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PWork;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if cur^.restSpellPrep > 0 then begin
        Dec(cur^.restSpellPrep);
        if cur^.restSpellPrep = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          GDVars.prepTimers[i] := lvl * 3;
        end;
      end;
      cur := cur^.next;
      Inc(i);
    end;
  end;
end;

function CampRest(interactive: Boolean): Boolean;
var
  cur: Types.PWork;
  { Unused in this version; see the other implementations of this routine. }
  member: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Boolean;
begin
  CampRest := False;
  interrupted := False;
  i := 1;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    cur := cur^.next;
  end;
  FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1);
  tick := 0;
  cnt := 0;
  if interactive then begin
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    GameTime.DisplayRestTime(0);
  end;
  GDVars.suppressDrawingBorderFlag := 1;
  if interactive then
    stop := not GameTime.CampRestMenu
  else
    stop := False;
  GameIo.WaitMouseRelease;
  while (not stop) and
      ((GDVars.restTime[4] > 0) or (GDVars.restTime[3] > 0) or (GDVars.restTime[2] > 0) or
       (GDVars.restTime[1] > 0)) do begin
    if interactive and GameIo.InputPending then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White) = 'Y' then
        stop := True
      else
        MenuCore.ClearBottomLine;
      GameIo.WaitMouseRelease;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, 1);
      Inc(cnt);
      if interactive and (cnt >= 5) then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, 1);
      GameTime.CheckRestingHeal(interactive);
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      if GDVars.gbvmZone1Ptr^[C_Gbvm.REST_SAFE_TIME] > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.gbvmZone1Ptr^[C_Gbvm.REST_SAFE_TIME] then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.gbvmZone1Ptr^[C_Gbvm.REST_INTERRUPT_PERCENT] then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, Black, 'Your repose is suddenly interrupted!');
            stop := True;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  if interactive then
    TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  GDVars.suppressDrawingBorderFlag := 0;
end;

begin
end.
