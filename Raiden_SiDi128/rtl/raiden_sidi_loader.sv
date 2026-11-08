// SPDX-License-Identifier: GPL-3.0-or-later

module raiden_sidi_loader (
	input             clk,
	input             reset,

	input             ioctl_download,
	input       [7:0] ioctl_index,
	input             ioctl_wr,
	input      [26:0] ioctl_addr,
	input       [7:0] ioctl_dout,

	output            active,
	output reg        overflow = 1'b0,

	output reg        dl_wr = 1'b0,
	output reg [24:1] dl_waddr,
	output reg [15:0] dl_wdata,
	input             dl_busy,

	output reg [27:0] spr_waddr,
	output reg [15:0] spr_wdata,
	output reg        spr_we_req = 1'b0,
	input             spr_we_ack,

	output reg        wide_wr = 1'b0,
	output reg [26:0] wide_addr,
	output reg [15:0] wide_dout
);

reg  [7:0] lo_byte;
reg        push;
reg [23:0] push_a;
reg [15:0] push_d;

always @(posedge clk) begin
	push <= 1'b0;
	if (ioctl_download && ioctl_wr && ioctl_index == 8'd0) begin
		if (!ioctl_addr[0]) lo_byte <= ioctl_dout;
		else begin
			push   <= 1'b1;
			push_a <= ioctl_addr[24:1];
			push_d <= {ioctl_dout, lo_byte};
		end
	end
end

localparam AW = 10;
reg [39:0] fifo_mem [0:(1<<AW)-1];
reg [AW:0] wp = 0, rp = 0;
wire       empty = (wp == rp);
wire       full  = (wp[AW-1:0] == rp[AW-1:0]) && (wp[AW] != rp[AW]);

always @(posedge clk) begin
	if (reset) begin
		wp       <= 0;
		overflow <= 1'b0;
	end else if (push) begin
		if (full) overflow <= 1'b1;
		else begin
			fifo_mem[wp[AW-1:0]] <= {push_a, push_d};
			wp <= wp + 1'd1;
		end
	end
end

reg  [39:0] fifo_q;
reg         rd_pend = 1'b0;
wire        a_move;
wire        fetch = !empty && (!rd_pend || a_move);
always @(posedge clk) if (fetch) fifo_q <= fifo_mem[rp[AW-1:0]];

wire [26:0] q_byte_addr = {2'b00, fifo_q[39:16], 1'b0};
wire [15:0] q_dec;
raiden_decrypt u_decrypt (
	.ioctl_addr_in     (q_byte_addr),
	.ioctl_dout_in     (fifo_q[15:0]),
	.ioctl_wr_in       (1'b1),
	.ioctl_index_in    (16'd0),
	.ioctl_download_in (1'b1),
	.ioctl_addr_out    (),
	.ioctl_dout_out    (q_dec),
	.ioctl_wr_out      (),
	.ioctl_index_out   (),
	.ioctl_download_out()
);

localparam [1:0] K_SD = 2'd0, K_SPR = 2'd1, K_WIDE = 2'd2, K_DROP = 2'd3;
reg  [1:0]  kind;
always @(*) begin
	if      (q_byte_addr < 27'h0A0000) kind = K_SD;
	else if (q_byte_addr < 27'h0C0000) kind = K_WIDE;
	else if (q_byte_addr < 27'h1C0000) kind = K_SD;
	else if (q_byte_addr < 27'h240000) kind = K_SPR;
	else if (q_byte_addr < 27'h280000) kind = K_SD;
	else                               kind = K_DROP;
end
wire [1:0] bank = (q_byte_addr < 27'h060000) ? 2'd1 :
                  (q_byte_addr < 27'h0A0000) ? 2'd2 :
                  (q_byte_addr < 27'h1C0000) ? 2'd0 :
                                               2'd3;

reg         h_valid = 1'b0;
reg  [1:0]  h_kind;
reg  [26:0] h_addr;
reg  [23:0] h_waddr;
reg  [15:0] h_data;

wire issue_ok =
	(h_kind == K_SD)  ? !dl_busy :
	(h_kind == K_SPR) ? (spr_we_ack == spr_we_req) : 1'b1;
wire h_take = h_valid & issue_ok;
assign a_move = rd_pend & (!h_valid | h_take);

always @(posedge clk) begin
	dl_wr   <= 1'b0;
	wide_wr <= 1'b0;
	if (reset) begin
		rp      <= 0;
		rd_pend <= 1'b0;
		h_valid <= 1'b0;
	end else begin
		if (h_take) begin
			h_valid <= 1'b0;
			case (h_kind)
				K_SD:   begin dl_wr <= 1'b1; dl_waddr <= h_waddr; dl_wdata <= h_data; end
				K_SPR:  begin spr_waddr <= {1'b0, h_addr - 27'h1C0000}; spr_wdata <= h_data;
				              spr_we_req <= ~spr_we_req; end
				K_WIDE: begin wide_wr <= 1'b1; wide_addr <= h_addr; wide_dout <= h_data; end
				default: ;
			endcase
		end
		if (a_move) begin
			h_valid <= 1'b1;
			h_kind  <= kind;
			h_addr  <= q_byte_addr;
			h_waddr <= {bank, q_byte_addr[22:1]};
			h_data  <= q_dec;
			rd_pend <= 1'b0;
		end
		if (fetch && !reset) begin
			rp      <= rp + 1'd1;
			rd_pend <= 1'b1;
		end
	end
end

assign active = ioctl_download | ~empty | rd_pend | h_valid | dl_busy |
                (spr_we_ack != spr_we_req);

endmodule
