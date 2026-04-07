`default_nettype none
`timescale 1ns / 1ps

module tb;
  reg clk, rst_n, ena;
  reg [7:0] ui_in, uio_in;
  wire [7:0] uo_out, uio_out, uio_oe;
  integer errors = 0;

  tt_um_kishorenetheti_tt8_mips dut (
    .clk(clk), .rst_n(rst_n), .ena(ena),
    .ui_in(ui_in), .uo_out(uo_out),
    .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe)
  );

  // 100ns period (10MHz)
  always #50 clk = ~clk;

  // Program one instruction into instruction memory in program mode.
  task load_word(input [3:0] addr, input [15:0] word);
    begin
      @(posedge clk);
      #5;
      uio_in = {1'b0, 3'b000, addr};
      uio_in[6] = 1'b0;
      ui_in = word[7:0];
      ena = 1'b1;
      @(posedge clk);
      #5;
      ena = 1'b0;

      @(posedge clk);
      #5;
      uio_in = {1'b0, 3'b000, addr};
      uio_in[6] = 1'b1;
      ui_in = word[15:8];
      ena = 1'b1;
      @(posedge clk);
      #5;
      ena = 1'b0;
    end
  endtask

  // Check ALU output for current cycle and then advance one CPU cycle.
  task check(input [7:0] exp, input [8*40-1:0] msg);
    begin
      #10;
      if (uo_out !== exp) begin
        $display("[FAIL] %s | Exp: 0x%h, Got: 0x%h", msg, exp, uo_out);
        errors = errors + 1;
      end else begin
        $display("[PASS] %s | Result: 0x%h", msg, uo_out);
      end
      @(posedge clk);
    end
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    ena = 0;
    ui_in = 8'h00;
    uio_in = 8'h00;

    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    #200;
    rst_n = 1;
    #100;

    $display("============================================================================");
    $display("                   ASSEMBLY PROGRAM (8 INST, 3-REG R-TYPE)                 ");
    $display("============================================================================");
    $display("PC  | Word  | Assembly            | Expected ALU_out / Effect              ");
    $display("----|-------|---------------------|-----------------------------------------");
    $display("0x0 | 0x6115 | ADDI R1, 5          | R1=6,  ALU_out=0x06                   ");
    $display("0x1 | 0x6223 | ADDI R2, 3          | R2=5,  ALU_out=0x05                   ");
    $display("0x2 | 0x0120 | ADD  R0, R1, R2     | R0=11, ALU_out=0x0B                   ");
    $display("0x3 | 0x2023 | XOR  R3, R0, R2     | R3=14, ALU_out=0x0E                   ");
    $display("0x4 | 0x5031 | SW   R3, 1(R0)      | mem[0]=R3, addr ALU_out=0x0C          ");
    $display("0x5 | 0x4021 | LW   R2, 1(R0)      | R2=mem[0], addr ALU_out=0x0C          ");
    $display("0x6 | 0x1201 | SUB  R1, R2, R0     | R1=3,  ALU_out=0x03                   ");
    $display("0x7 | 0x7002 | JUMP 2              | Loop back to PC=2                     ");
    $display("============================================================================\n");

    $display("--- Loading Program into Instruction Memory ---");
    load_word(4'd0, 16'h6115); // ADDI R1, 5
    load_word(4'd1, 16'h6223); // ADDI R2, 3
    load_word(4'd2, 16'h0120); // ADD  R0, R1, R2
    load_word(4'd3, 16'h2023); // XOR  R3, R0, R2
    load_word(4'd4, 16'h5031); // SW   R3, 1(R0)
    load_word(4'd5, 16'h4021); // LW   R2, 1(R0)
    load_word(4'd6, 16'h1201); // SUB  R1, R2, R0
    load_word(4'd7, 16'h7002); // JUMP 2

    #100;
    $display("\n--- Running Program ---");

    @(posedge clk);
    #5;
    uio_in = 8'h80; // run mode, starts execution from PC=0

    check(8'h06, "PC=0: ADDI R1, 5");
    check(8'h05, "PC=1: ADDI R2, 3");
    check(8'h0B, "PC=2: ADD  R0, R1, R2");
    check(8'h0E, "PC=3: XOR  R3, R0, R2");
    check(8'h0C, "PC=4: SW   R3, 1(R0) address calc");
    check(8'h0C, "PC=5: LW   R2, 1(R0) address calc");
    check(8'h03, "PC=6: SUB  R1, R2, R0");

    $display("[INFO] PC=7: JUMP 2 (Advancing clock...)");
    @(posedge clk);

    check(8'h11, "PC=2: ADD  R0, R1, R2 (After Jump)");

    if (errors == 0)
      $display("\n*** ALL TESTS PASSED ***\n");
    else
      $display("\n!!! FAILED %0d TESTS !!!\n", errors);

    #1000;
    $finish;
  end

endmodule

`default_nettype wire
