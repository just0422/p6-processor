module retire (
  // Housekeeping
  input clk, reset,

  input rob_entry rob_head,

  output Register rd,
  output MemoryWord value,

  output map_table_entry mte,
  output rob_entry re,

  output rob_decrement
);

  always_comb begin
    rd = 0;
    value = 0;
    re = 0;
    mte  = 0;
    rob_decrement = 0;

    if (rob_head.ready) begin
      rd = rob_head.rd;
      value = rob_head.value;

      rob_decrement = 1;
      re = rob_head;

    end

  end

endmodule
