`timescale 1ns/1ps

module tb_top_controller;
    // Slow Domain Signals
    logic        clk_slow = 0;
    logic        rst_slow_n;
    logic        enable;
    logic [15:0] optical_power;

    // Fast Domain Signals
    logic        clk_fast = 0;
    logic        rst_fast_n;
    logic        heater_pwm;

    // Instantiate the Top-Level SoC
    top_controller #(8) dut (
        .clk_slow(clk_slow),
        .rst_slow_n(rst_slow_n),
        .enable(enable),
        .optical_power(optical_power),
        .clk_fast(clk_fast),
        .rst_fast_n(rst_fast_n),
        .heater_pwm(heater_pwm)
    );

    // Generate Clocks
    always #10 clk_slow = ~clk_slow; // 50 MHz FSM Clock
    always #2  clk_fast = ~clk_fast; // 250 MHz Sigma-Delta Clock

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top_controller);

        // 1. System Reset
        rst_slow_n = 0; 
        rst_fast_n = 0;
        enable = 0;
        optical_power = 16'd1000;
        #30;
        
        rst_slow_n = 1; 
        rst_fast_n = 1;
        #20;
        
        // 2. Enable the Control Loop
        enable = 1;

        // 3. Feed mock sensor data to watch the PWM output adapt
        #200; optical_power = 16'd1200; // Power increasing
        #200; optical_power = 16'd1500; // Power increasing
        #200; optical_power = 16'd1300; // Power dropped (passed peak)
        
        #500;
        $finish;
    end
endmodule