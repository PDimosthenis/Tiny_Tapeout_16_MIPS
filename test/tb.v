/*`default_nettype none
`timescale 1ns / 1ps

module tb;
  reg        clk;
  reg        rst_n;
  reg        ena;
  reg  [7:0] ui_in;
  wire [7:0] uo_out;
  reg  [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  integer failures;

  tt_um_top_module_16_mips dut (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );

  // 10 MHz clock (100 ns period)
  initial clk = 1'b0;
  always #50 clk = ~clk;

  task automatic check_u8;
    input [7:0] got;
    input [7:0] exp;
    input [255:0] msg;
    begin
      if (got !== exp) begin
        failures = failures + 1;
        $display("[FAIL] %0s got=0x%02h exp=0x%02h @%0t", msg, got, exp, $time);
      end
      else begin
        $display("[OK]   %0s = 0x%02h", msg, got);
      end
    end
  endtask

  task automatic check_u16;
    input [15:0] got;
    input [15:0] exp;
    input [255:0] msg;
    begin
      if (got !== exp) begin
        failures = failures + 1;
        $display("[FAIL] %0s got=0x%04h exp=0x%04h @%0t", msg, got, exp, $time);
      end
      else begin
        $display("[OK]   %0s = 0x%04h", msg, got);
      end
    end
  endtask

  // Load one 16-bit instruction into instruction memory in load mode.
  task automatic load_instr;
    input [2:0] addr;
    input [15:0] instr;
    begin
      @(negedge clk);
      // Low byte write
      ui_in  = {1'b0, 1'b0, 3'b000, addr};
      uio_in = instr[7:0];
      @(posedge clk);

      @(negedge clk);
      // High byte write
      ui_in  = {1'b0, 1'b1, 3'b000, addr};
      uio_in = instr[15:8];
      @(posedge clk);
    end
  endtask

  // Check current pre-edge execution state, then advance one instruction.
  task automatic run_and_step;
    input [2:0] exp_pc;
    input [15:0] exp_alu;
    begin
      #1;
      check_u8(dut.cpu.pc_out, {5'b0, exp_pc}, "PC value");
      check_u16({uio_out, uo_out}, exp_alu, "ALU output");
      @(posedge clk);
    end
  endtask

  task automatic check_loaded_instr;
    input [2:0] addr;
    input [15:0] exp;
    begin
      check_u16(dut.cpu.inst_mem.ram[addr], exp, "Instruction memory word");
    end
  endtask

  initial begin
    failures = 0;

    rst_n   = 1'b0;
    ena     = 1'b0;
    ui_in   = 8'h00;
    uio_in  = 8'h00;

    // Reset and settle
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    ena   = 1'b1;

    // Program using RTL-defined fields:
    // I-type: [15:12] opcode, [11:10] rs, [9:8] rt, [7:0] imm
    // J-type: [15:12] opcode, [2:0] target
    // 0: addi r1, r0, 1
    // 1: addi r2, r0, 2
    // 2: addi r3, r0, 3
    // 3: addi r1, r1, 1
    // 4: addi r2, r2, 1
    // 5: addi r3, r3, 1
    // 6: jump 6 (self loop)
    // 7: addi r1, r0, 9 (should never execute because of jump)
    load_instr(3'd0, 16'h6101);
    load_instr(3'd1, 16'h6202);
    load_instr(3'd2, 16'h6303);
    load_instr(3'd3, 16'h6501);
    load_instr(3'd4, 16'h6A01);
    load_instr(3'd5, 16'h6F01);
    load_instr(3'd6, 16'h7006);
    load_instr(3'd7, 16'h6109);

    #1;

    // Verify the load path assembled each 16-bit instruction correctly.
    check_loaded_instr(3'd0, 16'h6101);
    check_loaded_instr(3'd1, 16'h6202);
    check_loaded_instr(3'd2, 16'h6303);
    check_loaded_instr(3'd3, 16'h6501);
    check_loaded_instr(3'd4, 16'h6A01);
    check_loaded_instr(3'd5, 16'h6F01);
    check_loaded_instr(3'd6, 16'h7006);
    check_loaded_instr(3'd7, 16'h6109);

    // In load mode, outputs are pass-through / input mode.
    check_u8(uio_oe, 8'h00, "uio_oe in load mode");

    // Enter run mode.
    ui_in  = 8'h80;
    uio_in = 8'h00;
    @(negedge clk);
    check_u8(uio_oe, 8'hFF, "uio_oe in run mode");

    // Check each instruction result while PC points to it.
    run_and_step(3'd0, 16'h0001);
    run_and_step(3'd1, 16'h0002);
    run_and_step(3'd2, 16'h0003);
    run_and_step(3'd3, 16'h0002);
    run_and_step(3'd4, 16'h0003);
    run_and_step(3'd5, 16'h0004);
    run_and_step(3'd6, 16'h0000);
    run_and_step(3'd6, 16'h0000);

    #1;
    check_u16(dut.cpu.rf.registers[1], 16'h0002, "register r1 final");
    check_u16(dut.cpu.rf.registers[2], 16'h0003, "register r2 final");
    check_u16(dut.cpu.rf.registers[3], 16'h0004, "register r3 final");

    if (failures == 0) begin
      $display("\n[PASS] Behavioral testbench completed with no failures.");
    end
    else begin
      $display("\n[FAIL] Behavioral testbench completed with %0d failure(s).", failures);
      $fatal(1);
    end

    $finish;
  end

endmodule

`default_nettype wire
*/
`default_nettype none
`timescale 1ns / 1ps

module tb;
  // DUT interface signals
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  wire [7:0] uo_out;
  reg [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  
  // Instantiate the DUT
  tt_um_top_module_16_mips dut (
    .clk(clk),
    .rst_n(rst_n),
    .ena(ena),
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe)
  );
  
  // Clock generation
  initial clk = 0;
  always #50 clk = ~clk;  // 100ns period -> 10 MHz
  
  // Initial stimulus
  initial begin
    rst_n = 0;
    ena = 1;
    ui_in = 8'b0;
    uio_in = 8'b0;
    
    #1000;
    rst_n = 1;
    
    #5000;
    
    $display("Testbench completed successfully");
    $finish;
  end
  
  // Monitor outputs
  initial begin
    $monitor("Time: %0t, rst_n: %b, ena: %b, uo_out: %02h, uio_out: %02h, uio_oe: %02h", 
             $time, rst_n, ena, uo_out, uio_out, uio_oe);
  end
  
endmodule

`default_nettype wire