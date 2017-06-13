`include "Sysbus.defs"
`include "src/consts.sv"
`include "src/cache.sv"

module top
#(
  BUS_DATA_WIDTH = 64,
  BUS_TAG_WIDTH = 13
)
(
  input  clk,
         reset,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,
  
  // interface to connect to the bus
  output bus_reqcyc,
  output bus_respack,
  output [BUS_DATA_WIDTH-1:0] bus_req,
  output [BUS_TAG_WIDTH-1:0] bus_reqtag,
  input  bus_respcyc,
  input  bus_reqack,
  input  [BUS_DATA_WIDTH-1:0] bus_resp,
  input  [BUS_TAG_WIDTH-1:0] bus_resptag
);

  logic [63:0] pc;

  int x = 0;
  always_ff @(posedge clk) begin
    x++;
    if (x > 200)
      $finish;
  end

  always @ (posedge clk)
    if (reset) begin
      pc <= entry;
    end else begin
      $display("Hello World!  @ %x - %x", pc, instruction_response);
      if (!i_busy)
        pc <= pc + 4;
//      $finish;
    end

  always_ff @ (posedge clk) begin
    if (!reset)
      instruction_read = 1;
  end

/************************** INSTRUCTION FETCH ******************************/
  logic [`INSTRUCTION_SIZE-1:0] instruction_response;
  logic [`ADDRESS_SIZE - 1:0] instruction_address;
  logic instruction_read;
  logic busy;
  
  logic [`DATA_SIZE-1:0] d_req_r, d_req_w, d_write, d_data;
  logic mem_read, mem_write;
  logic [3:0] req_size_w, req_size_r;
  logic i_busy, d_busy, w_busy;

  cache cache (
    // Housekeeping
    .clk(clk), .reset(reset),
    
    // MemRead                        // MemWrite
    .bus_respcyc(bus_respcyc),        .bus_reqack(bus_reqack),
    .bus_respack(bus_respack),        .bus_reqcyc(bus_reqcyc), 
    .bus_resptag(bus_resptag),        .bus_req(bus_req),
    .bus_resp(bus_resp),              .bus_reqtag(bus_reqtag), 
         
    .busy(i_busy),
    
    .instruction_read(instruction_read),
    .instruction_address(pc),
    .instruction_response(instruction_response),

    .mem_read(0),
    .mem_write(0)
  );

  always_ff @(posedge clk) begin
    if (!busy) begin
    //  pc <= pc + 4;
    end
  end

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
