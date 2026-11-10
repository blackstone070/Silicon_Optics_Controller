`timescale 1ns/1ps

module tb_async_fifo;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    
    // Testbench signals
    logic                  wclk = 0;
    logic                  wrst_n;
    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;
    
    logic                  rclk = 0;
    logic                  rrst_n;
    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // Instantiate the Hardware (Device Under Test)
    async_fifo #(DATA_WIDTH, ADDR_WIDTH) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
    );

    // --- CLOCK GENERATION ---
    // The FSM writes data slowly (20ns period = 50 MHz)
    always #10 wclk = ~wclk; 
    // The Sigma-Delta reads data quickly (4ns period = 250 MHz)
    always #2  rclk = ~rclk; 

    // --- TEST SEQUENCE ---
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_async_fifo);

        // 1. Initialize & Reset
        wrst_n = 0; rrst_n = 0;
        winc = 0; wdata = 0; rinc = 0;
        #30; 
        wrst_n = 1; rrst_n = 1;
        #20;

        // 2. Slow FSM Write (Write the value '8' into the FIFO)
        @(posedge wclk);
        winc = 1; wdata = 8'd8;
        @(posedge wclk);
        winc = 0;

        // Wait a bit to let the Gray codes synchronize across clock domains
        #50;

        // 3. Fast Sigma-Delta Read (Pull the value out of the FIFO)
        @(posedge rclk);
        rinc = 1;
        @(posedge rclk);
        rinc = 0;
        
        // Wait to observe the output
        #50;
        
        $finish;
    end
endmodule