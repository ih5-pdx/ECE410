// =============================================================================
// Testbench: crossbar_tb
// File:      codefest/cf06/hdl/crossbar_tb.sv
// Simulator: Icarus Verilog (iverilog -g2012) >= 11
//
// Test vector:
//   Weight matrix W[i][j] (row=input i, col=output j):
//     W = [[ 1, -1,  1, -1],    i=0
//          [ 1,  1, -1, -1],    i=1
//          [-1,  1,  1, -1],    i=2
//          [-1, -1, -1,  1]]    i=3
//
//   Input vector: in = [10, 20, 30, 40]
//
//   Hand-calculated expected outputs:
//     out[0] =  1*10 +  1*20 + (-1)*30 + (-1)*40 = 10+20-30-40 = -40
//     out[1] = (-1)*10 + 1*20 +  1*30  + (-1)*40 = -10+20+30-40 =   0
//     out[2] =  1*10 + (-1)*20 +  1*30 + (-1)*40 = 10-20+30-40 =  -20
//     out[3] = (-1)*10 + (-1)*20 + (-1)*30 + 1*40 = -10-20-30+40 = -20
//
// Pass criterion: DUT outputs match expected values exactly.
// =============================================================================

`timescale 1ns/1ps

module crossbar_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int CLK_PERIOD    = 10;
    localparam int TIMEOUT_CYCLES = 50;

    // Weight encoding
    localparam logic signed [1:0] POS = 2'sb01;   // +1
    localparam logic signed [1:0] NEG = 2'sb11;   // -1

    // Expected results (hand-calculated)
    localparam signed [31:0] EXP0 = -32'sd40;
    localparam signed [31:0] EXP1 =  32'sd0;
    localparam signed [31:0] EXP2 = -32'sd20;
    localparam signed [31:0] EXP3 = -32'sd20;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk, rst_n;
    logic        load_weights;
    logic [1:0]  wr_row, wr_col;
    logic signed [1:0] wr_weight;
    logic        in_valid;
    logic [31:0] data_in;
    logic        out_valid;
    logic [127:0] data_out;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    crossbar_mac dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_weights (load_weights),
        .wr_row       (wr_row),
        .wr_col       (wr_col),
        .wr_weight    (wr_weight),
        .in_valid     (in_valid),
        .data_in      (data_in),
        .out_valid    (out_valid),
        .data_out     (data_out)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper task: write one weight
    // -------------------------------------------------------------------------
    task automatic write_weight(
        input logic [1:0]       row,
        input logic [1:0]       col,
        input logic signed [1:0] wt
    );
        @(posedge clk); #1;
        load_weights = 1'b1;
        wr_row       = row;
        wr_col       = col;
        wr_weight    = wt;
        @(posedge clk); #1;
        load_weights = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    integer cyc = 0;
    always @(posedge clk) begin
        cyc++;
        if (cyc > TIMEOUT_CYCLES) begin
            $display("FAIL: Timeout — out_valid never asserted");
            $finish;
        end
    end

    // -------------------------------------------------------------------------
    // Unpack output helper
    // -------------------------------------------------------------------------
    function automatic signed [31:0] get_out(input [127:0] d, input int j);
        return $signed(d[j*32 +: 32]);
    endfunction

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    initial begin
        $dumpfile("sim/crossbar_run.vcd");
        $dumpvars(0, crossbar_tb);

        // -- Initialise --
        rst_n        = 1'b0;
        load_weights = 1'b0;
        in_valid     = 1'b0;
        data_in      = 32'h0;
        wr_row = 0; wr_col = 0; wr_weight = POS;

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;
        @(posedge clk); #1;

        // =====================================================================
        // Phase 1: Program weight matrix row by row
        //   W = [[ 1,-1, 1,-1],   i=0
        //        [ 1, 1,-1,-1],   i=1
        //        [-1, 1, 1,-1],   i=2
        //        [-1,-1,-1, 1]]   i=3
        // =====================================================================
        $display("--- Phase 1: Loading weight matrix ---");

        // Row 0: [ 1, -1,  1, -1]
        write_weight(0, 0, POS); write_weight(0, 1, NEG);
        write_weight(0, 2, POS); write_weight(0, 3, NEG);
        // Row 1: [ 1,  1, -1, -1]
        write_weight(1, 0, POS); write_weight(1, 1, POS);
        write_weight(1, 2, NEG); write_weight(1, 3, NEG);
        // Row 2: [-1,  1,  1, -1]
        write_weight(2, 0, NEG); write_weight(2, 1, POS);
        write_weight(2, 2, POS); write_weight(2, 3, NEG);
        // Row 3: [-1, -1, -1,  1]
        write_weight(3, 0, NEG); write_weight(3, 1, NEG);
        write_weight(3, 2, NEG); write_weight(3, 3, POS);

        $display("Weights loaded.");

        // =====================================================================
        // Phase 2: Apply input vector [10, 20, 30, 40]
        //   data_in = {in[3]=40, in[2]=30, in[1]=20, in[0]=10}
        // =====================================================================
        $display("--- Phase 2: Applying input [10, 20, 30, 40] ---");

        @(posedge clk); #1;
        data_in  = {8'sd40, 8'sd30, 8'sd20, 8'sd10};  // [31:24]=40,[23:16]=30,[15:8]=20,[7:0]=10
        in_valid = 1'b1;
        @(posedge clk); #1;
        in_valid = 1'b0;

        // =====================================================================
        // Phase 3: Wait for out_valid and check results
        // =====================================================================
        @(posedge clk); // out_valid registered; result available 1 cycle after in_valid

        $display("--- Phase 3: Checking outputs ---");
        $display("  out[0] = %0d  (expected %0d) %s",
            $signed(get_out(data_out, 0)), EXP0,
            ($signed(get_out(data_out, 0)) === EXP0) ? "PASS" : "FAIL");
        $display("  out[1] = %0d  (expected %0d) %s",
            $signed(get_out(data_out, 1)), EXP1,
            ($signed(get_out(data_out, 1)) === EXP1) ? "PASS" : "FAIL");
        $display("  out[2] = %0d  (expected %0d) %s",
            $signed(get_out(data_out, 2)), EXP2,
            ($signed(get_out(data_out, 2)) === EXP2) ? "PASS" : "FAIL");
        $display("  out[3] = %0d  (expected %0d) %s",
            $signed(get_out(data_out, 3)), EXP3,
            ($signed(get_out(data_out, 3)) === EXP3) ? "PASS" : "FAIL");

        if ($signed(get_out(data_out, 0)) === EXP0) pass_cnt++; else fail_cnt++;
        if ($signed(get_out(data_out, 1)) === EXP1) pass_cnt++; else fail_cnt++;
        if ($signed(get_out(data_out, 2)) === EXP2) pass_cnt++; else fail_cnt++;
        if ($signed(get_out(data_out, 3)) === EXP3) pass_cnt++; else fail_cnt++;

        $display("");
        if (fail_cnt == 0)
            $display("ALL %0d TESTS PASSED", pass_cnt);
        else
            $display("%0d TESTS FAILED, %0d PASSED", fail_cnt, pass_cnt);

        #(CLK_PERIOD * 5);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor — use intermediate nets for iverilog compatibility
    // -------------------------------------------------------------------------
    wire signed [31:0] mon0 = data_out[31:0];
    wire signed [31:0] mon1 = data_out[63:32];
    wire signed [31:0] mon2 = data_out[95:64];
    wire signed [31:0] mon3 = data_out[127:96];

    initial begin
        $monitor("[%0t ns] in_valid=%b out_valid=%b | out={%0d,%0d,%0d,%0d}",
            $time, in_valid, out_valid, mon0, mon1, mon2, mon3);
    end

endmodule
