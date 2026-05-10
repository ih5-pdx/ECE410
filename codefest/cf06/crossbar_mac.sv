// =============================================================================
// Module:      crossbar_mac
// Generated:   Claude Sonnet 4.6 (claude-sonnet-4-20250514)
// Project:     4×4 Binary-Weight Crossbar MAC Unit
// File:        codefest/cf06/hdl/crossbar_mac.sv
//
// Description:
//   Implements a 4×4 resistive crossbar multiply-accumulate (MAC) unit with
//   binary ±1 weights stored in a 4×4 register array. Each clock cycle
//   computes the matrix-vector product:
//
//       out[j] = Σ_i  weight[i][j] × in[i]    for j = 0..3
//
//   Weights are signed 2-bit values encoded as +1 (2'sb01) or −1 (2'sb11).
//   Inputs are signed 8-bit integers. Outputs are signed 32-bit accumulators
//   wide enough to hold any 4-element dot product of INT8 inputs with ±1
//   weights without overflow (max |out| = 4 × 128 = 512).
//
// Port List:
//   clk          - input  1b   Rising-edge triggered
//   rst_n        - input  1b   Active-low synchronous reset
//   load_weights - input  1b   When high, latch wr_weight into weight[wr_row][wr_col]
//   wr_row       - input  2b   Weight write row address (0..3)
//   wr_col       - input  2b   Weight write column address (0..3)
//   wr_weight    - input  2b   Signed ±1 value to write (2'sb01=+1, 2'sb11=−1)
//   in_valid     - input  1b   Input vector is valid; latch and compute this cycle
//   data_in      - input  32b  Packed input vector: {in[3],in[2],in[1],in[0]}, each 8b signed
//   out_valid    - output 1b   Output vector is valid (registered, one cycle after in_valid)
//   data_out     - output 128b Packed output: {out[3],out[2],out[1],out[0]}, each 32b signed
//
// Encoding:
//   data_in[7:0]   = in[0], data_in[15:8]  = in[1],
//   data_in[23:16] = in[2], data_in[31:24] = in[3]
//   data_out[31:0]   = out[0], data_out[63:32]  = out[1],
//   data_out[95:64]  = out[2], data_out[127:96] = out[3]
//
// Latency: 1 cycle (out_valid asserted one cycle after in_valid)
// Reset:   Synchronous active-low; clears outputs and weight array.
// =============================================================================

module crossbar_mac (
    input  logic        clk,
    input  logic        rst_n,

    // Weight programming interface
    input  logic        load_weights,
    input  logic [1:0]  wr_row,
    input  logic [1:0]  wr_col,
    input  logic signed [1:0] wr_weight,   // 2'sb01=+1, 2'sb11=-1

    // Data interface
    input  logic        in_valid,
    input  logic [31:0] data_in,            // packed: {in[3],in[2],in[1],in[0]}

    output logic        out_valid,
    output logic [127:0] data_out           // packed: {out[3],out[2],out[1],out[0]}
);

    // -------------------------------------------------------------------------
    // Weight register array: weight[row][col], signed 2-bit ±1
    // -------------------------------------------------------------------------
    logic signed [1:0] weight [0:3][0:3];

    // -------------------------------------------------------------------------
    // Unpack input vector
    // -------------------------------------------------------------------------
    logic signed [7:0] vec_in [0:3];
    assign vec_in[0] = $signed(data_in[7:0]);
    assign vec_in[1] = $signed(data_in[15:8]);
    assign vec_in[2] = $signed(data_in[23:16]);
    assign vec_in[3] = $signed(data_in[31:24]);

    // -------------------------------------------------------------------------
    // Combinational crossbar: compute out[j] = Σ_i weight[i][j] × in[i]
    // Each product: signed 2-bit × signed 8-bit → signed 9-bit
    // Sum of 4 terms: signed 11-bit (safe), widened to 32-bit for output
    // -------------------------------------------------------------------------
    logic signed [31:0] mac_result [0:3];

    always_comb begin
        for (int j = 0; j < 4; j++) begin
            mac_result[j] = 32'sd0;
            for (int i = 0; i < 4; i++) begin
                mac_result[j] = mac_result[j] + (32'(signed'(weight[i][j])) *
                                                  32'(signed'(vec_in[i])));
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output register — latch result one cycle after in_valid
    // -------------------------------------------------------------------------
    logic signed [31:0] out_reg [0:3];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            for (int j = 0; j < 4; j++)
                out_reg[j] <= 32'sd0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                for (int j = 0; j < 4; j++)
                    out_reg[j] <= mac_result[j];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Weight programming — synchronous write
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int r = 0; r < 4; r++)
                for (int c = 0; c < 4; c++)
                    weight[r][c] <= 2'sb01;  // default: all +1
        end else if (load_weights) begin
            weight[wr_row][wr_col] <= wr_weight;
        end
    end

    // -------------------------------------------------------------------------
    // Pack output vector
    // -------------------------------------------------------------------------
    assign data_out[31:0]   = out_reg[0];
    assign data_out[63:32]  = out_reg[1];
    assign data_out[95:64]  = out_reg[2];
    assign data_out[127:96] = out_reg[3];

endmodule
