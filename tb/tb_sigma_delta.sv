`timescale 1ns/1ps

module tb_sigma_delta;
    parameter WIDTH = 8;
    
    // Testbench signals
    logic             clk;
    logic             rst_n;
    logic [WIDTH-1:0] din;
    logic             dout;

    // Instantiate the Hardware (Device Under Test)
    sigma_delta #(WIDTH) dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(dout)
    );

    // Generate a clock signal (toggles every 5 nanoseconds)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Apply the test stimulus
    initial begin
        // Tell the simulator to record the waveforms so we can view them
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sigma_delta);

        // 1. System Reset
        rst_n = 0;
        din = 8'd0;
        #20; // Wait 20 nanoseconds
        rst_n = 1;

        // 2. Test Low Power (Value: 25/255 -> ~10% pulse density)
        din = 8'd25;
        #200;

        // 3. Test Half Power (Value: 128/255 -> ~50% pulse density)
        din = 8'd128;
        #200;

        // 4. Test High Power (Value: 230/255 -> ~90% pulse density)
        din = 8'd230;
        #200;

        // End simulation
        $finish;
    end
endmodule