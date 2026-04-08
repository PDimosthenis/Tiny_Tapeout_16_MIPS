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
