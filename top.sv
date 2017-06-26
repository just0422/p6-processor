`include "Sysbus.defs"
`include "src/consts.sv"

`include "src/allocator.sv"
`include "src/branch_prediction.sv"
`include "src/cache.sv"
`include "src/decoder.sv"
`include "src/register_file.sv"

module top
#(
  BUS_DATA_WIDTH = 64,
  BUS_TAG_WIDTH = 13
)
(
  input  clk,
         reset,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,
  
  // interface to connect to the bus
  output bus_reqcyc,
  output bus_respack,
  output [BUS_DATA_WIDTH-1:0] bus_req,
  output [BUS_TAG_WIDTH-1:0] bus_reqtag,
  input  bus_respcyc,
  input  bus_reqack,
  input  [BUS_DATA_WIDTH-1:0] bus_resp,
  input  [BUS_TAG_WIDTH-1:0] bus_resptag
);

  logic [63:0] pc, next_pc;

  int x = 0;
  always_ff @(posedge clk) begin
    x++;
    if (x > 200)
      $finish;
  end

  always @ (posedge clk)
    if (reset) begin
      pc <= entry;
    end else begin
//      $finish;
    end

  always_ff @ (posedge clk) begin
    if (!reset)
      instruction_read = 1;
  end

/************************** INSTRUCTION FETCH ******************************/
  logic [`INSTRUCTION_SIZE-1:0] instruction_response;
  logic [`ADDRESS_SIZE - 1:0] instruction_address;
  logic instruction_read;
  logic busy;
  
  logic [`DATA_SIZE-1:0] d_req_r, d_req_w, d_write, d_data;
  logic mem_read, mem_write;
  logic [3:0] req_size_w, req_size_r;
  logic i_busy, d_busy, w_busy;

  cache cache (
    // Housekeeping
    .clk(clk), .reset(reset),
    
    // MemRead                        // MemWrite
    .bus_respcyc(bus_respcyc),        .bus_reqack(bus_reqack),
    .bus_respack(bus_respack),        .bus_reqcyc(bus_reqcyc), 
    .bus_resptag(bus_resptag),        .bus_req(bus_req),
    .bus_resp(bus_resp),              .bus_reqtag(bus_reqtag), 
         
    .busy(i_busy),
    
    .instruction_read(instruction_read),
    .instruction_address(pc),
    .instruction_response(instruction_response),

    .mem_read(0),
    .mem_write(0)
  );

  // Branch Prediction
  branch_predictor branch_predictor (
    // Housekeeping
    .clk(clk), .reset(reset),

    // Inputs
    .pc(pc),
    .instruction(instruction_response),

    // Outputs
    .next_pc(next_pc)
  );
  

  // Assign next PC value 
  always_ff @(posedge clk) begin
    if (!i_busy && instruction_response) begin
      $display("%d - Hello World!  @ %x - %x", x, pc, instruction_response);
      pc <= next_pc;
      fet_dec_reg = { instruction_response , pc };
    end
  end
  
  fetch_decode_register fet_dec_reg;
  /************************ INSTRUCTION DECODE ************************/
  Register rs1;
  Register rs2;
  Register rd;
  Immediate imm;
  control_bits ctrl_bits;

  decoder decode(
    // Input
    .instruction(fet_dec_reg.instruction),

    // Output
    .register_source_1(rs1),
    .register_source_2(rs2),
    .register_destination(rd),
    .imm(imm),
    .ctrl_bits(ctrl_bits)
  );

  always_ff @(posedge clk) begin
    dec_regs_reg = {fet_dec_reg.instruction,
                    fet_dec_reg.pc, 
                    rs1, rs2, rd, imm, 
                    ctrl_bits};
  end
  
  decode_registers_register dec_regs_reg;
  /************************ REGISTER FETCH ******************************/
  logic [`DATA_SIZE - 1 : 0] rs1_value;
  logic [`DATA_SIZE - 1 : 0] rs2_value;
  logic [`DATA_SIZE - 1 : 0] imm_value;

  register_file register_file (
    // House keeping
    .clk(clk), .reset(reset),

    // Register Read Inputs
    .rs1_in(dec_regs_reg.rs1),  .rs2_in(dec_regs_reg.rs2),
    // Register Read Outputs
    .rs1_out(rs1_value),        .rs2_out(rs2_value)


    // TODO
    // DONT FORGET ABOUT THE STACKPTR WHEN WRITING 
  );

  always_ff @(posedge clk) begin
    regs_dis_reg = { dec_regs_reg.instruction, dec_regs_reg.pc,
                     dec_regs_reg.rs1, dec_regs_reg.rs2, dec_regs_reg.rd, 
                     rs1_value, rs2_value, dec_regs_reg.imm,
                     dec_regs_reg.ctrl_bits };
  end

  registers_dispatch_register regs_dis_reg;
  /*********************** INSTRUCTION DISPATCH ***********************/
  int rob_tail;

  map_table_entry map_table [`NUMBER_OF_REGISTERS - 1 : 0];   // MAP TABLE
  rob_entry rob [`ROB_SIZE - 1 : 0];                          // ROB
  lsq_entry lsq [`LSQ_SIZE - 1 : 0];                          // LSQ
  rs_entry res_stations[`RS_SIZE - 1 : 0];                    // RESERVATION STATIONS

  // Holds values to be inserted into data structures
  map_table_entry mte;
  rs_entry        rse;
  rob_entry       re;
  lsq_entry       le;

  allocator allocate(
    // Housekeeping
    .clk(clk), .reset(reset),

    // The tag that will be associated with this entry
    .rob_tail(rob_tail),
  
    // Need to read from the hardware structures
    .rob(rob),
    .map_table(map_table),
    .res_stations(res_stations),
    .regs_dis_reg(regs_dis_reg),

    // TODO: Need to include the CDB

    // Created rows for each data structure
    .mte(mte),
    .re(re),
    .rse(rse),
    .le(le),
    .bypass_rs(bypass_rs)
  );

  always_ff @(posedge clk) begin
    // add to the rob
    rob[rob_tail - 1] <= re;

    for(int i = 0; i < `RS_SIZE; i++) begin
      if(!res_stations[i].busy && !bypass_rs) begin
        res_stations[i] <= rse;
      end
    end

    if (mte) begin
      map_table[re.rd] <= mte;
    end

    // TODO: Add to the LSQ.....

    // TODO: Perfect ROB/LSQ head/tail logic
    rob_tail <= 1;
  end

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
