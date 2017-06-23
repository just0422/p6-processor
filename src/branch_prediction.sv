module branch_predictor 
(
  input clk,
  input reset, 

  input [`ADDRESS_SIZE - 1 : 0] pc,
  input [`INSTRUCTION_SIZE - 1 : 0] instruction,
  output [`ADDRESS_SIZE - 1 : 0] next_pc
);

  always_comb begin
    next_pc = pc + 4;
  end

endmodule
