module svga_fb
(
	input             clk_sys,
	input             reset,

	input             fb_en,
	input      [19:0] start_addr,
	input       [8:0] stride,
	input       [8:0] width,
	input             dscan,

	input       [7:0] pal_a,
	input      [17:0] pal_d,
	input             pal_we,

	output reg        sd_req = 1'b0,
	input             sd_ack,
	output reg [25:0] sd_addr,
	output reg  [3:0] sd_burst,
	input             sd_ready,
	input      [31:0] sd_dout,

	input             clk_vga,
	input             ce,
	input             in_blank_n,
	input             in_hs,
	input             in_vs,
	input       [7:0] in_r, in_g, in_b,
	output reg        out_blank_n,
	output reg        out_hs,
	output reg        out_vs,
	output reg  [7:0] out_r, out_g, out_b,
	output            active
);

localparam [25:0] VRAM_BASE = 26'h3C00000;

reg  [31:0] lbuf [0:511];
reg   [8:0] lb_wa;
reg  [31:0] lb_wd;
reg         lb_we;
always @(posedge clk_sys) if (lb_we) lbuf[lb_wa] <= lb_wd;
reg   [8:0] lb_ra;
reg  [31:0] lb_q;
always @(posedge clk_vga) lb_q <= lbuf[lb_ra];

reg  [17:0] pal [0:255];
always @(posedge clk_sys) if (pal_we) pal[pal_a] <= pal_d;
reg   [7:0] pal_ra;
reg  [17:0] pal_q;
always @(posedge clk_vga) pal_q <= pal[pal_ra];

reg  [2:0] bl_s = 0, vs_s = 0;
always @(posedge clk_sys) begin
	bl_s <= {bl_s[1:0], in_blank_n};
	vs_s <= {vs_s[1:0], in_vs};
end
wire line_end = bl_s[2] & ~bl_s[1];
wire vsync    = ~vs_s[1];

reg  [10:0] k = 0;
reg  [10:0] nf = 0;
reg         restart = 1'b1;
reg  [21:0] row_addr;
reg   [8:0] nd;
reg   [8:0] di;
reg         busy = 1'b0;
reg         inburst = 1'b0;
wire [21:0] dw_addr = row_addr + {11'd0, di, 2'b00};
wire  [3:0] to_align = 4'd8 - {1'b0, dw_addr[4:2]};
wire  [8:0] left = nd - di;

always @(posedge clk_sys) begin
	lb_we <= 1'b0;
	if (vsync) begin k <= 0; restart <= 1'b1; end
	else if (line_end) k <= k + 1'd1;

	if (reset) begin
		busy <= 1'b0; inburst <= 1'b0; restart <= 1'b1; sd_req <= sd_ack;
	end else if (!busy) begin
		if (restart) begin
			restart  <= vsync;
			nf       <= 0;
			row_addr <= {start_addr, 2'b00};
		end else if (fb_en && (nf < k + 11'd2) && nf != 11'h7FF) begin
			busy <= 1'b1;
			di   <= 0;
			nd   <= ({width, 1'b0} > 10'd256) ? 9'd256 : {width, 1'b0};
		end
	end else if (!inburst) begin
		if (di == nd) begin
			busy <= 1'b0;
			nf   <= nf + 1'd1;
			if (!dscan || nf[0]) row_addr <= row_addr + {stride, 3'b000};
		end else begin
			sd_addr  <= {VRAM_BASE[25:22], dw_addr};
			sd_burst <= (left < to_align) ? left[3:0] : to_align;
			sd_req   <= ~sd_req;
			inburst  <= 1'b1;
		end
	end else begin
		if (sd_ready) begin
			lb_we <= 1'b1;
			lb_wa <= {nf[0], di[7:0]};
			lb_wd <= sd_dout;
			di    <= di + 1'd1;
		end
		if (sd_ack == sd_req && !sd_ready) inburst <= 1'b0;
	end
end

reg  [2:0] en_s = 0;
always @(posedge clk_vga) en_s <= {en_s[1:0], fb_en};
assign active = en_s[2];

reg  [9:0] npx;
always @(posedge clk_vga) npx <= (width > 9'd128) ? 10'd1023 : {width[6:0], 3'b000};

reg  [10:0] x = 0;
reg  [10:0] y = 0;
reg         old_bl = 0;
reg   [1:0] lane1;
reg         vis1 = 0, vis2 = 0;
reg   [1:0] bl_d, hs_d, vs_d;

always @(posedge clk_vga) if (ce) begin
	old_bl <= in_blank_n;
	if (~in_vs) y <= 0;
	else if (old_bl & ~in_blank_n) y <= y + 1'd1;

	if (in_blank_n) x <= x + 1'd1; else x <= 0;
	lb_ra <= {y[0], x[9:2]};
	lane1 <= x[1:0];
	vis1  <= in_blank_n && (x < {1'b0, npx});

	case (lane1)
		2'd0: pal_ra <= lb_q[7:0];
		2'd1: pal_ra <= lb_q[15:8];
		2'd2: pal_ra <= lb_q[23:16];
		2'd3: pal_ra <= lb_q[31:24];
	endcase
	vis2 <= vis1;

	bl_d <= {bl_d[0], in_blank_n};
	hs_d <= {hs_d[0], in_hs};
	vs_d <= {vs_d[0], in_vs};
end

always @(posedge clk_vga) if (ce) begin
	if (active) begin
		out_blank_n <= bl_d[1];
		out_hs      <= hs_d[1];
		out_vs      <= vs_d[1];
		out_r       <= vis2 ? {pal_q[17:12], pal_q[17:16]} : 8'd0;
		out_g       <= vis2 ? {pal_q[11:6],  pal_q[11:10]} : 8'd0;
		out_b       <= vis2 ? {pal_q[5:0],   pal_q[5:4]}   : 8'd0;
	end else begin
		out_blank_n <= in_blank_n;
		out_hs      <= in_hs;
		out_vs      <= in_vs;
		out_r       <= in_r;
		out_g       <= in_g;
		out_b       <= in_b;
	end
end

endmodule
