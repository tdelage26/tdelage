//
// scandoubler_rotate.v
// 
// Copyright (c) 2024 Alastair M. Robinson
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

// Streams incoming video data to an SDRAM port, in 16-word bursts.
// Incoming data is scaled to RGB565
//
// Streams data from SDRAM to output linebuffers in 8-word bursts
// Outgoing data is scaled to OUT_COLOR_DEPTH
//
// The SDRAM controller is responsible for the actual cornerturn.
//

module raiden_scandoubler_rotate
(
	// system interface
	input        clk_sys,

	input        bypass,
	input [1:0]  rotation, // 0 - no rotation, 1 - clockwise, 2 - anticlockwise
	input        rotateonly,
	input        hfilter,
	input        vfilter,

	// Pixelclock
	input        pe_in,
	input        ppe_out,

	// incoming video interface
	input        hb_in,
	input        vb_in,
	input        hs_in,
	input        vs_in,
	input [COLOR_DEPTH-1:0] r_in,
	input [COLOR_DEPTH-1:0] g_in,
	input [COLOR_DEPTH-1:0] b_in,

	// output interface
	input        hb_sd,
	input        vb_sd,
	input        vs_sd,
	output [OUT_COLOR_DEPTH-1:0] r_out,
	output [OUT_COLOR_DEPTH-1:0] g_out,
	output [OUT_COLOR_DEPTH-1:0] b_out,

	// Memory interface - to RAM.  Operates on 16-word bursts
	output reg          vidin_req,    // High at start of row, remains high until burst of 16 pixels has been delivered
	output wire [1:0]   vidin_frame,  // Odd or even frame for double-buffering
	output reg [10:0]   vidin_row,    // X position of current row (after rotation).
	output reg [10:0]   vidin_col,    // Y position of current burst (after rotation).
	output reg [15:0]   vidin_d,      // Incoming video data
	input wire          vidin_ack,    // Request next word from host
	
	// Memory interface - from RAM.  Operates on 8-word bursts
	output wire         vidout_req,   // High at start of row, remains high until entire row has been delivered
	output wire [1:0]   vidout_frame, // Odd or even frame for double-buffering
	output wire [10:0]  vidout_row,   // Y position of current row.
	output wire [10:0]  vidout_col,   // X position of current burst.
	input wire [15:0]   vidout_d,     // Outgoing video data
	input wire          vidout_ack    // Valid data available.
);

parameter HCNT_WIDTH = 10; // Resolution of scandoubler buffer
parameter COLOR_DEPTH = 6; // Bits per colour to be stored in the buffer
parameter OUT_COLOR_DEPTH = 6; // Bits per color outputted
parameter XPOS_MIN = 4'd10; // Filter out partial lines do to H/Vblank misalignments

// Scale incoming video signal to RGB565
wire [15:0] vin_rgb565;

scandoubler_scaledepth #(.IN_DEPTH(COLOR_DEPTH),.OUT_DEPTH(5)) scalein_r (.d(r_in),.q(vin_rgb565[15:11]));
scandoubler_scaledepth #(.IN_DEPTH(COLOR_DEPTH),.OUT_DEPTH(6)) scalein_g (.d(g_in),.q(vin_rgb565[10:5]));
scandoubler_scaledepth #(.IN_DEPTH(COLOR_DEPTH),.OUT_DEPTH(5)) scalein_b (.d(b_in),.q(vin_rgb565[4:0]));


// Stream incoming pixels to SDRAM, taking care of inverting either X or Y coordinates.
// The SDRAM controller does the actual cornerturn.

// Framing
reg [HCNT_WIDTH-1:0] in_xpos;
reg [HCNT_WIDTH-1:0] in_ypos=239;
reg [HCNT_WIDTH-1:0] in_xpos_max = 320;
reg [HCNT_WIDTH-1:0] in_ypos_max = 238;
reg hb_in_d;

// Toggle logical / physical frame every vblank
reg [1:0] logicalframe = 2'b00;
reg vb_d = 1'b1;

always @(posedge clk_sys) if (pe_in) begin
	vb_d<=vb_in;
	if(!vb_d && vb_in) begin
		logicalframe<=~logicalframe;
		in_ypos_max<=in_ypos - (in_xpos <= XPOS_MIN);
	end
end

always @(posedge clk_sys) if (pe_in) begin
	hb_in_d<=hb_in;
	if(vb_in)
		in_ypos<=0;
	else if(!hb_in_d && hb_in && in_xpos > XPOS_MIN) begin // Increment row on hblank
		in_ypos<=in_ypos+1'd1;
		in_xpos_max <= in_xpos;
	end
end

always @(posedge clk_sys) if (pe_in) begin
	if((hb_in | vb_in) && rowwptr[3:0] == 0)
		in_xpos<=0;
	else if (!hb_in & !vb_in)
		in_xpos<=in_xpos+1'd1;	// Increment column on pixel enable
end

// Buffer incoming video data and write to SDRAM.
// (16 word bursts, striped across two banks, SDRAM controller handles the actual cornerturn)

reg [15:0] rowbuf[0:15] /* synthesis ramstyle="logic" */;
reg [3:0] rowwptr;
reg [3:0] rowrptr;
reg running=1'b0;

wire [3:0] escape,start;

always @(posedge clk_sys) begin

	// Reset on vblank
	if(vb_in) begin
		running<=1'b1; // (rotation!=2'b00 && !bypass);
		rowwptr<=4'h0;
	end

	// Don't update row during hblank (gives linebuffer time to empty)
	if(!hb_in) begin
		if(rotation[0])
			vidin_row<=in_ypos_max-in_ypos;
		else
			vidin_row<=in_ypos;
	end

	// Write incoming pixels to a line buffer
	if(running && pe_in && !vb_in && (!hb_in || rowwptr[3:0] != 0)) begin
		rowbuf[rowwptr]<=vin_rgb565;
		rowwptr<=rowwptr+1'b1;
		if(rowwptr[2:0]==3'b111) begin
			vidin_col<=in_xpos;
			vidin_req<=1'b1;
			rowrptr<={rowwptr[3],3'b000};
		end
	end

	// Write pixels from linebuffer to SDRAM
	vidin_d <= rowbuf[rowrptr];
	vidin_col[2:0] <= rowrptr[2:0];

	// Terminate burst after 16 pixels
	if(vidin_ack) begin
		if(rowrptr[2:0]==3'b111)
			vidin_req<=1'b0;
		rowrptr<=rowrptr+1'b1;
	end
end

assign vidin_frame = logicalframe;


// Pixel read process - streams data from SDRAM to linebuffers.

reg [15:0] linebuffer1 [0:2**HCNT_WIDTH-1];
reg [15:0] linebuffer2 [0:2**HCNT_WIDTH-1];

reg fetch;

reg [HCNT_WIDTH-1:0] fetch_xpos;
reg [HCNT_WIDTH-1:0] sd_ypos;

reg hb_sd_d;
reg vs_sd_d;

reg hb_sd_stb;
reg hb_any_stb;
reg vs_sd_stb;


localparam vi_fracwidth=16;

wire [HCNT_WIDTH-1:0] vi_whole; // Row number
wire [hi_fracwidth-1:0] vi_fraction; // Blend factor
wire vi_step; // Move onto the next line
wire vi_ready;
wire vi_blank;

frac_interp #(.bitwidth(HCNT_WIDTH),.fracwidth(vi_fracwidth),.centre(0)) interp_core_v (
	.clk(clk_sys),
	.reset_n(1'b1),
	//.num({in_ypos_max[HCNT_WIDTH-2:0],1'b0}),
	.num(in_ypos_max[HCNT_WIDTH-1:0] << ~rotateonly),
	.den(in_xpos_max),
	.limit(in_xpos_max),
	.newfraction(vs_sd_stb),
	.ready(vi_ready),
	.step_reset(vs_sd_stb),
	.step_in(hb_sd_stb),
	.step_out(vi_step),
	.whole(vi_whole),
	.fraction(vi_fraction),
	.blank(vi_blank)
);

reg fetchbuffer;
reg vs_sd_stb_d;

always @(posedge clk_sys) begin

	hb_sd_d<=hb_sd;
	vs_sd_d<=vs_sd;

	vs_sd_stb<=1'b0;
	if(!vs_sd_d && vs_sd)
		vs_sd_stb<=1'b1;
	vs_sd_stb_d<=vs_sd_stb;

	sd_ypos <= rotation[0] ? vi_whole : in_xpos_max-vi_whole - 1'd1;

	hb_sd_stb<=1'b0;
	hb_any_stb<=1'b0;
	if(!hb_sd_d && hb_sd)
		hb_any_stb<=1'b1;
	if(!vb_sd && !hb_sd_d && hb_sd)
		hb_sd_stb<=1'b1;

	if (vi_step) begin
		fetch_xpos <= 0;
		fetch<=1'b1;
		fetchbuffer<=fetchbuffer ^ vfilter;
	end

	if(vs_sd_stb_d) begin
		fetch_xpos <= 0;	// Pre-fetch the first row after the frac_interp has reset the row number
		fetch<=1'b1;
		fetchbuffer<=1'b0;
	end

	if(fetch && fetch_xpos==in_ypos_max)
		fetch<=1'b0;

	if(vidout_ack) begin
		fetch_xpos<=fetch_xpos+1'd1;
		if(fetchbuffer)
			linebuffer1[fetch_xpos]<=vidout_d;
		else
			linebuffer2[fetch_xpos]<=vidout_d;
	end

end

assign vidout_row = sd_ypos;
assign vidout_col = fetch_xpos;

assign vidout_frame = ~logicalframe;
assign vidout_req = fetch;


// Basic horizontal interpolation

localparam hi_fracwidth=16;

wire [HCNT_WIDTH-1:0] hi_whole; // Index into pixel buffer
wire [HCNT_WIDTH:0]   hi_whole_w;
wire [hi_fracwidth-1:0] hi_fraction; // Blend factor
wire hi_step; // Move onto the next pixel
wire hi_ready;
wire hi_blank;

wire [HCNT_WIDTH:0] hi_xmax = {1'b0, in_xpos_max};
wire [HCNT_WIDTH:0] hi_ymax = {1'b0, in_ypos_max};
wire [HCNT_WIDTH:0] hi_num  = rotateonly ? (hi_xmax + {hi_xmax[HCNT_WIDTH-1:0], 1'b0})
                                         : {in_ypos_max[HCNT_WIDTH-1:0], 1'b0};
wire [HCNT_WIDTH+1:0] hi_off2 = {hi_xmax, 2'b00} - ({1'b0, hi_ymax} + {hi_ymax, 1'b0});
parameter ROT15_HSHIFT = 24;
wire [HCNT_WIDTH:0] hi_off  = rotateonly ? hi_off2[HCNT_WIDTH+1:1] + ROT15_HSHIFT[HCNT_WIDTH:0]
                                         : ({hi_xmax[HCNT_WIDTH-1:0], 1'b0} - hi_num);

raiden_frac_interp_h #(.bitwidth(HCNT_WIDTH+1),.fracwidth(hi_fracwidth)) interp_core_h (
	.clk(clk_sys),
	.num(hi_num),
	.den(hi_xmax),
	.limit(hi_ymax),
	.offset_init(hi_off),
	.newfraction(vs_sd_stb),
	.ready(hi_ready),
	.step_reset(hb_any_stb),
	.step_in(!hb_sd && ppe_out),
	.step_out(hi_step),
	.whole(hi_whole_w),
	.fraction(hi_fraction),
	.blank(hi_blank)
);
assign hi_whole = hi_whole_w[HCNT_WIDTH-1:0];
wire hi_past = hi_whole_w > hi_ymax;

// Interpolate pixels 

reg [15:0] row1_pix1;
reg [15:0] row2_pix1;
reg [15:0] row1_pix2;
reg [15:0] row2_pix2;
wire [15:0] col_pix1;
wire [15:0] col_pix2;
wire [15:0] final_rgb565;

reg [2:0] hi_blank_d;

always @(posedge clk_sys) begin
	hi_blank_d<= {hi_blank_d[1:0],hi_blank};

	if(fetchbuffer) begin
		row1_pix1<=linebuffer1[hi_whole];
		row2_pix1<=linebuffer2[hi_whole];
	end else begin
		row2_pix1<=linebuffer1[hi_whole];
		row1_pix1<=linebuffer2[hi_whole];
	end

	if(hi_step) begin
		if(rotateonly) begin
			if (fetchbuffer) begin
				row1_pix2 <= row2_pix1;
				row2_pix2 <= row2_pix1;
			end
			else
			begin
				row1_pix2 <= row1_pix1;
				row2_pix2 <= row1_pix1;
			end
		end
		else begin
			row1_pix2<=row1_pix1;
			row2_pix2<=row2_pix1;
		end
	end

	if(hi_past) begin
		{row1_pix1, row2_pix1} <= 0;
		{row1_pix2, row2_pix2} <= 0;
	end

end

wire [7:0] hfilter_fraction = hfilter ? hi_fraction[15:8] : 8'h00;
wire [7:0] vfilter_fraction = vfilter ? vi_fraction[15:8] : 8'h00;

scandoubler_rgb_interp rgbinterp_h1
(
	.clk_sys(clk_sys),
	.blank(hi_blank_d[2]),
	.fraction(hfilter_fraction),
	.rgb_in(row1_pix1),
	.rgb_in_prev(row1_pix2),
	.rgb_out(col_pix1)
);

scandoubler_rgb_interp rgbinterp_h2
(
	.clk_sys(clk_sys),
	.blank(hi_blank_d[2]),
	.fraction(hfilter_fraction),
	.rgb_in(row2_pix1),
	.rgb_in_prev(row2_pix2),
	.rgb_out(col_pix2)
);

scandoubler_rgb_interp rgbinterp_v
(
	.clk_sys(clk_sys),
	.blank(vi_blank),
	.fraction(vfilter_fraction),
	.rgb_in(col_pix1),
	.rgb_in_prev(col_pix2),
	.rgb_out(final_rgb565)
);

scandoubler_scaledepth #(.IN_DEPTH(5),.OUT_DEPTH(OUT_COLOR_DEPTH)) scaleout_r (.d(final_rgb565[15:11]),.q(r_out));
scandoubler_scaledepth #(.IN_DEPTH(6),.OUT_DEPTH(OUT_COLOR_DEPTH)) scaleout_g (.d(final_rgb565[10: 5]),.q(g_out));
scandoubler_scaledepth #(.IN_DEPTH(5),.OUT_DEPTH(OUT_COLOR_DEPTH)) scaleout_b (.d(final_rgb565[ 4: 0]),.q(b_out));

endmodule




module raiden_frac_interp_h #(parameter bitwidth=10, parameter fracwidth=16) (
	input clk,
	input [bitwidth-1:0] num,
	input [bitwidth-1:0] den,
	input [bitwidth-1:0] limit,
	input [bitwidth-1:0] offset_init,
	input newfraction,
	output reg ready,
	input step_reset,
	input step_in,
	output reg step_out,
	output [bitwidth-1:0] whole,
	output reg [fracwidth-1:0] fraction,
	output blank
);

wire div_done;
wire [bitwidth+fracwidth-1:0] step;
wire [bitwidth+fracwidth-1:0] remain;

unsigned_division #(.widthlog2(bitwidth+fracwidth)) div (
	.clk(clk),
	.reset_n(1'b1),
	.dividend({num,{fracwidth{1'b0}}}),
	.divisor({{fracwidth{1'b0}},den}),
	.quotient(step),
	.remainder(remain),
	.req(newfraction),
	.ack(div_done)
);

reg [bitwidth+fracwidth-1:0] spos;
wire [bitwidth-1:0] spos_whole = spos[bitwidth+fracwidth-1:fracwidth];
wire [fracwidth-1:0] spos_frac = spos[fracwidth-1:0];
reg [bitwidth-1:0] dpos;
reg [bitwidth-1:0] whole_i;
reg [bitwidth-1:0] offset;

always @(posedge clk) begin
	step_out<=1'b0;
	if (step_in) begin
		if(dpos>spos_whole) begin
			spos<=spos+step;
			fraction<=spos_frac;
			step_out<=1'b1;
			whole_i<=whole_i+1'd1;
		end else
			fraction<=0;
		if(|offset)
			offset<=offset-1'd1;
		else
			dpos<=dpos+1'b1;
	end
	if (newfraction)
		ready <= 1'b0;
	if (whole_i>limit)
		offset<={bitwidth{1'b1}};
	if (step_reset || newfraction) begin
		spos<=0;
		dpos<=0;
		whole_i<=0;
		offset<=offset_init;
	end
	if(div_done)
		ready<=1'b1;
end

assign whole=whole_i;
assign blank=|offset;

endmodule
