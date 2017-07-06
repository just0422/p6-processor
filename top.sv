`include "Sysbus.defs"
`include "src/consts.sv"

`include "src/alu.sv"
`include "src/branch_prediction.sv"
`include "src/cache.sv"
`include "src/commit.sv"
`include "src/decoder.sv"
`include "src/dispatcher.sv"
`include "src/hazard_detection.sv"
`include "src/issue.sv"
`include "src/register_file.sv"
`include "src/retire.sv"

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

    rob_tail = 1;
    rob_head = 1;
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

    // Hardware hazards
    .rob_full(rob_full),

    // Output
    .frontend_stall(frontend_stall), // Stall when 1
    .rob_increment(rob_increment), // Basicall !frontend_stall
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
    if (!frontend_stall) begin
      cac_bp_reg <= { instruction_response, pc };
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
  Register decode_rs1;
  Register decode_rs2;
  Register decode_rd;
  Immediate decode_imm;
  control_bits decode_ctrl_bits;

  decoder decode(
    // Input
    .instruction(fet_dec_reg.instruction),

    // Output
    .register_source_1(decode_rs1),
    .register_source_2(decode_rs2),
    .register_destination(decode_rd),
    .imm(decode_imm),
    .ctrl_bits(decode_ctrl_bits)
  );

  always_ff @(posedge clk) begin
    if (!frontend_stall)
      dec_regs_reg <= {fet_dec_reg.instruction,
                      fet_dec_reg.pc, 
                      decode_rs1, decode_rs2, decode_rd, decode_imm, 
                      decode_ctrl_bits};
  end
  
  decode_registers_register dec_regs_reg;
  /************************ REGISTER FETCH ******************************/
  logic [`DATA_SIZE - 1 : 0] rs1_value;
  logic [`DATA_SIZE - 1 : 0] rs2_value;
  logic [`DATA_SIZE - 1 : 0] imm_value;

  register_file register_update (
    // House keeping
    .clk(clk), .reset(reset),

    // Register Read Inputs
    .rs1_in(dec_regs_reg.rs1),  .rs2_in(dec_regs_reg.rs2),
    // Register Read Outputs
    .rs1_out(rs1_value),        .rs2_out(rs2_value),


    // Register Write Inputs
    .rd(write_rd), .data(write_data), .regwr(write_regwr)
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
  logic rob_increment, rob_decrement, rob_full;
  int rob_head, rob_tail;
  int rob_count;

  cdb cdb1, cdb2;

  map_table_entry map_table [`NUMBER_OF_REGISTERS - 1 : 0];   // MAP TABLE
  rob_entry rob [`ROB_SIZE - 1 : 0];                          // ROB
  lsq_entry lsq [`LSQ_SIZE - 1 : 0];                          // LSQ
  rs_entry res_stations[`RS_SIZE - 1 : 0];                    // RESERVATION STATIONS

  // Holds values to be inserted into data structures
  map_table_entry dispatch_mte;
  rs_entry        dispatch_rse;
  rob_entry       dispatch_re;
  lsq_entry       dispatch_le;

  dispatcher dispatch(
    // Housekeeping
    .clk(clk), .reset(reset),

    // The tag that will be associated with this entry
    .rob_tail(rob_tail),
    .rob_count(rob_count),
    .frontend_stall(frontend_stall),
  
    // Need to read from the hardware structures
    .rob(rob),
    .map_table(map_table),
    .res_stations(res_stations),
    .regs_dis_reg(regs_dis_reg),

    // TODO: Need to include the CDB
    .cdb1(cdb1),
    .cdb2(cdb2),

    // Created rows for each data structure
    .mte(dispatch_mte),
    .re(dispatch_re),
    .rse(dispatch_rse),
    .le(dispatch_le),

    .bypass_rs(bypass_rs),
    .rob_full(rob_full),
    .rob_increment(rob_increment) // Does an instruction need to be inserted into the rob;
  );

  always_ff @(posedge clk) begin
    if (!frontend_stall) begin
      // add to the rob
      if (dispatch_re) begin
        rob[rob_tail - 1] <= dispatch_re;
        rob[rob_tail - 1].tag <= rob_tail;

        rob_tail <= rob_tail % `ROB_SIZE + 1;
        if (rob_increment ^ rob_decrement && rob_increment)
          rob_count <= rob_count + 1;

      end

      for(int i = 0; i < `RS_SIZE; i++) begin
        if(!res_stations[i].busy && !bypass_rs) begin
          res_stations[i] <= dispatch_rse;
          res_stations[i].id <= i + 1;
        end
      end

      if (dispatch_mte) begin
        map_table[dispatch_re.rd] <= dispatch_mte;
      end

      // TODO: Add to the LSQ.....

      // TODO: Perfect ROB/LSQ head/tail logic

      // TODO: Make sure that the ROB entry isn't set before first instruction arrives
    end
  end

  /****************************** ISSUE *******************************/
  int tag1, rs_id1;
  MemoryWord sourceA1, sourceB1, data1;
  control_bits ctrl_bits1;

  issue_execute_register ie_reg2;
  issue issue(
    // Housekeeping
    .clk(clk), .reset(reset),

    // Needed to find the next Reservation Station
    .res_stations(res_stations),

    // Outputs for each pipeline
    .tag1(tag1), .rs_id1(rs_id1), .sourceA1(sourceA1), .sourceB1(sourceB1),
    .data1(data1), .ctrl_bits1(ctrl_bits1),
    .iss_exe_reg_2(ie_reg2)
  );

  always_ff @(posedge clk) begin
    iss_exe_reg_1 = { tag1, sourceA1, sourceB1, data1, ctrl_bits1 };
    iss_exe_reg_2 = ie_reg2;
    res_stations[rs_id1 - 1].busy <= 0;
  end

  issue_execute_register iss_exe_reg_1;
  issue_execute_register iss_exe_reg_2;
  /***************************** EXECUTE ******************************/
  MemoryWord result1;
  logic zero1;

  alu alu1(
    // Inputs
    .ctrl_bits(iss_exe_reg_1.ctrl_bits),
    .sourceA(iss_exe_reg_1.sourceA),
    .sourceB(iss_exe_reg_1.sourceB),

    // Outpus
    .result(result1),
    .zero(zero1)
  );

  always_ff @(posedge clk) begin
    exe_mem_reg_1 = { iss_exe_reg_1.tag, result1, 
                      iss_exe_reg_1.data, iss_exe_reg_1.ctrl_bits };
  end

  execute_memory_register exe_mem_reg_1;
  execute_memory_register exe_mem_reg_2;
  /***************************** MEMORY *******************************/
  MemoryWord memory_data1;
  always_comb begin
    memory_data1 = exe_mem_reg_1.result;
  end

  always_ff @(posedge clk) begin
    mem_com_reg_1 = { exe_mem_reg_1.tag, memory_data1, 
                      exe_mem_reg_1.ctrl_bits };
  end

  memory_commit_register mem_com_reg_1;
  memory_commit_register mem_com_reg_2;
  /***************************** COMMIT *******************************/
  int cdb_tag1, cdb_tag2;
  MemoryWord cdb_value1, cdb_value2;

  rob_entry commit_re1;
  map_table_entry commit_mte1;

  commit commit(
    // Housekeeping
    .clk(clk), .reset(reset),

    // Inputs
    .data1(mem_com_reg_1.data),           .data2(mem_com_reg_2.data), 
    .tag1 (mem_com_reg_1.tag),            .tag2 (mem_com_reg_2.tag),
    .ctrl_bits1(mem_com_reg_1.ctrl_bits), .ctrl_bits2(mem_com_reg_2.ctrl_bits),

    .rob_entry1(rob[mem_com_reg_1.tag - 1]),
    
    // Outputs
    .cdb_tag1  (cdb_tag1),   .cdb_tag2(cdb_tag2),
    .cdb_value1(cdb_value1), .cdb_value2(cdb_value2),

    .re1(commit_re1),
    .mte1(commit_mte1)
  );

  always_ff @(posedge clk) begin
    cdb1 <= { cdb_tag1, cdb_value1 };
    cdb2 <= { cdb_tag2, cdb_value2 };
    
    rob[cdb_tag1 - 1] <= commit_re1;
    map_table[commit_re1.rd] <= commit_mte1;
  end


  
  /***************************** RETIRE *******************************/
  Register retire_rd;
  MemoryWord retire_value;
  rob_entry retire_re;
  map_table_entry retire_mte;
  
  retire retire(
    // Housekeeping
    .clk(clk), .reset(reset),

    .rob_head(rob[rob_head - 1]),
    
    // Outputs
    .rd(retire_rd), .value(retire_value),
    .mte(retire_mte),
    .re(retire_re),

    .rob_decrement(rob_decrement)
  );
 
  Register write_rd;
  MemoryWord write_data;
  logic write_regwr;
  always_ff @(posedge clk) begin
    if (retire_re.ready) begin
      if (retire_rd) begin
        write_rd <= retire_rd;
        write_data <= retire_value;
        write_regwr <= retire_re.ctrl_bits.regwr;
        

        // HMMMMM Will a later instruction entering the map table make this useless??
        //map_table[retire_re.rd] = retire_mte;
      end


      rob[rob_head - 1] = 0;
      rob[rob_head - 1].tag = retire_re.tag;

      rob_head <= rob_head % `ROB_SIZE + 1;
      if (rob_increment ^ rob_decrement && rob_decrement)
        rob_count <= rob_count - 1;

    end
  end
   
endmodule
