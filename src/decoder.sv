module decoder
(
  input InstructionWord instruction,
  input branch_taken,

  output Register register_source_1,
  output Register register_source_2,
  output Register register_destination,

  output Immediate imm,
  output control_bits ctrl_bits
);

  always_comb begin
    logic [6:0] opcode = instruction[6:0];

    logic [2:0] funct3 = instruction[14:12];
    logic [6:0] funct7 = instruction[31:25];
    logic [5:0] shamt  = instruction[25:20];
    logic [4:0] shamtw = instruction[24:20];

    control_bits ctrl = 0;
    logic sign = instruction[31]; // Grab the sign

    // Create all the possible immediates
    Immediate itype  = {{ 52 { sign }}, 
                          instruction[31:20]};  // 11:0

    Immediate stype  = {{ 52 { sign }}, 
                          instruction[31:25],   // 11:5
                          instruction[11:7] };  // 0:4

    Immediate sbtype = {{ 52 { sign }}, 
                          instruction[31],      // 11
                          instruction[7],       // 10
                          instruction[30:25],   // 9:4
                          instruction[11:8] };  // 3:0
                                                   
    Immediate utype  = {{ 44 { sign }}, 
                          instruction[31:12]};  // 19:0

    Immediate ujtype = {{ 44 { sign }}, 
                          instruction[31],      // 19
                          instruction[19:12],   // 18:11
                          instruction[20],      // 10
                          instruction[30:21] }; // 9:0

    Immediate uitype = {{ 52 { 1'b0 }}, 
                          instruction[31:20]};  // 11:0



    register_source_1 = instruction[19:15];
    register_source_2 = instruction[24:20];
    register_destination = instruction[11:7];

    imm = 0;

    case(opcode)
      7'b0110111: begin // LUI
                    ctrl.regwr = 1; 
                    ctrl.alusrc = 1;
                    ctrl.aluop = LUI;
                    imm = utype << 12;
                  end
      7'b0010111: begin // AUIPC
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    ctrl.apc = 1;
                    ctrl.aluop = ADD;
                    imm = utype << 12;
                  end
      7'b1101111: begin // JAL 
                    ctrl.apc = 1;
                    ctrl.regwr = 1;
                    ctrl.ucjump = 1;
                    ctrl.alusrc = 1;
                    ctrl.aluop = ADD;
                    imm = ujtype << 1; // Signed offset multipe of 2 bytes (8 bits)
                  end
      7'b1100111: begin // JALR
                    ctrl.regwr = 1;
                    ctrl.ucjump = 1;
                    ctrl.alusrc = 1;
                    ctrl.aluop = JALR;
                    imm = itype;
                  end
      7'b1100011: begin // BRANCH
                    imm = sbtype << 1; // Did this for ujtype too ....
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
      7'b0000011: begin // LOADS
                    ctrl.regwr = 1;
                    ctrl.memtoreg = 1;
                    ctrl.alusrc = 1;
                    ctrl.aluop = ADD;
                    imm = itype;
                    case (funct3)
                      3'b000: ctrl.memory_type = LB;
                      3'b001: ctrl.memory_type = LH;
                      3'b010: ctrl.memory_type = LW;
                      3'b011: ctrl.memory_type = LD;
                      3'b100: ctrl.memory_type = LBU;
                      3'b101: ctrl.memory_type = LHU; 
                      3'b110: ctrl.memory_type = LWU;
                    endcase
                  end
      7'b0100011: begin // STORES
                    ctrl.memwr = 1;
                    ctrl.alusrc = 1;
                    ctrl.aluop = ADD;
                    imm = stype;
                    case (funct3)
                      3'b000: ctrl.memory_type = SB;
                      3'b001: ctrl.memory_type = SH;
                      3'b010: ctrl.memory_type = SW;
                      3'b011: ctrl.memory_type = SD;
                    endcase
                  end
      7'b0010011: begin // I - type Instructions
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    imm = itype;
                    case (funct3)
                      3'b000: ctrl.aluop = ADD;     // ADDI
                      3'b010: ctrl.aluop = SLT;     // SLTI
                      3'b011: begin                 // SLTIU
                                ctrl.aluop = SLTU;
                                ctrl.usign = 1;
                                imm = uitype;
                              end
                      3'b100: ctrl.aluop = XOR;     // XORI
                      3'b110: ctrl.aluop = OR;      // ORI
                      3'b111: ctrl.aluop = AND;     // ANDI
                      3'b001: begin                 // SLLI
                                ctrl.aluop = SLL;
                                imm = shamt;
                              end
                      3'b101: begin                 // SR_I
                                ctrl.aluop = instruction[30] ? SRA : SRL;
                                imm = shamt;
                              end
                    endcase
                  end
      7'b0011011: begin // IW - type Instructions
                    ctrl.regwr = 1;
                    ctrl.alusrc = 1;
                    imm = itype;
                    case (funct3)
                      3'b000: ctrl.aluop = ADDW;    // ADDIW
                      3'b001: begin                 // SLLIW
                                ctrl.aluop = SLLW;
                                imm = shamtw;
                              end
                      3'b101: begin                 // SR_I
                                ctrl.aluop = instruction[30] ? SRAW : SRLW;
                                imm = shamtw;
                              end
                    endcase
                  end
      7'b0110011: begin // R-TYPE instructions
                    ctrl.regwr = 1;
                    case(funct3)
                      3'b000: begin
                                case(instruction[31:25])
                                   0: ctrl.aluop = ADD;      // ADD
                                   1: ctrl.aluop = MUL;      // MUL
                                  32: ctrl.aluop = SUB;      // SUB
                                endcase
                              end
                      3'b001: begin
                                case(instruction[25])
                                   0: ctrl.aluop = SLL;       // SLL
                                   1: ctrl.aluop = MULH;      // MULH
                                endcase
                               end
                      3'b010: begin
                                case(instruction[25])
                                   0: ctrl.aluop = SLT;       // SLT
                                   1: begin ctrl.aluop = MULHSU; ctrl.usign = 1; end
                                endcase
                               end
                      3'b011: begin
                                case(instruction[25])
                                   0: begin ctrl.aluop = SLTU; ctrl.usign = 1; end
                                   1: begin ctrl.aluop = MULHU; ctrl.usign = 1; end
                                endcase
                              end
                      3'b100: begin
                                case(instruction[25])
                                   0: ctrl.aluop = XOR;       // XOR
                                   1: ctrl.aluop = DIV;       // DIV 
                                endcase
                              end
                      3'b101: begin
                                case(instruction[31:25])
                                   0: ctrl.aluop = SRL;      // SRL
                                   1: begin ctrl.aluop = DIVU; ctrl.usign = 1; end
                                  32: ctrl.aluop = SRA;      // SRA
                                endcase
                              end
                      3'b110: begin
                                case(instruction[25])
                                   0: ctrl.aluop = OR;        // OR
                                   1: ctrl.aluop = REM;       // REM 
                                endcase
                              end
                      3'b111: begin
                                case(instruction[25])
                                   0: ctrl.aluop = AND;       // AND
                                   1: begin ctrl.aluop = REMU; ctrl.usign = 1; end
                                endcase
                              end
                    endcase 
                  end
      7'b0111011: begin // RW-TYPE instructions
                    ctrl.regwr = 1;
                    case(funct3)
                      3'b000: begin
                                case(instruction[31:25])
                                   0: ctrl.aluop = ADDW;      // ADDW
                                   1: ctrl.aluop = MULW;      // MULW
                                  32: ctrl.aluop = SUBW;      // SUBW
                                endcase
                              end
                      3'b001: ctrl.aluop = SLLW;              // SLLW
                      3'b100: ctrl.aluop = DIVW;              // DIVW
                      3'b101: begin
                                case(instruction[31:25])
                                   0: ctrl.aluop = SRLW;      // SRL
                                   1: begin ctrl.aluop = DIVUW; ctrl.usign = 1; end
                                  32: ctrl.aluop = SRAW;      // SRA
                                endcase
                              end
                      3'b110: ctrl.aluop = REMW;              // REMW
                      3'b111: begin ctrl.aluop = REMUW; ctrl.usign = 1; end
                    endcase
                  end
      7'b1110011: begin // ecall 
                    ctrl.ecall = instruction[31:7] == 0;
                    ctrl.unsupported = instruction[31:7] != 0;
                  end
      default   : ctrl.unsupported = instruction[31:7] != 0;
    endcase

    ctrl.branch_prediction = branch_taken;
    ctrl_bits = ctrl;
  end
endmodule



