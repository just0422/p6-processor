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
  input [BUS_DATA_WIDTH - 1 : 0] bus_resp,
  input [BUS_TAG_WIDTH - 1 : 0] bus_resptag,

  // Memory Write Request interface
  output bus_reqcyc,
  input bus_reqack,
  output [BUS_DATA_WIDTH - 1 : 0] bus_req,
  output [BUS_TAG_WIDTH - 1 : 0] bus_reqtag,

  // Instruction Read Request
  input instr_read,
  input [`ADDRSIZE - 1 : 0] instruction_address,
  output [`INSTRSIZE - 1 : 0] instruction_repsonse,
  output instruction_busy,

  // Data Request
  input mem_read,
  input mem_write,
  input [`ADDRSIZE - 1 : 0] data_address,
  output [`DATASIZE - 1 : 0] data_repsonse,
  output data_busy
);

  data_cache_block [`WAYS - 1 : 0] data_way;
  instr_cache_block [`WAYS - 1 : 0] instr_way;
  
  task reset_signals;
    begin
      data_busy = 0;
      data_response = 0;

      instruction_busy = 0;
      instruction_response = 0;
    end
  endtask
  
  task read;
    input [`ADDRSIZE - 1 : 0] address;
    output success;
    output [`DATASIZE - 1 : 0] val;
    begin
      cache_instruction addr = address;
      logic success = 0;

      for (int i = 0; i < `INDEXSIZE; i++) begin
        if (addr.tag == data_way[i].tag) begin
          success = 1;
          value = data_way[i].data_cells[addr.tag];
        end 
        if (addr.tag == instr_way[i].tag) begin
          success = 1;
          value = instr_way[i].data_cells[addr.tag];
        end 
      end
    end
  endtask


  // Make request to Memory
  always_comb begin
    if (!reset) begin
      if (mem_read ^ mem_write) begin
        // Send a data read request
      end else if (instr_read) begin
        // Check cache


        // Send an instruction read request
        bus_req = instruction_address;
        bus_reqtag = `MEMR;
        bus_reqcyc = 1;
      end
    end
  end

  // Make Reset Signals when request returns
  always_ff @(posedge clk) begin
    bus_respack <= 0;
  end

  // Insert into cache and return to processor
  always_comb begin
  end
endmodule
