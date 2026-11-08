// SPDX-License-Identifier: GPL-3.0-or-later

module raiden_sdram2_ddrhost #(
	parameter DEVICE_FAMILY = "Cyclone 10 LP",
	parameter [9:0] RFRSH_CYCLES = 10'd500
)(
	input             clk,
	input             init,

	ddr_if.from_host  ddr,

	inout      [15:0] SDRAM_DQ,
	output reg [12:0] SDRAM_A,
	output reg        SDRAM_DQML,
	output reg        SDRAM_DQMH,
	output reg  [1:0] SDRAM_BA,
	output            SDRAM_nCS,
	output reg        SDRAM_nWE,
	output reg        SDRAM_nRAS,
	output reg        SDRAM_nCAS,
	output            SDRAM_CLK,
	output            SDRAM_CKE
);

localparam [12:0] MODE = {3'b000, 1'b1, 2'b00, 3'd3, 1'b0, 3'b010};

localparam [2:0] CMD_NOP   = 3'b111, CMD_ACT = 3'b011, CMD_READ = 3'b101,
                 CMD_WRITE = 3'b100, CMD_PRE = 3'b010, CMD_REF  = 3'b001,
                 CMD_MRS   = 3'b000;

assign SDRAM_nCS = 1'b0;
assign SDRAM_CKE = 1'b1;

reg  [15:0] dq_out;
reg         dq_oe;
assign SDRAM_DQ = dq_oe ? dq_out : 16'hZZZZ;
reg  [15:0] dq_in;
always @(posedge clk) dq_in <= SDRAM_DQ;

localparam [2:0] S_INIT = 3'd0, S_IDLE = 3'd1, S_ACT = 3'd2, S_RW = 3'd3,
                 S_RD   = 3'd4, S_WAIT = 3'd5;

reg  [2:0]  st       = S_INIT;
reg  [13:0] init_cnt = 14'd0;
reg  [9:0]  rfs_cnt  = 10'd0;
reg  [3:0]  wcnt;
reg  [2:0]  rcnt;
reg         op_we;
reg  [23:0] op_w;
reg  [15:0] op_d;
reg  [7:0]  beats_left;
reg  [63:0] rbuf;
reg         rdy_pulse = 1'b0;

assign ddr.busy        = (st != S_IDLE) & ~rdy_pulse;
assign ddr.rdata       = rbuf;
assign ddr.rdata_ready = rdy_pulse;

wire [1:0] wr_lane = (|ddr.byteenable[1:0]) ? 2'd0 :
                     (|ddr.byteenable[3:2]) ? 2'd1 :
                     (|ddr.byteenable[5:4]) ? 2'd2 : 2'd3;

always @(posedge clk) begin
	{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
	dq_oe     <= 1'b0;
	rdy_pulse <= 1'b0;
	if (rfs_cnt != 10'h3FF) rfs_cnt <= rfs_cnt + 10'd1;

	if (init) begin
		st       <= S_INIT;
		init_cnt <= 14'd0;
		{SDRAM_DQMH, SDRAM_DQML} <= 2'b11;
	end else case (st)

	S_INIT: begin
		init_cnt <= init_cnt + 14'd1;
		{SDRAM_DQMH, SDRAM_DQML} <= 2'b11;
		case (init_cnt)
			14'd9000: begin {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRE; SDRAM_A <= 13'h0400; end
			14'd9010, 14'd9020, 14'd9030, 14'd9040,
			14'd9050, 14'd9060, 14'd9070, 14'd9080:
			          {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REF;
			14'd9090: begin {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_MRS; SDRAM_A <= MODE; SDRAM_BA <= 2'b00; end
			14'd9100: begin st <= S_IDLE; rfs_cnt <= 10'd0; end
			default: ;
		endcase
	end

	S_IDLE: begin
		if (ddr.read | ddr.write) begin
			op_we      <= ddr.write & ~ddr.read;
			op_w       <= ddr.write ? {ddr.addr[24:3], wr_lane} : {ddr.addr[24:3], 2'b00};
			op_d       <= ddr.wdata[{wr_lane, 4'b0000} +: 16];
			beats_left <= (ddr.burstcnt == 8'd0) ? 8'd1 : ddr.burstcnt;
			st         <= S_ACT;
		end else if (rfs_cnt >= RFRSH_CYCLES) begin
			{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REF;
			rfs_cnt <= 10'd0;
			wcnt    <= 4'd8;
			st      <= S_WAIT;
		end
	end

	S_ACT: begin
		{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACT;
		SDRAM_A  <= op_w[22:10];
		SDRAM_BA <= {1'b0, op_w[23]};
		wcnt     <= 4'd0;
		st       <= S_RW;
	end

	S_RW: begin
		if (wcnt == 4'd0) wcnt <= 4'd1;
		else begin
			SDRAM_A  <= {2'b00, 1'b1, op_w[9:0]};
			SDRAM_BA <= {1'b0, op_w[23]};
			if (op_we) begin
				{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_WRITE;
				{SDRAM_DQMH, SDRAM_DQML} <= 2'b00;
				dq_out <= op_d;
				dq_oe  <= 1'b1;
				wcnt   <= 4'd6;
				st     <= S_WAIT;
			end else begin
				{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;
				{SDRAM_DQMH, SDRAM_DQML} <= 2'b00;
				rcnt <= 3'd0;
				st   <= S_RD;
			end
		end
	end

	S_RD: begin
		rcnt <= rcnt + 3'd1;
		case (rcnt)
			3'd4: rbuf[15:0]  <= dq_in;
			3'd5: rbuf[31:16] <= dq_in;
			3'd6: rbuf[47:32] <= dq_in;
			3'd7: begin
				rbuf[63:48] <= dq_in;
				rdy_pulse   <= 1'b1;
				if (beats_left > 8'd1) begin
					beats_left <= beats_left - 8'd1;
					op_w       <= op_w + 24'd4;
					st         <= S_ACT;
				end else
					st <= S_IDLE;
			end
			default: ;
		endcase
	end

	S_WAIT: begin
		if (wcnt != 4'd0) wcnt <= wcnt - 4'd1;
		else st <= S_IDLE;
	end

	default: st <= S_IDLE;
	endcase
end

`ifdef SIMULATION
assign SDRAM_CLK = ~clk;
`else
altddio_out #(
	.extend_oe_disable("OFF"), .intended_device_family(DEVICE_FAMILY),
	.invert_output("OFF"), .lpm_hint("UNUSED"), .lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"), .power_up_high("OFF"), .width(1)
) sdram2clk_ddr (
	.datain_h(1'b0), .datain_l(1'b1), .outclock(clk), .dataout(SDRAM_CLK),
	.aclr(1'b0), .aset(1'b0), .oe(1'b1), .outclocken(1'b1), .sclr(1'b0), .sset(1'b0)
);
`endif

endmodule
