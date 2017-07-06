module register_file
(
  input clk,
  input reset,
  
  // Just for reading from registers
  input MemoryWord register_file [`NUMBER_OF_REGISTERS - 1 : 0],

  // WRITING TO REGISTERS
//  input regwr,
//  input Register rd,
//  input MemoryWord data,

  // READING REGISTERS
  input Register rs1_in,
  input Register rs2_in,
  output MemoryWord rs1_out,
  output MemoryWord rs2_out
);
  // Register array
  //logic [`DATA_SIZE-1:0] register_file[`NUMBER_OF_REGISTERS-1:0];
  // Read the reg_file from rs1 and rs2 and output them
  always_comb begin
    rs1_out = register_file[rs1_in];
    rs2_out = register_file[rs2_in];
  end
/*
  //Write to reg_file at rd if posedge of clock
  always_ff @ (posedge clk) begin
    if (reset) begin
      for(int i = 0; i < `NUMBER_OF_REGISTERS; i++)
        register_file[i] <= 0;
      register_file[2] <= data;
    end else begin
      //Reg write needs to be set and rd cannot be 0
      if (rd && regwr) begin
        register_file[rd] <= data;
      end
    end
  end*/
endmodule
