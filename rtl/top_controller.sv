module top_controller #(
    parameter DATA_WIDTH = 8
)(
    // Slow Clock Domain (FSM)
    input  logic        clk_slow,
    input  logic        rst_slow_n,
    input  logic        enable,
    input  logic [15:0] optical_power,

    // Fast Clock Domain (Sigma-Delta)
    input  logic        clk_fast,
    input  logic        rst_fast_n,
    
    // Output to Heater
    output logic        heater_pwm
);

    // Internal wires connecting the blocks
    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;
    
    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // 1. Control FSM (The Brain)
    fsm_controller #(DATA_WIDTH) u_fsm (
        .clk(clk_slow),
        .rst_n(rst_slow_n),
        .enable(enable),
        .optical_power(optical_power),
        .winc(winc),
        .wdata(wdata),
        .wfull(wfull)
    );

    // 2. Asynchronous FIFO (The Bridge)
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

    // 3. Sigma-Delta Modulator (The Heater Driver)
    // We only update the Sigma-Delta input when new data is pulled from the FIFO
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