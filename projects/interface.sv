// =============================================================================
// Module:      interface
// Project:     Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
// File:        interface.sv
// Description: AXI4-Lite slave interface bridging the host CPU to the
//              compute_core. The host writes matrix elements and control
//              registers over AXI4-Lite; the core result is read back via
//              a status/result register.
//
// Port List (AXI4-Lite Slave):
//   clk           - input,  1b   - System clock
//   rst_n         - input,  1b   - Active-low synchronous reset
//   -- Write address channel --
//   s_awvalid     - input,  1b   - Write address valid
//   s_awready     - output, 1b   - Write address ready
//   s_awaddr      - input,  8b   - Write address (byte-addressed, 256B space)
//   -- Write data channel --
//   s_wvalid      - input,  1b   - Write data valid
//   s_wready      - output, 1b   - Write data ready
//   s_wdata       - input,  32b  - Write data
//   s_wstrb       - input,  4b   - Byte strobes
//   -- Write response channel --
//   s_bvalid      - output, 1b   - Write response valid
//   s_bready      - input,  1b   - Write response ready
//   s_bresp       - output, 2b   - Response: 2'b00=OKAY
//   -- Read address channel --
//   s_arvalid     - input,  1b   - Read address valid
//   s_arready     - output, 1b   - Read address ready
//   s_araddr      - input,  8b   - Read address
//   -- Read data channel --
//   s_rvalid      - output, 1b   - Read data valid
//   s_rready      - input,  1b   - Read data ready
//   s_rdata       - output, 32b  - Read data
//   s_rresp       - output, 2b   - Response: 2'b00=OKAY
//   -- Core interface --
//   core_a_data   - output, 8b   - Matrix A element to compute_core
//   core_b_data   - output, 8b   - Matrix B element to compute_core
//   core_a_valid  - output, 1b   - a_data valid
//   core_b_valid  - output, 1b   - b_data valid
//   core_start    - output, 1b   - Start pulse to compute_core
//   core_dim      - output, 4b   - Dimension register to compute_core
//   core_result   - input,  32b  - Result from compute_core
//   core_result_v - input,  1b   - Result valid from compute_core
//   core_busy     - input,  1b   - Core busy signal
//
// Clock Domain: Single (clk). Synchronous active-low reset (rst_n).
//
// Register Map (byte address, 32-bit aligned):
//   0x00  CTRL       WO  [0]=START pulse, [4:1]=DIM (matrix dimension)
//   0x04  A_DATA     WO  [7:0]=matrix A element (INT8, sign-extended)
//   0x08  B_DATA     WO  [7:0]=matrix B element (INT8, sign-extended)
//   0x0C  STATUS     RO  [0]=BUSY, [1]=RESULT_VALID
//   0x10  RESULT     RO  [31:0]=accumulated dot-product result (INT32)
//
// AXI4-Lite handshake: AWVALID+WVALID must be presented before AWREADY+WREADY
// are asserted. This implementation accepts address and data independently
// and completes the write once both are received. BRESP is always OKAY (2'b00).
// =============================================================================

module interface #(
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
    output logic [1:0]  s_rresp,

    // Compute core interface
    output logic signed [7:0] core_a_data,
    output logic signed [7:0] core_b_data,
    output logic        core_a_valid,
    output logic        core_b_valid,
    output logic        core_start,
    output logic [3:0]  core_dim,
    input  logic signed [31:0] core_result,
    input  logic        core_result_v,
    input  logic        core_busy
);

    // -------------------------------------------------------------------------
    // Register Map addresses (byte-addressed)
    // -------------------------------------------------------------------------
    localparam logic [7:0] ADDR_CTRL   = 8'h00;
    localparam logic [7:0] ADDR_A_DATA = 8'h04;
    localparam logic [7:0] ADDR_B_DATA = 8'h08;
    localparam logic [7:0] ADDR_STATUS = 8'h0C;
    localparam logic [7:0] ADDR_RESULT = 8'h10;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] aw_addr_reg;
    logic                  aw_addr_valid;   // address phase captured
    logic [31:0]           w_data_reg;
    logic                  w_data_valid;    // data phase captured
    logic [3:0]            dim_reg;
    logic signed [31:0]    result_reg;
    logic                  result_valid_reg;

    // -------------------------------------------------------------------------
    // Write address channel
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aw_addr_reg   <= '0;
            aw_addr_valid <= 1'b0;
            s_awready     <= 1'b0;
        end else begin
            s_awready <= 1'b0;
            if (s_awvalid && !aw_addr_valid) begin
                aw_addr_reg   <= s_awaddr;
                aw_addr_valid <= 1'b1;
                s_awready     <= 1'b1;
            end else if (aw_addr_valid && w_data_valid) begin
                aw_addr_valid <= 1'b0;  // consumed
            end
        end
    end

    // -------------------------------------------------------------------------
    // Write data channel
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            w_data_reg   <= '0;
            w_data_valid <= 1'b0;
            s_wready     <= 1'b0;
        end else begin
            s_wready <= 1'b0;
            if (s_wvalid && !w_data_valid) begin
                w_data_reg   <= s_wdata;
                w_data_valid <= 1'b1;
                s_wready     <= 1'b1;
            end else if (aw_addr_valid && w_data_valid) begin
                w_data_valid <= 1'b0;  // consumed
            end
        end
    end

    // -------------------------------------------------------------------------
    // Write response channel + register write logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_bvalid     <= 1'b0;
            s_bresp      <= 2'b00;
            dim_reg      <= 4'd4;
            core_a_data  <= 8'sd0;
            core_b_data  <= 8'sd0;
            core_a_valid <= 1'b0;
            core_b_valid <= 1'b0;
            core_start   <= 1'b0;
        end else begin
            core_start   <= 1'b0;
            core_a_valid <= 1'b0;
            core_b_valid <= 1'b0;

            if (s_bvalid && s_bready) begin
                s_bvalid <= 1'b0;
            end

            if (aw_addr_valid && w_data_valid && !s_bvalid) begin
                // Decode register write
                case (aw_addr_reg)
                    ADDR_CTRL: begin
                        dim_reg    <= w_data_reg[4:1];
                        core_start <= w_data_reg[0];
                    end
                    ADDR_A_DATA: begin
                        core_a_data  <= w_data_reg[7:0];
                        core_a_valid <= 1'b1;
                    end
                    ADDR_B_DATA: begin
                        core_b_data  <= w_data_reg[7:0];
                        core_b_valid <= 1'b1;
                    end
                    default: ; // ignore writes to RO registers
                endcase
                s_bvalid <= 1'b1;
                s_bresp  <= 2'b00; // OKAY
            end
        end
    end

    // Drive core_dim combinatorially from register
    assign core_dim = dim_reg;

    // -------------------------------------------------------------------------
    // Latch result from core
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            result_reg       <= 32'sd0;
            result_valid_reg <= 1'b0;
        end else begin
            if (core_result_v) begin
                result_reg       <= core_result;
                result_valid_reg <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Read address channel
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'h0;
            s_rresp   <= 2'b00;
        end else begin
            s_arready <= 1'b0;

            if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end

            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1'b1;
                s_rvalid  <= 1'b1;
                s_rresp   <= 2'b00;
                case (s_araddr)
                    ADDR_STATUS: s_rdata <= {30'b0, result_valid_reg, core_busy};
                    ADDR_RESULT: s_rdata <= result_reg;
                    default:     s_rdata <= 32'hDEAD_BEEF; // undefined address
                endcase
            end
        end
    end

endmodule
