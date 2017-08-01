module commit (
  // Housekeeping
  input clk, reset,

  input MemoryWord data1, data2,
  input take_branch1, take_branch2,
  input int tag1, tag2,
  input control_bits ctrl_bits1, ctrl_bits2,

  input rob_entry rob_entry1,

  output int cdb_tag1, cdb_tag2,
  output MemoryWord cdb_value1, cdb_value2,

  output rob_entry re1,
  output map_table_entry mte1
);
  // Update CDB
  always_comb begin
    cdb_tag1 = 0;
    cdb_value1 = 0;

    if (tag1 && ctrl_bits1.regwr && !rob_entry1.ready) begin
      cdb_tag1 = tag1;
      cdb_value1 = data1;
    end
  end

  // Update rob entry
  always_comb begin
    re1 = 0;
    if (tag1 > 0) begin
      re1 = rob_entry1;
      mte1 = 0;

      if (ctrl_bits1.regwr) begin
        re1.value = data1;
        mte1.tag = tag1;
        mte1.in_rob = 1;
      end

      if (ctrl_bits1.branch_prediction ^ take_branch1)
        re1.ctrl_bits.flush = 1;

      re1.ready = 1; 
    end
  end
endmodule
