module scheduler
(
  input clk,
  input reset,

  // The tag that will be associated with this entry
  input int rob_tail,
  input int lsq_tail,
  input int rob_count,
  input int lsq_count,
  input logic frontend_stall,
 
  // Needed for assigning values an tags
  input map_table_entry map_table[`NUMBER_OF_REGISTERS - 1 : 0],
  input rob_entry rob[`ROB_SIZE - 1 : 0],
  input lsq_entry lsq[`LSQ_SIZE - 1 : 0],
  input rs_entry res_stations[`RS_SIZE - 1 : 0],

  input Address pc, jumpto,
  input InstructionWord instruction,
  input Register rs1, rs2, rd,
  input MemoryWord val1, val2, immediate,
  input control_bits ctrl,

  // CDB Inputs
  input cdb cdb1,
  input cdb cdb2,

  // Should output the created entries (handle indexing outside)
  output map_table_entry mte,
  output rob_entry re,
  output rs_entry rse,
  output lsq_entry le,
  
  output ResSize station_id,
  output RobSize tag,
  output logic bypass_rs, // Should I skip the Reservation stations??
  output logic rob_full,
  output logic rob_increment, // Will we need to insert into rob
  output logic lsq_full,
  output logic lsq_increment,

  output logic nop
);

  always_comb
    nop = instruction ? 0 : 1;
  
  task assign_tag_value;
    input Register register_source;
    input MemoryWord register_value;
    output MemoryWord rs_value;
    output ResSize rs_tag;
    begin
      rs_value = 0;
      rs_tag = 0;
      // Can't believe this edge case came up lol
      if (register_source == 0) 
        rs_value = 0;
      // Check the CDB Broadcasts
      else if (cdb1.tag && cdb1.tag == map_table[register_source].tag)
        rs_value = cdb1.value;
      else if (cdb2.tag && cdb2.tag == map_table[register_source].tag)
        rs_value = cdb2.value;
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
    MemoryWord rs_val_1 = 0, rs_val_2 = 0;
    ResSize rs_tag_1 = 0, rs_tag_2 = 0;
    control_bits ctrl_bits = ctrl;
    rse = 0;
    
    // Assign tags
    assign_tag_value(.register_source(rs1), .register_value(val1),
                     .rs_value (rs_val_1), .rs_tag(rs_tag_1));
    assign_tag_value(.register_source(rs2), .register_value(val2),
                     .rs_value (rs_val_2), .rs_tag(rs_tag_2));

    // Unique Cases
    // Is the PC one of the operands??
    if (ctrl_bits.apc) begin
      rs_val_1 = pc;
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
      rse.imm = immediate;

      bypass_rs = 0;
    // Skip reservation stations for JAL
    end else if (ctrl_bits.ucjump) begin
      if (ctrl_bits.alusrc) begin
        rse.busy = 1;
        rse.tag = rob_tail;
        rse.ctrl_bits = ctrl_bits;
        rse.value_1 = rs_val_1;
        rse.tag_1 = rs_tag_1;
        rse.value_2 = 0;
        rse.tag_1 = 0;
        rse.imm = immediate;
      end else begin
        rse.busy = 1;
        rse.tag = rob_tail;
        rse.ctrl_bits = ctrl_bits;
        rse.imm = immediate;
        //bypass_rs = 1; // Do we need to skip reservation stations
      end
    // Otherwaise behave as normal
    end else if (ctrl_bits.aluop == LUI) begin
      rse = 0;
      bypass_rs = 1;
    end else if (ctrl_bits) begin
      rse.tag = rob_tail;
      rse.busy = 1;
      rse.ctrl_bits = ctrl_bits;
      rse.value_1 = rs_val_1;
      rse.value_2 = rs_val_2;
      rse.tag_1 = rs_tag_1;
      rse.tag_2 = rs_tag_2;

      // Assign the immediate field if we have one
      if (ctrl_bits.alusrc) begin
        rse.imm = immediate;
        // TODO: Check to see if we have to zero out V2 and T2
      end

      if (ctrl_bits.memwr || ctrl_bits.memtoreg)
        rse.lsq_id = lsq_tail;

      bypass_rs = 0;
    end
  end

  // Find empty reservation station
  always_comb begin
    station_id = 0;
    for (int i = 0; i < `RS_SIZE; i++) begin
      if (!res_stations[i].busy) begin
        station_id = i;
        break;
      end
    end
  end

  // Create ROB Entries
  always_comb begin
    control_bits ctrl_bits = ctrl;
    tag = rob_tail; //rob[rob_tail - 1].tag;
    re = 0;
    
    rob_increment = 0;
    if (ctrl_bits && !frontend_stall) begin
      rob_increment = 1;
    end

    rob_full = 0;
    if (rob_count >= `ROB_SIZE) begin
      rob_full = 1;
    end

    re.pc = pc;
    re.instruction = instruction;
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
      re.rd = rd;
      //if (!ctrl_bits.alusrc) begin
      //  re.value = pc + 4;
      //end
    // Otherwise behave as normal
    end else if (ctrl_bits.aluop == LUI) begin
      re.ready = 1;
      re.rd = rd;
      re.value = immediate;
    end if (ctrl_bits) begin
      re.rd = rd;
      re.ctrl_bits = ctrl_bits;

      if (ctrl_bits.cjump)
        re.value = jumpto; // TODO: DANGER: PC + 4 should be here
    end
  end

  // Create Map Table Entries
  always_comb begin
    control_bits ctrl_bits = ctrl;
    mte = 0;
    
    // Didn't think code would actually do something like this for me to protect against
    if (rd == 0)
      mte = 0;
    // No map table entry needed for Unsupported and Ecall
    else if (ctrl_bits.unsupported || ctrl_bits.ecall) begin
      mte = 0;
    // Set entry as ready for JAL && JALR
    end else if (ctrl_bits.ucjump) begin
      mte.tag = rob[rob_tail - 1].tag;
    end else if (ctrl_bits.aluop == LUI) begin
      mte.tag = rob[rob_tail - 1].tag;
      mte.in_rob = 1;
    // Otherwise behave as normal
    end else if (ctrl_bits.regwr) begin
      mte.tag = rob[rob_tail - 1].tag;
      mte.in_rob = 0;
    end
  end

  // Create LSQ Entries
  always_comb begin
    control_bits ctrl_bits = ctrl;
    int previous_le = lsq_tail > 1 ? lsq_tail - 2 : `LSQ_SIZE - 1;
    le = 0;

    // Prep for loads
    if (ctrl_bits.memtoreg) begin
      le.tag = rob_tail;
      le.id = lsq_tail;
      le.category = LOAD;
      le.memory_type = ctrl_bits.memory_type;
    end

    // Prep for stores
    if (ctrl_bits.memwr) begin
      le.tag = rob_tail;
      le.id = lsq_tail;
      le.category = STORE;
      le.memory_type = ctrl_bits.memory_type;
    end

    lsq_increment = 0;
    if ((ctrl_bits.memwr || ctrl_bits.memtoreg) && !frontend_stall) begin
      lsq_increment = 1;
    end

    lsq_full = 0;
    if (lsq_count >= `LSQ_SIZE) begin
      lsq_full = 1;
    end
  end
endmodule
