module fsm_controller #(
    parameter DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    
    // Sensor Input (Optical Power reading)
    input  logic [15:0]           optical_power,
    
    // Output to Async FIFO
    output logic                  winc,
    output logic [DATA_WIDTH-1:0] wdata,
    input  logic                  wfull
);

    // FSM States
    typedef enum logic [1:0] {
        IDLE, 
        MEASURE, 
        ADJUST, 
        WRITE_FIFO
    } state_t;
    
    state_t state, next_state;

    // Registers to track the hill-climbing algorithm
    logic [15:0]           prev_power;
    logic [DATA_WIDTH-1:0] current_heater;
    logic                  search_dir; // 1 = increase heat, 0 = decrease heat

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            prev_power     <= '0;
            current_heater <= 8'd128; // Start at 50% power
            search_dir     <= 1'b1;
            winc           <= 1'b0;
            wdata          <= '0;
        end else begin
            winc <= 1'b0; // Default to not writing
            
            case (state)
                IDLE: begin
                    if (enable) state <= MEASURE;
                end
                
                MEASURE: begin
                    // Compare current power to previous power
                    if (optical_power < prev_power) begin
                        // We went down the hill. Reverse direction.
                        search_dir <= ~search_dir;
                    end
                    prev_power <= optical_power;
                    state      <= ADJUST;
                end
                
                ADJUST: begin
                    // Step the heater power up or down
                    if (search_dir && current_heater < 255)
                        current_heater <= current_heater + 1;
                    else if (!search_dir && current_heater > 0)
                        current_heater <= current_heater - 1;
                        
                    state <= WRITE_FIFO;
                end
                
                WRITE_FIFO: begin
                    // Send the new heater value to the FIFO safely
                    if (!wfull) begin
                        wdata <= current_heater;
                        winc  <= 1'b1;
                        state <= MEASURE;
                    end
                end
            endcase
        end
    end

endmodule