// mac_correct.v — Corrected synthesizable SystemVerilog MAC module
// Fixes applied vs LLM outputs:
//   1. (vs LLM A) product is combinational, not registered — removed intermediate
//      registered `product` flop so accumulation is correct in one cycle, not two.
//      Also added explicit 32-bit sign extension of the 16-bit product.
//   2. (vs LLM B) corrected reset polarity (active-high, not active-low);
//      replaced always @(posedge clk) with always_ff; replaced wire/reg with logic.

module mac (
    input  logic        clk,
    input  logic        rst,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [31:0] out
);

    // Compute signed 16-bit product combinationally, sign-extend to 32 bits
    logic signed [15:0] product;
    assign product = a * b;

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + 32'(signed'(product));
        end
    end

endmodule
