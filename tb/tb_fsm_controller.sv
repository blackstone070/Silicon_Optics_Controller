`timescale 1ns/1ps

module tb_fsm_controller;
    // Testbench signals
    logic        clk = 0;
    logic        rst_n;
    logic        enable;
    logic [15:0] optical_power;
    logic        winc;
    logic [7:0]  wdata;
    logic        wfull;

    // Instantiate the FSM
    fsm_controller #(8) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .optical_power(optical_power),
        .winc(winc),
        .wdata(wdata),
        .wfull(wfull)
    );

    // Generate FSM clock (50 MHz)
    always #10 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fsm_controller);

        // 1. Initialize
        rst_n = 0;
        enable = 0;
        optical_power = 16'd1000; // Baseline power
        wfull = 0; // FIFO is not full
        #25; 
        rst_n = 1;

        // 2. Enable FSM
        #20; 
        enable = 1;

        // 3. Simulate Hill Climbing
        // The FSM starts at heater value 128 and increments. 
        // We will fake the sensor readings to see if it responds correctly.
        
        #80; 
        optical_power = 16'd1200; // Power went UP (FSM should keep increasing heater)
        
        #80; 
        optical_power = 16'd1500; // Power went UP (FSM should keep increasing)
        
        #80; 
        optical_power = 16'd1400; // Power went DOWN! We passed the peak. 
                                  // FSM should reverse direction and decrease heater.
                                  
        #80; 
        optical_power = 16'd1450; // Power goes UP again in the new direction.

        #100;
        $finish;
    end
endmodule