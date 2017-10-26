module commit (
  // Housekeeping
  input clk, reset,

  input MemoryWord data,
  input take_branch,
  input RobSize tag,
  input control_bits ctrl_bits,

  input rob_entry in_re,

  output int cdb_tag, 
  output MemoryWord cdb_value,

  output rob_entry out_re,
  output map_table_entry mte
);
  // Update CDB
  always_comb begin
    cdb_tag = 0;
    cdb_value = 0;

    if (tag && ctrl_bits.regwr && !in_re.ready) begin
      cdb_tag = tag;
      cdb_value = data;
    end
  end

  // Update rob entry
  always_comb begin
    out_re = 0;
    if (tag > 0) begin
      out_re = in_re;
      mte = 0;

      if (ctrl_bits.regwr) begin
        if (!ctrl_bits.cjump)
          out_re.value = data;
        if(out_re.rd) begin
          mte.tag = tag;
          mte.in_rob = 1;
        end 
      end

      if (ctrl_bits.cjump && (ctrl_bits.branch_prediction ^ take_branch))
        out_re.ctrl_bits.flush = 1;

      out_re.ready = 1; 
    end
  end
endmodule
