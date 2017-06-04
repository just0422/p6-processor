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

  cache_block [`WAYS - 1 : 0] data_way; // 32 KB Data Cache
  cache_block [`WAYS - 1 : 0] instruction_way; // 32 KB Instruction Cache

  logic busy_register;
  logic [`BUS_DATA_WIDTH - 1 : 0] response_register;
  logic waiting; // Waiting for memory response
  logic miss; // Did we miss in cache??
  
  task reset_signals;
    begin
//      data_busy = 0;
      data_response = 0;

//      instruction_busy = 0;
      instruction_response = 0;
    end
  endtask


 
  task read;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input full_cache fc_in;
    output [`DATA_SIZE - 1 : 0] value;
    begin
      cache_address ca = address;

      miss = 1;
      value = 0;

      // No break because no block should ever have the same tag
      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];  // Get block 'cb' at way[i]
        cache_line cl = cb[ca.index]; // Get cache line 'cl' cb[index]
        if (ca.tag == cl.tag && cl.valid) begin // IF address tag and cache set tag are the same
          miss = 0;
          busy = 0; // Reset busy once found
          value = cl.cache_cells[ca.offset]; // grab value at offset
    //      fix_lru(i, ca.index, instruction_or_data);
        end 
      end
    end
  endtask

  task evict;
    input cache_tag tag;
    input cache_index index;
    input cache_cell cells;
    begin
      // send to memory
      logic [`ADDRESS_SIZE - 1 : 0] address;

      address = { tag, index, {`OFFSET_SIZE_B{1'b0}} };
    end
  endtask

  task insert;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input [`DATA_SIZE *  - 1 : 0] value;
    input full_cache fc_in;
    output full_cache fc_out;
    begin
      cache_address ca = address;
      int way = $random() % `WAYS;

      cache_block cb = fc_in[way];  // Get block 'dcb' at way[i]
      cache_line cl = cb[ca.index]; // Get cache line 'dcl' dcb[index]

      if (cl.dirty) begin
        evict(cl.tag, ca.index, cl.cache_cells);
        
      end

      cl = 0;
      cl.valid = 1;
      cl.cache_cells = value;

      cb[ca.index] = cl;
      fc_in[way] = cb;
    end
  endtask


  // Make request to Memory
  always_comb begin : cache_or_mem
    if (!reset) begin
      if (mem_read ^ mem_write) begin
        // Send a data read request
//        read(instruction_address, data_way, ir;
      end 
      if (instruction_read) begin// && !busy_register) begin
        logic [`DATA_SIZE - 1 : 0] ir;
        // Check cache
        read(instruction_address, instruction_way, ir);
        instruction_response = ir[`INSTRUCTION_SIZE - 1 : 0];

     end
    end
  end

  logic response_received;
  logic waiting_register;
  // Make Reset Signals when request returns
  always_ff @(posedge clk) begin
    // ** Should reach here first
    // If Instruction is not in cache
    if (miss & !waiting) begin
      // Send an instruction read request
      bus_req <= instruction_address;
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      busy = 1;
      waiting <= 1;
    end

    // ** Should reach here second
    // Reset values when request is acknowledged
    if (bus_reqack) begin
      bus_reqcyc <= 0;
      bus_req <= 0;
      bus_reqtag <= 0;
      // Once memory acknowledges our request
    end

    bus_respack <= 0;
    response_received <= 0;

    // ** Should reach here second also
    // Acknowledge that response was received
    if (bus_respcyc) begin
      response_register <= bus_resp;
      bus_respack <= 1;
      response_received <= 1;
    end

    if (bus_resptag == `MEM_READ) begin
      waiting <= 0;
    end
  end

  // Insert into cache and return to processor
  always_comb begin
    logic [`BUS_DATA_WIDTH - 1 : 0] response = response_register;
  end
endmodule
