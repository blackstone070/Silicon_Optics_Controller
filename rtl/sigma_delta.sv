module sigma_delta #(
    parameter WIDTH = 8 // 8-bit input allows heater power levels from 0 to 255
)(
    input  logic             clk,
    input  logic             rst_n, // Active-low reset
    input  logic [WIDTH-1:0] din,   // The multi-bit heater power command
    output logic             dout   // The 1-bit high-speed pulse output
);

    // We make the accumulator 1 bit wider than the input to catch the overflow (the carry bit)
    logic [WIDTH:0] accumulator;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
            dout        <= 1'b0;
        end else begin
            // Add the input to the accumulator's lower bits every clock cycle
            accumulator <= accumulator[WIDTH-1:0] + din;
            
            // The output is simply the overflow bit. 
            // A higher 'din' causes overflows more often, creating more '1' pulses.
            dout        <= accumulator[WIDTH];
        end
    end

endmodule