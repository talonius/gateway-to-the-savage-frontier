{ The EGA ports, and the register indices and values the Pascal code writes through them: the Graphics Controller (GC_)
  and the Sequencer (SEQ_). }
unit C_Ega;

interface

const
  { the Graphics Controller's index port, and GC_DATA_PORT its data port }
  GC_ADDR_PORT = $3CE;
  GC_DATA_PORT = $3CF;
  { the Sequencer's index port, and SEQ_DATA_PORT its data port }
  SEQ_ADDR_PORT = $3C4;
  SEQ_DATA_PORT = $3C5;
  { the Graphics Controller's Bit Mask register: the pixels a write reaches }
  GC_BIT_MASK_REG = 8;
  { the Sequencer's Map Mask register: the planes a write reaches }
  SEQ_MAP_MASK_REG = 2;
  { Map Mask value: the four planes enabled }
  MAP_MASK_ALL_PLANES = $0F;

implementation

end.
