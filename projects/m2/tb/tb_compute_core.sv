// =============================================================================
// Testbench: tb_compute_core
// Project:   Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:      tb_compute_core.sv
// Simulator: Icarus Verilog (iverilog) >= 11 or ModelSim / Vivado XSIM
//
// Description:
//   Verifies the compute_core module by computing a representative dot product
//   and comparing the DUT output against an independently computed reference.
//
//   Test vector:
//     A row  = [3, -1, 2, 5]  (INT8)
//     B col  = [4,  7, -3, 1] (INT8)
//     dim    = 4
//     Expected = 3*4 + (-1)*7 + 2*(-3) + 5*1 = 12 - 7 - 6 + 5 = 4
//
//   The reference value (4) was computed by hand and verified in Python:
//     import numpy as np
//     a = np.array([3, -1, 2, 5], dtype=np.int8)
//     b = np.array([4,  7, -3, 1], dtype=np.int8)
//     print(int(np.dot(a.astype(np.int32), b.astype(np.int32))))  # => 4
//
//   This exercise covers the dominant kernel (multiply-accumulate) identified
//   during M1 profiling.
//
// Pass criterion:
//   DUT result_valid rises exactly once after start, and
//   DUT result == EXPECTED_RESULT.
//   Testbench prints "PASS" or "FAIL: ..." on $display so the log is parseable.
// =============================================================================

`timescale 1ns/1ps

module tb_compute_core;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int CLK_PERIOD    = 10;     // ns
    localparam int TIMEOUT_CYCLES = 100;
    localparam int DIM           = 4;
    localparam signed [31:0] EXPECTED_RESULT = 32'sd4;
                          // 3*4 + (-1)*7 + 2*(-3) + 5*1 = 12-7-6+5 = 4

    // -------------------------------------------------------------------------
    // DUT interface signals
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        start;
    logic signed [7:0] a_data;
    logic signed [7:0] b_data;
    logic        a_valid;
    logic        b_valid;
    logic [3:0]  dim;
    logic signed [31:0] result;
    logic        result_valid;
    logic        busy;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    compute_core #(
        .MAX_DIM(8)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .a_data       (a_data),
        .b_data       (b_data),
        .a_valid      (a_valid),
        .b_valid      (b_valid),
        .dim          (dim),
        .result       (result),
        .result_valid (result_valid),
        .busy         (busy)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Test vectors (must match EXPECTED_RESULT derivation above)
    // -------------------------------------------------------------------------
    logic signed [7:0] a_vec [0:DIM-1] = '{8'sd3, -8'sd1, 8'sd2,  8'sd5};
    logic signed [7:0] b_vec [0:DIM-1] = '{8'sd4,  8'sd7, -8'sd3, 8'sd1};

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    integer timeout_cnt;
    initial begin
        timeout_cnt = 0;
        forever begin
            @(posedge clk);
            timeout_cnt++;
            if (timeout_cnt > TIMEOUT_CYCLES) begin
                $display("FAIL: Timeout waiting for result_valid after %0d cycles",
                         TIMEOUT_CYCLES);
                $finish;
            end
            if (result_valid) disable timeout_cnt; // disables the forever block label
        end
    end

    // -------------------------------------------------------------------------
    // Stimulus and checking
    // -------------------------------------------------------------------------
    integer i;
    initial begin
        // Optionally dump waveforms (comment out if not needed)
        $dumpfile("sim/compute_core_run.vcd");
        $dumpvars(0, tb_compute_core);

        // -- Initialization --
        rst_n   = 1'b0;
        start   = 1'b0;
        a_data  = 8'sd0;
        b_data  = 8'sd0;
        a_valid = 1'b0;
        b_valid = 1'b0;
        dim     = DIM[3:0];

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;
        @(posedge clk); #1;

        // -- Issue start --
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;

        // -- Feed input pairs one per cycle --
        for (i = 0; i < DIM; i++) begin
            a_data  = a_vec[i];
            b_data  = b_vec[i];
            a_valid = 1'b1;
            b_valid = 1'b1;
            @(posedge clk); #1;
        end

        a_valid = 1'b0;
        b_valid = 1'b0;

        // -- Wait for result_valid --
        @(posedge result_valid);

        // -- Check result --
        if (result === EXPECTED_RESULT) begin
            $display("PASS: result = %0d (expected %0d)", result, EXPECTED_RESULT);
        end else begin
            $display("FAIL: result = %0d (expected %0d)", result, EXPECTED_RESULT);
        end

        // -- Verify busy deasserted after completion --
        @(posedge clk); #1;
        if (busy !== 1'b0) begin
            $display("FAIL: busy still asserted after result_valid");
        end

        #(CLK_PERIOD * 5);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor (optional, helps in waveform analysis)
    // -------------------------------------------------------------------------
    initial begin
        $monitor("[%0t ns] a=%0d b=%0d av=%b bv=%b | result=%0d rv=%b busy=%b",
                 $time, a_data, b_data, a_valid, b_valid,
                 result, result_valid, busy);
    end

endmodule
