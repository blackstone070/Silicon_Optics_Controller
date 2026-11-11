`timescale 1ns/1ps

module fsm_controller #(
    parameter DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    input  logic [15:0]           optical_power,
    output logic                  winc,
    output logic [DATA_WIDTH-1:0] wdata,
    input  logic                  wfull
);

    typedef enum logic [1:0] {
        IDLE, 
        MEASURE, 
        ADJUST, 
        WRITE_FIFO
    } state_t;
    
    state_t state;

    logic [15:0]           prev_power;
    logic [DATA_WIDTH-1:0] current_heater;
    logic                  search_dir;
    logic [2:0]            settle_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            prev_power     <= '0;
            current_heater <= 8'd128;
            search_dir     <= 1'b1;
            winc           <= 1'b0;
            wdata          <= '0;
            settle_cnt     <= '0;
        end else begin
            winc <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (enable) state <= MEASURE;
                end
                
                MEASURE: begin
                    if (optical_power < prev_power) begin
                        search_dir <= ~search_dir;
                    end
                    prev_power <= optical_power;
                    state      <= ADJUST;
                end
                
                ADJUST: begin
                    if (search_dir && current_heater < 255)
                        current_heater <= current_heater + 1;
                    else if (!search_dir && current_heater > 0)
                        current_heater <= current_heater - 1;
                        
                    settle_cnt <= '0;
                    state      <= WRITE_FIFO;
                end
                
                WRITE_FIFO: begin
                    if (settle_cnt == 3'd0) begin
                        if (!wfull) begin
                            wdata      <= current_heater;
                            winc       <= 1'b1;
                            settle_cnt <= 3'd1;
                        end
                    end else if (settle_cnt < 3'd6) begin
                        settle_cnt <= settle_cnt + 3'd1;
                    end else begin
                        settle_cnt <= 3'd0;
                        state      <= MEASURE;
                    end
                end
            endcase
        end
    end

endmodule