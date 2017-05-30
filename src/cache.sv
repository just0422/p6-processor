//L1 = 8 KB
//64 Byte blocks

//128 Blocks
//4 ways - 32 blocks per way

module cache
(
  // Memoory Read Request Interface
  input bus_respcyc,
  input bus_reqack,
  input [BUS_DATA_WIDTH - 1 : 0] bus_resp,
  input [BUS_TAG_WIDTH - 1 : 0] bus_resptag,

  // Memory Write Request interface
  output bus_reqcyc,
  output bus_respack,
  output [BUS_DATA_WIDTH - 1 : 0] bus_req,
  output [BUS_TAG_WIDTH - 1 : 0] bus_reqtag,

  // Instruction Read Request
  input [`ADDRSIZE - 1 : 0] instruction_address,
  output [`INSTRSIZE - 1 : 0] instruction_repsonse,
  output instruction_busy,

  // Data Request
  input [`ADDRSIZE - 1 : 0] data_address,
  input mem_read,
  input mem_write,
  output [`INSTRSIZE - 1 : 0] data_repsonse,
  output data_busy
);



  always_comb begin
  end
endmodule
