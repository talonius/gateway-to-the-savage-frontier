{ The ECL opcode names. While GDConsts.debugOn is set, EclVm's script loop writes the name of each opcode it fetches to
  GameIo's debug log. The unit owns no state. }
{$O+,F+,I-,R-,S+,V-,B-,A+}
unit Debug;
interface

{ Names the current ECL opcode.
  @param(op Unused: the name is always GDVars.curOpcode's, which EclVm passes.)
  @returns(The opcode's name as the game spells it ('SUBTRAT'); $1F has no arm.) }
function OpcodeName(op: Byte): String;

implementation

uses GDConsts, GDVars;

function OpcodeName(op: Byte): String;
begin
 case GDVars.curOpcode of
  $00: OpcodeName := 'EXIT';
  $01: OpcodeName := 'GOTO';
  $02: OpcodeName := 'GOSUB';
  $03: OpcodeName := 'COMPARE';
  $04: OpcodeName := 'ADD';
  $05: OpcodeName := 'SUBTRAT';
  $06: OpcodeName := 'DIVIDE';
  $07: OpcodeName := 'MULTIPLY';
  $08: OpcodeName := 'RANDOM';
  $09: OpcodeName := 'SAVE';
  $0A: OpcodeName := 'LOAD CHARACTER';
  $0B: OpcodeName := 'LOAD MONSTER';
  $0C: OpcodeName := 'SETUP MONSTER';
  $0D: OpcodeName := 'APPROACH';
  $0E: OpcodeName := 'PICTURE';
  $0F: OpcodeName := 'INPUT NUMBER';
  $10: OpcodeName := 'INPUT STRING';
  $11: OpcodeName := 'PRINT';
  $12: OpcodeName := 'PRINTCLEAR';
  $13: OpcodeName := 'RETURN';
  $14: OpcodeName := 'COMPARE AND';
  $15: OpcodeName := 'VERTICAL MENU';
  $16: OpcodeName := 'IF = ';
  $17: OpcodeName := 'IF <>';
  $18: OpcodeName := 'IF <';
  $19: OpcodeName := 'IF >';
  $1A: OpcodeName := 'IF <=';
  $1B: OpcodeName := 'IF >=';
  $1C: OpcodeName := 'CLEARMONSTERS';
  $1D: OpcodeName := 'PARTYSTRENGTH';
  $1E: OpcodeName := 'CHECKPARTY';
  $20: OpcodeName := 'NEWECL';
  $21: OpcodeName := 'LOAD FILES';
  $37: OpcodeName := 'LOAD PIECES';
  $22: OpcodeName := 'PARTY SURPRISE';
  $23: OpcodeName := 'SURPRISE';
  $24: OpcodeName := 'COMBAT';
  $25: OpcodeName := 'ON GOTO';
  $26: OpcodeName := 'ON GOSUB';
  $27: OpcodeName := 'TREASURE';
  $28: OpcodeName := 'ROB';
  $29: OpcodeName := 'ENCOUNTER MENU';
  $2A: OpcodeName := 'GETTABLE';
  $2B: OpcodeName := 'HORIZONTAL MENU';
  $2C: OpcodeName := 'PARLAY';
  $2D: OpcodeName := 'CALL';
  $2E: OpcodeName := 'DAMAGE';
  $2F: OpcodeName := 'AND';
  $30: OpcodeName := 'OR';
  $31: OpcodeName := 'SPRITE OFF';
  $32: OpcodeName := 'FIND ITEM';
  $33: OpcodeName := 'PRINT RETURN';
  $34: OpcodeName := 'ECL CLOCK';
  $35: OpcodeName := 'SAVE TABLE';
  $36: OpcodeName := 'ADD NPC';
  $38: OpcodeName := 'PROGRAM';
  $39: OpcodeName := 'WHO';
  $3A: OpcodeName := 'DELAY';
  $3B: OpcodeName := 'SPELL';
  $3C: OpcodeName := 'PROTECTION';
  $3D: OpcodeName := 'CLEAR BOX';
  $3E: OpcodeName := 'DUMP';
  $3F: OpcodeName := 'FIND SPECIAL';
  $40: OpcodeName := 'DESTROY ITEMS'
 end
end;
begin end.
