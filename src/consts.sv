`define ADDRSIZE      64
`define BLOCKSIZE     64
`define BLOCKSPERWAY  32
`define DATASIZE      64
`define DIRTY          1
`define INSTRSIZE     32
`define OFFSETSIZE     6
`define TAGSIZE       56
`define VALID          1

// CACHE CONSTANTS
typedef logic [`DATASIZE - 1 : 0] data;
typedef struct packed {
   logic valid;
   logic dirty;
   logic [`TAGSIZE - 1 : 0] tag;
   data [`OFFSETSIZE - 1 : 0] data_cells;
} cache_line;

typedef cache_line[`BLOCKSPERWAY - 1 : 0] cache_block;
