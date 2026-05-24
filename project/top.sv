// =============================================================================
// Module:      top
// Project:     Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:        project/m3/rtl/top.sv
// Description: Integration top module for Milestone 3.
//              Instantiates the AXI4-Lite slave interface (interface.sv) and
//              the single-PE MAC compute core (compute_core.sv) and wires all
//              inter-module signals.  This is the synthesis boundary presented
//              to OpenLane 2.
//
//              Glue logic note:
//              interface.sv issues core_a_valid and core_b_valid as independent
//              one-cycle pulses (one per AXI write transaction).  compute_core
//              expects both valid signals asserted simultaneously on the same
//              cycle to perform a MAC.  A two-register synchronisation latch
//              inside top holds the A element until B arrives (or vice-versa),
//              then presents both to the core together.  The latch clears after
//              the joint pulse and also on reset.  This is the only glue logic
//              required between the two M2 modules; all other signals connect
//              point-to-point.
//
// External port list (AXI4-Lite slave + clock/reset):
//   clk           - input,  1b   - System clock (rising-edge triggered)
//   rst_n         - input,  1b   - Active-low synchronous reset (top-level)
//   -- AXI4-Lite write address channel --
//   s_awvalid     - input,  1b
//   s_awready     - output, 1b
//   s_awaddr      - input,  8b
//   -- AXI4-Lite write data channel --
//   s_wvalid      - input,  1b
//   s_wready      - output, 1b
//   s_wdata       - input,  32b
//   s_wstrb       - input,  4b
//   -- AXI4-Lite write response channel --
//   s_bvalid      - output, 1b
//   s_bready      - input,  1b
//   s_bresp       - output, 2b
//   -- AXI4-Lite read address channel --
//   s_arvalid     - input,  1b
//   s_arready     - output, 1b
//   s_araddr      - input,  8b
//   -- AXI4-Lite read data channel --
//   s_rvalid      - output, 1b
//   s_rready      - input,  1b
//   s_rdata       - output, 32b
//   s_rresp       - output, 2b
//
// Clock domain:  Single (clk).  Synchronous active-low reset throughout.
// Reset mapping: interface uses rst_n (active-low); compute_core uses rst_n.
// =============================================================================

module top #(
    parameter int MAX_DIM    = 8,
    parameter int ADDR_WIDTH = 8
)(
    input  logic        clk,
    input  logic        rst_n,

    // AXI4-Lite Write Address Channel
    input  logic        s_awvalid,
    output logic        s_awready,
    input  logic [ADDR_WIDTH-1:0] s_awaddr,

    // AXI4-Lite Write Data Channel
    input  logic        s_wvalid,
    output logic        s_wready,
    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,

    // AXI4-Lite Write Response Channel
    output logic        s_bvalid,
    input  logic        s_bready,
    output logic [1:0]  s_bresp,

    // AXI4-Lite Read Address Channel
    input  logic        s_arvalid,
    output logic        s_arready,
    input  logic [ADDR_WIDTH-1:0] s_araddr,

    // AXI4-Lite Read Data Channel
    output logic        s_rvalid,
    input  logic        s_rready,
    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp
);

    // -------------------------------------------------------------------------
    // Inter-module wires: interface → glue → compute_core
    // -------------------------------------------------------------------------
    logic signed [7:0]  raw_a_data;
    logic signed [7:0]  raw_b_data;
    logic               raw_a_valid;
    logic               raw_b_valid;
    logic               core_start;
    logic [3:0]         core_dim;
    logic signed [31:0] core_result;
    logic               core_result_v;
    logic               core_busy;

    // -------------------------------------------------------------------------
    // Glue: A/B valid-synchronisation latch
    // interface.sv writes A and B in separate AXI transactions, producing
    // independent one-cycle pulses.  compute_core needs both valids on the
    // same cycle.  Hold whichever arrives first; fire the joint pulse when
    // the second one lands.
    // -------------------------------------------------------------------------
    logic signed [7:0]  held_a;
    logic               a_held;
    logic signed [7:0]  held_b;
    logic               b_held;

    // Signals actually presented to compute_core
    logic signed [7:0]  core_a_data;
    logic signed [7:0]  core_b_data;
    logic               core_a_valid;
    logic               core_b_valid;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            held_a      <= 8'sd0;
            a_held      <= 1'b0;
            held_b      <= 8'sd0;
            b_held      <= 1'b0;
            core_a_data <= 8'sd0;
            core_b_data <= 8'sd0;
            core_a_valid <= 1'b0;
            core_b_valid <= 1'b0;
        end else begin
            // Default: deassert joint pulse
            core_a_valid <= 1'b0;
            core_b_valid <= 1'b0;

            // Latch incoming A
            if (raw_a_valid && !a_held) begin
                held_a <= raw_a_data;
                a_held <= 1'b1;
            end

            // Latch incoming B
            if (raw_b_valid && !b_held) begin
                held_b <= raw_b_data;
                b_held <= 1'b1;
            end

            // Fire joint pulse when both are ready
            if ((a_held || raw_a_valid) && (b_held || raw_b_valid)) begin
                core_a_data  <= a_held ? held_a : raw_a_data;
                core_b_data  <= b_held ? held_b : raw_b_data;
                core_a_valid <= 1'b1;
                core_b_valid <= 1'b1;
                a_held       <= 1'b0;
                b_held       <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite Interface instantiation
    // -------------------------------------------------------------------------
    interface #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_interface (
        .clk            (clk),
        .rst_n          (rst_n),

        .s_awvalid      (s_awvalid),
        .s_awready      (s_awready),
        .s_awaddr       (s_awaddr),

        .s_wvalid       (s_wvalid),
        .s_wready       (s_wready),
        .s_wdata        (s_wdata),
        .s_wstrb        (s_wstrb),

        .s_bvalid       (s_bvalid),
        .s_bready       (s_bready),
        .s_bresp        (s_bresp),

        .s_arvalid      (s_arvalid),
        .s_arready      (s_arready),
        .s_araddr       (s_araddr),

        .s_rvalid       (s_rvalid),
        .s_rready       (s_rready),
        .s_rdata        (s_rdata),
        .s_rresp        (s_rresp),

        // Core interface — raw (pre-glue) signals
        .core_a_data    (raw_a_data),
        .core_b_data    (raw_b_data),
        .core_a_valid   (raw_a_valid),
        .core_b_valid   (raw_b_valid),
        .core_start     (core_start),
        .core_dim       (core_dim),
        .core_result    (core_result),
        .core_result_v  (core_result_v),
        .core_busy      (core_busy)
    );

    // -------------------------------------------------------------------------
    // Compute Core instantiation
    // -------------------------------------------------------------------------
    compute_core #(
        .MAX_DIM(MAX_DIM)
    ) u_compute_core (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (core_start),
        .a_data         (core_a_data),
        .b_data         (core_b_data),
        .a_valid        (core_a_valid),
        .b_valid        (core_b_valid),
        .dim            (core_dim),
        .result         (core_result),
        .result_valid   (core_result_v),
        .busy           (core_busy)
    );

endmodule
