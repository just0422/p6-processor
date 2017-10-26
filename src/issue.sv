module issue
(
  input clk,
  input reset,

  // Used to find the next res_station
  input rob_entry rob[`ROB_SIZE - 1 : 0],
  input rs_entry res_stations[`RS_SIZE - 1 : 0],
  input lsq_entry lsq[`LSQ_SIZE - 1 : 0],

  input int rob_head, rob_tail,
  input int lsq_head, lsq_tail,

  // Output Needed Issue values
  output RobSize tag1,              tag2, 
  output ResSize rs_id1,            rs_id2,
  output LsqSize lsq_id1,           lsq_id2, 
  output MemoryWord sourceA1,       sourceA2,
  output MemoryWord sourceB1,       sourceB2,
  output MemoryWord data1,          data2,
  output control_bits ctrl_bits1,   ctrl_bits2
);

  // Find an earlier store
  function earlier_store;
    input int lsq_id;
    begin
      if (lsq_head < lsq_tail) begin
        //$display("lsq_head <= lsq_tail -- (%1d,%1d),%1d", lsq_head, lsq_tail, lsq_id);
        for (int i = lsq_id - 1; i >= lsq_head; i--) begin
          //$display("Store %x --> %x", i, lsq[i - 1].category == STORE);
          if (lsq[i - 1].category == STORE)
            return 1;
        end
      end else begin
        for (int i = lsq_head; i <= `LSQ_SIZE; i++) begin
          if (i == lsq_id)
            return 0;
          if (lsq[i - 1].category == STORE)
            return 1;
        end
        for (int i = 1; i < lsq_tail; i++) begin
          if (i == lsq_id)
            return 0;
          if (lsq[i - 1].category == STORE)
            return 1;
        end
      end
      return 0;
    end
  endfunction
  
  // Find an earlier jump
  function earlier_jump;
    input int rob_tag;
    begin
      //$display("Got Here - %1d - %1d - %1d", rob_head, rob_tail, rob_tag);
      if (rob_head < rob_tail) begin
        for (int i = rob_head; i < rob_tag; i++) begin
          //$display("\t\t%x - %x - %b - %b", rob[i - 1].pc, rob[i- 1].instruction, rob[i - 1].ctrl_bits.ucjump, rob[i - 1].ctrl_bits.cjump);
          if (rob[i - 1].ctrl_bits.ucjump || rob[i - 1].ctrl_bits.cjump) begin
            return 1;
          end
        end
      end else begin
        for (int i = rob_head; i <= `ROB_SIZE; i++) begin
          if (i == rob_tag)
            return 0;
          if (rob[i - 1].ctrl_bits.ucjump || rob[i - 1].ctrl_bits.cjump)
            return 1;
        end
        for (int i = 1; i < rob_tail; i++) begin
          if (i == rob_tag)
            return 0;
          if (rob[i - 1].ctrl_bits.ucjump || rob[i - 1].ctrl_bits.cjump) begin
            return 1;
          end
        end
      end
      return 0;
    end
  endfunction

  
  always_comb begin : issue
    logic first_selected = 0;

    tag1 = 0;
    lsq_id1 = 0;
    rs_id1 = 0;
    sourceA1 = 0;
    sourceB1 = 0;
    data1 = 0;
    ctrl_bits1 = 0;

    tag2 = 0;
    lsq_id2 = 0;
    rs_id2 = 0;
    sourceA2 = 0;
    sourceB2 = 0;
    data2 = 0;
    ctrl_bits2 = 0;


    // Check all reservation stations
    for (int i = 0; i < `RS_SIZE; i++) begin
      if ( res_stations[i].busy &&      // Station is busy
          !res_stations[i].tag_1 &&     // First tag is free
          !res_stations[i].tag_2) begin // Second tag is free

        if (res_stations[i].ctrl_bits.memtoreg) begin
          // Wait until there are no more jumps or stores before issuing loads
          if (earlier_store(res_stations[i].lsq_id) || earlier_jump(res_stations[i].tag)) begin
            continue;
          end
          
          // Stores go off in order
          if (res_stations[i].ctrl_bits.memwr) begin
            if (res_stations[i].lsq_id != lsq_head)
              continue;
          end
        end
        
        if (!first_selected) begin
          sourceA1 = res_stations[i].value_1;

          // If it's an i-instruction
          if (res_stations[i].ctrl_bits.alusrc)
            sourceB1 = res_stations[i].imm;
          else
            sourceB1 = res_stations[i].value_2;

          // Stores
          if (res_stations[i].ctrl_bits.memwr)
            data1 = res_stations[i].value_2;

          ctrl_bits1 = res_stations[i].ctrl_bits;
          rs_id1 = res_stations[i].id;
          tag1 = res_stations[i].tag;
          lsq_id1 = res_stations[i].lsq_id;

          first_selected = 1;
        end else begin
           sourceA2 = res_stations[i].value_1;

          // If it's an i-instruction
          if (res_stations[i].ctrl_bits.alusrc)
            sourceB2 = res_stations[i].imm;
          else
            sourceB2 = res_stations[i].value_2;

          // Stores
          if (res_stations[i].ctrl_bits.memwr)
            data2 = res_stations[i].value_2;

          ctrl_bits2 = res_stations[i].ctrl_bits;
          rs_id2 = res_stations[i].id;
          tag2 = res_stations[i].tag;
          lsq_id2 = res_stations[i].lsq_id;
          break;
        end
      end
    end
  end
endmodule
