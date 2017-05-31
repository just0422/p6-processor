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

  // Instruction Read Request
  input instruction_read,
  input [`ADDRESS_SIZE - 1 : 0] instruction_address,
  output [`INSTRUCTION_SIZE - 1 : 0] instruction_response,
  output instruction_busy,

  // Data Request
  input mem_read,
  input mem_write,
  input [`ADDRESS_SIZE - 1 : 0] data_address,
  output [`DATA_SIZE - 1 : 0] data_response,
  output data_busy
);

  data_cache_block [`WAYS - 1 : 0] data_way;
  instruction_cache_block [`WAYS - 1 : 0] instruction_way;

  logic busy_register;
  logic [`BUS_DATA_WIDTH - 1 : 0] response_register;
  
  task reset_signals;
    begin
      data_busy = 0;
      data_response = 0;

      instruction_busy = 0;
      instruction_response = 0;
    end
  endtask
  
  // Read from both caches simultaneously
  task read;
    input [`ADDRESS_SIZE - 1 : 0] address;
    output [`DATA_SIZE - 1 : 0] value;
    output success;
    begin
      cache_address ca = address;
      success = 0;
      value = 0;
      
      // No break because no block should evern have the same tag
      for (int i = 0; i < `INDEX_SIZE; i++) begin
        data_cache_line dcl = data_way[i];
        if (ca.tag == dcl.cl.tag) begin
          success = 1;
          value = dcl.data_cells[ca.offset];
        end 

        instruction_cache_line icl = instruction_way[i];
        if (ca.tag == icl.cl.tag) begin
          success = 1;
          value = icl.data_cells[ca.offset];
        end 
      end
    end
  endtask


  // Make request to Memory
  always_comb begin
    logic success = 0;
    if (!reset) begin
      if (mem_read ^ mem_write) begin
        // Send a data read request
      end 
      if (instruction_read) begin// && !busy_register) begin
        logic [`DATA_SIZE - 1 : 0] ir;
        // Check cache
        read(instruction_address, ir, success);
        instruction_response = ir[`INSTRUCTION_SIZE - 1 : 0];

        // If Instruction is not in cache
        if (!success) begin
          // Send an instruction read request
          bus_req = instruction_address;
          bus_reqtag = `MEMORY;
          bus_reqcyc = 1;
          instruction_busy = 1;
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
      bus_respack <= 0;
    end
  end

  // Insert into cache and return to processor
  always_comb begin
  end
endmodule
