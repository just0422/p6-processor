module decoder
(
  input [`INSTRUCTION_SIZE - 1: 0] instruction,
  input branch_taken,

  output [`NUMBER_OF_REGISTERS - 1: 0] register_source_1,
  output [`NUMBER_OF_REGISTERS - 1: 0] register_source_2,
  output [`NUMBER_OF_REGISTERS - 1: 0] register_destination,
  output [`IMMEDIATE_SIZE - 1 : 0] imm,
  output [`CONTROL_BITS_SIZE - 1 : 0] ctrl_bits
);

    logic [6:0] op = instruction[6:0];
    logic [2:0] funct3 = instruction[14:12];
    logic [6:0] funct7 = instruction[31:25];

  always_comb begin
    control_bits ctrl = 0;
    //Straight from the instruction
    logic [`DATA_SIZE-1:0] imm_i = {{52{instruction[31]}}, instruction[31:20]};
    logic [`DATA_SIZE-1:0] imm_s = {{53{instruction[31]}}, instruction[31:25], instruction[11:8], instruction[7]};
    logic [`DATA_SIZE-1:0] imm_b = {{52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    logic [`DATA_SIZE-1:0] imm_u = {{32{instruction[31]}}, instruction[31:12], 12'b0};
    logic [`DATA_SIZE-1:0] imm_j = {{44{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21] , 1'b0};
    logic [`DATA_SIZE-1:0] uimm_i = {{32{1'b0}}, {20{instruction[31]}}, instruction[31:20]};
    logic [`DATA_SIZE-1:0] uimm_s = {{32{1'b0}}, {20{instruction[31]}}, instruction[31:25], instruction[11:8], instruction[7]};
    logic [`DATA_SIZE-1:0] uimm_b = {{32{1'b0}}, {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    logic [`DATA_SIZE-1:0] uimm_u = {{32{1'b0}}, instruction[31:12], 12'b0};
    logic [`DATA_SIZE-1:0] uimm_j = {{32{1'b0}}, {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21] , 1'b0};
    //Straight from the instruction
    register_source_1 = instruction[19:15];
    register_source_2 = instruction[24:20];
    register_destination = instruction[11:7];
    imm = 0;
    //Calculated
    case(op)
      7'b0000000: begin end
      7'b0110111: begin //LUI
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    //ctrl.apc = 1;
                    ctrl.aluop = ADD;
                    imm = imm_u;
                  end
      7'b0010111: begin //AUIPC
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    ctrl.apc = 1;
                    ctrl.aluop = ADD;
                    imm = imm_u;
                  end
      7'b1101111: begin //JAL
                    ctrl.regwr = 1;
                    ctrl.ucjump = 1;
                    ctrl.aluop = ADD;
                    imm = 0;
                  end
      7'b1100111: begin //JALR
                    ctrl.regwr = 1;
                    ctrl.ucjump = 1;
                    ctrl.alusrc = 1;
                    ctrl.aluop = ADD;
                    imm = 0;
                  end
      7'b1100011: begin //BRANCH
                    imm = imm_b;
                    ctrl.cjump = 1;
                    case (funct3)
                      3'b000: ctrl.aluop = BEQ;
                      3'b001: ctrl.aluop = BNE;
                      3'b100: ctrl.aluop = BLT;
                      3'b101: ctrl.aluop = BGE;
                      3'b110: begin ctrl.aluop = BLTU; ctrl.usign = 1; end
                      3'b111: begin ctrl.aluop = BGEU; ctrl.usign = 1; end
                    endcase
                  end
      // I think all loads should just be add signed, but not sure
      7'b0000011: begin //LB, LH, LW, LBU, LHU, LWU, LD
                    ctrl.regwr = 1;
                    ctrl.memtoreg = 1;
                    ctrl.alusrc = 1;
                    imm = imm_i;
                    case(funct3)
                      3'b000: ctrl.memory_type = LB;
                      3'b001: ctrl.memory_type = LH;
                      3'b010: ctrl.memory_type = LW;
                      3'b011: ctrl.memory_type = LD;
                      3'b100: begin ctrl.memory_type = LBU; ctrl.usign = 1; imm = uimm_i; end
                      3'b101: begin ctrl.memory_type = LHU; ctrl.usign = 1; imm = uimm_i; end
                      3'b110: begin ctrl.memory_type = LWU; ctrl.usign = 1; imm = uimm_i; end
                    endcase
                  end
      7'b0100011: begin //SB, SH, SW, SD
                    ctrl.memwr = 1;
                    ctrl.alusrc = 1;
                    imm = imm_s;
                    case(funct3)
                      3'b000: ctrl.memory_type = SB;
                      3'b001: ctrl.memory_type = SH;
                      3'b010: ctrl.memory_type = SW;
                      3'b011: ctrl.memory_type = SD;
                    endcase
                  end
      7'b0010011: begin //ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    imm = imm_i;
                    case(funct3)
                      3'b000: ctrl.aluop = ADD;
                      3'b010: ctrl.aluop = SLT;
                      3'b011: begin ctrl.aluop = SLT; ctrl.usign = 1; imm = uimm_i; end
                      3'b100: ctrl.aluop = XOR;
                      3'b110: ctrl.aluop = OR;
                      3'b111: ctrl.aluop = AND;
                      3'b001: begin ctrl.aluop = SLL; imm = instruction[24:20]; end
                      3'b101: begin
                                imm = instruction[24:20];
                                ctrl.aluop = (instruction[30]) ? SRA : SRL;
                              end
                    endcase
                  end
      7'b0011011: begin //ADDIW, SLLIW, SRLIW, SRAIW
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    imm = imm_i;
                    case(funct3)
                      3'b000: ctrl.aluop = ADDW;
                      3'b001: begin ctrl.aluop = SLLW; imm = instruction[24:20]; end
                      3'b101: begin
                                imm = instruction[24:20];
                                ctrl.aluop = (instruction[30]) ? SRAW : SRLW;
                              end
                    endcase
                  end
      7'b0110011: begin //ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
                    ctrl.regwr = 1;
                    case(funct3)
                      3'b000: begin
                                if (instruction[25])
                                  ctrl.aluop = MUL; // MUL
                                else
                                  ctrl.aluop = (instruction[30]) ? SUB : ADD; //ADD
                              end
                      3'b001: ctrl.aluop = (instruction[25]) ? MULH : SLL;
                      3'b010: begin
                                if (instruction[25]) begin
                                  ctrl.aluop = MULHSU; // MULHSU
                                  ctrl.usign = 1;
                                end else begin
                                  ctrl.aluop = SLT; // SLT
                                end
                              end
                      3'b011: begin
                                if (instruction[25]) begin
                                  ctrl.aluop = MULHU; // MULHU
                                  ctrl.usign = 1;
                                end else begin
                                  ctrl.aluop = SLT; // SLTU
                                  ctrl.usign = 1;
                                end
                              end
                      3'b100: begin
                                if (instruction[25])
                                  ctrl.aluop = DIV; //DIV
                                else
                                  ctrl.aluop = XOR; //XOR
                              end
                      3'b101: begin
                                if (instruction[25])
                                  ctrl.aluop = DIVU;
                                else
                                  ctrl.aluop = (instruction[30]) ? SRA : SRL;
                              end
                      3'b110: ctrl.aluop = (instruction[25]) ? DIV : OR;
                      3'b111: begin
                                if (instruction[25]) begin
                                  ctrl.aluop = REMU;
                                  ctrl.usign = 1;
                                end else begin
                                  ctrl.aluop = AND;
                                end
                              end
                    endcase
                  end
      7'b0111011: begin //ADDW, SUBW, SLLW, SRLW, SRAW, MULW, DIVW, DIVUW, REMW, REMUW
                    ctrl.regwr = 1;
                    case(funct3)
                      3'b000: begin
                                if (instruction[25])
                                  ctrl.aluop = MULW;
                                else
                                  ctrl.aluop = (instruction[30]) ? SUBW : ADDW;
                              end
                      3'b001: ctrl.aluop = SLLW; //SLLW
                      3'b100: ctrl.aluop = DIVW;
                      3'b101: begin
                                if (instruction[25]) begin
                                  ctrl.aluop = DIVUW;
                                  ctrl.usign = 1;
                                end
                                else
                                  ctrl.aluop = (instruction[30]) ? SRAW : SRLW;
                              end
                      3'b110: ctrl.aluop = REMW;
                      3'b111: begin ctrl.aluop = REMUW; ctrl.usign = 1; end
                    endcase
                  end
      7'b1110011: begin
                     ctrl.ecall = instruction[31:7] == 0;
                     ctrl.unsupported = instruction[31:7] != 0;
                  end
      default   : ctrl.unsupported = 1;
    endcase
    ctrl.branch_prediction = branch_taken;
    ctrl_bits = ctrl;
  end
endmodule
