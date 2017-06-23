`define ADDRESS_SIZE      64
`define BLOCK_SIZE        64
`define BUS_DATA_WIDTH    64
`define BUS_TAG_WIDTH     13
`define DATA_SIZE         64
`define DIRTY             1
`define INDEX_SIZE        32 
`define INDEX_SIZE_B      $clog2(`INDEX_SIZE - 1)
`define INDEXES_PER_WAY   32
`define INSTRUCTION_SIZE  32
`define MEM_READ          0'h1100
`define OFFSET_SIZE       64 
`define OFFSET_SIZE_B     $clog2(`OFFSET_SIZE - 1)
`define CELLS_NEEDED      8
`define CELLS_NEEDED_B    $clog2(`CELLS_NEEDED - 1)
`define TAG_SIZE_B        64 - (`OFFSET_SIZE_B + `INDEX_SIZE_B)
`define VALID             1
`define WAYS              4
`define WAYS_B            $clog2(`WAYS - 1)

// OFFSET bits will alawys be a multiple of 4
// TAG SIZE + INDEX + OFFSET
//   53         5       6

typedef logic [`TAG_SIZE_B - 1 : 0] cache_tag; 
typedef logic [`INDEX_SIZE_B - 1 : 0] cache_index;
typedef logic [`OFFSET_SIZE_B - 1 : 0] cache_offset;
// CACHE CONSTANTS
typedef struct packed {
  cache_tag tag;
  cache_index index;
  cache_offset offset;
} cache_address;

// Cache Block
// Block size = 32 * (1 + 1 + 53 + 3 * 64) = 18176 bits
typedef logic [`DATA_SIZE - 1 : 0] cache_cell; // One Cell of Size 64
typedef struct packed {
  logic valid;
  logic dirty;
  logic [`TAG_SIZE_B - 1 : 0] tag;
  cache_cell [`CELLS_NEEDED - 1 : 0] cache_cells; // 64 byte offset (8 cells)
} cache_line;
typedef cache_line[`INDEXES_PER_WAY - 1 : 0] cache_block;
typedef cache_block [`WAYS - 1 : 0] full_cache;


// Register between fetch and decode
typedef struct packed {
  logic [`INSTRUCTION_SIZE - 1 : 0] instruction;
} fetch_decode_register;







`define IMMEDIATE_SIZE              64
`define NUMBER_OF_REGISTERS         32
`define NUMBER_OF_REGISTERS_B       $clog2(`NUMBER_OF_REGISTERS - 1)

// Data Structure Lengths
`define CONTROL_BITS_SIZE           $bits(control_bits)


// Memory Instruction Type
typedef enum logic[3:0] { 
        LB, LBU, LH, LHU, LW, LWU, LD,
        SB, SH, SW, SD 
      } memory_instruction_type;

// ALU operation
typedef enum logic [5:0] {
  // Normal ALU
  ADD, SUB, AND, OR, XOR,
  SLT, SRL, SRA, SLL,
  ADDW, SUBW, SLTW, SRAW, SRLW, SLLW,
  BEQ, BNE, BGE, BLT, BGEU, BLTU,
  //M extention
  MUL, MULH, MULSU, MULHU, MULHSU,
  MULW, DIV, DIVU, REM,
  REMU, DIVW, DIVUW,
  REMW, REMUW
} alu_operation;

typedef struct packed {
  logic alusrc;                       // ALU source (rs2 or imm)
  logic apc;                          // APC
  logic cjump;                        // Conditional Jump
  logic ecall;                        // e-call
  logic memtoreg;                     // Memory To Register
  logic memwr;                        // Memory Write
  logic regwr;                        // Register Write
  logic ucjump;                       // Unconditional Jump
  logic unsupported;                  // *Unsuppored Instruction
  logic usign;                        // Unsigned
  alu_operation aluop;                // ALU Operation
  memory_instruction_type memtype;    // Memory Instruction Type
} control_bits;















