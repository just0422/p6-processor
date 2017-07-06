module issue
(
  input clk,
  input reset,

  // Used to find the next res_station
  input rs_entry res_stations[`RS_SIZE-1:0],

  // Output Needed Issue values
  output int tag1, rs_id1,
  output MemoryWord sourceA1, sourceB1, data1,
  output control_bits ctrl_bits1,
  output issue_execute_register iss_exe_reg_2
);
  
  always_comb begin : issue
    int first_selected;
    int second_selected;
    tag1 = 0;
    rs_id1 = 0;
    sourceA1 = 0;
    sourceB1 = 0;
    data1 = 0;
    ctrl_bits1 = 0;

    iss_exe_reg_2 = 0;

    // Check all reservation stations
    for (int i = 0; i < `RS_SIZE; i++) begin
      if ( res_stations[i].busy &&      // Station is busy
          !res_stations[i].tag_1 &&     // First tag is free
          !res_stations[i].tag_2) begin // Second tag is free
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
        break;
      end
    end
  end
  
endmodule
