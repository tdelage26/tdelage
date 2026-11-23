// Derive a real VBlank from the combined H+V blanking of vga.v (vga_blank_n).
// mist_video/osd.v with USE_BLANKS=1 (HDMI path) needs separate HBlank and VBlank:
// feeding the combined blank to both makes osd.v reset its line counter on every
// horizontal blank, so the OSD window is never opened.
// Horizontal blanking (incl. overscan borders) is always far shorter than THRESH dots,
// vertical blanking is at least a couple of whole lines, so "blank has lasted > THRESH
// clocks" identifies vertical blanking. vb falls on the same edge as blank.
module vb_from_blank #(parameter THRESH = 10'd512) (
	input  clk,       // pixel clock (clk_25)
	input  blank,     // combined H+V blank, active high, same timing as VGA_BLANK
	output reg vb     // vertical blank, active high
);
	reg [9:0] cnt = 10'd0;
	always @(posedge clk) begin
		if (!blank) begin
			cnt <= 10'd0;
			vb  <= 1'b0;
		end else begin
			if (cnt != 10'h3FF) cnt <= cnt + 1'd1;
			if (cnt == THRESH)  vb  <= 1'b1;
		end
	end
endmodule
