module retire (
  // Housekeeping
  input clk, reset,

  input rob_entry rob_head,
  input lsq_entry lsq_head,

  input retire_stall,

  output regwr,
  output Register rd,
  output MemoryWord value,

  output map_table_entry mte,
  output rob_entry re,
  output lsq_entry le,
  output int le_size,

  output rob_decrement,
  output lsq_decrement,

  output victim, 
  
  output flush,
  output Address jump_to
);

  always_comb begin
      rd = 0;
      value = 0;
      re = 0;
      mte  = 0;
      regwr = 0;
      rob_decrement = 0;

      le = 0;
      le_size = 0;
      lsq_decrement = 0;

      flush = 0;
      jump_to = 0;

    if (!retire_stall) begin
      if (rob_head.ready) begin
        rd = rob_head.rd;
        value = rob_head.rd ? rob_head.value : 0;
        regwr = rob_head.ctrl_bits.regwr;

        rob_decrement = 1;
        re = rob_head;

        if (rob_head.ctrl_bits.regwr && rob_head.ctrl_bits.ucjump && rob_head.ctrl_bits.alusrc) begin
          flush = 1;
          jump_to = rob_head.value;
          value = rob_head.pc + 4;
        end

        if (rob_head.ctrl_bits.cjump && rob_head.ctrl_bits.flush) begin
          flush = 1;
          jump_to = rob_head.value;
        end

        if (rob_head.tag == lsq_head.tag) begin
          le = lsq_head;
          lsq_decrement = 1;

          case(rob_head.ctrl_bits.memory_type)
            SB: le_size = 1;
            SH: le_size = 2;
            SW: le_size = 4; 
            SD: le_size = 8;
            default: le_size = 0;
          endcase
        end
      end
    end
  end

  always_comb
    victim = rob_head.ready && rob_head.ctrl_bits.regwr;

endmodule
