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
  output instruction_busy, data_busy1, data_busy2,

  // Instruction Read Request
  input instruction_read,
  input [`ADDRESS_SIZE - 1 : 0] instruction_address,
  output [`INSTRUCTION_SIZE - 1 : 0] instruction_response,
  //output instruction_busy,

  // Data Request
  input                         mem_read1,      mem_read2,
  input                         mem_write1,     mem_write2,
  input Address                 data_address1,  data_address2,
  input MemoryWord              data_write1,    data_write2,
  input memory_instruction_type memory_type1,   memory_type2,
  output MemoryWord             data_response1, data_response2,
  output                        data_finished1, data_finished2
  //output data_busy
);

  cache_block [`WAYS - 1 : 0] data_way; // 32 KB Data Cache
  cache_block [`WAYS - 1 : 0] instruction_way; // 32 KB Instruction Cache

  cache_reserve reserver; // Is something making a call to cache right now??
  cache_reserve reserver_reg;

  logic busy_register;
  logic [`BUS_DATA_WIDTH - 1 : 0] response_register;
  logic waiting; // Waiting for memory response
  logic data_miss1, data_miss2, instruction_miss; // Did we miss in cache??
  logic inserting; // Are we currently inserting into the cache

  task read_data;
    input Address address;
    input memory_instruction_type memory_type;
    input full_cache fc_in;
    output data_busy;
    output data_miss;
    output data_finished;
    output MemoryWord value;
    begin
      DoubleLine double_cells;
      WordLine word_cells;
      HalfLine half_cells;
      ByteLine byte_cells;

      cache_address ca = address;
      
      value = 0;


      if (!waiting && !inserting)
        data_miss = 1;
      else
        data_miss = 0;

      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];
        cache_line cl = cb[ca.index];

        if (ca.tag == cl.tag && cl.valid) begin
          $display("*********DATA\ncache address  -  %x", ca);
          $display("%b - %b - %b", ca.tag, ca.index, ca.offset);
          //$display("way            -  %x", way);
          $display("cache line     -  %x\n**********DATA", cl);

          data_finished = 1;

          double_cells = cl.cache_cells;
          word_cells = cl.cache_cells;
          half_cells = cl.cache_cells;
          byte_cells = cl.cache_cells;

          data_miss = 0;
          data_busy = 0;
          reserver = 0;

          // value = _____[ca.offset]
          case(memory_type)
            LD : value = double_cells[ca.offset >> 3];
            LW : value = { { 32 { word_cells[ca.offset][31] } }, word_cells[ca.offset >> 2] };
            LH : value = { { 48 { half_cells[ca.offset][15] } }, half_cells[ca.offset >> 1] };
            LB : value = { { 56 {  byte_cells[ca.offset][7] } }, byte_cells[ca.offset] };
            LWU: value = word_cells[ca.offset >> 2] & 32'hFFFFFFFF;
            LHU: value = half_cells[ca.offset >> 1] & 16'hFFFF;
            LBU: value = half_cells[ca.offset] &  8'hFF;
          endcase
        end
      end
    end
  endtask

  task read_instruction;
    input Address address;
    input full_cache fc_in;
    output MemoryWord value;
    begin
      cache_address ca = address;
      InstructionLine instruction_cells;

      value = 0;
      if (!waiting && !inserting) 
        instruction_miss = 1; 
      else
        instruction_miss = 0;

      // No break because no block should ever have the same tag
      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];  // Get block 'cb' at way[i]
        cache_line cl = cb[ca.index]; // Get cache line 'cl' cb[index]
        if (ca.tag == cl.tag && cl.valid) begin // IF address tag and cache set tag are the same
          instruction_cells = cl.cache_cells; // Cast cache_cells to instruction_cells for size_purposes
          instruction_miss = 0;
          instruction_busy = 0;
          reserver = 0;
          value = instruction_cells[ca.offset >> 2]; // grab value at offset
      //    $display("%d - %x", ca.index, cl);
      //    $display("%b", ca);
      //    $display("%b - %b", ca.index, ca.offset);
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

      if (cl.dirty && ca.tag != cl.tag) begin
        evict(cl.tag, ca.index, cl.cache_cells);
      end

      cl = 0;
      cl.valid = 1;
      cl.cache_cells = value;

      cb[ca.index] = cl;
      fc_in[way] = cb;

      current_request_offset = 0;
      response_cache_line = 0;

      $display("cache address  -  %x", ca);
      $display("%b - %b - %b", ca.tag, ca.index, ca.offset);
      $display("way            -  %x", way);
      $display("cache line     -  %x", cl);

      fc_out = fc_in;
    end
  endtask

  task insert_data;
    input Address address;
    input MemoryWord value;
    input memory_instruction_type memory_type;
    output data_busy;
    output data_miss;
    output full_cache data_way_register;
    begin
      logic insert_data_busy;
      logic data_finished; //////////////////////TODO : Make sure this doesn't break anything
      WordMemory words;
      HalfMemory halfs;
      ByteMemory bytes;
      MemoryWord response = 0;
      cache_address ca = address;

      read_data(address, LD, data_way, insert_data_busy, data_miss, data_finished, response);
      words = (response & 32'hFFFFFFFF << ((!ca.offset >> 2) * 32)) | (value << ((ca.offset >> 2) * 32));
      halfs = (response & 16'hFFFF     << ((!ca.offset >> 3) * 16)) | (value << ((ca.offset >> 3) * 16));
      bytes = (response &  8'hFF       << ((!ca.offset >> 4) *  8)) | (value << ((ca.offset >> 4) *  8));

      if (!insert_data_busy && response) begin
        case(memory_type)
          SD: insert(address, value, data_way, data_way_register);
          SW: insert(address, words, data_way, data_way_register);
          SH: insert(address, halfs, data_way, data_way_register);
          SB: insert(address, bytes, data_way, data_way_register);
        endcase
        data_busy = 0;
      end
    end
  endtask

  /******************* STEP 1 *************************/
  // Find in cache or prep for emory request
  MemoryWord instruction_response_register;
  full_cache data_way_reg;
  always_comb begin : cache_or_mem
    if (!reset) begin
      data_finished1 = 0;
      data_finished2 = 0;
      data_busy1 = mem_read1;
      data_busy2 = mem_read2;
      instruction_busy = 1;

      if (mem_write1 && (!reserver_reg || reserver_reg.write1)) begin
        // Write to cache
        reserver = `WRITE1;
        insert_data(data_address1, data_write1, memory_type1, data_busy1, data_miss1, data_way_reg);
      end else if (mem_write2 && (!reserver_reg || reserver_reg.write2)) begin
        reserver = `WRITE2;
        insert_data(data_address2, data_write2, memory_type2, data_busy2, data_miss2, data_way_reg);
        //insert_data();
      end else if (mem_read1 && (!reserver_reg || reserver_reg.read1)) begin
        reserver = `READ1;
        // Send a data read request
        read_data(data_address1, memory_type1, data_way, data_busy1, data_miss1, data_finished1, data_response1);
      end else if (mem_read2 && (!reserver_reg || reserver_reg.write1)) begin
        reserver = `READ2;
        // Send a data read request
        read_data(data_address2, memory_type2, data_way, data_busy2, data_miss2, data_finished2, data_response2);
      end else if (instruction_read && (!reserver_reg || reserver_reg.iread)) begin// && !busy_register) begin
        reserver = `IREAD;
        // Check cache
        read_instruction(instruction_address, instruction_way, instruction_response_register);
        instruction_response = instruction_response_register[`INSTRUCTION_SIZE - 1 : 0];
     end
    end
  end

  always_ff @(posedge clk) begin
    reserver_reg <= reserver;
  end

  always_ff @(posedge clk) begin
    if ((mem_write1 && !data_busy1) || (mem_write2 && !data_busy2))
      data_way <= data_way_reg;
  end

  /******************* STEP 2a **************************/
  // Send request to memory
  logic response_received;
  Address instruction_address_register;
  Address data_address1_register;
  Address data_address2_register;
  logic [`CELLS_NEEDED_B : 0] current_request_offset;
  always_ff @(posedge clk) begin : make_request
    instruction_address_register = instruction_address;
    data_address1_register = data_address1;
    data_address2_register = data_address2;
    // ** Should reach here first
    // If Instruction is not in cache
    if (data_miss1) begin
      bus_req <= data_address1 & 64'hfffffffffffffff8;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end else if (data_miss2) begin
      bus_req <= data_address2 & 64'hfffffffffffffff8;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end else if (instruction_miss) begin
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
  cache_block [`WAYS - 1 : 0] instruction_way_insert_register; // 32 KB Placeholder Instruction Cache
  cache_block [`WAYS - 1 : 0] data_way_insert_register; // 32 KB Placeholder Data Cache
  always_ff @(posedge clk) begin
    if (response_added)
      current_request_offset += 1;

    ready_to_insert <= 0;
    response_cache_line_register <= 0;
    if (current_request_offset >= `CELLS_NEEDED) begin
      ready_to_insert <= 1;
      data_way_insert_register = 0;
      instruction_way_insert_register = 0;
      response_cache_line_register <= response_cache_line;
    end
  end


  /******************* STEP 4 **************************/
  // Insert into cache
  logic inserted;
  always_comb begin
    logic [`DATA_SIZE * `CELLS_NEEDED - 1 : 0] value = response_cache_line_register;
    Address instruction_insert_address, data_insert_address1, data_insert_address2;
    inserted = 0; 

    if (ready_to_insert && mem_read1) begin
      data_insert_address1 = data_address1_register  & 64'hfffffffffffffff8;
      insert(data_insert_address1, value, data_way, data_way_insert_register);
      inserted = 1;
    end else if (ready_to_insert && mem_read2) begin
      data_insert_address2 = data_address2_register  & 64'hfffffffffffffff8;
      insert(data_insert_address2, value, data_way, data_way_insert_register);
      inserted = 1;
    end else if (ready_to_insert && instruction_read) begin
      instruction_insert_address = instruction_address_register & 64'hfffffffffffffff8;
      insert(instruction_insert_address, value, instruction_way, instruction_way_insert_register);
      inserted = 1;
    end
  end

  always_ff @(posedge clk) begin
    if (inserted && (mem_read1 || mem_read2)) begin
      data_way <= data_way_insert_register;
      inserting <= 0;
    end else if (inserted && instruction_read) begin
      instruction_way <= instruction_way_insert_register;
      inserting <= 0;
    end
  end

  /******************* STEP 5 **************************
  // Return to processor
  always_ff @(posedge clk) begin : return_to_processor
    if (!busy) begin
  //    instruction_response <= instruction_response_register[`INSTRUCTION_SIZE - 1 : 0];
    end
  end*/
endmodule
