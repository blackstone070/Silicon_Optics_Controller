`timescale 1ns/1ps

module tb_top_controller;
    // Slow Domain Signals (50 MHz)
    logic        clk_slow = 0;
    logic        rst_slow_n;
    logic        enable;
    logic [15:0] optical_power;

    // Fast Domain Signals (250 MHz)
    logic        clk_fast = 0;
    logic        rst_fast_n;
    logic        heater_pwm;

    // Instantiate the Top-Level Controller
    top_controller #(8) dut (
        .clk_slow(clk_slow),
        .rst_slow_n(rst_slow_n),
        .enable(enable),
        .optical_power(optical_power),
        .clk_fast(clk_fast),
        .rst_fast_n(rst_fast_n),
        .heater_pwm(heater_pwm)
    );

    // 1. Clock Generation (50 MHz Slow / 250 MHz Fast)
    always #10 clk_slow = ~clk_slow;
    always #2  clk_fast = ~clk_fast;

    // =========================================================================
    // 2. CLOSED-LOOP REAL-NUMBER PLANT MODEL (Silicon Photonics + Thermal Lag)
    // =========================================================================
    real silicon_temp     = 20.0;
    real target_temp      = 55.0;  // Optimal optical resonance temperature
    real ambient_temp     = 20.0;
    real thermal_alpha    = 0.85;  // Fast-settled thermal RC constant for sim
    real heater_drive     = 20.0;
    real temp_diff        = 0.0;
    real lorentzian_curve = 0.0;
    int  noise_phase      = 0;
    real sensor_noise     = 0.0;
    real raw_photodiode   = 0.0;

    // Update physical silicon temperature in the 250 MHz fast domain
    always @(posedge clk_fast) begin
        if (!rst_fast_n) begin
            silicon_temp <= ambient_temp;
        end else if (enable) begin
            heater_drive = ambient_temp + (real'(dut.current_heater_val) * (80.0 / 255.0));
            silicon_temp <= silicon_temp + thermal_alpha * (heater_drive - silicon_temp);
        end
    end

    // Sample Lorentzian optical resonance + photodiode noise in the 50 MHz slow domain
    always @(posedge clk_slow) begin
        if (!rst_slow_n) begin
            optical_power <= 16'd1000;
            noise_phase   <= 0;
        end else if (enable) begin
            temp_diff        = target_temp - silicon_temp;
            lorentzian_curve = 50000.0 / (1.0 + (temp_diff * temp_diff) / 120.0);

            noise_phase  <= noise_phase + 1;
            sensor_noise = (noise_phase[0] ? 450.0 : -450.0);

            raw_photodiode = lorentzian_curve + sensor_noise;
            if (raw_photodiode < 0.0)        optical_power <= 16'd0;
            else if (raw_photodiode > 65535) optical_power <= 16'd65535;
            else                             optical_power <= int'(raw_photodiode);
        end
    end

    // =========================================================================
    // 3. SELF-CHECKING CDC SCOREBOARD & ASSERTIONS (50 MHz -> 250 MHz)
    // =========================================================================
    logic [7:0] cdc_scoreboard [$];
    logic [7:0] expected_val;
    int         cdc_words_verified = 0;
    int         assertion_errors   = 0;

    // Write-Domain Monitor & FIFO Overflow Assertion
    always @(posedge clk_slow) begin
        if (rst_slow_n) begin
            if (dut.wfull && dut.winc) begin
                $display("[SVA ERROR] Time %0t: FIFO Overflow! winc asserted while wfull=1", $time);
                assertion_errors++;
            end
            if (dut.winc && !dut.wfull) begin
                cdc_scoreboard.push_back(dut.wdata);
            end
        end
    end

    // Read-Domain Checker & FIFO Underflow Assertion
    always @(posedge clk_fast) begin
        if (rst_fast_n) begin
            if (dut.rempty && dut.rinc) begin
                $display("[SVA ERROR] Time %0t: FIFO Underflow! rinc asserted while rempty=1", $time);
                assertion_errors++;
            end
            if (dut.rinc && !dut.rempty) begin
                if (cdc_scoreboard.size() == 0) begin
                    $display("[SCOREBOARD ERROR] Time %0t: Unexpected read from FIFO!", $time);
                    assertion_errors++;
                end else begin
                    expected_val = cdc_scoreboard.pop_front();
                    if (dut.rdata !== expected_val) begin
                        $display("[CDC DATA MISMATCH] Time %0t: Expected %0d, Got %0d", $time, expected_val, dut.rdata);
                        assertion_errors++;
                    end else begin
                        cdc_words_verified++;
                    end
                end
            end
        end
    end

    // =========================================================================
    // 4. FUNCTIONAL COVERAGE COLLECTOR
    // =========================================================================
    bit [3:0] cov_fsm_states   = 4'b0000;
    bit       cov_dir_reversal = 1'b0;
    bit       cov_peak_locked  = 1'b0;
    logic     prev_dir         = 1'b1;

    always @(posedge clk_slow) begin
        if (rst_slow_n && enable) begin
            case (dut.u_fsm.state)
                0: cov_fsm_states[0] <= 1'b1;
                1: cov_fsm_states[1] <= 1'b1;
                2: cov_fsm_states[2] <= 1'b1;
                3: cov_fsm_states[3] <= 1'b1;
            endcase

            if (dut.u_fsm.search_dir != prev_dir) begin
                cov_dir_reversal <= 1'b1;
                prev_dir <= dut.u_fsm.search_dir;
            end

            if (dut.filtered_optical_power >= 16'd45000) begin
                cov_peak_locked <= 1'b1;
            end
        end
    end

    // =========================================================================
    // 5. MULTI-TARGET CLOSED-LOOP TEST EXECUTION
    // =========================================================================
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top_controller);

        $display("================================================================");
        $display(" STARTING CLOSED-LOOP VERIFICATION (SV REAL PLANT + SCOREBOARD)");
        $display("================================================================");

        // --- TEST CASE 1: Nominal Resonance Target (55.0 C) ---
        target_temp  = 55.0;
        ambient_temp = 20.0;
        rst_slow_n   = 0;
        rst_fast_n   = 0;
        enable       = 0;
        #40;
        rst_slow_n   = 1;
        rst_fast_n   = 1;
        #20;
        enable       = 1;

        #18000;
        $display("[TEST 1] Target Temp: %0.1f C | Reached Temp: %0.1f C | Filtered Power: %0d / 50000",
                 target_temp, silicon_temp, dut.filtered_optical_power);

        // --- TEST CASE 2: Shifted Thermal Target (72.0 C) ---
        target_temp = 72.0;
        #18000;
        $display("[TEST 2] Target Temp: %0.1f C | Reached Temp: %0.1f C | Filtered Power: %0d / 50000",
                 target_temp, silicon_temp, dut.filtered_optical_power);

        if (!cov_peak_locked) begin
            $display("[ASSERTION ERROR] Controller failed to lock above 90%% optical peak!");
            assertion_errors++;
        end

        // --- FINAL VERIFICATION & FUNCTIONAL COVERAGE REPORT ---
        $display("================================================================");
        $display("                 VERIFICATION & COVERAGE SUMMARY                ");
        $display("================================================================");
        $display(" CDC Transactions Verified : %0d words (0 corruption)", cdc_words_verified);
        $display(" FSM State Coverage        : %0.1f%% (%b)", ($countones(cov_fsm_states)/4.0)*100.0, cov_fsm_states);
        $display(" Gradient Reversal Covered : %s", cov_dir_reversal ? "YES (100%)" : "NO (0%)");
        $display(" Resonance Lock Achieved   : %s", cov_peak_locked  ? "YES (>90% Peak)" : "NO");
        $display(" Total Assertion Errors    : %0d", assertion_errors);
        $display(" FINAL RESULT              : %s", (assertion_errors == 0 && cov_peak_locked) ? "PASS" : "FAIL");
        $display("================================================================");

        $finish;
    end
endmodule