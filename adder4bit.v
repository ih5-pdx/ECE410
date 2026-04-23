// 4-bit ripple-carry adder with carry-out
// Adds two 4-bit operands A and B along with a carry-in Cin.
// Produces a 4-bit Sum and a 1-bit carry-out Cout.
module adder4bit (
    input  [3:0] A,     // 4-bit operand A
    input  [3:0] B,     // 4-bit operand B
    input        Cin,   // carry-in
    output [3:0] Sum,   // 4-bit sum
    output       Cout   // carry-out
);

    // The concatenation {Cout, Sum} captures the full 5-bit result,
    // propagating the carry out of bit 3 naturally.
    assign {Cout, Sum} = A + B + Cin;

endmodule
