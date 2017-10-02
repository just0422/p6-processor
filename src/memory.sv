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
      
    end
    
    if (ctrl_bits.memtoreg) begin
      if (!data_ready1)
        data_missed1 = 1;
      else begin
        result1 = data_response1;
        lsq_pointer = lsq_id;

        le = lsq[lsq_id - 1];
        le.ready = 1;
        le.value = data_response1;
      end
    end
  end
endmodule
