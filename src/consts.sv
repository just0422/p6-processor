`define ADDRESS_SIZE             64
`define BLOCK_SIZE               64
`define BUS_DATA_WIDTH           64
`define BUS_TAG_WIDTH            13
`define DATA_SIZE                64
`define DIRTY                     1
`define INDEX_SIZE_B              4
`define INDEXES_PER_WAY          32
`define INSTRUCTION_SIZE         32
`define MEM_READ            0'h1100
`define OFFSET_SIZE              64
`define OFFSET_SIZE_B             6
`define TAG_SIZE                 56
`define VALID                     1
`define WAYS                      4
`define WAYS_B     $bits(`WAYS - 1)

typedef logic [`TAG_SIZE - 1 : 0] cache_tag; 
typedef logic [`INDEX_SIZE_B - 1 : 0] cache_index;
typedef logic [`OFFSET_SIZE_B - 1 : 0] cache_offset;
// CACHE CONSTANTS
typedef struct packed {
  cache_tag tag;
  cache_index index;
  cache_offset offset;
} cache_address;

// Cache Block
typedef logic [`DATA_SIZE - 1 : 0] cache_cell; // One Cell of Size 64
typedef struct packed {
  logic valid;
  logic dirty;
  logic [`TAG_SIZE - 1 : 0] tag;
  cache_cell [`OFFSET_SIZE_B - 1 : 0] cache_cells; // 64 byte offset (8 words)
} cache_line;
typedef cache_line[`INDEXES_PER_WAY - 1 : 0] cache_block;
typedef cache_block [`WAYS - 1 : 0] full_cache;
