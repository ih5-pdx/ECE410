// =============================================================================
// Module:      compute_core (synth_top)
// Project:     Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:        synth_top.sv  (copy of projects/m2/rtl/compute_core.sv)
// Description: Single-PE baseline compute core for matrix multiplication.
//              Computes one dot-product element at a time.
//              INT8 inputs, INT32 accumulation.
// =============================================================================

module compute_core #(
    parameter int MAX_DIM = 8
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic signed [7:0]  a_data,
    input  logic signed [7:0]  b_data,
    input  logic        a_valid,
    input  logic        b_valid,
    input  logic [3:0]  dim,
    output logic signed [31:0] result,
    output logic        result_valid,
    output logic        busy
);

    logic signed [31:0] accumulator;
    logic [3:0]         count;
    logic               computing;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            accumulator  <= 32'sd0;
            count        <= 4'd0;
            result       <= 32'sd0;
            result_valid <= 1'b0;
            busy         <= 1'b0;
            computing    <= 1'b0;
        end else begin
            result_valid <= 1'b0;

            if (start && !computing) begin
                accumulator <= 32'sd0;
                count       <= 4'd0;
                computing   <= 1'b1;
                busy        <= 1'b1;
            end else if (computing && a_valid && b_valid) begin
                accumulator <= accumulator + ({{24{a_data[7]}}, a_data} *
                                              {{24{b_data[7]}}, b_data});
                count <= count + 4'd1;

                if (count == dim - 4'd1) begin
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
