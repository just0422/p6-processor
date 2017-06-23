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
  logic inserting; // Are we currently inserting into the cache
  

  task read;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input full_cache fc_in;
    output [`DATA_SIZE - 1 : 0] value;
    begin
      cache_address ca = address;
      logic [`CELLS_NEEDED * 2 - 1 : 0][`INSTRUCTION_SIZE - 1 : 0] instruction_cells;

      busy = 1;
      value = 0;
      if (!waiting && !inserting) 
        miss = 1; 
      else
        miss = 0;

      // No break because no block should ever have the same tag
      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];  // Get block 'cb' at way[i]
        cache_line cl = cb[ca.index]; // Get cache line 'cl' cb[index]
        if (ca.tag == cl.tag && cl.valid) begin // IF address tag and cache set tag are the same
          instruction_cells = cl.cache_cells; // Cast cache_cells to instruction_cells for size_purposes
          miss = 0;
          busy = 0;
          value = instruction_cells[ca.offset >> 2]; // grab value at offset
      //    $display("%d - %x", ca.index, cl);
      //    $display("%b", ca);
          $display("%b - %b", ca.index, ca.offset);
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
    input [`DATA_SIZE * `CELLS_NEEDED - 1 : 0] value;
    input full_cache fc_in;
    output full_cache fc_out;
    begin
      cache_address ca = address;
      int way = $random % `WAYS;

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

      current_request_offset = 0;
      response_cache_line = 0;

      fc_out = fc_in;
    end
  endtask

  /******************* STEP 1 *************************/
  // Find in cache or prep for emory request
  logic [`DATA_SIZE - 1 : 0] instruction_response_register;
  always_comb begin : cache_or_mem
    if (!reset) begin
      if (mem_read ^ mem_write) begin
        // Send a data read request
//        read(instruction_address, data_way, ir;
      end 
      if (instruction_read) begin// && !busy_register) begin
        // Check cache
        read(instruction_address, instruction_way, instruction_response_register);
     end
    end
  end

  /******************* STEP 2a **************************/
  // Send request to memory
  logic response_received;
  logic [`ADDRESS_SIZE - 1 : 0] instruction_address_register;
  logic [`CELLS_NEEDED_B : 0] current_request_offset;
  always_ff @(posedge clk) begin : make_request
    instruction_address_register = instruction_address;
    // ** Should reach here first
    // If Instruction is not in cache
    if (miss) begin
      // Send an instruction read request
      bus_req <= instruction_address & 64'hfffffffffffffff8;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end
  end

  /******************* STEP 2b **************************/
  // Reset values when request is acknowledged
  always_ff @(posedge clk) begin : request_acknowledged
    if (bus_reqack) begin
      bus_reqcyc <= 0;
      bus_req <= 0;
      bus_reqtag <= 0;
      // Once memory acknowledges our request
    end
  end

  /******************* STEP 2c **************************/
  // Receive response
  always_ff @(posedge clk) begin : receive_response
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
      inserting <= 1;
    end
  end

  /******************* STEP 3 **************************/
  // Build cache line
  cache_cell [`CELLS_NEEDED - 1: 0] response_cache_line;
  logic response_added;
  always_comb begin : build_cache_line
    shortint offset = `OFFSET_SIZE_B, tag = `TAG_SIZE_B, index = `INDEX_SIZE_B;
   
    response_added = 0;
    if (response_received) begin
      response_cache_line[current_request_offset] = response_register;
      response_added = 1;
    end
  end

  logic ready_to_insert;
  cache_cell [`CELLS_NEEDED - 1 : 0] response_cache_line_register;
  cache_block [`WAYS - 1 : 0] instruction_way_insert_register; // 32 KB Instruction Cache
  always_ff @(posedge clk) begin
    if (response_added)
      current_request_offset += 1;

    ready_to_insert <= 0;
    response_cache_line_register <= 0;
    if (current_request_offset >= `CELLS_NEEDED) begin
      ready_to_insert <= 1;
      instruction_way_insert_register = 0;
      response_cache_line_register <= response_cache_line;
    end
  end


  /******************* STEP 4 **************************/
  // Insert into cache
  logic inserted;
  always_comb begin
    logic [`ADDRESS_SIZE - 1 : 0] address = instruction_address_register & 64'hfffffffffffffff8;
    logic [`DATA_SIZE * `CELLS_NEEDED - 1 : 0] value = response_cache_line_register;
    inserted = 0; if (ready_to_insert && instruction_read) begin
      insert(address, value, instruction_way, instruction_way_insert_register);
      inserted = 1;
    end
  end

  always_ff @(posedge clk) begin
    if (inserted) begin
      instruction_way = instruction_way_insert_register;
      inserting <= 0;
    end
  end

  /******************* STEP 5 **************************/
  // Return to processor
  always_ff @(posedge clk) begin : return_to_processor
    if (!busy) begin
      instruction_response = instruction_response_register[`INSTRUCTION_SIZE - 1 : 0];
    end
  end
endmodule
