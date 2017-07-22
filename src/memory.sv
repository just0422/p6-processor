module memory 
(
  // Housekeeping
  input clk, reset,
  
  // Memory Inputs
  input control_bits ctrl_bits,
  input Address      address,
  input MemoryWord   data,
  input int          tag,


  input lsq_entry lsq[`LSQ_SIZE - 1 : 0],
  input int lsq_tail,
  
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
      for (int i = 0; i < `LSQ_SIZE; i++) begin
        if (lsq[i].tag == tag) begin
          lsq_pointer = i + 1;  // Let's try to keep the array 1-index

          le.tag = tag;
          le.address = address;
          le.value = data;
          le.color = lsq[i].color;
          
          for (int j = 0; j < `LSQ_SIZE; j++) begin
            if (lsq[j].address == address &&
                lsq[j].category == LOAD &&
                lsq[j].color > lsq[i].color) begin
                  lsq_register[j].value = lsq[i].value;
            end
          end
        end
      end

      if (lsq_pointer > 0) begin
      end
    end
    
    if (ctrl_bits.memtoreg) begin
      // Find LSQ Entry
      for (int i = 0; i < `LSQ_SIZE; i++) begin
        if (lsq[i].tag == tag) begin
          if (lsq[i].ready) begin
            result1 = lsq[i].value;

            le = lsq[i];
            le.ready = 1;
            data_missed1 = 0;
          end
          else begin
            // If False
            //    Search LSQ
            current_color = -1;
            for (int j = 0; j < `LSQ_SIZE; j++) begin
              if (lsq[j].address == address &&
                  lsq[j].category == STORE &&
                  lsq[j].color > current_color &&
                  lsq[j].color < lsq[i].color) begin
                current_color = lsq[j].color;

                result1 = lsq[i].value; 

                le = lsq[i];
                le.value = lsq[i].value;
                le.ready = 1;
              end
            end

            if (!le) begin
              data_missed1 = 1;

              lsq_register[i].value = data_response1;
            end
              // If false
              //    Request from memoryfor (int i = 0; i < `LSQ_SIZE; i++) begin
          end
        end
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
