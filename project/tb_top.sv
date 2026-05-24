`timescale 1ns/1ps
module tb_top;
    localparam int CLK_PERIOD     = 10;
    localparam int TIMEOUT_CYCLES = 500;
    localparam int DIM            = 4;
    localparam signed [31:0] EXPECTED = 32'sd4;

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

    logic signed [7:0] a_vec [0:DIM-1];
    logic signed [7:0] b_vec [0:DIM-1];
    initial begin
        a_vec[0] =  8'sd3; a_vec[1] = -8'sd1; a_vec[2] =  8'sd2; a_vec[3] =  8'sd5;
        b_vec[0] =  8'sd4; b_vec[1] =  8'sd7; b_vec[2] = -8'sd3; b_vec[3] =  8'sd1;
    end

    int cyc; logic timed_out;
    initial begin cyc=0; timed_out=0; end
    always @(posedge clk) begin
        cyc<=cyc+1;
        if (cyc>TIMEOUT_CYCLES) begin
            $display("FAIL: Timeout after %0d cycles", TIMEOUT_CYCLES);
            $finish;
        end
    end

    task axi_write(input logic [7:0] addr, input logic [31:0] data);
        s_awvalid=1; s_awaddr=addr; s_wvalid=1; s_wdata=data; s_wstrb=4'hF;
        // Wait for both handshakes (may arrive same cycle)
        fork
            begin : aw @(posedge clk); while (!s_awready) @(posedge clk); #1; s_awvalid=0; end
            begin : dw @(posedge clk); while (!s_wready)  @(posedge clk); #1; s_wvalid=0;  end
        join
        s_bready=1;
        @(posedge clk); while (!s_bvalid) @(posedge clk); #1;
        s_bready=0;
    endtask

    task axi_read(input logic [7:0] addr, output logic [31:0] rdata);
        s_arvalid=1; s_araddr=addr;
        @(posedge clk); while (!s_arready) @(posedge clk); #1; s_arvalid=0;
        s_rready=1;
        @(posedge clk); while (!s_rvalid) @(posedge clk); #1;
        rdata=s_rdata; s_rready=0;
    endtask

    logic [31:0] rd_val;
    integer i, poll_cnt;

    initial begin
        $dumpfile("sim/cosim_run.vcd");
        $dumpvars(0, tb_top);

        rst_n=0; s_awvalid=0; s_awaddr=0; s_wvalid=0; s_wdata=0; s_wstrb=4'hF;
        s_bready=0; s_arvalid=0; s_araddr=0; s_rready=0;

        repeat(3) @(posedge clk); #1;
        rst_n=1;
        repeat(2) @(posedge clk); #1;

        // Phase 1: Write CTRL — DIM=4, START=1 => data=0x09
        $display("[TB] Phase 1: Write CTRL (DIM=4, START=1)");
        axi_write(ADDR_CTRL, 32'h00000009);
        repeat(2) @(posedge clk); #1;

        // Phase 2: Stream 4 element pairs via A_DATA / B_DATA registers
        $display("[TB] Phase 2: Streaming %0d element pairs", DIM);
        for (i=0; i<DIM; i=i+1) begin
            axi_write(ADDR_A_DATA, {{24{a_vec[i][7]}}, a_vec[i]});
            axi_write(ADDR_B_DATA, {{24{b_vec[i][7]}}, b_vec[i]});
            $display("[TB]   pair[%0d]: a=%0d  b=%0d", i, $signed(a_vec[i]), $signed(b_vec[i]));
            @(posedge clk); #1;
        end

        // Phase 3: Poll STATUS until result_valid (bit[1])
        $display("[TB] Phase 3: Polling STATUS for result_valid");
        poll_cnt=0; rd_val=0;
        while (!rd_val[1]) begin
            axi_read(ADDR_STATUS, rd_val);
            poll_cnt=poll_cnt+1;
            if (poll_cnt>100) begin
                $display("FAIL: STATUS.result_valid never set after %0d polls", poll_cnt);
                $finish;
            end
        end
        $display("[TB] STATUS=0x%08X  result_valid=%0b  busy=%0b", rd_val, rd_val[1], rd_val[0]);

        // Phase 4: Read RESULT
        $display("[TB] Phase 4: Reading RESULT register");
        axi_read(ADDR_RESULT, rd_val);
        if ($signed(rd_val) === EXPECTED)
            $display("PASS: result = %0d (expected %0d)", $signed(rd_val), EXPECTED);
        else
            $display("FAIL: result = %0d (expected %0d)", $signed(rd_val), EXPECTED);

        @(posedge clk); #1;
        axi_read(ADDR_STATUS, rd_val);
        if (rd_val[0] !== 1'b0)
            $display("FAIL: busy still asserted after completion");
        else
            $display("[TB] busy correctly deasserted");

        #(CLK_PERIOD*10);
        $finish;
    end
endmodule
