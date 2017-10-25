`define ADDRESS_SIZE                64
`define BLOCK_SIZE                  64
`define BUS_DATA_WIDTH              64
`define BUS_TAG_WIDTH               13
`define BTB_SIZE                    4
`define CELLS_NEEDED                8
`define CELLS_NEEDED_B              $clog2(`CELLS_NEEDED - 1)
`define DATA_SIZE                   64
`define DIRTY                       1
`define IMMEDIATE_SIZE              64
`define INDEX_SIZE                  32 
`define INDEX_SIZE_B                $clog2(`INDEX_SIZE - 1)
`define INDEXES_PER_WAY             32
`define INSTRUCTION_SIZE            32
`define INVALIDATE                  0'h0800
`define LSQ_SIZE                    `BTB_SIZE
`define MEM_READ                    0'h1100
`define MEM_WRITE                   0'h0100
`define MEMORY_MASK                 64'hffffffffffffffC0
`define NUMBER_OF_REGISTERS         32
`define NUMBER_OF_REGISTERS_B       $clog2(`NUMBER_OF_REGISTERS - 1)
`define OFFSET_SIZE                 64 
`define OFFSET_SIZE_B               $clog2(`OFFSET_SIZE - 1)
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

`define DOUBLE_MASK                 64'hFFFFFFFFFFFFFFFF
`define WORD_MASK                   32'hFFFFFFFF
`define HALF_MASK                   16'hFFFF
`define BYTE_MASK                    8'hFF


// Data Structure Lengths
`define CONTROL_BITS_SIZE           $bits(control_bits)


// Used in cache insert to break up response
typedef logic [1:0][`WORD - 1 : 0]                                    WordMemory;
typedef logic [3:0][`HALF - 1 : 0]                                    HalfMemory;
typedef logic [7:0][`BYTE - 1 : 0]                                    ByteMemory;

typedef logic [`DOUBLE - 1 : 0]                                       Double;
typedef logic [`WORD - 1 : 0]                                         Word;
typedef logic [`HALF - 1 : 0]                                         Half;
typedef logic [`BYTE - 1 : 0]                                         Byte;

typedef logic [`ADDRESS_SIZE - 1 : 0]                                 Address;
typedef logic [`CELLS_NEEDED * `DOUBLE - 1 : 0]                       Line;
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

// Cache Cell
typedef logic [`DATA_SIZE - 1 : 0] cache_cell; // One Cell of Size 64
// Cache line
typedef struct packed {
  logic valid;
  logic dirty;
  logic [`TAG_SIZE_B - 1 : 0] tag;
  Address base_address;
  cache_cell [`CELLS_NEEDED - 1 : 0] cache_cells; // 64 byte offset (8 cells)
} cache_line;
// Cache Block = 32 cache lines
typedef cache_line[`INDEXES_PER_WAY - 1 : 0] cache_block;
// Way
typedef cache_block [`WAYS - 1 : 0] full_cache;

typedef logic [`CELLS_NEEDED - 1 : 0][`DATA_SIZE - 1 : 0] CacheCells;


// BTB Entry
typedef struct packed {
  logic taken;
  InstructionWord instruction;
  Address address;
  Address jump_location;
} branch;



// Memory Instruction Type
typedef enum logic[3:0] { 
  LB, LBU, LH, LHU, LW, LWU, LD,
  SB, SH, SW, SD 
} memory_instruction_type;

typedef enum logic { LOAD, STORE } memory_instruction_category;

// ALU operation
typedef enum logic [5:0] {                // 36
  // Normal ALU
  ADD, SUB, AND, OR, XOR,                 // 5
  SLT, SLTU, SRL, SRA, SLL,               // 5
  ADDW, SUBW, SRAW, SRLW, SLLW,           // 5
  BEQ, BNE, BGE, BLT, BGEU, BLTU,         // 6
  LUI, JALR,                              // 2
  //M extention
  MUL, MULH, MULHU, MULHSU,               // 4
  MULW, DIV, DIVU, REM,                   // 4
  REMU, DIVW, DIVUW,                      // 3
  REMW, REMUW                             // 2
} alu_operation;

typedef struct packed {
  logic alusrc;                        // ALU source (rs2 or imm)       21
  logic apc;                           // Adding PC                     20
  logic cjump;                         // Conditional Jump              19
  logic ecall;                         // e-call                        18
  logic memtoreg;                      // Memory To Register            17
  logic memwr;                         // Memory Write                  16
  logic regwr;                         // Register Write                15
  logic ucjump;                        // Unconditional Jump            14
  logic unsupported;                   // *Unsuppored Instruction       13
  logic usign;                         // Unsigned                      12
  logic branch_prediction;             // 1 = taken, 0 = not taken      11
  logic flush;                         //                               10
  alu_operation aluop;                 // ALU Operation                  9 | 4
  memory_instruction_type memory_type; // Memory Instruction Type        3 | 0
} control_bits;




typedef logic [$clog2(`ROB_SIZE) : 0] RobSize;
typedef logic [$clog2(`LSQ_SIZE) : 0] LsqSize;
typedef logic [$clog2(`RS_SIZE) : 0] ResSize;
//typedef int RobSize;
//typedef int LsqSize;
//typedef int ResSize;

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
  Address pc;
  logic branch_prediction;
  Address jumpto;
} fetch_decode_register;

// Register between register decode and dipatch
typedef struct packed {
  InstructionWord instruction;
  MemoryWord pc;
  Address jumpto;
	Register rs1;
  Register rs2;
  Register rd;
	Immediate imm;
	control_bits ctrl_bits;
} decode_dispatch_register;

// Register between issue and execute
typedef struct packed {
  RobSize tag;
  LsqSize lsq_id;
  MemoryWord sourceA;
  MemoryWord sourceB;
  MemoryWord data; // For stores
	control_bits ctrl_bits;
} issue_execute_register;

// Register between execute and memory
typedef struct packed {
  RobSize tag;
  LsqSize lsq_id;
  logic take_branch;
  MemoryWord result;
  MemoryWord data;
  control_bits ctrl_bits;
} execute_memory_register;

// Register between memory and commit
typedef struct packed {
  RobSize tag;
  logic take_branch;
  MemoryWord data; // For loads/results
  control_bits ctrl_bits;
} memory_commit_register;


/////////////////////////////////////////////////////////////////////////////////
/********************************** HARDWARE ***********************************/
/////////////////////////////////////////////////////////////////////////////////

typedef struct packed {
  logic in_rob;
  RobSize tag;
} map_table_entry;


// ROB Entry
typedef struct packed {
  logic ready;
  Address pc;
  InstructionWord instruction;
  RobSize tag;
  Register rd;
  MemoryWord value;
  control_bits ctrl_bits;
} rob_entry;

// Reservation Station Entry
typedef struct packed {
  logic busy;
  ResSize id;
  LsqSize lsq_id;
  RobSize tag;
  RobSize tag_1;
  RobSize tag_2;
  MemoryWord value_1;
  MemoryWord value_2;
  MemoryWord imm;
  control_bits ctrl_bits;
} rs_entry;

// Load/Story Queue Entry
typedef struct packed {
  logic ready;
  LsqSize id;
  RobSize tag;
  Address address;
  MemoryWord value;
  memory_instruction_category category;
  memory_instruction_type memory_type;
} lsq_entry;

// CDB
typedef struct packed {
  RobSize tag;
  MemoryWord value;
} cdb;

