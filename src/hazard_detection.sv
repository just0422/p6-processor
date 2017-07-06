module hazard_detection
(
  // Housekeeping
  input clk,
  input reset, 

  // Cache inputs
  input busy, overwrite_pc, instruction,

  // Hardware Inputs
  input rob_full,

  // Outputs
  output frontend_stall,
  output rob_increment, rob_decrement
);

  always_ff @(posedge clk) begin
    frontend_stall = reset;

    frontend_stall |= (busy || overwrite_pc || !instruction);
    frontend_stall |= rob_full;
  end

  always_comb begin
    //rob_increment = !reset;
    //rob_increment &= !busy && !overwrite_pc && instruction;
  end

endmodule
