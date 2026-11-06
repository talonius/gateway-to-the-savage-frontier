{ The journal word challenge. Each try picks one of journalChallenges, never the previous try's, asks for the word at
  its page, line and word position, and compares the typed word, spaces removed and upper-cased, with the answer spelled
  down that challenge's column of journalAnswerGrid. GDVars.protectionFlags are cleared on entry and set one by one as
  the challenge reaches each stage. }
{$O+,F+}
{$A+}
unit CopyProt;

interface

{ Give the player up to three journal word challenges. Records the verdict in hasPassedCopyProtection and quits the game
  after the third wrong answer. }
procedure CopyProtection;

implementation

uses Types, GDConsts, GDVars, Border, TextRend, CharHlp, GameIo, Crt;

const
  MAX_ATTEMPTS = 3;
  ANSWER_MAX_LENGTH = 20;

procedure CopyProtection;
var
  i: Byte;
  entry: Byte;
  attempts: Byte;
  expected: String;
  wordNum: Byte;
  lineNum: Byte;
  pageNum: Byte;
  reply: String;
  filtered: String;
  candidate: Byte;

  { Spell answer word `column`: letter n is in row n; a space or the last row ends it. }
  function DecodeWord(column: Word): String;
  var
    { Unused in this version; see the other implementations of this routine. }
    wordLen: Byte;
    row: Byte;
    { Unused in this version; see the other implementations of this routine. }
    startCol: Byte;
    ch: Char;
    acc: String;
  begin
    acc := '';
    for row := 1 to SizeOf(GDConsts.journalAnswerGrid) div SizeOf(GDConsts.journalAnswerGrid[1]) do begin
      ch := GDConsts.journalAnswerGrid[row][column];
      if ch = ' ' then begin
        DecodeWord := acc;
        Exit;
      end;
      acc := acc + ch;
    end;
    DecodeWord := acc;
  end;

begin
  FillChar(GDVars.protectionFlags, SizeOf(GDVars.protectionFlags), 0);
  Border.DrawWindowFrame;
  attempts := 0;
  entry := 0;
  repeat
    Inc(attempts);
    expected := '';
    GDVars.protectionFlags[0] := 1;
    candidate := Random(SizeOf(GDConsts.journalChallenges) div SizeOf(Types.TJournalChallenge)) + 1;
    while candidate =
        entry do candidate := Random(SizeOf(GDConsts.journalChallenges) div SizeOf(Types.TJournalChallenge)) + 1;
    entry := candidate;
    wordNum := GDConsts.journalChallenges[entry].wordNum;
    lineNum := GDConsts.journalChallenges[entry].lineNum;
    pageNum := GDConsts.journalChallenges[entry].pageNum;
    expected := DecodeWord(entry);
    GDVars.protectionFlags[1] := 1;
    TextRend.DisplayString(3, 2, LightGreen, Black,
                           GDConsts.pagePrompt + CharHlp.Uint8Str(pageNum) + ' of the journal  ');
    TextRend.DisplayString(3, 4, LightGreen, Black,
                           GDConsts.linePrompt + CharHlp.Uint8Str(lineNum) + ' including headings  ');
    TextRend.DisplayString(3, 6, LightGreen, Black, GDConsts.wordPrompt + CharHlp.Uint8Str(wordNum) + ' ?  ');
    reply := TextRend.ReadString('Enter:', Yellow, Black, CopyProt.ANSWER_MAX_LENGTH);
    filtered := '';
    for i := 1 to Length(reply) do
      if reply[i] <> ' ' then filtered := filtered + UpCase(reply[i]);
  until (attempts = CopyProt.MAX_ATTEMPTS) or (filtered = expected);
  GDVars.protectionFlags[2] := 1;
  if filtered = expected then GDConsts.hasPassedCopyProtection := True
  else GDConsts.hasPassedCopyProtection := False;
  GDVars.protectionFlags[3] := 1;
  if filtered <> expected then GameIo.ExitGame;
end;

begin
end.
