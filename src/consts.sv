`define ADDRSIZE      64
`define BLOCKSIZE     64
`define BLOCKSPERWAY  32
`define DATASIZE      64
`define DIRTY          1
`define INSTRSIZE     32
`define MEMR     0'h1100
`define OFFSETSIZE     6
`define SETSIZE        4
`define TAGSIZE       56
`define VALID          1
`define WAYS           4


// CACHE CONSTANTS
typedef struct packed {
   logic [`TAGSIZE - 1 : 0] tag;
   logic [`SETSIZE - 1 : 0] set;
   logic [`OFFSETSIZE - 1 : 0] offset;
} cache_instruction;

typedef struct packed {
   logic valid;
   logic dirty;
   logic [`TAGSIZE - 1 : 0] tag;
} cache_line;

// Data Cache Block
typedef logic [`DATASIZE - 1 : 0] data;
typedef struct packed {
  cache_line cache;
  data [`OFFSETSIZE - 1 : 0] data_cells;
} data_cache_line;
typedef data_cache_line[`BLOCKSPERWAY - 1 : 0] data_cache_block;

// Instruction cache block
typedef logic [`INSTRSIZE - 1 : 0] instr;
typedef struct packed {
  cache_line cache;
  instr [`OFFSETSIZE - 1 : 0] instr_cells;
} instr_cache_line;
typedef instr_cache_line[`BLOCKSPERWAY - 1 : 0] instr_cache_block;


