{ The vault. PoolVault loads VAULT.DAT from GDVars.saveDir into the treasure pool (the pool's money, then one item
  record after another), runs the vault menu over the pool, then writes the pool back to the file and frees its items.
  It owns no storage. }
{$O+,F+,I-}
{$A+}
{$S+}
unit Vault;
interface

{ The vault: load VAULT.DAT from GDVars.saveDir into the treasure pool (the pool's money, then one item record after
  another), run the vault menu (Deposit, Withdraw, Vault, Pool, Share) over the pool until Exit, then write the pool
  back to the file and free its items. Note: a disk without room is reported, but the vault is written anyway. }
procedure PoolVault;
implementation
uses Dos, Crt, GDConsts, GDVars, C_Keys, C_Ifc, Money, SaveLoad, PostCbt, CharHlp, DaxIo, MenuCore,
  ViewChar, TextRend, GameIo, Types;

procedure PoolVault;
var
  f: File;
  choice: Char;
  bytesRead: Word;
  { Unused in this version; see the other implementations of this routine. }
  opened: Byte;
  node: Types.PItemRec;
  t: Types.PItemRec;
  buffer: Types.PItemRec;
  prompt: String[44];
  exitFlag: Boolean;
  ext: Boolean;
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  needed: Byte;
  bytesNeeded: Word;
  { Unused in this version; see the other implementations of this routine. }
  moved: Integer;
  menuStr: String[40];
begin
  GDVars.interfaceState := C_Ifc.IN_VAULT;
  GDVars.shopSessionFlag := False;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopSessionFlag := True;
  CharHlp.DisplayParty(GDVars.curChar);
  if not SaveLoad.CheckSaveDir then Exit;
  GDVars.treasureItems := nil;
  if DaxIo.FileExists(GDVars.saveDir + 'vault.dat') then begin
    opened := Ord(DaxIo.OpenWithRetry(GDVars.saveDir + 'vault.dat', prompt, #0, f));
    BlockRead(f, GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), bytesRead);
    hasItems := False;
    GetMem(buffer, SizeOf(Types.TItemRec));
    repeat
      BlockRead(f, buffer^, SizeOf(Types.TItemRec), bytesRead);
      if bytesRead = SizeOf(Types.TItemRec) then begin
        if GDVars.treasureItems = nil then begin
          GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
          GDVars.treasureItems^ := buffer^;
          GDVars.itemListCursor := GDVars.treasureItems;
        end else begin
          GetMem(GDVars.itemListCursor^.next, SizeOf(Types.TItemRec));
          GDVars.itemListCursor := GDVars.itemListCursor^.next;
          GDVars.itemListCursor^ := buffer^;
        end;
        hasItems := True;
      end;
    until bytesRead <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(buffer, SizeOf(Types.TItemRec));
  end else
    FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  GDVars.treasureMoneyFlag := False;
  exitFlag := False;
  repeat
    menuStr := 'Deposit';
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney or hasItems then menuStr := menuStr + ' Withdraw';
    if GDVars.curChar^.numberOfItems > 0 then menuStr := menuStr + ' Vault';
    if Money.PooledMoney then menuStr := menuStr + ' Pool';
    if hasMoney then menuStr := menuStr + ' Share';
    menuStr := menuStr + ' Exit';
    GDVars.canClickParty := 1;
    GDConsts.canClickToView := True;
    choice := MenuCore.MenuHorizontal('', menuStr, LightMagenta, LightGreen, White, True, False, ext);
    GDConsts.canClickToView := False;
    GDVars.canClickParty := 0;
    if not ext then begin
      case choice of
        'P': Money.PoolMoney;
        'S': Money.ShareMoney;
        'V': begin
          ViewChar.UseItemMenu(ext);
          CharHlp.DisplayNoncombatInterface
        end;
        'D': ViewChar.ViewCharMenu(ext);
        'W': PostCbt.LootTakeMenu(hasMoney, hasItems);
        'E', C_Keys.NONE: exitFlag := True;
      end;
    end else if (choice = C_Keys.DOWN) or (choice = C_Keys.UP) then begin
      CharHlp.PrintMiscInfo(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.PrintMiscInfo(GDVars.curChar, True);
    end;
  until exitFlag;
  bytesNeeded := 0;
  Inc(bytesNeeded, SizeOf(GDVars.treasureMoney));
  if GDVars.treasureItems <> nil then begin
    GDVars.itemListCursor := GDVars.treasureItems;
    while GDVars.itemListCursor <> nil do begin
      Inc(bytesNeeded, SizeOf(Types.TItemRec));
      GDVars.itemListCursor := GDVars.itemListCursor^.next;
    end;
  end;
  DaxIo.DeleteIfPresent
    (GDVars.saveDir + 'vault.dat');
  { drive letter to drive number, A = 1 }
  if bytesNeeded > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - (Ord('A') - 1)) then begin
    TextRend.DisplayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
    TextRend.DisplayAndPause(Yellow, Black, 'Please insert another disk.');
  end;
  Assign(f, GDVars.saveDir + 'vault.dat');
  Rewrite(f, 1);
  BlockWrite(f, GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
  GDVars.itemListCursor := GDVars.treasureItems;
  while GDVars.itemListCursor <> nil do begin
    BlockWrite(f, GDVars.itemListCursor^, SizeOf(Types.TItemRec));
    buffer := GDVars.itemListCursor;
    GDVars.itemListCursor := GDVars.itemListCursor^.next;
  end;
  Close(f);
  node := GDVars.treasureItems;
  while node <> nil do begin
    t := node;
    node := node^.next;
    FreeMem(t, SizeOf(Types.TItemRec));
  end;
  GDVars.treasureItems := nil;
  GameIo.KbdNoop;
end;
begin end.
