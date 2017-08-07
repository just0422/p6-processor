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
  output instruction_busy, data_busy, write_busy,

  // Instruction Read Request
  input instruction_read,
  input [`ADDRESS_SIZE - 1 : 0] instruction_address,
  output [`INSTRUCTION_SIZE - 1 : 0] instruction_response,
  //output instruction_busy,

  // Data Read Request
  input                         mem_read1,           mem_read2,
  input Address                 data_read_address1,  data_read_address2,
  output MemoryWord             data_response1,      data_response2,
  output                        data_finished1,      data_finished2,
  input memory_instruction_type memory_read_type1,   memory_read_type2,

  // Data Write Request
  input                         mem_write1,          mem_write2,
  input Address                 data_write_address1, data_write_address2,
  input MemoryWord              data_write1,         data_write2,
  input memory_instruction_type memory_write_type1,  memory_write_type2,
  output                        write_finished
  //output data_busy
);

  cache_block [`WAYS - 1 : 0] data_way; // 32 KB Data Cache
  cache_block [`WAYS - 1 : 0] instruction_way; // 32 KB Instruction Cache

  int x = 0;
  always_ff @(posedge clk)
    x++;

  cache_reserve reserver; // Is something making a call to cache right now??
  cache_reserve reserver_reg;

  logic busy_register;
  logic [`BUS_DATA_WIDTH - 1 : 0] response_register;
  logic waiting; // Waiting for memory response
  logic inserting; // Are we currently inserting into the cache
  logic evicting; // Am I evicting from memory
  logic write_data_miss1, write_data_miss2, read_data_miss1, read_data_miss2, instruction_miss; // Did we miss in cache??

  task read_data;
    input Address address;
    input memory_instruction_type memory_type;
    input full_cache fc_in;
    output data_miss;
    output data_finished;
    output MemoryWord value;
    begin : read_data
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

        //$display("%3d - (CA) %x == %x (CL)\t\tValid - %1d\tWay - %1d", x, ca.tag, cl.tag, cl.valid, i);

        if (ca.tag == cl.tag && cl.valid) begin
          $display("*********DATA - %3d\ncache address  -  %x",x, ca);
          $display("%b - %b - %b", ca.tag, ca.index, ca.offset);
          //$display("way            -  %x", way);
          $display("cache line     -  %x\n**********DATA", cl);

          data_finished = 1;

          double_cells = cl.cache_cells;
          word_cells = cl.cache_cells;
          half_cells = cl.cache_cells;
          byte_cells = cl.cache_cells;

          data_miss = 0;
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

  
  logic [`ADDRESS_SIZE - 1 : 0] eviction_address;  // Eviction cache address
  cache_cell [`CELLS_NEEDED - 1 : 0] eviction_ccs; // Eviction cache line values
  task evict;
    input cache_line cl;
    input cache_index index;
    begin
      // send to memory

      eviction_address = { cl.tag, index, {`OFFSET_SIZE_B{1'b0}} };
      eviction_ccs = cl.cache_cells;
      evicting = 1;
      $display("%3d - EVICTING -> %b - %b - %b", x, cl.tag, index, 6'b0);
      $display ("%3d - EVICTING -> %x", x, cl.cache_cells);
    end
  endtask

  int way_register;
  always_ff @(posedge clk) begin : generate_way
      abs($random % `WAYS, way_register);
  end

  task abs;
    input int value;
    output int unsign;
    begin
      unsign = value[31] == 1 ? -value : value;
    end
  endtask

  task insert;
    input [`ADDRESS_SIZE - 1 : 0] address;
    input [`DATA_SIZE * `CELLS_NEEDED - 1 : 0] value;
    input full_cache fc_in;
    output full_cache fc_out;
    begin
      int way = way_register;
      cache_address ca = address;
      
      cache_block cb = fc_in[way];  // Get block 'dcb' at way[i]
      cache_line cl = cb[ca.index]; // Get cache line 'dcl' dcb[index]


      eviction_address = 0;
      eviction_ccs = 0;
      evicting = 0;
      if (cl.dirty && ca.tag != cl.tag) begin
        evict(cl, ca.index);
      end

      cl = 0;
      cl.tag = ca.tag;
      cl.valid = 1;
      cl.cache_cells = value;

      cb[ca.index] = cl;
      fc_in[way] = cb;

      current_request_offset = 0;
      response_cache_line = 0;

      $display("cache address  -  %x", ca);
      $display("%b - %b - %b", ca.tag, ca.index, ca.offset);
      $display("way            -  %1d", way);
      $display("cache line     -  %x", cl);

      fc_out = fc_in;
    end
  endtask

  task insert_data;
    input Address address;
    input MemoryWord value;
    input memory_instruction_type memory_type;
    output data_miss;
    output full_cache data_way_register;
    begin
      logic data_finished = 0; 
      WordMemory words;
      HalfMemory halfs;
      ByteMemory bytes;
      MemoryWord response = 0;
      cache_address ca = address;

      read_data(address, LD, data_way, data_miss, data_finished, response);
      words = (response & 32'hFFFFFFFF << ((!ca.offset >> 2) * 32)) | (value << ((ca.offset >> 2) * 32));
      halfs = (response & 16'hFFFF     << ((!ca.offset >> 3) * 16)) | (value << ((ca.offset >> 3) * 16));
      bytes = (response &  8'hFF       << ((!ca.offset >> 4) *  8)) | (value << ((ca.offset >> 4) *  8));

      $display("Inserting Write Data - %3d", x);
      if (data_finished) begin
        case(memory_type)
          SD: insert(address, value, data_way, data_way_register);
          SW: insert(address, words, data_way, data_way_register);
          SH: insert(address, halfs, data_way, data_way_register);
          SB: insert(address, bytes, data_way, data_way_register);
        endcase
      end

      if (!evicting) begin
        write_busy = 0;
        write_finished = 1;
        reserver = 0;
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
      write_finished = 0;
      write_busy = mem_write1;
      data_busy = mem_read1 || mem_read2; 
      instruction_busy = 1;

      if (mem_write1 && (!reserver_reg || reserver_reg.write1)) begin
        // Write to cache
        reserver = `WRITE1;
        insert_data(data_write_address1, data_write1, memory_write_type1, write_data_miss1, data_way_reg);
      end else if (mem_write2 && (!reserver_reg || reserver_reg.write2)) begin
        reserver = `WRITE2;
        insert_data(data_write_address2, data_write2, memory_write_type2, write_data_miss2, data_way_reg);
        //insert_data();
      end else if (mem_read1 && (!reserver_reg || reserver_reg.read1)) begin
        reserver = `READ1;
        // Send a data read request
        read_data(data_read_address1, memory_read_type1, data_way, read_data_miss1, data_finished1, data_response1);
      end else if (mem_read2 && (!reserver_reg || reserver_reg.write1)) begin
        reserver = `READ2;
        // Send a data read request
        read_data(data_read_address2, memory_read_type2, data_way,  read_data_miss2, data_finished2, data_response2);
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
    if (mem_write1 && write_finished) 
      data_way <= data_way_reg;
  end

  /******************* STEP 2a **************************/
  // Send write requets to memory
  logic start_sending_out;
  // Send read request to memory
  logic response_received;
  Address instruction_address_register;
  Address data_address1_register;
  Address data_address2_register;
  logic [`CELLS_NEEDED_B : 0] current_request_offset;
  always_ff @(posedge clk) begin : make_request
    instruction_address_register = instruction_address;
    data_address1_register = data_read_address1;
    data_address2_register = data_read_address2;
    // ** Should reach here first
    // If Instruction is not in cache
    if (evicting) begin
      bus_reqtag <= `MEM_WRITE;
      bus_reqcyc <= 1;
      bus_req <= eviction_address;
      start_sending_out <= 0;
      // waiting <= 1;
    end
    if (read_data_miss1) begin
      bus_req <= data_read_address1 & `MEMORY_MASK;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end else if (read_data_miss2) begin
      bus_req <= data_read_address2 & `MEMORY_MASK;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end else if (instruction_miss) begin
      // Send an instruction read request
      bus_req <= instruction_address & `MEMORY_MASK;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end
  end

  /******************* STEP 2b **************************/
  // Reset values when request is acknowledged
  always_ff @(posedge clk) begin : request_acknowledged
    if (bus_reqack) begin
      if (evicting) begin
        start_sending_out <= 1;
        sent_out <= 0;
        eviction_index <= 0;
      end else begin
        bus_reqcyc <= 0;
        bus_req <= 0;
        bus_reqtag <= 0;
      end
      // Once memory acknowledges our request
    end
  end

  /******************* STEP 2c **************************/
  // Receive response
  logic sent_out;
  logic [2:0] eviction_index;
  always_ff @(posedge clk) begin : receive_response
    if (evicting) begin
      if (start_sending_out) begin
        bus_req <= eviction_ccs[eviction_index];
        if (eviction_index == 7) begin
          start_sending_out <= 0;
          sent_out <= 1;
        end
        eviction_index <= eviction_index + 1;
      end
    end else begin
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
  end

  
  /******************* STEP 2d **************************/
  always_ff @(posedge clk) begin
    bus_respack <= 0;
    if (sent_out && bus_respcyc) begin
      sent_out <= 0;
      evicting = 0;

      bus_respack <= 1;
      bus_reqtag <= 0;
      bus_req <= 0;
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

    if (ready_to_insert && mem_read1 && reserver_reg.read1) begin
      $display("Inserting Read Data - %3d", x);
      data_insert_address1 = data_address1_register  & `MEMORY_MASK;
      insert(data_insert_address1, value, data_way, data_way_insert_register);
      inserted = 1;
    end else if (ready_to_insert && mem_read2 && reserver_reg.read2) begin
      $display("Inserting Read Data - %3d", x);
      data_insert_address2 = data_address2_register  & `MEMORY_MASK;
      insert(data_insert_address2, value, data_way, data_way_insert_register);
      inserted = 1;
    end else if (ready_to_insert && instruction_read && reserver_reg.iread) begin
      $display("Inserting Instruction - %3d", x);
      instruction_insert_address = instruction_address_register & `MEMORY_MASK;
      insert(instruction_insert_address, value, instruction_way, instruction_way_insert_register);
      inserted = 1;
    end
  end

  always_ff @(posedge clk) begin
    if (inserted && ((mem_read1 && reserver_reg.read1) || (mem_read2 && reserver_reg.read2))) begin
      data_way <= data_way_insert_register;
      inserting <= 0;
    end else if (inserted && instruction_read && reserver_reg.iread) begin
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
