module allocator
(
  input clk,
  input reset,

  // The tag that will be associated with this entry
  input int rob_tail,
 
  // Needed for assigning values an tags
  input map_table_entry map_table[`NUMBER_OF_REGISTERS - 1 : 0],
  input rob_entry rob[`ROB_SIZE-1:0],
  input rs_entry res_stations[`RS_SIZE-1:0],
  input registers_dispatch_register regs_dis_reg,

  // CDB Inputs
  input int cdb_tag_1,
  input int cdb_tag_2,
  input logic [`DATA_SIZE-1:0] cdb_value_1,
  input logic [`DATA_SIZE-1:0] cdb_value_2,

  // Should output the created entries (handle indexing outside)
  output map_table_entry mte,
  output rob_entry re,
  output rs_entry rse,
  output lsq_entry le,
  output logic bypass_rs // Should I skip the Reservation stations??
);
  
  task assign_tag_value;
    input Register register_source;
    input MemoryWord register_value;
    output MemoryWord rs_value;
    output int rs_tag;
    begin
      // Check the CDB Broadcasts
      if (cdb_tag_1 && cdb_tag_1 == map_table[register_source].tag)
        rs_value = cdb_value_1;
      else if (cdb_tag_2 && cdb_tag_2 == map_table[register_source].tag)
        rs_value = cdb_value_2;
      // Check for it in the ROB
      else if (map_table[register_source].tag && map_table[register_source].in_rob)
        rs_value = rob[map_table[register_source].tag - 1].value;
      // Check for it in the register file
      else if (!map_table[register_source].tag)
        rs_value = register_value;
      // I give up....allocate a new tag
      else
        rs_tag = map_table[register_source].tag;
    end
  endtask

  // Create Reservation station entry
  always_comb begin
    logic [`DATA_SIZE-1:0] rs_val_1 = 0, rs_val_2 = 0;
    int rs_tag_1 = 0, rs_tag_2 = 0;
    control_bits ctrl_bits = regs_dis_reg.ctrl_bits;
    
    // TODO
    // Remember to consider AUIPC and LUI for res station 1

    // Assign tags
    assign_tag_value(.register_source(regs_dis_reg.rs1), .register_value(regs_dis_reg.rs1_value),
                     .rs_value (rs_val_1), .rs_tag(rs_tag_1));
    assign_tag_value(.register_source(regs_dis_reg.rs2), .register_value(regs_dis_reg.rs2_value),
                     .rs_value (rs_val_2), .rs_tag(rs_tag_2));

    // Unique Cases
    // Is the PC one of the operands??
    if (ctrl_bits.apc) begin
      rs_val_1 = (regs_dis_reg.instruction[5]) ? 0 : 1; // TODO: DANGER: PC + 4 should substitute 1
      rs_tag_1 = 0;
    end
    
    // If it's an I-type instruction, let's remove the possibility of waiting for rs2
    if (ctrl_bits.alusrc && !ctrl_bits.memwr) begin
      rs_tag_2 = 0;
      rs_val_2 = 0;
    end
    
    
    // Skip reservation stations for ecall and unsupported characters
    if (ctrl_bits.ecall || ctrl_bits.unsupported) begin
      rse = 0;
      bypass_rs = 1; // Do we need to skip reservation stations
    // Remove second value if it's an unconditional jump
    end else if (ctrl_bits.ucjump && ctrl_bits.alusrc) begin
      rse.busy = 1;
      rse.ctrl_bits = ctrl_bits;
      rse.tag = rob_tail;

      rse.value_1 = rs_val_1;
      rse.value_2 = 0;
      rse.tag_1 = rs_tag_1;
      rse.tag_2 = 0;
      rse.imm = regs_dis_reg.imm;

      bypass_rs = 0;
    // Skip reservation stations for JAL
    end else if (ctrl_bits.ucjump) begin
      rse = 0;
      bypass_rs = 1; // Do we need to skip reservation stations
    // Otherwaise behave as normal
    end else begin
      rse.tag = rob_tail;
      rse.busy = 1;
      rse.ctrl_bits = ctrl_bits;
      rse.value_1 = rs_val_1;
      rse.value_2 = rs_val_2;
      rse.tag_1 = rs_tag_1;
      rse.tag_2 = rs_tag_2;

      // Assign the immediate field if we have one
      if (ctrl_bits.alusrc) begin
        rse.imm = regs_dis_reg.imm;
        // TODO: Check to see if we have to zero out V2 and T2
      end

      bypass_rs = 0;
    end
  end

  // Create ROB Entries
  always_comb begin
    control_bits ctrl_bits = regs_dis_reg.ctrl_bits;
    re = 0;
    re.tag = rob_tail;

    // Empty rob entry if it's unsupported
    if (ctrl_bits.unsupported)
      re.ready = 1;
    // Empty rob entery (except control bits!!)
    else if (ctrl_bits.ecall) begin
      re.ctrl_bits = ctrl_bits;
      re.ready = 1;
    // Prepare for unconditional jump
    end else if (ctrl_bits.ucjump) begin
      re.ctrl_bits = ctrl_bits;
      re.rd = regs_dis_reg.rd;
      re.value = 1;// TODO: DANGER: PC + 4 should be here
    // Otherwise behave as normal
    end else begin
      re.rd = regs_dis_reg.rd;
      re.ctrl_bits = ctrl_bits;

      if (ctrl_bits.cjump)
        re.value = 1; // TODO: DANGER: PC + 4 should be here
    end
  end

  // Create Map Table Entries
  always_comb begin
    control_bits ctrl_bits = regs_dis_reg.ctrl_bits;
    
    // No map table entry needed for Unsupported and Ecall
    if (ctrl_bits.unsupported || ctrl_bits.ecall)
      mte = 0;
    // Set entry as ready for JALR
    // TODO: check this to see if the logic is correct
    else if (ctrl_bits.ucjump && ctrl_bits.alusrc)begin
      mte.tag = rob_tail;
      mte.in_rob = 1;
    // No map table entry needed for JAL
    end else if (ctrl_bits.ucjump)
      mte = 0;
    // Otherwise behave as normal
    else begin
      mte.tag = rob_tail;
      mte.in_rob = 0;
    end
  end

  // Create LSQ Entries
  always_comb begin
    control_bits ctrl_bits = regs_dis_reg.ctrl_bits;
    le = 0;

    // Prep for loads
    if (ctrl_bits.memtoreg) begin
      le.category = LOAD;
      le.memory_type = ctrl_bits.memory_type;
    end

    // Prep for stores
    if (ctrl_bits.memwr) begin
      le.category = STORE;
      le.memory_type = ctrl_bits.memory_type;
    end
  end
endmodule
