`define ADDRESS_SIZE                64
`define BLOCK_SIZE                  64
`define BUS_DATA_WIDTH              64
`define BUS_TAG_WIDTH               13
`define BTB_SIZE                    4
`define DATA_SIZE                   64
`define DIRTY                       1
`define IMMEDIATE_SIZE              64
`define INDEX_SIZE                  32 
`define INDEX_SIZE_B                $clog2(`INDEX_SIZE - 1)
`define INDEXES_PER_WAY             32
`define INSTRUCTION_SIZE            32
`define LSQ_SIZE                    `BTB_SIZE
`define MEM_READ                    0'h1100
`define MEM_WRITE                   0'h0100
`define MEMORY_MASK                 64'hffffffffffffffC0
`define NUMBER_OF_REGISTERS         32
`define NUMBER_OF_REGISTERS_B       $clog2(`NUMBER_OF_REGISTERS - 1)
`define OFFSET_SIZE                 64 
`define OFFSET_SIZE_B               $clog2(`OFFSET_SIZE - 1)
`define CELLS_NEEDED                8
`define CELLS_NEEDED_B              $clog2(`CELLS_NEEDED - 1)
`define ROB_SIZE                    `LSQ_SIZE
`define RS_SIZE                     `ROB_SIZE
`define TAG_SIZE_B                  64 - (`OFFSET_SIZE_B + `INDEX_SIZE_B)
`define VALID                       1
`define WAYS                        4
`define WAYS_B                      $clog2(`WAYS - 1)


// Cache Sizes
`define DOUBLE                      `DATA_SIZE
`define DOUBLE_B                    $clog2(`DOUBLE - 1) - 3
`define WORD                        `DOUBLE / 2
`define WORD_B                      $clog2(`WORD - 1) - 3
`define HALF                        `WORD / 2
`define HALF_B                      $clog2(`HALF - 1) - 3
`define BYTE                        `HALF / 2
`define BYTE_B                      $clog2(`BYTE - 1) - 3


// Data Structure Lengths
`define CONTROL_BITS_SIZE           $bits(control_bits)


// Used in cache insert to break up response
typedef logic [1:0][`WORD - 1 : 0]                                    WordMemory;
typedef logic [3:0][`HALF - 1 : 0]                                    HalfMemory;
typedef logic [7:0][`BYTE - 1 : 0]                                    ByteMemory;

typedef logic [`ADDRESS_SIZE - 1 : 0]                                 Address;
typedef logic [`CELLS_NEEDED * 2 - 1 : 0][`INSTRUCTION_SIZE - 1 : 0]  InstructionLine;
typedef logic [`CELLS_NEEDED - 1 : 0][`DOUBLE - 1 : 0]                DoubleLine;
typedef logic [`CELLS_NEEDED * 2 - 1 : 0][`WORD - 1 : 0]              WordLine;
typedef logic [`CELLS_NEEDED * 4 - 1 : 0][`HALF - 1 : 0]              HalfLine;
typedef logic [`CELLS_NEEDED * 8 - 1 : 0][`BYTE - 1 : 0]              ByteLine;


typedef logic signed [`DATA_SIZE * 2 - 1 : 0]   DoubleWordSigned;
typedef logic signed [`DATA_SIZE - 1 : 0]       MemoryWordSigned;
typedef logic signed [`DATA_SIZE / 2 - 1 : 0]   HalfWordSigned;
typedef logic unsigned [`DATA_SIZE * 2 - 1 : 0] DoubleWordUnsigned;
typedef logic unsigned [`DATA_SIZE - 1 : 0]     MemoryWordUnsigned;
typedef logic unsigned [`DATA_SIZE / 2 - 1 : 0] HalfWordUnsigned;

typedef logic [`DATA_SIZE * 2 - 1 : 0]          DoubleWord;
typedef logic [`DATA_SIZE - 1 : 0]              MemoryWord;
typedef logic [`DATA_SIZE / 2 - 1 : 0]          HalfWord;
typedef logic [`INSTRUCTION_SIZE - 1 : 0]       InstructionWord;
typedef logic [`NUMBER_OF_REGISTERS_B - 1 : 0]  Register;
typedef logic [`IMMEDIATE_SIZE - 1 : 0]         Immediate;



// OFFSET bits will alawys be a multiple of 4
// TAG SIZE + INDEX + OFFSET
//   53         5       6
`define WRITE1          1
`define WRITE2          `WRITE1 * 2
`define READ1           `WRITE2 * 2
`define READ2           `READ1  * 2
`define IREAD           `READ2  * 2


// These types of instructions can reserve the cache if requested address is in memory
typedef struct packed {
  logic iread;
  logic read2;
  logic read1;
  logic write2;
  logic write1;
} cache_reserve;

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




typedef struct packed {
  Address address;
  Address jump_location;
  MemoryWord instruction;
} branch;



// Memory Instruction Type
typedef enum logic[3:0] { 
  LB, LBU, LH, LHU, LW, LWU, LD,
  SB, SH, SW, SD 
} memory_instruction_type;

typedef enum logic { LOAD, STORE } memory_instruction_category;

// ALU operation
typedef enum logic [5:0] {
  // Normal ALU
  ADD, SUB, AND, OR, XOR,
  SLT, SRL, SRA, SLL,
  ADDW, SUBW, SLTW, SRAW, SRLW, SLLW,
  BEQ, BNE, BGE, BLT, BGEU, BLTU,
  //M extention
  MUL, MULH, MULHU, MULHSU,
  MULW, DIV, DIVU, REM,
  REMU, DIVW, DIVUW,
  REMW, REMUW
} alu_operation;

typedef struct packed {
  logic alusrc;                        // ALU source (rs2 or imm)
  logic apc;                           // Adding PC
  logic cjump;                         // Conditional Jump
  logic ecall;                         // e-call
  logic memtoreg;                      // Memory To Register
  logic memwr;                         // Memory Write
  logic regwr;                         // Register Write
  logic ucjump;                        // Unconditional Jump
  logic unsupported;                   // *Unsuppored Instruction
  logic usign;                         // Unsigned
  alu_operation aluop;                 // ALU Operation
  memory_instruction_type memory_type; // Memory Instruction Type
} control_bits;






/////////////////////////////////////////////////////////////////////////////////
/********************************** REGISTERS **********************************/
/////////////////////////////////////////////////////////////////////////////////
// Register between cache and branch prediction 
typedef struct packed {
  InstructionWord instruction;
  MemoryWord pc;
} cache_branchprediction_register;

// Register between fetch and decode
typedef struct packed {
  InstructionWord instruction;
  MemoryWord pc;
} fetch_decode_register;

// Register between decode and register fetch
typedef struct packed {
  InstructionWord instruction;
  MemoryWord pc;
	Register rs1;
  Register rs2;
  Register rd;
	Immediate imm;
	control_bits ctrl_bits;
} decode_registers_register;

// Register between register fetch and dipatch
typedef struct packed {
  InstructionWord instruction;
  MemoryWord pc;
	Register rs1;
  Register rs2;
  Register rd;
  MemoryWord rs1_value;
  MemoryWord rs2_value;
	Immediate imm;
	control_bits ctrl_bits;
} registers_dispatch_register;

typedef struct packed {
  int tag;
  MemoryWord sourceA;
  MemoryWord sourceB;
  MemoryWord data; // For stores
	control_bits ctrl_bits;
} issue_execute_register;

typedef struct packed {
  int tag;
  MemoryWord result;
  MemoryWord data;
  control_bits ctrl_bits;
} execute_memory_register;

typedef struct packed {
  int tag;
  MemoryWord data; // For loads/results
  control_bits ctrl_bits;
} memory_commit_register;


/////////////////////////////////////////////////////////////////////////////////
/********************************** HARDWARE ***********************************/
/////////////////////////////////////////////////////////////////////////////////
typedef struct packed {
  logic in_rob;
  int tag;
} map_table_entry;


// ROB Entry
typedef struct packed {
  logic ready;
  int tag;
  Register rd;
  MemoryWord value;
  control_bits ctrl_bits;
} rob_entry;

// Reservation Station Entry
typedef struct packed {
  logic busy;
  int id;
  int tag;
  int tag_1;
  int tag_2;
  MemoryWord value_1;
  MemoryWord value_2;
  MemoryWord imm;
  control_bits ctrl_bits;
} rs_entry;

// Load/Story Queue Entry
typedef struct packed {
  logic ready;
  int tag;
  longint color;
  Address address;
  MemoryWord value;
  memory_instruction_category category;
  memory_instruction_type memory_type;
} lsq_entry;

typedef struct packed {
  int tag;
  MemoryWord value;
} cdb;

typedef struct packed {
  Register regstr;
  MemoryWord value;
} Victim;
