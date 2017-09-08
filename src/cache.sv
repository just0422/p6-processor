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
  // output instruction_busy, data_busy, write_busy,
  output busy, instruction_finished, data_finished,

  input RorW, IorD,
  input Address data_address, instruction_address,
  input MemoryWord value,
  input memory_instruction_type mem_type,

  output MemoryWord response

  // Instruction Read Request
  /*input instruction_read,
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
  input                         mem_write,
  input Address                 data_write_address,
  input MemoryWord              data_write,
  input memory_instruction_type memory_write_type,
  output                        write_finished,*/

  //output data_busy
);

logic DEBUG = 1;

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
  logic miss;
  //logic data_miss, instruction_miss;
  //logic write_data_miss, read_data_miss1, read_data_miss2, instruction_miss; // Did we miss in cache??


  /****************************/
  //// Read Data From Cache \\\\ 
  /****************************/
  task read_data;
    input Address address;
    input memory_instruction_type memory_type;
    input full_cache fc_in;
    //output data_miss;
    output read_data_finished;
    output MemoryWord value;
    output CacheCells value_line;
    output int write_way;
    begin : read_data
      DoubleLine double_cells;
      WordLine word_cells;
      HalfLine half_cells;
      ByteLine byte_cells;

      cache_address ca = address;
      
      value = 0;
      read_data_finished = 0;

      write_way = -1;
      miss = 1;
/*
      if (!waiting && !inserting)
        //data_miss = 1;
      else
        data_miss = 0;
*/

      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];
        cache_line cl = cb[ca.index];
        //$display("\t%4d - (CA) %x == %x (CL)\t\tValid - %1d\tWay - %1d", x, ca.tag, cl.tag, cl.valid, i);
        //$display("WAY %2d --- CA == CL (%d)(%x == %x) --- CL Valid (%d)", i, ca.tag == cl.tag, ca.tag, cl.tag, cl.valid);
        if (ca.tag == cl.tag && cl.valid) begin
          if (DEBUG) begin
            $display("\t%4d - DATA\tway - %1d\tcache address - %x", x, i, ca);
            //$display("%b - %b - %b", ca.tag, ca.index, ca.offset);
            //$display("way            -  %x", way);
            $display("\t\tcache line - %x", cl);
          end

          read_data_finished = 1;
          //data_miss = 0;
          miss = 0;
          busy = 0;
          reserver = 0;
          write_way = i;

          value_line = cl.cache_cells;
          double_cells = cl.cache_cells;
          word_cells = cl.cache_cells;
          half_cells = cl.cache_cells;
          byte_cells = cl.cache_cells;

          // value = _____[ca.offset]
          case(memory_type)
            LD : value = double_cells[ca.offset >> 3];
            LW : value = { { 32 { word_cells[ca.offset][31] } }, word_cells[ca.offset >> 2] };
            LH : value = { { 48 { half_cells[ca.offset][15] } }, half_cells[ca.offset >> 1] };
            LB : value = { { 56 {  byte_cells[ca.offset][7] } }, byte_cells[ca.offset] };
            LWU: value = word_cells[ca.offset >> 2] & 32'hFFFFFFFF;
            LHU: value = half_cells[ca.offset >> 1] & 16'hFFFF;
            LBU: value = byte_cells[ca.offset] &  8'hFF;
          endcase
        end
      end
    end
  endtask

  /***********************************/
  //// Read Instruction From Cache \\\\ 
  /***********************************/
  task read_instruction;
    input Address address;
    input full_cache fc_in;
    output MemoryWord value;
    begin
      cache_address ca = address;
      InstructionLine instruction_cells;

      value = 0;
      miss = 1;
/*
      if (!waiting && !inserting) 
        instruction_miss = 1; 
      else
        instruction_miss = 0;
*/
      // No break because no block should ever have the same tag
      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];  // Get block 'cb' at way[i]
        cache_line cl = cb[ca.index]; // Get cache line 'cl' cb[index]
        if (ca.tag == cl.tag && cl.valid) begin // IF address tag and cache set tag are the same
          instruction_cells = cl.cache_cells; // Cast cache_cells to instruction_cells for size_purposes
          miss = 0;
          //instruction_miss = 0;
          busy = 0;
          instruction_finished = 1;

          value = instruction_cells[ca.offset >> 2]; // grab value at offset
          //$display("\t%4d - INSTRUCTION READ", x);
          //$display("\t%d - %x", ca.index, cl);
          //$display("\t%x - %x", ca.tag, cl.tag);
          //$display("\t%x - %x", ca, cl.base_address);
          //$display("\t%x (%2d) - %x (%2d) - %x (%2d)", ca.tag, ca.tag, ca.index, ca.index, ca.offset >> 2, ca.offset >> 2);
          //$display("\tVALUE - %x", instruction_cells[ca.offset >> 2]);
        end 
      end

    end
  endtask

  /******************************/
  //// Invalidate Cache Entry \\\\
  /******************************/
  task invalidate;
    input Address address;
    input full_cache fc_in;
    output full_cache fc_out;
    begin
      cache_address ca = address;

      for (int i = 0; i < `WAYS; i++) begin
        cache_block cb = fc_in[i];
        cache_line cl = cb[ca.index];

        if (DEBUG)
          $display("\t%4d - INVALIDATE\n\t\tcache address - %x\n\t\tcache line - %x", x, ca, cl);
        if (ca.tag == cl.tag) begin
          if (DEBUG)
            $display("\t%4d - INVALIDATE\tcache address - %x", x, ca);
          cl.valid = 0;
          cb[ca.index] = cl;
          fc_in[i] = cb;
        end
      end

      fc_out = fc_in;
    end
  endtask

  
  /************************/
  //// Evict From Cache \\\\ 
  /************************/
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
      eviction_start = 1;
      if (DEBUG)
        $display("\t%4d - EVICTING -> (%x) - %b - %b - %b", x, eviction_address,  cl.tag, index, 6'b0);
      //$display ("\t%4d - EVICTING -> %x", x, cl.cache_cells);
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

  /*************************/
  //// Insert into Cache \\\\ 
  /*************************/
  task insert;
    input Address address;
    input CacheCells value;
    input dirty;
    input write_way;
    input full_cache fc_in;
    output full_cache fc_out;
    begin
      int way = write_way >= 0 ? write_way : way_register;
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
      cl.dirty = dirty;
      cl.base_address = address & `MEMORY_MASK;
      cl.cache_cells = value;

      cb[ca.index] = cl;
      fc_in[way] = cb;

      current_request_offset = 0;
      response_cache_line = 0;

      if (DEBUG) begin
        $display("\t%4d - INSERT\tway - %1d\tcache address - %x", x, way, ca);
        //$display("cache address  -  %x", ca);
        //$display("%b - %b - %b", ca.tag, ca.index, ca.offset);
        //$display("way            -  %1d", way);
        $display("\t\tcache line - %x", cl);
      end

      fc_out = fc_in;
    end
  endtask

  /******************************/
  //// Insert data into Cache \\\\ 
  /******************************/
  task insert_data;
    input Address address;
    input MemoryWord value;
    input memory_instruction_type memory_type;
    //output data_miss;
    begin
      int write_way;
      CacheCells write_line;
      DoubleLine double_line;
      WordLine word_line;
      HalfLine half_line;
      ByteLine byte_line;
      MemoryWord response = 0;
      cache_address ca = address;
      logic write_data_finished = 0;


      read_data(address, LD, data_way, write_data_finished, response, write_line, write_way);
      
      double_line = write_line;
      double_line[ca.offset >> 3] = value;

      word_line = write_line;
      word_line[ca.offset >> 2] = value;
      
      half_line = write_line;
      half_line[ca.offset >> 1] = value;

      byte_line = write_line;
      byte_line[ca.offset] = value;

      //words = (response & 32'hFFFFFFFF << ((!ca.offset >> 2) * 32)) | (value << ((ca.offset >> 2) * 32));
      //halfs = (response & 16'hFFFF     << ((!ca.offset >> 3) * 16)) | (value << ((ca.offset >> 3) * 16));
      //bytes = (response &  8'hFF       << ((!ca.offset >> 4) *  8)) | (value << ((ca.offset >> 4) *  8));

      //$display("Inserting Write Data - \t%4d", x);
      //if (!data_miss && !waiting && !inserting && data_finished) begin
      if (write_data_finished) begin
        if (DEBUG) begin
          $display("\t%4d - STORE - %x - %x", x, address, value);
        end
        case(memory_type)
          SD: insert(address, double_line, 1, write_way, data_way, data_way_write_register);
          SW: insert(address, word_line, 1, write_way, data_way, data_way_write_register);
          SH: insert(address, half_line, 1, write_way, data_way, data_way_write_register);
          SB: insert(address, byte_line, 1, write_way, data_way, data_way_write_register);
        endcase

        if (!evicting) begin
          //$display("Finisehd evicting - %3d", x);
          busy = 0;
          data_finished = 1;
        end
      end
    end
  endtask

  /******************* STEP 1 *************************/
  // Find in cache or prep for emory request
  MemoryWord instruction_response_register;
  full_cache data_way_write_register;
  always_comb begin : cache_or_mem
    if (!reset) begin
      int dud = 0;
      CacheCells cldud = 0;

      busy = 1;
      instruction_finished = 0;
      data_finished = 0;
      miss = 0;

      if (!waiting && !inserting) begin
        //data_address_register = data_address;
        //instruction_address_register = instruction_address;

        if (RorW && IorD) begin // Mem Write
          //data_address_register = data_address;
          insert_data(data_address, value, mem_type);
          address_register = data_address;
        end else if (!RorW && IorD) begin // Mem Read
          //data_address_register = data_address;
          read_data(data_address, mem_type, data_way, data_finished, response, cldud, dud);
          address_register = data_address;
        end else begin
          //instruction_address_register = instruction_address;
          read_instruction(instruction_address, instruction_way, response); 
          address_register = instruction_address;
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (inserted_data_flushed || inserted_instruction_flushed)
      reserver_reg <= 0;
    else
      reserver_reg <= reserver;
  end

  always_ff @(posedge clk) begin
    if (IorD && RorW && data_finished) 
      data_way <= data_way_write_register;
  end


  /******************* STEP 2a **************************/
  // Send write requets to memory
  logic start_sending_out;
  // Send read request to memory
  logic response_received;
//  Address instruction_address_register;
//  Address data_address_register;
  Address address_register;
  logic [`CELLS_NEEDED_B : 0] current_request_offset;
  always_ff @(posedge clk) begin : make_request
    // ** Should reach here first
    // If Instruction is not in cache
    if (eviction_start) begin
      bus_reqtag <= `MEM_WRITE;
      bus_reqcyc <= 1;
      bus_req <= eviction_address;
      eviction_index <= 0;
    end else if (miss) begin
      bus_req <= address_register & `MEMORY_MASK;// + (current_request_offset * `CELLS_NEEDED_B);
      bus_reqtag <= `MEM_READ;
      bus_reqcyc <= 1;
      waiting <= 1;
    end 
  end

  /******************* STEP 2b **************************/
  // Reset values when request is acknowledged
  logic eviction_start;
  always_ff @(posedge clk) begin : request_acknowledged
    if (bus_reqack) begin
      eviction_start = 0;
      if (evicting) begin
        sent_out <= 0;

        bus_reqcyc <= 1;
        bus_reqtag <= `MEM_WRITE;
        bus_req <= eviction_ccs[eviction_index];
        if (eviction_index == 7) begin
          sent_out <= 1;
        end
        eviction_index <= eviction_index + 1;
      end else begin
        bus_reqcyc <= 0;
        bus_reqtag <= 0;
        bus_req <= 0;
      end
    end

  end

  /******************* STEP 2c **************************/
  // Receive response
  logic sent_out;
  logic [2:0] eviction_index;
  always_ff @(posedge clk) begin : receive_response
    if (sent_out) begin // && bus_respcyc) begin
      sent_out <= 0;
      evicting = 0;

      //bus_respack <= 1;
      bus_reqcyc <= 0;
      bus_reqtag <= 0;
      bus_req <= 0;
    end
   
    invalidating <= 0;
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
    if (bus_resptag == `INVALIDATE) begin
      invalidating <= 1;
    end
  end

  
  /******************* STEP 2d **************************/
  always_ff @(posedge clk) begin
    bus_respack <= 0;
  end

  /******************* STEP 3 **************************/
  // Build cache line
  cache_cell [`CELLS_NEEDED - 1: 0] response_cache_line;
  cache_block [`WAYS - 1 : 0] instruction_way_invalidate_register; // 32 KB Placeholder Instruction Cache
  cache_block [`WAYS - 1 : 0] data_way_invalidate_register; // 32 KB Placeholder Instruction Cache
  logic response_added, invalidated, invalidating;
  always_comb begin : build_cache_line
    shortint offset = `OFFSET_SIZE_B, tag = `TAG_SIZE_B, index = `INDEX_SIZE_B;
   
    response_added = 0;
    invalidated = 0;

    if (invalidating) begin
      invalidate(response_register, instruction_way, instruction_way_invalidate_register);
      invalidate(response_register, data_way, data_way_invalidate_register);
      invalidated = 1;
    end else if (response_received) begin
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

  always_ff @(posedge clk) begin
    if (invalidated) begin
      instruction_way <= instruction_way_invalidate_register;
      data_way <= data_way_invalidate_register;
    end
  end


  /******************* STEP 4 **************************/
  // Insert into cache
  logic inserted;
  logic inserted_data_flushed, inserted_instruction_flushed;
  always_comb begin
    logic [`DATA_SIZE * `CELLS_NEEDED - 1 : 0] value = response_cache_line_register;
    Address instruction_insert_address, data_insert_address, data_insert_address2;
    //inserted = 0;
    inserted_instruction_flushed = 0;
    inserted_data_flushed = 0;

/*    if (flushing && ready_to_insert) begin
      if (flushed_reserver_register.iread) begin
        inserted = 1;
        instruction_busy = 0;
        inserted_instruction_flushed = 1;
        instruction_insert_address = flushed_instruction_register & `MEMORY_MASK;
        insert(instruction_insert_address, value, 0, -1, instruction_way, instruction_way_insert_register);
      end else if (flushed_reserver_register) begin
        inserted = 1;
        data_busy = 0;
        write_busy = 0;
        inserted_data_flushed = 1;
        data_insert_address = flushed_data_register & `MEMORY_MASK;
        insert(data_insert_address, value, 0, -1, data_way, data_way_insert_register);
      end
    end else */
    if (ready_to_insert && IorD) begin// (
//          (reserver_reg.read1) || 
//          (reserver_reg.read2) ||
//          (reserver_reg.write1))) begin
      //$display("Inserting Read Data - %3d - %b", x, reserver_reg);
      data_insert_address = address_register  & `MEMORY_MASK;
      insert(data_insert_address, value, 0, -1, data_way, data_way_insert_register);
      inserted = 1;
    end else if (ready_to_insert && !IorD) begin
      //$display("Inserting Instruction - %3d", x);
      instruction_insert_address = address_register & `MEMORY_MASK;
      insert(instruction_insert_address, value, 0, -1, instruction_way, instruction_way_insert_register);
      inserted = 1;
    end
  end

  always_ff @(posedge clk) begin
    /*if (inserted_data_flushed) begin
      //flushing <= 0;
      flushed_data_register <= 0;
      data_way <= data_way_insert_register;
      inserting <= 0;
    end else if (inserted_instruction_flushed) begin
      flushing <= 0;
      flushed_instruction_register <= 0;
      instruction_way <= instruction_way_insert_register;
      inserting <= 0;
    end else*/

    if (inserted && !evicting) begin
      inserting <= 0;
      inserted = 0;
      if (IorD)
        data_way <= data_way_insert_register;
      else
        instruction_way <= instruction_way_insert_register;
    end
    /*
    if (inserted && IorD) begin//(
//          (reserver_reg.read1) || 
//          (reserver_reg.read2) ||
//          (reserver_reg.write1))) begin
    //if (inserted && ((mem_read1 && reserver_reg.read1) || (mem_read2 && reserver_reg.read2))) begin
      data_way <= data_way_insert_register;
      inserting <= 0;
    end else if (inserted && !IorD) begin //instruction_read && reserver_reg.iread) begin
      instruction_way <= instruction_way_insert_register;
      inserting <= 0;
    end*/
  end

  /******************* STEP 5 **************************/
/*k
  // Return to processor
  always_ff @(posedge clk) begin : return_to_processor
    if (!busy) begin
  //    instruction_response <= instruction_response_register[`INSTRUCTION_SIZE - 1 : 0];
    end
  end*/
endmodule
