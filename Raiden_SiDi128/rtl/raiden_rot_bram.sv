// SPDX-License-Identifier: GPL-3.0-or-later

module raiden_rot_bram #(
	parameter XMAX = 256,
	parameter YMAX = 224
)(
	input             clk,

	input             vidin_req,
	input      [1:0]  vidin_frame,
	input      [10:0] vidin_row,
	input      [10:0] vidin_col,
	input      [15:0] vidin_d,
	output reg        vidin_ack = 1'b0,

	input             vidout_req,
	input      [1:0]  vidout_frame,
	input      [10:0] vidout_row,
	input      [10:0] vidout_col,
	output reg [15:0] vidout_q,
	output reg        vidout_ack = 1'b0
);

localparam FRAME = XMAX * YMAX;
`ifdef NO_ROTATION
localparam DEPTH = 2;
`else
localparam DEPTH = 2 * FRAME;
`endif
localparam AW    = 17;

(* ramstyle = "M9K,no_rw_check" *) reg [11:0] fb [0:DEPTH-1];

function automatic [AW-1:0] fb_addr(input f, input [7:0] x, input [7:0] y);
	fb_addr = (f ? FRAME[AW-1:0] : {AW{1'b0}}) +
	          ({1'b0, x, 8'd0} - {4'd0, x, 5'd0}) + {9'd0, y};
endfunction

reg  [3:0] wcnt = 4'd0;
reg  [1:0] wgap = 2'd0;
reg        wsamp = 1'b0;
reg        w_en = 1'b0;
reg [AW-1:0] w_addr;
reg [11:0] w_data;

always @(posedge clk) begin
	vidin_ack <= 1'b0;
	if (wcnt != 4'd0) begin
		vidin_ack <= 1'b1;
		wcnt      <= wcnt - 4'd1;
		if (wcnt == 4'd1) wgap <= 2'd3;
	end else if (wgap != 2'd0)
		wgap <= wgap - 2'd1;
	else if (vidin_req)
		wcnt <= 4'd8;

	wsamp <= vidin_ack;
	w_en  <= wsamp && (vidin_row < YMAX) && (vidin_col < XMAX);
	w_addr <= fb_addr(vidin_frame[0], vidin_col[7:0], vidin_row[7:0]);
	w_data <= {vidin_d[15:12], vidin_d[10:7], vidin_d[4:1]};
`ifdef NO_ROTATION
	if (w_en) fb[w_addr[0]] <= w_data;
`else
	if (w_en) fb[w_addr] <= w_data;
`endif
end

reg  [3:0] rcnt = 4'd0;
reg  [2:0] rgap = 3'd0;
reg  [7:0] r_x;
reg [10:0] r_y;
reg        r_f;
reg        p1_v = 1'b0, p2_v = 1'b0, p1_ok, p2_ok;
reg [AW-1:0] r_addr;
reg [11:0] r_q;

always @(posedge clk) begin
	p1_v <= 1'b0;
	if (rcnt != 4'd0) begin
		p1_v   <= 1'b1;
		p1_ok  <= (r_y < YMAX) && ({3'd0, r_x} < XMAX);
		r_addr <= fb_addr(r_f, r_x, r_y[7:0]);
		r_y    <= r_y + 11'd1;
		rcnt   <= rcnt - 4'd1;
		if (rcnt == 4'd1) rgap <= 3'd5;
	end else if (rgap != 3'd0)
		rgap <= rgap - 3'd1;
	else if (vidout_req) begin
		r_x  <= vidout_row[7:0];
		r_y  <= {vidout_col[10:3], 3'b000};
		r_f  <= vidout_frame[0];
		rcnt <= 4'd8;
	end

`ifdef NO_ROTATION
	r_q   <= fb[r_addr[0]];
`else
	r_q   <= fb[r_addr];
`endif
	p2_v  <= p1_v;
	p2_ok <= p1_ok;

	vidout_ack <= p2_v;
	vidout_q   <= p2_ok ? {r_q[11:8], r_q[11], r_q[7:4], r_q[7:6], r_q[3:0], r_q[3]} : 16'h0000;
end

endmodule
