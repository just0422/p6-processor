module branch_predictor 
(
  input clk,
  input reset, 

  input frontend_stall,

  input [`ADDRESS_SIZE - 1 : 0] pc,
  input [`INSTRUCTION_SIZE - 1 : 0] instruction,
  output [`ADDRESS_SIZE - 1 : 0] next_pc,
  output overwrite_pc,
  
  input flush,
  input InstructionWord retire_instruction,
  input Address retire_pc
);

  branch [`BTB_SIZE - 1 : 0] btb, btb_register;

  always_comb begin
    overwrite_pc = 0;
    case (instruction[6:0]) // Op Code
      7'b1100011: begin // Conditional Branch
                    Address pc_index = (pc >> 2) % `BTB_SIZE;
                    if (btb_register[pc_index].address == pc) begin
                      overwrite_pc = btb_register[pc_index].taken;
                      next_pc = btb_register[pc_index].taken ? 
                                            btb_register[pc_index].jump_location : 
                                            btb_register[pc_index].address + 4;
                    end else begin
                      overwrite_pc = 1;
                      next_pc = pc + {{52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                      btb[pc_index] = { overwrite_pc, instruction, pc, next_pc };
                    end

                    //target = pc + {{52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                  end
      //7'b1100111: begin end// jalr
  //    7'b1101111: begin // Uncoditional Jump (JAL)
 //                   overwrite_pc = 1;
//                    next_pc = pc + {{44{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21] , 1'b0};
  //                end
      //7'b1110011: ecall_stall = instruction[31:7] == 0;
      default   : begin
                    overwrite_pc = 0;
                    next_pc = pc + 4;
                  end
    endcase
  end

  always_ff @(posedge clk)
    btb_register <= btb;

  always_ff @(posedge clk) begin
    if (flush && btb_register[(retire_pc >> 2) % `BTB_SIZE].instruction == retire_instruction)
      btb_register[retire_instruction].taken <= !btb_register[retire_instruction].taken;

  end

endmodule
