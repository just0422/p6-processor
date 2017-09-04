module memory 
(
  // Housekeeping
  input clk, reset,
  
  // Memory Inputs
  input control_bits ctrl_bits,
  input Address      address,
  input MemoryWord   data,

  input LsqSize      lsq_id,
  input RobSize      tag,


  input lsq_entry lsq[`LSQ_SIZE - 1 : 0],
  input int lsq_head, lsq_tail,
  
  // Outut
  output MemoryWord result1,

  output int lsq_pointer,
  output lsq_entry le,
  output lsq_entry lsq_register[`LSQ_SIZE - 1 : 0],

  output data_missed1,

  // Cache interface
  input                          data_ready1,    data_readyy2,
  input MemoryWord               data_response1, data_response2
);
  always_comb begin
    if (!(ctrl_bits.memwr || ctrl_bits.memtoreg))
      result1 = address;
  end

  always_comb begin
    int current_color;
    lsq_pointer = 0;
    le = 0;
    lsq_register = lsq;
    data_missed1 = 0;

    if(ctrl_bits.memwr) begin
      le = lsq[lsq_id - 1];
      le.ready = 1;
      le.address = address;
      le.value = data;
      lsq_pointer = lsq_id;

      if (lsq_head <= lsq_tail) begin
        // technically lsq_id == LSQ[id + 1]
        for (int i = lsq_id; i <= lsq_tail; i++) begin
          if (lsq[i - 1].address == address && lsq[i - 1].category == LOAD) begin
            lsq_register[i - 1].value = data;
            lsq_register[i - 1].ready = 1;
          end
        end
      end else begin
        // technically lsq_id == LSQ[id + 1]
        for (int i = lsq_id; i <= `LSQ_SIZE; i++) begin
          if (lsq[i - 1].address == address && lsq[i - 1].category == LOAD) begin
            lsq_register[i - 1].value = data;
            lsq_register[i - 1].ready = 1;
          end
        end

        for (int i = 1; i <= lsq_tail; i++) begin
          if (lsq[i - 1].address == address && lsq[i - 1].category == LOAD) begin
            lsq_register[i - 1].value = data;
            lsq_register[i - 1].ready = 1;
          end
        end
      end
    end
    
    if (ctrl_bits.memtoreg) begin
      // Find LSQ Entry
      if (lsq[lsq_id - 1].ready) begin
        result1 = lsq[lsq_id - 1].value;

        le = lsq[lsq_id - 1];
        le.ready = 1;
        data_missed1 = 0;
      end
      else begin
				if (lsq_head <= lsq_tail) begin
          for (int i = lsq_head; i < lsq_id; i++) begin
            if (lsq[i - 1].address == address && lsq[i - 1].category == STORE) begin
							result1 = lsq[i - 1].value; 

							le = lsq[lsq_id - 1];
							le.value = lsq[i - 1].value;
							le.ready = 1;
						end
          end
        end else begin
          for (int i = lsq_id - 1; i > 0; i --) begin
            if (lsq[i - 1].address == address && lsq[i - 1].category == STORE) begin
							result1 = lsq[i - 1].value; 

							le = lsq[lsq_id - 1];
							le.value = lsq[i - 1].value;
							le.ready = 1;
						end
          end
          for (int i = `LSQ_SIZE; i >= lsq_head; i--) begin
            if (lsq[i - 1].address == address && lsq[i - 1].category == STORE) begin
							result1 = lsq[i - 1].value; 

							le = lsq[lsq_id - 1];
							le.value = lsq[i - 1].value;
							le.ready = 1;
						end
          end
        end

        if (!le) begin
          if (!data_ready1)
            data_missed1 = 1;
          else begin
            lsq_register[lsq_id - 1].value = data_response1;
            result1 = data_response1;
            lsq_pointer = lsq_id;
          end
        end
          // If false
          //    Request from memoryfor (int i = 0; i < `LSQ_SIZE; i++) begin
      end
    end
  end

  //always_comb begin
/*    int store_index = 0;
    if (ctrl_bits.mem_to_reg) begin
      for (int i = 0; i < `LSQ_SIZE; i++) begin
        if (lsq_register[i].tag == tag) begin
          store_index = i;
        end
      end

      if (store_index < lsq_tail) begin
        for (int i = store_index + 1; i < lsq_tail; i++) begin
          //if(lsq_register[i].address == address ) begin
          //end
        end
      end
    end
  end*/
endmodule
