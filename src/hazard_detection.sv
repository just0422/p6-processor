module hazard_detection
(
  // Housekeeping
  input clk,
  input reset, 

  // Cache inputs
  input busy, overwrite_pc, instruction,
  input data_busy1, data_finished1, data_missed1,

  // Hardware Inputs
  input rob_full,

  // Retire Inputs
  input rob_entry rob [`ROB_SIZE - 1 : 0],
  input int rob_head,

  // Output
  output Victim victim, 

  output fetch_stall, frontend_stall, backend_stall
);

  //always_ff @(posedge clk) begin
  always_comb begin
    fetch_stall = reset;

    fetch_stall |= (busy || overwrite_pc || !instruction);
    fetch_stall |= rob_full;
  end
  always_comb begin
    frontend_stall = reset;

    frontend_stall |= rob_full;
  end

  always_comb begin
    backend_stall = reset;
    backend_stall |= data_missed1 || data_busy1 || data_finished1;
    //rob_increment = !reset;
    //rob_increment &= !busy && !overwrite_pc && instruction;
  end

endmodule
