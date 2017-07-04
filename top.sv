`include "Sysbus.defs"
`include "src/consts.sv"

`include "src/allocator.sv"
`include "src/alu.sv"
`include "src/branch_prediction.sv"
`include "src/cache.sv"
`include "src/decoder.sv"
`include "src/hazard_detection.sv"
`include "src/issue.sv"
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

  // Init data structures
  initial begin
    $display("Initializing top, entry point = 0x%x", entry);

    for (int i = 0; i < `ROB_SIZE; i++) begin
      rob[i] = 0;
      rob[i].tag = i + 1;
    end
    
    for (int i = 0; i < `RS_SIZE; i++) begin
      res_stations[i] = 0;
      res_stations[i].id = i + 1;
    end
  end

  always @ (posedge clk)
    if (reset) begin
      pc <= entry;
    end else begin
//      $finish;
    end

  /************************** HAZARD DETECTION *****************************/
  logic frontend_stall;
  hazard_detection hazards(
    // Housekeeping
    .clk(clk), .reset(reset),
    
    // Cache hazards
    .busy(i_busy), .overwrite_pc(overwrite_pc), .instruction(instruction_response),

    // Output
    .frontend_stall(frontend_stall) // Stall when 1
  );


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

  always_ff @(posedge clk) begin
    cac_bp_reg <= { instruction_response, pc };
    if (!frontend_stall) begin
      pc <= pc + 4;
      $display("%d - Hello World!  @ %x - %x", x, pc, instruction_response);
    end
  end

  cache_branchprediction_register cac_bp_reg;

  /************************ BRANCH PREDICTION ************************/
  logic overwrite_pc; // Do we need to overwrite the PC??

  // Branch Prediction
  branch_predictor predict (
    // Housekeeping
    .clk(clk), .reset(reset),

    // Inputs
    .pc(cac_bp_reg.pc),
    .instruction(cac_bp_reg.instruction),

    // Outputs
    .next_pc(next_pc),
    .overwrite_pc(overwrite_pc)
  );
  

  // Assign next PC value 
  always_ff @(posedge clk) begin
    if (!frontend_stall)
      fet_dec_reg <= cac_bp_reg;
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
    if (!frontend_stall)
      dec_regs_reg <= {fet_dec_reg.instruction,
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
    if (!frontend_stall)
      regs_dis_reg <= { dec_regs_reg.instruction, dec_regs_reg.pc,
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
    if (!frontend_stall) begin
      // add to the rob
      rob[rob_tail - 1] <= re;
      rob[rob_tail - 1].tag = rob_tail;

      for(int i = 0; i < `RS_SIZE; i++) begin
        if(!res_stations[i].busy && !bypass_rs) begin
          res_stations[i] <= rse;
          res_stations[i].id = i + 1;
        end
      end

      if (mte) begin
        map_table[re.rd] <= mte;
      end

      // TODO: Add to the LSQ.....

      // TODO: Perfect ROB/LSQ head/tail logic
      rob_tail <= 1;

      // TODO: Make sure that the ROB entry isn't set before first instruction arrives
    end
  end

  /****************************** ISSUE *******************************/
  issue_execute_register ie_reg1, ie_reg2;
  issue issue(
    // Housekeeping
    .clk(clk), .reset(reset),

    // Needed to find the next Reservation Station
    .res_stations(res_stations),

    // Outputs for each pipeline
    .iss_exe_reg_1(ie_reg1),
    .iss_exe_reg_2(ie_reg2)
  );

  always_ff @(posedge clk) begin
    iss_exe_reg_1 = ie_reg1;
    iss_exe_reg_2 = ie_reg2;
  end

  issue_execute_register iss_exe_reg_1;
  issue_execute_register iss_exe_reg_2;
  /***************************** EXECUTE ******************************/
  MemoryWord result1;
  logic zero1;
  alu alu1(
    .ctrl_bits(iss_exe_reg_1.ctrl_bits),
    .sourceA(iss_exe_reg_1.sourceA),
    .sourceB(iss_exe_reg_1.sourceB),

    .result(result1),
    .zero(zero1)
  );

  always_ff @(posedge clk) begin
  end

  //execute_memory_register exe_mem_reg_1;
  //execute_memory_register exe_mem_reg_2;
endmodule
