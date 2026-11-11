module moving_average #(
    parameter DATA_WIDTH  = 16,
    parameter WINDOW_LOG2 = 2   // 2^2 = 4-sample moving average window
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    localparam WINDOW_SIZE = 1 << WINDOW_LOG2;

    // Shift register pipeline to store the last N samples
    logic [DATA_WIDTH-1:0] samples [0:WINDOW_SIZE-1];
    
    // Accumulator widened by WINDOW_LOG2 bits to prevent addition overflow
    logic [DATA_WIDTH+WINDOW_LOG2-1:0] running_sum;

    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum <= '0;
            for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                samples[i] <= '0;
            end
        end else if (enable) begin
            // Subtract oldest sample and add newest sample in O(1) hardware time
            running_sum <= running_sum - samples[WINDOW_SIZE-1] + din;
            
            // Shift the sample pipeline
            samples[0] <= din;
            for (i = 1; i < WINDOW_SIZE; i = i + 1) begin
                samples[i] <= samples[i-1];
            end
        end
    end

    // Divide by WINDOW_SIZE using a hardware right-shift
    assign dout = running_sum[DATA_WIDTH+WINDOW_LOG2-1 : WINDOW_LOG2];

endmodule