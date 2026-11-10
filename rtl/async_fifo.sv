module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4 // 2^4 = 16 slots deep
)(
    // Write Domain (FSM side - Slow Clock)
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,

    // Read Domain (Sigma-Delta side - Fast Clock)
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    
    // Memory Array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    logic [ADDR_WIDTH:0] wptr_bin, wptr_gray, wptr_gray_next, wptr_bin_next;
    logic [ADDR_WIDTH:0] rptr_bin, rptr_gray, rptr_gray_next, rptr_bin_next;
    
    // Synchronizers
    logic [ADDR_WIDTH:0] wq1_rptr, wq2_rptr; // Read pointer synchronized to write clock
    logic [ADDR_WIDTH:0] rq1_wptr, rq2_wptr; // Write pointer synchronized to read clock

    // --- WRITE DOMAIN ---
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
            if (winc && !wfull) mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
        end
    end

    assign wptr_bin_next  = wptr_bin + (winc & ~wfull);
    assign wptr_gray_next = (wptr_bin_next >> 1) ^ wptr_bin_next;
    
    // Write Full condition: Gray pointers match exactly except for the top two bits
    assign wfull = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});

    // --- READ DOMAIN ---
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    assign rptr_bin_next  = rptr_bin + (rinc & ~rempty);
    assign rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;
    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];
    
    // Read Empty condition: Gray pointers match exactly
    assign rempty = (rptr_gray_next == rq2_wptr);

    // --- CLOCK DOMAIN CROSSING SYNCHRONIZERS ---
    // Pass read pointer to write domain
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= '0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr_gray};
    end

    // Pass write pointer to read domain
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= '0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr_gray};
    end

endmodule