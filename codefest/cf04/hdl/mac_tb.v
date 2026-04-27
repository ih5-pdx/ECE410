// mac_tb.v — Testbench for mac module
// Test sequence:
//   1. Apply a=3, b=4 for 3 cycles  → accumulates 3*4=12 each cycle
//   2. Assert rst for 1 cycle        → out resets to 0
//   3. Apply a=-5, b=2 for 2 cycles  → accumulates -5*2=-10 each cycle

`timescale 1ns/1ps

module mac_tb;

    logic        clk;
    logic        rst;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] out;

    // Instantiate DUT
    mac dut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .out(out)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;

    task check(input signed [31:0] expected, input string label);
        if (out !== expected) begin
            $display("FAIL  [%s] cycle=%0t  out=%0d  expected=%0d", label, $time, out, expected);
            errors++;
        end else begin
            $display("PASS  [%s] cycle=%0t  out=%0d", label, $time, out);
        end
    endtask

    initial begin
        // Initialise
        rst = 1; a = 8'sd0; b = 8'sd0;
        @(posedge clk); #1;          // cycle 0: reset
        check(32'sd0, "rst_init");

        rst = 0;
        a = 8'sd3; b = 8'sd4;

        @(posedge clk); #1;          // cycle 1: out = 0 + 12 = 12
        check(32'sd12, "cycle1 a=3 b=4");

        @(posedge clk); #1;          // cycle 2: out = 12 + 12 = 24
        check(32'sd24, "cycle2 a=3 b=4");

        @(posedge clk); #1;          // cycle 3: out = 24 + 12 = 36
        check(32'sd36, "cycle3 a=3 b=4");

        // Assert reset
        rst = 1;
        @(posedge clk); #1;          // cycle 4: out = 0
        check(32'sd0, "rst_asserted");

        // Negative product
        rst = 0;
        a = -8'sd5; b = 8'sd2;

        @(posedge clk); #1;          // cycle 5: out = 0 + (-10) = -10
        check(-32'sd10, "cycle5 a=-5 b=2");

        @(posedge clk); #1;          // cycle 6: out = -10 + (-10) = -20
        check(-32'sd20, "cycle6 a=-5 b=2");

        $display("");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
