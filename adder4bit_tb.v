// Testbench for the 4-bit adder with carry-out
`timescale 1ns/1ps

module adder4bit_tb;

    // Inputs driven as regs
    reg  [3:0] A;
    reg  [3:0] B;
    reg        Cin;

    // Outputs observed as wires
    wire [3:0] Sum;
    wire       Cout;

    // Track pass/fail counts
    integer pass_count;
    integer fail_count;

    // Instantiate the design under test
    adder4bit uut (
        .A   (A),
        .B   (B),
        .Cin (Cin),
        .Sum (Sum),
        .Cout(Cout)
    );

    // Task to apply inputs, wait, and check results
    task check;
        input [3:0] a_in;
        input [3:0] b_in;
        input       cin_in;
        input [3:0] expected_sum;
        input       expected_cout;
        begin
            A   = a_in;
            B   = b_in;
            Cin = cin_in;
            #10;  // allow combinational logic to settle

            if (Sum === expected_sum && Cout === expected_cout) begin
                $display("PASS | A=%0d B=%0d Cin=%0d | Sum=%0d Cout=%0d",
                         A, B, Cin, Sum, Cout);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL | A=%0d B=%0d Cin=%0d | Expected Sum=%0d Cout=%0d | Got Sum=%0d Cout=%0d",
                         A, B, Cin, expected_sum, expected_cout, Sum, Cout);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("=== 4-bit Adder Testbench ===");
        $display("%-6s %-6s %-6s | %-6s %-6s", "A", "B", "Cin", "Sum", "Cout");
        $display("--------------------------------------");

        // ------------------------------------------------------------------
        // Edge / boundary cases
        // ------------------------------------------------------------------
        // 0 + 0 + 0 = 0, Cout=0
        check(4'd0,  4'd0,  1'b0, 4'd0,  1'b0);
        // 0 + 0 + 1 = 1, Cout=0
        check(4'd0,  4'd0,  1'b1, 4'd1,  1'b0);
        // max + 0 + 0 = 15, Cout=0
        check(4'd15, 4'd0,  1'b0, 4'd15, 1'b0);
        // 0 + max + 0 = 15, Cout=0
        check(4'd0,  4'd15, 1'b0, 4'd15, 1'b0);
        // max + max + 0 = 14, Cout=1  (15+15=30 => 4'b1110, Cout=1)
        check(4'd15, 4'd15, 1'b0, 4'd14, 1'b1);
        // max + max + 1 = 15, Cout=1  (15+15+1=31 => 4'b1111, Cout=1)
        check(4'd15, 4'd15, 1'b1, 4'd15, 1'b1);
        // Carry-out triggered: 8+8=16 => Sum=0, Cout=1
        check(4'd8,  4'd8,  1'b0, 4'd0,  1'b1);
        // Carry-out triggered with Cin: 7+8+1=16 => Sum=0, Cout=1
        check(4'd7,  4'd8,  1'b1, 4'd0,  1'b1);

        // ------------------------------------------------------------------
        // Typical / intermediate cases
        // ------------------------------------------------------------------
        check(4'd3,  4'd5,  1'b0, 4'd8,  1'b0);
        check(4'd6,  4'd7,  1'b1, 4'd14, 1'b0);
        check(4'd9,  4'd6,  1'b0, 4'd15, 1'b0);
        check(4'd10, 4'd5,  1'b1, 4'd0,  1'b1);
        check(4'd1,  4'd1,  1'b1, 4'd3,  1'b0);
        check(4'd12, 4'd3,  1'b0, 4'd15, 1'b0);
        check(4'd12, 4'd4,  1'b0, 4'd0,  1'b1);
        check(4'd11, 4'd11, 1'b0, 4'd6,  1'b1);

        // ------------------------------------------------------------------
        // Exhaustive spot-check across different magnitudes
        // ------------------------------------------------------------------
        check(4'd2,  4'd13, 1'b0, 4'd15, 1'b0);
        check(4'd2,  4'd14, 1'b0, 4'd0,  1'b1);
        check(4'd7,  4'd7,  1'b1, 4'd15, 1'b0);
        check(4'd8,  4'd7,  1'b1, 4'd0,  1'b1);

        $display("--------------------------------------");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
