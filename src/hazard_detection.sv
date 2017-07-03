module hazard_detection
(
  // Housekeeping
  input clk,
  input reset, 

  // Cache inputs
  input busy, overwrite_pc, instruction,

  // Outputs
  output frontend_stall
);

  always_comb begin
    frontend_stall = reset;

    frontend_stall |= (busy || overwrite_pc || !instruction);
  end

endmodule
