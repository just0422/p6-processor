module alu (
  // Control bits (for unsigned and aluop)
  input control_bits ctrl_bits,

  // Operands
  input MemoryWord sourceA,
  input MemoryWord sourceB,

  // Outputs
  output MemoryWord result,
  output take_branch
);

  always_comb begin
    DoubleWord result_mul;
    MemoryWord result_add, result_sub, result_div, result_divw;
    MemoryWord result_rem, result_remw;
    HalfWord result_sllw, result_srlw, result_sraw;

    // Lets get all the difference operand sizes we need
    HalfWordSigned      sourceAHS = sourceA[31 : 0],   sourceBHS = sourceB[31 : 0];
    HalfWordUnsigned    sourceAHU = sourceA[31 : 0],   sourceBHU = sourceB[31 : 0];
    MemoryWordSigned    sourceAMS = sourceA[63 : 0],   sourceBMS = sourceB[63 : 0];
    MemoryWordUnsigned  sourceAMU = sourceA[63 : 0],   sourceBMU = sourceB[63 : 0];

    // Do some work to see if we need signed results or not;
    result_add = sourceAMS + sourceBMS;
    result_sub = sourceAMS - sourceBMS;
    result_mul = sourceAMS * sourceBMS;
    result_div = sourceAMS / sourceBMS;
    result_rem = sourceAMS % sourceBMS;
    result_divw = sourceAHS / sourceBHS;
    result_remw = sourceAHS % sourceBHS;
    if (ctrl_bits.usign) begin
      result_add = sourceAMU + sourceBMU;
      result_sub = sourceAMU - sourceBMU;
      result_mul = sourceAMU * sourceBMU;
      result_div = sourceAMU / sourceBMU;
      result_rem = sourceAMU % sourceBMU;
      result_divw = sourceAHU / sourceBHU;
      result_remw = sourceAHU % sourceBHU;
    end

    result_sllw = sourceAHS << sourceBHU[4:0];
    result_srlw = sourceAHS >> sourceBHU[4:0];
    result_sraw = sourceAHS >>> sourceBHU[4:0];

    take_branch = 0;
    case(ctrl_bits.aluop) 
      AND       :   result = sourceA & sourceB;
      OR        :   result = sourceA | sourceB;
      XOR       :   result = sourceA ^ sourceB;

      ADD       :   result = result_add;
      SUB       :   result = result_sub;
      MUL       :   result = result_mul[ 63 :  0];
      DIV,DIVU  :   result = result_div;
      REM,REMU  :   result = result_div;

      MULHU,MULH:   result = result_mul[127 : 64];

      ADDW      :   result = { {32 {!ctrl_bits.usign & result_add[31] } }, result_add[31:0] };
      SUBW      :   result = { {32 {!ctrl_bits.usign & result_sub[31] } }, result_sub[31:0] };
      MULW      :   result = { {32 {!ctrl_bits.usign & result_mul[31] } }, result_mul[31:0] };
      DIVW,DIVUW:   result = { {32 {!ctrl_bits.usign & result_divw[31] } }, result_divw[31:0] };
      REMW,REMUW:   result = { {32 {!ctrl_bits.usign & result_remw[31] } }, result_remw[31:0] };

      BEQ       :   take_branch = sourceA == sourceB;
      BNE       :   take_branch = sourceA != sourceB;
      BLT       :   take_branch = sourceA < sourceB;
      BGE       :   take_branch = sourceA >= sourceB;
      BLTU      :   take_branch = sourceAMU < sourceBMU;
      BGEU      :   take_branch = sourceAMU >= sourceBMU;

      SLT       :   result = ctrl_bits.usign ? sourceAMU < sourceBMU : sourceAMS < sourceBMS;
      SLTW      :   result = ctrl_bits.usign ? sourceAHU < sourceBHU : sourceAHS < sourceBHS;
      
      SLL       :   result = sourceAMS << sourceBMU[5:0];
      SRL       :   result = sourceAMS >> sourceBMU[5:0];
      SRA       :   result = sourceAMS >>> sourceBMU[5:0];

      SLLW      :   result = { {32 {result_sllw[31]} }, result_sllw}; 
      SRLW      :   result = { {32 {result_srlw[31]} }, result_srlw}; 
      SRAW      :   result = { {32 {result_sraw[31]} }, result_sraw}; 
    endcase
  end
endmodule
