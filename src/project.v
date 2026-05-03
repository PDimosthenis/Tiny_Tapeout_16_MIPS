`timescale 1ns / 1ps
`default_nettype none

module tt_um_top_module_16_mips (
    input  wire [7:0] ui_in,  //input    
    output wire [7:0] uo_out, //output   
    input  wire [7:0] uio_in, //bi-in  
    output wire [7:0] uio_out,//bi-out  
    output wire [7:0] uio_oe, //mask which controll bidi  
    input  wire       ena,      
    input  wire       clk,
    input  wire       rst_n
);

    wire _unused_ok = &{1'b0, ui_in[5:3], 1'b0}; //To not let the unused input pins floating
    // Tiny Tapeout reset is active-low at the top-level pin.
    wire rst = !rst_n;
    // ui_in[7] selects between instruction loading and CPU execution.
    wire mode = ui_in[7];           // Run = 1, Load = 0
    // During load mode, ui_in[6] selects which byte of a 16-bit word is written.
    wire byte_sel = ui_in[6];       // 0 = low byte, 1 = high byte
    wire [15:0] alu_out;
    wire write_ena;

    // Writes to instruction memory are only allowed in load mode.
    assign write_ena = ena & !mode;

    mips_single_cycle cpu (
        .clk(clk),
        .rst(rst),
        .run_en(mode),
        .write_enable(write_ena),
        .write_addr(ui_in[2:0]), //instruction memory address will be given by ui_in[2:0] during load mode
        .write_data_byte(uio_in),
        .write_byte_sel(byte_sel),
        .ALU_out(alu_out)
    );

    // In run mode show ALU result; in load mode echo ui_in for quick bring-up visibility.
    assign uo_out = mode ? alu_out[7:0] : uio_in; // Debug visibility: echo load data on output pins.
    assign uio_oe = mode ? 8'b1111_1111 : 8'b0000_0000; //1 to use them as output on Run , 0 to use them as input on Load
    // In run mode expose PC[3:0] on bidir pins, otherwise leave output value benign.
    assign uio_out = alu_out[15:8];

endmodule

//  PC Module
module PC(
    input wire clk, rst, en, jump,
    input wire [2:0] jump_address,
    output reg [2:0] pc_out
);
    always @(posedge clk) begin
        if (rst) pc_out <= 3'd0;
        else if (en) pc_out <= jump ? jump_address : (pc_out + 1);
    end
endmodule

//  Instruction Memory 
module instruction_memory(
    input wire clk, write_enable,
    input wire [2:0] p_in, write_addr,
    input wire byte_select,
    input wire [7:0] write_data_byte,
    output wire [15:0] instruction
);
    reg [15:0] ram [0:7];

    always @(posedge clk) begin
        if (write_enable) begin
            // Assemble one 16-bit instruction from two 8-bit writes to same address.
            if (byte_select)
                ram[write_addr][15:8] <= write_data_byte;
            else
                ram[write_addr][7:0] <= write_data_byte;
        end
    end

    assign instruction = ram[p_in];
endmodule

//  Decoder 
module decoder (
    input wire [15:0] instruction_in,
    output reg [1:0] rs, rt, rd,
    output reg [7:0] im,
    output reg [2:0] jump_addr
);

    wire [3:0] opcode = instruction_in[15:12];

    always @(*) begin
        rs = 2'b00;
        rt = 2'b00;
        rd = 2'b00;
        im = 8'b0000_0000;
        jump_addr = 3'b000;

        case (opcode)
            4'b0000, // add
            4'b0001, // sub
            4'b0010, // xor 
            4'b0011: //or
             begin // R-type: add, sub, xor, or
                rs = instruction_in[11:10];
                rt = instruction_in[9:8];
                rd = instruction_in[7:6];
            end

            4'b0100, //lw
            4'b0101, //sw
            4'b0110: //addi
             begin // lw, sw, addi
                rs = instruction_in[11:10]; //
                rt = instruction_in[9:8];  //
                im = instruction_in[7:0];  //
            end

            4'b0111: begin // jump
                jump_addr = instruction_in[2:0];
            end

            default: begin
            end
        endcase
    end

endmodule

module alu
  #(parameter ADD = 3'b000,
              SUB = 3'b001,
              ORR = 3'b010,
              XORR = 3'b011)
(
    input wire [15:0] A,
    input wire [15:0] B,
    input wire [2:0] alu_op,
    output reg [15:0] alu_out
);

always @(*) begin
        case (alu_op)
            ADD: alu_out = A + B;
            SUB: alu_out = A - B;
            ORR:  alu_out = A | B;
            XORR: alu_out = A ^ B;
            default: alu_out = 16'b0;
        endcase
   end
endmodule

//  Control Unit 
module control_unit (
    input wire [3:0] opcode,
    output reg MemRead,
    output reg MemWrite,
    output reg RegWrite,
    output reg ALUsrc,
    output reg RegDst,
    output reg MemtoReg,
    output reg Jump,
    output reg [2:0] alu_op
);

    always @(*) begin
        // Safe defaults: NOP-like behavior unless opcode enables a path.
        MemRead = 1'b0;
        MemWrite = 1'b0;
        RegWrite = 1'b0;
        ALUsrc = 1'b0;
        RegDst = 1'b0;
        MemtoReg = 1'b0;
        Jump = 1'b0;
        alu_op = 3'b000;

        case (opcode)
            4'b0000: begin RegDst = 1'b1; RegWrite = 1'b1; alu_op = 3'b000; end // add
            4'b0001: begin RegDst = 1'b1; RegWrite = 1'b1; alu_op = 3'b001; end // sub
            4'b0010: begin RegDst = 1'b1; RegWrite = 1'b1; alu_op = 3'b011; end // xor
            4'b0011: begin RegDst = 1'b1; RegWrite = 1'b1; alu_op = 3'b010; end // or
            4'b0100: begin ALUsrc = 1'b1; MemtoReg = 1'b1; RegWrite = 1'b1; MemRead = 1'b1; alu_op = 3'b000; end // lw
            4'b0101: begin ALUsrc = 1'b1; MemWrite = 1'b1; alu_op = 3'b000; end // sw
            4'b0110: begin ALUsrc = 1'b1; RegWrite = 1'b1; alu_op = 3'b000; end // addi
            4'b0111: begin Jump = 1'b1; end // jump
            default: begin
            end
        endcase
    end
endmodule

module data_mem(
    input wire clk,
    input wire MemWrite,
    input wire MemRead,
    input wire  addr,
    input wire [15:0] writeData,
    output wire [15:0] readData
);

    // 4 x 16-bit data memory.
    reg [15:0] memory [0:1];

    assign readData = MemRead ? memory[addr] : 16'b0;

    always @(posedge clk) begin
        if (MemWrite)
            memory[addr] <= writeData;
    end

endmodule

module regfile (
    input wire clk,                  
    input wire [1:0] readReg1, 
    input wire [1:0] readReg2, 
    input wire [1:0] writeReg,
    input wire [15:0] writeData,
    input wire RegWrite,
    output wire [15:0] readData1,    
    output wire [15:0] readData2
);

    reg [15:0] registers [3:0];

    
    assign readData1 = (readReg1 == 2'b00) ? 16'h0000 : registers[readReg1];
    assign readData2 = (readReg2 == 2'b00) ? 16'h0000 : registers[readReg2];

    
    always @(posedge clk) begin
        if (RegWrite && writeReg != 2'b00) begin
            registers[writeReg] <= writeData;
        end
    end

endmodule

module mips_single_cycle (
    input  wire        clk, rst, run_en, write_enable,
    input  wire [2:0] write_addr,
    input  wire [7:0] write_data_byte,
    input  wire write_byte_sel,    
    output wire [15:0] ALU_out   
);

   //Internal nets
   wire [2:0] pc_out;
   wire        jump;
   wire [15:0] instruction;
   wire [1:0]  rs, rt, rd;
   wire [7:0] im;
   wire [2:0] jump_addr;
   wire        MemRead, MemWrite, RegWrite, ALUsrc, RegDst, MemtoReg;
   wire [2:0]  ALUOp;
   wire [1:0]  writeReg;
   wire [15:0] writeData_reg;
   wire [15:0] readData1, readData2;
   wire [15:0] MemData;
   wire [15:0] ALU_input1, ALU_input2;
   wire [15:0] imm_sgn_ext;

   
   
   assign writeReg          = (RegDst) ? rd : rt; //Choose to which register to write
   assign writeData_reg     = (MemtoReg) ? MemData : ALU_out; //Choose what data to write on the regfile. Mem or ALU result
   assign ALU_input1        = readData1;
   assign imm_sgn_ext       = {{8{im[7]}}, im};               // Sign-extend the immediate value
   assign ALU_input2        = (ALUsrc) ? imm_sgn_ext : readData2;  //Choose the second ALU operand between reg2 or immediate value

   PC pc (
       .clk(clk), 
       .rst(rst), 
       .en(run_en),
       .jump(jump), 
       .jump_address(jump_addr), 
       .pc_out(pc_out)
   );   

   instruction_memory inst_mem (
       .clk(clk),
       .write_enable(write_enable),
       .p_in(pc_out), 
       .write_addr(write_addr),
       .byte_select(write_byte_sel),
       .write_data_byte(write_data_byte),  
       .instruction(instruction)
   );

   decoder dec (
       .instruction_in(instruction), //Get the full 16bit instruction
       .rs(rs),                      
       .rt(rt), 
       .rd(rd), 
       .im(im), 
       .jump_addr(jump_addr)
   );

   control_unit cu (
       .opcode(instruction[15:12]), 
       .MemRead(MemRead), 
       .MemWrite(MemWrite), 
       .RegWrite(RegWrite), 
       .ALUsrc(ALUsrc), 
       .RegDst(RegDst), 
       .MemtoReg(MemtoReg), 
       .Jump(jump), 
       .alu_op(ALUOp)
   );

   regfile rf (
       .clk(clk), 
       .readReg1(rs), 
       .readReg2(rt),  
       .RegWrite(RegWrite & run_en), 
       .writeData(writeData_reg), 
       .readData1(readData1), 
       .readData2(readData2), 
       .writeReg(writeReg) 
   );

   alu alu_unit (
       .A(ALU_input1), 
       .B(ALU_input2), 
       .alu_op(ALUOp), 
       .alu_out(ALU_out)
   );

   data_mem data_memory (
       .clk(clk), 
       .MemWrite(MemWrite & run_en), 
       .MemRead(MemRead), 
       .addr(ALU_out[0]), 
       .writeData(readData2), 
       .readData(MemData)
   );

endmodule

