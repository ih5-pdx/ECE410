// =============================================================================
// Testbench: tb_top  (Milestone 4 — Final)
// Project:   Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:      project/m4/tb/tb_top.sv
// Simulator: Icarus Verilog 12 (iverilog -g2012)
//
// Description:
//   End-to-end co-simulation of the integrated top module.
//   Two test cases:
//     Test 1: A=[3,-1,2,5]  · B=[4,7,-3,1]   => expected  4
//     Test 2: A=[-2,-3,-1,-4] · B=[1,2,3,4]  => expected -27
//   Both use the full AXI4-Lite transaction sequence:
//     CTRL write → N pair writes (A_DATA, B_DATA) → STATUS poll → RESULT read
//
// Reproduce:
//   cd project/m4
//   iverilog -g2012 -o sim/tb_top.out tb/tb_top.sv rtl/top.sv rtl/axi_slave.sv rtl/compute_core.sv
//   vvp sim/tb_top.out | tee sim/final_run.log
// =============================================================================
`timescale 1ns/1ps

module tb_top;

    localparam int CLK_PERIOD     = 10;
    localparam int TIMEOUT_CYCLES = 2000;

    localparam logic [7:0] ADDR_CTRL   = 8'h00;
    localparam logic [7:0] ADDR_A_DATA = 8'h04;
    localparam logic [7:0] ADDR_B_DATA = 8'h08;
    localparam logic [7:0] ADDR_STATUS = 8'h0C;
    localparam logic [7:0] ADDR_RESULT = 8'h10;

    logic        clk, rst_n;
    logic        s_awvalid, s_awready;
    logic [7:0]  s_awaddr;
    logic        s_wvalid,  s_wready;
    logic [31:0] s_wdata;
    logic [3:0]  s_wstrb;
    logic        s_bvalid,  s_bready;
    logic [1:0]  s_bresp;
    logic        s_arvalid, s_arready;
    logic [7:0]  s_araddr;
    logic        s_rvalid,  s_rready;
    logic [31:0] s_rdata;
    logic [1:0]  s_rresp;

    top #(.MAX_DIM(8), .ADDR_WIDTH(8)) dut (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr),
        .s_wvalid(s_wvalid),   .s_wready(s_wready),   .s_wdata(s_wdata), .s_wstrb(s_wstrb),
        .s_bvalid(s_bvalid),   .s_bready(s_bready),   .s_bresp(s_bresp),
        .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr),
        .s_rvalid(s_rvalid),   .s_rready(s_rready),   .s_rdata(s_rdata), .s_rresp(s_rresp)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int cyc_cnt;
    initial cyc_cnt = 0;
    always @(posedge clk) begin
        cyc_cnt <= cyc_cnt + 1;
        if (cyc_cnt > TIMEOUT_CYCLES) begin
            $display("FAIL: Global timeout after %0d cycles", TIMEOUT_CYCLES);
            $finish;
        end
    end

    // AXI write task
    task automatic axi_write(input logic [7:0] addr, input logic [31:0] data);
        s_awvalid = 1; s_awaddr = addr;
        s_wvalid  = 1; s_wdata  = data; s_wstrb = 4'hF;
        @(posedge clk);
        while (!s_awready || !s_wready) @(posedge clk);
        #1; s_awvalid = 0; s_wvalid = 0;
        s_bready = 1;
        @(posedge clk);
        while (!s_bvalid) @(posedge clk);
        #1; s_bready = 0;
    endtask

    // AXI read task
    task automatic axi_read(input logic [7:0] addr, output logic [31:0] rdata);
        s_arvalid = 1; s_araddr = addr;
        @(posedge clk);
        while (!s_arready) @(posedge clk);
        #1; s_arvalid = 0;
        s_rready = 1;
        @(posedge clk);
        while (!s_rvalid) @(posedge clk);
        #1; rdata = s_rdata; s_rready = 0;
    endtask

    // Do reset
    task do_reset();
        rst_n = 1'b0;
        repeat(3) @(posedge clk); #1;
        rst_n = 1'b1;
        repeat(2) @(posedge clk); #1;
    endtask

    logic [31:0] status_val, result_val;
    logic signed [7:0] a_elem, b_elem;
    int poll_cnt;

    // Test 1 vectors: [3,-1,2,5] · [4,7,-3,1] = 4
    logic signed [7:0] a1_0, a1_1, a1_2, a1_3;
    logic signed [7:0] b1_0, b1_1, b1_2, b1_3;

    // Test 2 vectors: [-2,-3,-1,-4] · [1,2,3,4] = -27
    logic signed [7:0] a2_0, a2_1, a2_2, a2_3;
    logic signed [7:0] b2_0, b2_1, b2_2, b2_3;

    initial begin
        $dumpfile("sim/final_waveform.vcd");
        $dumpvars(0, tb_top);

        // Set test vectors
        a1_0 =  8'sd3;  a1_1 = -8'sd1;  a1_2 =  8'sd2;  a1_3 =  8'sd5;
        b1_0 =  8'sd4;  b1_1 =  8'sd7;  b1_2 = -8'sd3;  b1_3 =  8'sd1;
        a2_0 = -8'sd2;  a2_1 = -8'sd3;  a2_2 = -8'sd1;  a2_3 = -8'sd4;
        b2_0 =  8'sd1;  b2_1 =  8'sd2;  b2_2 =  8'sd3;  b2_3 =  8'sd4;

        // Initialize AXI signals
        s_awvalid=0; s_awaddr='0;
        s_wvalid=0; s_wdata='0; s_wstrb=4'hF;
        s_bready=0; s_arvalid=0; s_araddr='0; s_rready=0;

        $display("=== M4 Final Simulation — tb_top ===");
        $display("=== Matrix Multiply Co-Processor Chiplet, ECE 410/510 S2026 ===");
        $display("");

        // =====================================================================
        // TEST 1: A=[3,-1,2,5] · B=[4,7,-3,1] = 4
        // =====================================================================
        $display("[TB] === Test1_N4_mixed : dim=4, expected=4 ===");
        do_reset();

        // Write CTRL: DIM=4 (bits[4:1]=4'b0100), START=1 (bit0) => 0x09
        $display("[TB] Phase 1: Write CTRL = 0x00000009 (DIM=4, START=1)");
        axi_write(ADDR_CTRL, 32'h00000009);

        // Stream 4 element pairs
        $display("[TB] Phase 2: Streaming 4 element pairs");
        $display("[TB]   pair[0]: a=3  b=4");
        axi_write(ADDR_A_DATA, {{24{a1_0[7]}}, a1_0});
        axi_write(ADDR_B_DATA, {{24{b1_0[7]}}, b1_0});
        $display("[TB]   pair[1]: a=-1  b=7");
        axi_write(ADDR_A_DATA, {{24{a1_1[7]}}, a1_1});
        axi_write(ADDR_B_DATA, {{24{b1_1[7]}}, b1_1});
        $display("[TB]   pair[2]: a=2  b=-3");
        axi_write(ADDR_A_DATA, {{24{a1_2[7]}}, a1_2});
        axi_write(ADDR_B_DATA, {{24{b1_2[7]}}, b1_2});
        $display("[TB]   pair[3]: a=5  b=1");
        axi_write(ADDR_A_DATA, {{24{a1_3[7]}}, a1_3});
        axi_write(ADDR_B_DATA, {{24{b1_3[7]}}, b1_3});

        // Poll STATUS
        $display("[TB] Phase 3: Polling STATUS for result_valid");
        status_val = 32'h0; poll_cnt = 0;
        while (!status_val[1]) begin
            axi_read(ADDR_STATUS, status_val);
            poll_cnt = poll_cnt + 1;
            if (poll_cnt > 200) begin
                $display("FAIL: Test1 STATUS poll timeout");
                $finish;
            end
        end
        $display("[TB] STATUS=0x%08x  result_valid=%0b  busy=%0b",
                 status_val, status_val[1], status_val[0]);

        // Read result
        $display("[TB] Phase 4: Reading RESULT register");
        axi_read(ADDR_RESULT, result_val);
        if ($signed(result_val) === 32'sd4)
            $display("PASS: [Test1_N4_mixed] result = %0d (expected 4)", $signed(result_val));
        else
            $display("FAIL: [Test1_N4_mixed] result = %0d (expected 4)", $signed(result_val));
        $display("");

        // =====================================================================
        // TEST 2: A=[-2,-3,-1,-4] · B=[1,2,3,4] = -27
        // =====================================================================
        $display("[TB] === Test2_N4_negative : dim=4, expected=-27 ===");
        do_reset();

        $display("[TB] Phase 1: Write CTRL = 0x00000009 (DIM=4, START=1)");
        axi_write(ADDR_CTRL, 32'h00000009);

        $display("[TB] Phase 2: Streaming 4 element pairs");
        $display("[TB]   pair[0]: a=-2  b=1");
        axi_write(ADDR_A_DATA, {{24{a2_0[7]}}, a2_0});
        axi_write(ADDR_B_DATA, {{24{b2_0[7]}}, b2_0});
        $display("[TB]   pair[1]: a=-3  b=2");
        axi_write(ADDR_A_DATA, {{24{a2_1[7]}}, a2_1});
        axi_write(ADDR_B_DATA, {{24{b2_1[7]}}, b2_1});
        $display("[TB]   pair[2]: a=-1  b=3");
        axi_write(ADDR_A_DATA, {{24{a2_2[7]}}, a2_2});
        axi_write(ADDR_B_DATA, {{24{b2_2[7]}}, b2_2});
        $display("[TB]   pair[3]: a=-4  b=4");
        axi_write(ADDR_A_DATA, {{24{a2_3[7]}}, a2_3});
        axi_write(ADDR_B_DATA, {{24{b2_3[7]}}, b2_3});

        $display("[TB] Phase 3: Polling STATUS for result_valid");
        status_val = 32'h0; poll_cnt = 0;
        while (!status_val[1]) begin
            axi_read(ADDR_STATUS, status_val);
            poll_cnt = poll_cnt + 1;
            if (poll_cnt > 200) begin
                $display("FAIL: Test2 STATUS poll timeout");
                $finish;
            end
        end
        $display("[TB] STATUS=0x%08x  result_valid=%0b  busy=%0b",
                 status_val, status_val[1], status_val[0]);

        $display("[TB] Phase 4: Reading RESULT register");
        axi_read(ADDR_RESULT, result_val);
        if ($signed(result_val) === -32'sd27)
            $display("PASS: [Test2_N4_negative] result = %0d (expected -27)", $signed(result_val));
        else
            $display("FAIL: [Test2_N4_negative] result = %0d (expected -27)", $signed(result_val));
        $display("");

        $display("=== All tests complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
