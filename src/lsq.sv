module load_store_queue (
  input clk, reset,

  input int lsq_tail, lsq_head, lsq_count,
  input lsq_increment, lsq_decrement,
  input lsq_entry   memory_le1,     dispatch_le,
  input int         mem_index1,     dis_index,

  input lsq_entry lsq[`LSQ_SIZE - 1 : 0],

  output lsq_entry lsq_register[`LSQ_SIZE - 1 : 0],
  output int lsq_tail_register, lsq_head_register, lsq_count_register
);

  always_comb begin
    lsq_register = lsq;
    lsq_tail_register = lsq_tail;
    lsq_head_register = lsq_head;

    if (dispatch_le) begin
      lsq_register[lsq_tail_register - 1] = dispatch_le;
      lsq_tail_register = lsq_tail % `LSQ_SIZE + 1;

      if(lsq_increment ^ lsq_decrement && lsq_increment)
        lsq_count_register = lsq_count + 1;
    end

    if (memory_le1) begin
      lsq_register[mem_index1 - 1] = memory_le1;
    end
  end

  always_comb begin
    if (lsq_decrement) begin
      lsq_register[lsq_head - 1] = 0;

      lsq_head_register = lsq_head % `LSQ_SIZE + 1;

      if(lsq_increment ^ lsq_decrement && lsq_decrement)
        lsq_count_register = lsq_count - 1;
    end
  end
endmodule
