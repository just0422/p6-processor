module issue
(
  input clk,
  input reset,

  // Used to find the next res_station
  input rs_entry res_stations[`RS_SIZE-1:0],

  // Output Issue Executre Registers!!
  output issue_execute_register iss_exe_reg_1,
  output issue_execute_register iss_exe_reg_2
);
  
  always_comb begin : issue
    int first_selected;
    int second_selected;
    iss_exe_reg_1 = 0;
    iss_exe_reg_2 = 0;

    // Check all reservation stations
    for (int i = 0; i < `RS_SIZE; i++) begin
      if ( res_stations[i].busy &&      // Station is busy
          !res_stations[i].tag_1 &&     // First tag is free
          !res_stations[i].tag_2) begin // Second tag is free
        iss_exe_reg_1.sourceA = res_stations[i].value_1;

        // If it's an i-instruction
        if (res_stations[i].ctrl_bits.alusrc)
          iss_exe_reg_1.sourceB = res_stations[i].imm;
        else
          iss_exe_reg_1.sourceB = res_stations[i].value_2;

        // Stores
        if (res_stations[i].ctrl_bits.memwr)
          iss_exe_reg_1.data = res_stations[i].value_2;

        iss_exe_reg_1.ctrl_bits = res_stations[i].ctrl_bits;
        iss_exe_reg_1.rs_id = res_stations[i].id;
        iss_exe_reg_1.tag = res_stations[i].tag;
        break;
      end
    end
  end
  
endmodule
