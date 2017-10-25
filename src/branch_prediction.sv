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
    next_pc = pc + 4;
    // If it is a branch instruction
    if (instruction[6:0] == 7'b1100011) begin
      // Find the index int the btb
      Address pc_index = (pc >> 2) % `BTB_SIZE;
      // If the addresses align
      if (btb_register[pc_index].address == pc) begin
        overwrite_pc = btb_register[pc_index].taken;
        // Assign the pc to whatever was most recently chosen
        next_pc = btb_register[pc_index].taken ? 
                              btb_register[pc_index].jump_location : 
                              btb_register[pc_index].address + 4;
      end else begin
        // Otherwise put it into the BTB
        overwrite_pc = 1;
        next_pc = pc + {{52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        btb[pc_index] = { 1'b1, 
                          instruction, 
                          pc, 
                          pc + {{52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0}
                        };
      end
    end
  end


  always_ff @(posedge clk) begin
    // If we needed to flush, it means we mispredicted. Fix it.
    if (flush && btb_register[(retire_pc >> 2) % `BTB_SIZE].instruction == retire_instruction)
      btb_register[(retire_pc >> 2) % `BTB_SIZE].taken <= !btb_register[(retire_pc >> 2) % `BTB_SIZE].taken;
    else
      btb_register <= btb;

  end

endmodule
