`define ADDRESS_SIZE           64
`define BLOCK_SIZE             64
`define BLOCKS_PER_WAY         32
`define BUS_DATA_WIDTH         64
`define BUS_TAG_WIDTH          13
`define DATA_SIZE              64
`define DIRTY                   1
`define INSTRUCTION_SIZE       32
`define MEM_READ          0'h1100
`define OFFSET_SIZE             6
`define INDEX_SIZE              4
`define TAG_SIZE               56
`define VALID                   1
`define WAYS                    4


// CACHE CONSTANTS
typedef struct packed {
   logic [`TAG_SIZE - 1 : 0] tag;
   logic [`INDEX_SIZE - 1 : 0] index;
   logic [`OFFSET_SIZE - 1 : 0] offset;
} cache_address;

typedef struct packed {
   logic valid;
   logic dirty;
   logic [`TAG_SIZE - 1 : 0] tag;
} cache_line;

// Data Cache Block
typedef logic [`DATA_SIZE - 1 : 0] cache_data; // One Cell of Size 64
typedef struct packed {
  cache_line vdt;
  cache_data [`OFFSET_SIZE - 1 : 0] data_cells; // 64 byte offset (8 words)
} data_cache_line;
typedef data_cache_line[`BLOCKS_PER_WAY - 1 : 0] data_cache_block;

// Instruction cache block
typedef logic [`INSTRUCTION_SIZE - 1 : 0] cache_instruction;
typedef struct packed {
  cache_line vdt;
  cache_instruction [`OFFSET_SIZE - 1 : 0] instruction_cells;
} instruction_cache_line;
typedef instruction_cache_line[`BLOCKS_PER_WAY - 1 : 0] instruction_cache_block;


