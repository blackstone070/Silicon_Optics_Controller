module top_controller #(
    parameter DATA_WIDTH  = 8,
    parameter FILTER_LOG2 = 2   // 2^2 = 4-sample moving average filter
)(
    // Slow Clock Domain (FSM & Filter)
    input  logic        clk_slow,
    input  logic        rst_slow_n,
    input  logic        enable,
    input  logic [15:0] optical_power,

    // Fast Clock Domain (Sigma-Delta)
    input  logic        clk_fast,
    input  logic        rst_fast_n,
    
    // Output to Heater (1-bit PDM stream)
    output logic        heater_pwm
);

    // Internal wires connecting the blocks
    logic [15:0]           filtered_optical_power;

    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;
    
    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // 0. Digital Low-Pass Filter (Moving Average for Photodiode Noise)
    moving_average #(
        .DATA_WIDTH(16),
        .WINDOW_LOG2(FILTER_LOG2)
    ) u_filter (
        .clk(clk_slow),
        .rst_n(rst_slow_n),
        .enable(enable),
        .din(optical_power),
        .dout(filtered_optical_power)
    );

    // 1. Control FSM (The Brain - now fed with filtered optical power)
    fsm_controller #(DATA_WIDTH) u_fsm (
        .clk(clk_slow),
        .rst_n(rst_slow_n),
        .enable(enable),
        .optical_power(filtered_optical_power),
        .winc(winc),
        .wdata(wdata),
        .wfull(wfull)
    );

    // 2. Asynchronous FIFO (The CDC Bridge)
    async_fifo #(DATA_WIDTH, 4) u_fifo (
        .wclk(clk_slow),
        .wrst_n(rst_slow_n),
        .winc(winc),
        .wdata(wdata),
        .wfull(wfull),
        
        .rclk(clk_fast),
        .rrst_n(rst_fast_n),
        .rinc(rinc),
        .rdata(rdata),
        .rempty(rempty)
    );

    // Continuous read from FIFO if not empty
    assign rinc = ~rempty;

    // 3. Sigma-Delta Modulator (The Heater PDM Driver)
    // Only update the Sigma-Delta input when new data is pulled from the FIFO
    logic [DATA_WIDTH-1:0] current_heater_val;
    always_ff @(posedge clk_fast or negedge rst_fast_n) begin
        if (!rst_fast_n) current_heater_val <= '0;
        else if (rinc)   current_heater_val <= rdata;
    end

    sigma_delta #(DATA_WIDTH) u_sigma_delta (
        .clk(clk_fast),
        .rst_n(rst_fast_n),
        .din(current_heater_val),
        .dout(heater_pwm)
    );

endmodule