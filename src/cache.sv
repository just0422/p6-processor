//L1 = 8 KB
//64 Byte blocks

//128 Blocks
//4 ways - 32 blocks per way

module cache
(
  input clk,
  input reset, 

  // Memoory Read Request Interface
  input bus_respcyc,
  output bus_respack,
  input [`BUS_DATA_WIDTH - 1 : 0] bus_resp,
  input [`BUS_TAG_WIDTH - 1 : 0] bus_resptag,

  // Memory Write Request interface
  output bus_reqcyc,
  input bus_reqack,
  output [`BUS_DATA_WIDTH - 1 : 0] bus_req,
  output [`BUS_TAG_WIDTH - 1 : 0] bus_reqtag,

  // Hazard signals
  output busy,

  // Instruction Read Request
  input instruction_read,
  input [`ADDRESS_SIZE - 1 : 0] instruction_address,
  output [`INSTRUCTION_SIZE - 1 : 0] instruction_response,
  //output instruction_busy,

  // Data Request
  input mem_read,
  input mem_write,
  input [`ADDRESS_SIZE - 1 : 0] data_address,
  output [`DATA_SIZE - 1 : 0] data_response
  //output data_busy
);

  data_cache_block [`WAYS - 1 : 0] data_way;
  instruction_cache_block [`WAYS - 1 : 0] instruction_way;

  logic busy_register;
  logic [`BUS_DATA_WIDTH - 1 : 0] response_register;
  
  task reset_signals;
    begin
//      data_busy = 0;
      data_response = 0;

//      instruction_busy = 0;
      instruction_response = 0;
    end
  endtask
  
  // Read from both caches simultaneously
  task read;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input instruction_or_data;
    output [`DATA_SIZE - 1 : 0] value;
    output miss;
    begin
      cache_address ca = address;
      miss = 1;
      value = 0;
      
      // No break because no block should ever have the same tag
      if (instruction_or_data) begin
        for (int i = 0; i < `INDEX_SIZE; i++) begin
          data_cache_line dcl = data_way[i];
          if (ca.tag == dcl.vdt.tag && dcl.vdt.valid && !dcl.vdt.dirty) begin // IF address tag and cache set tag are the same
            miss = 0;
            value = dcl.data_cells[ca.offset]; // grab value at offset
          end 
        end
      end else begin
        for (int i = 0; i < `INDEX_SIZE; i++) begin
          instruction_cache_line icl = instruction_way[i];
          if (ca.tag == icl.vdt.tag && icl.vdt.valid && !icl.vdt.dirty) begin
            miss = 0;
            value = icl.instruction_cells[ca.offset];
          end 
        end
      end
    end
  endtask

  task insert;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input [`DATA_SIZE - 1 : 0] value;
    input inistruction_or_data;
    begin
    end
  end


  // Make request to Memory
  always_comb begin : cache_or_mem
    logic miss = 0;
    if (!reset) begin
      if (mem_read ^ mem_write) begin
        // Send a data read request
//        read(instruction_address, 1, ir, miss);
      end 
      if (instruction_read) begin// && !busy_register) begin
        logic [`DATA_SIZE - 1 : 0] ir;
        // Check cache
        read(instruction_address, 0, ir, miss);
        instruction_response = ir[`INSTRUCTION_SIZE - 1 : 0];

        // If Instruction is not in cache
        if (miss) begin
          // Send an instruction read request
          bus_req = instruction_address;
          bus_reqtag = `MEMORY;
          bus_reqcyc = 1;
          busy = 1;
        end
      end
      if (bus_reqack) begin
          bus_reqcyc = 0;
          bus_req = 0;
          // Once memory acknowledges our request
      end
    end
  end

  // Make Reset Signals when request returns
  always_ff @(posedge clk) begin
    bus_respack <= 0;
//    busy_register <= data_busy | instruction_busy;

    if (bus_respcyc) begin
      response_register <= bus_resp;
      bus_respack <= 1;
    end
  end

  // Insert into cache and return to processor
  always_comb begin
    logic [`BUS_DATA_WIDTH - 1 : 0] response = response_register;

  end
endmodule
