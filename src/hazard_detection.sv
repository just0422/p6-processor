module hazard_detection
(
  // Housekeeping
  input clk,
  input reset, 

  // Cache inputs
  input busy, overwrite_pc,
  input mem_write, mem_read,
  input InstructionWord instruction,
  input data_busy1, data_finished1, data_missed1,
  input data_busy2, data_finished2, data_missed2,
  input write_busy, write_finished,
  input flushing,

  // Hardware Inputs
  input rob_full,

  // Retire Inputs
  input rob_entry rob [`ROB_SIZE - 1 : 0],
  input int rob_head,

  // Output
  output fetch_stall, frontend_stall, backend_stall1, backend_stall2, retire_stall
);

  always_comb begin
    fetch_stall = reset;

    fetch_stall |= (busy || overwrite_pc);
    fetch_stall |= flushing;
    fetch_stall |= rob_full;
  end
  always_comb begin
    frontend_stall = reset;

    frontend_stall |= rob_full || busy;
  end

  always_comb begin
    backend_stall1 = reset;
    backend_stall1 |= data_missed1 || data_busy1 || data_finished1;

    backend_stall2 = reset;
    backend_stall2 |= data_missed2 || data_busy2 || data_finished2;
  end

  always_comb begin
    retire_stall = reset;

    retire_stall |= mem_write;
  end

endmodule
