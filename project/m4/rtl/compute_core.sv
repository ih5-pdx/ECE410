// =============================================================================
// Module:      compute_core
// Project:     Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:        compute_core.sv
// Description: Single-PE baseline compute core for matrix multiplication.
//              Computes one dot-product element at a time (one row of A dotted
//              with one column of B), accepting one INT8 operand pair per cycle.
//              Uses INT8 inputs with INT32 accumulation to preserve precision.
//
//              Scope note (M2): This module is a single multiply-accumulate
//              engine verified at up to MAX_DIM=8. The full 512x512 tiled
//              systolic-array architecture described in the Heilmeier Q3 is
//              the M3 target. M2 establishes the correct MAC kernel behavior
//              and synthesizable RTL baseline before scaling to a multi-PE
//              array with on-chip SRAM tile buffers in M3.
//
// Port List:
//   clk         - input,  1b   - System clock (rising-edge triggered)
//   rst_n       - input,  1b   - Active-low synchronous reset
//   start       - input,  1b   - Pulse high for 1 cycle to begin computation
//   a_data      - input,  8b   - Serialized input: row elements of matrix A
//   b_data      - input,  8b   - Serialized input: col elements of matrix B
//   a_valid     - input,  1b   - a_data is valid this cycle
//   b_valid     - input,  1b   - b_data is valid this cycle
//   dim         - input,  4b   - Matrix dimension N (1..MAX_DIM, square matrices)
//   result      - output, 32b  - Accumulated dot-product result (one element of C)
//   result_valid- output, 1b   - result holds a valid output element
//   busy        - output, 1b   - Core is actively computing; do not issue new start
//
// Clock Domain: Single clock domain (clk). No clock crossings.
// Reset:        Synchronous, active-low (rst_n). All registers clear on rst_n == 0.
// Arithmetic:   Signed 8-bit multiply, 32-bit signed accumulation (no overflow guard).
// Latency:      N cycles from first valid input pair to result_valid assertion.
// =============================================================================

module compute_core #(
    parameter int MAX_DIM = 8   // Maximum supported matrix dimension
)(
    input  logic        clk,
    input  logic        rst_n,      // Synchronous, active-low reset
    input  logic        start,
    input  logic signed [7:0]  a_data,
    input  logic signed [7:0]  b_data,
    input  logic        a_valid,
    input  logic        b_valid,
    input  logic [3:0]  dim,        // Matrix dimension N (square: NxN)
    output logic signed [31:0] result,
    output logic        result_valid,
    output logic        busy
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic signed [31:0] accumulator;
    logic [3:0]         count;          // Counts MAC operations within one dot product
    logic               computing;

    // -------------------------------------------------------------------------
    // MAC accumulator FSM
    // Single-state accumulation: shift in one (a,b) pair per cycle while valid.
    // result_valid pulses for one cycle when 'dim' MACs have completed.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            accumulator  <= 32'sd0;
            count        <= 4'd0;
            result       <= 32'sd0;
            result_valid <= 1'b0;
            busy         <= 1'b0;
            computing    <= 1'b0;
        end else begin
            result_valid <= 1'b0;   // default: deassert each cycle

            if (start && !computing) begin
                // Begin a new dot-product computation
                accumulator <= 32'sd0;
                count       <= 4'd0;
                computing   <= 1'b1;
                busy        <= 1'b1;
            end else if (computing && a_valid && b_valid) begin
                // Multiply-accumulate: a_data * b_data sign-extended to 32 bits
                accumulator <= accumulator + ({{24{a_data[7]}}, a_data} *
                                              {{24{b_data[7]}}, b_data});
                count <= count + 4'd1;

                if (count == dim - 4'd1) begin
                    // Last element of the dot product
                    result       <= accumulator + ({{24{a_data[7]}}, a_data} *
                                                   {{24{b_data[7]}}, b_data});
                    result_valid <= 1'b1;
                    computing    <= 1'b0;
                    busy         <= 1'b0;
                    count        <= 4'd0;
                end
            end
        end
    end

endmodule
