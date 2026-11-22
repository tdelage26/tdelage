module nv_init
(
	input             clk,
	input             start,
	input             io_busy,
	output reg [19:0] io_addr,
	output reg [31:0] io_din,
	output reg [ 3:0] io_we,
	output            active,
	output            ready,
	input             ld_hold,
	input             ld_req,
	input      [12:0] ld_addr,
	input      [31:0] ld_din,
	output reg        ld_ack
);
	reg  [13:0] k = 14'h2000;
	reg  [ 1:0] s = 0;
	reg  [ 3:0] tmo;
	reg         ldw = 0;
	assign active = !k[13] || (s != 2'd0) || ld_hold;
	assign ready  = k[13] && (s == 2'd0);

	function [31:0] img(input [12:0] a);
		case (a)
			13'd0:  img = 32'h015A5A5A;
			13'd1:  img = 32'h5A5A0200;
			13'd10: img = 32'h4E565241;
			13'd11: img = 32'h4D000000;
			13'd18: img = 32'hFFFFFFFF;
			13'd19: img = 32'h00000001;
			13'd20: img = 32'h00008000;
			13'd21: img = 32'hFFFFFFFE;
			13'd23: img = 32'h00000001;
			13'd25: img = 32'h00000084;
			13'd33: img = 32'h855A02B6;
			13'd34: img = 32'h00000098;
			13'd35: img = 32'h00000098;
			13'd36: img = 32'h00000014;
			13'd37: img = 32'h00000014;
			13'd38: img = 32'h7AA565BD;
			13'd39: img = 32'h00000084;
			13'd40: img = 32'h00000084;
			13'd41: img = 32'h00007F68;
			13'd42: img = 32'h00000014;
			default: img = 32'h00000000;
		endcase
	endfunction

	always @(posedge clk) begin
		ld_ack <= 1'b0;
		case (s)
			2'd0: begin
				io_we <= 4'b0000;
				if (start && k[13]) k <= 14'd0;
				else if (!k[13]) begin
					io_addr <= {1'b1, 6'b000000, k[12:0]};
					io_din  <= img(k[12:0]);
					io_we   <= 4'b1111;
					tmo <= 4'd15;
					s <= 2'd1;
				end
				else if (ld_req) begin
					io_addr <= {1'b1, 6'b000000, ld_addr};
					io_din  <= ld_din;
					io_we   <= 4'b1111;
					tmo <= 4'd15;
					ldw <= 1'b1;
					s <= 2'd1;
				end
			end
			2'd1: begin
				if (io_busy) s <= 2'd2;
				else if (tmo) tmo <= tmo - 1'd1;
				else s <= 2'd2;
			end
			2'd2: begin
				if (!io_busy) begin
					io_we <= 4'b0000;
					if (ldw) begin
						ldw <= 1'b0;
						ld_ack <= 1'b1;
					end
					else k <= k + 1'd1;
					s <= 2'd3;
				end
			end
			2'd3: s <= 2'd0;
			default: s <= 2'd0;
		endcase
	end
endmodule

module nv_save
(
	input             clk,
	input             img_mounted,
	input      [63:0] img_size,
	input             fmt_done,
	input             dl_idle,
	input             save_req,
	output            hold_rst,

	output reg [31:0] sd_lba,
	output reg        sd_rd = 0,
	output reg        sd_wr = 0,
	input             sd_ack,
	input      [ 8:0] sd_buff_addr,
	input      [ 7:0] sd_dout,
	input             sd_dout_strobe,
	output     [ 7:0] sd_din,

	output            ld_hold,
	output reg        ld_req = 0,
	output     [12:0] ld_addr,
	output     [31:0] ld_din,
	input             ld_ack,

	output     [14:1] nvram_addr,
	output reg        nvram_rd = 0,
	input      [15:0] nvram_dout,
	input             nvram_busy
);
	localparam S_IDLE = 4'd0, L_REQ = 4'd1, L_RX = 4'd2, L_WAIT = 4'd3, L_B0 = 4'd4, L_B1 = 4'd5, L_WR = 4'd6,
	           V_RD = 4'd7, V_RD1 = 4'd8, V_RD2 = 4'd9, V_ST = 4'd10, V_WR = 4'd11, V_WA = 4'd12;

	reg  [ 3:0] st = S_IDLE;
	reg         mounted = 0, pending = 0, loading = 0;
	reg         save_old = 0, hdr_bad = 0;
	reg  [ 5:0] lba;
	reg  [ 7:0] widx;
	reg  [ 1:0] bcnt;
	reg  [31:0] word;
	reg  [ 3:0] tmo;

	reg  [ 7:0] buffer[512];
	reg  [ 7:0] bq;
	reg         bw;
	reg  [ 8:0] bwa;
	reg  [ 7:0] bwd;
	wire [ 8:0] bra = (st == V_WR || st == V_WA) ? sd_buff_addr : {widx[6:0], bcnt};
	always @(posedge clk) begin
		if (bw) buffer[bwa] <= bwd;
		bq <= buffer[bra];
	end

	function [7:0] hdr(input [2:0] a);
		case (a)
			3'd0: hdr = 8'h01;
			3'd6: hdr = 8'h02;
			default: hdr = 8'h5A;
		endcase
	endfunction

	assign hold_rst   = pending | loading;
	assign ld_hold    = (st == L_B0) || (st == L_B1) || (st == L_WR);
	assign ld_addr    = {lba, widx[6:0]};
	assign ld_din     = word;
	assign nvram_addr = {lba, widx};
	assign sd_din     = bq;

	always @(posedge clk) begin
		bw <= 1'b0;
		save_old <= save_req;
		if (img_mounted) begin
			mounted <= |img_size;
			pending <= |img_size;
		end

		case (st)
			S_IDLE: begin
				if (pending && fmt_done) begin
					pending <= 1'b0;
					loading <= 1'b1;
					hdr_bad <= 1'b0;
					lba <= 6'd0;
					st <= L_REQ;
				end
				else if (save_req && !save_old && mounted && fmt_done) begin
					lba <= 6'd0;
					widx <= 8'd0;
					st <= V_RD;
				end
			end

			L_REQ: begin
				sd_lba <= {26'd0, lba};
				sd_rd <= 1'b1;
				if (sd_ack) begin
					sd_rd <= 1'b0;
					st <= L_RX;
				end
			end

			L_RX: begin
				if (sd_dout_strobe) begin
					bw <= 1'b1;
					bwa <= sd_buff_addr;
					bwd <= sd_dout;
					if (lba == 6'd0 && sd_buff_addr < 9'd7 && sd_dout != hdr(sd_buff_addr[2:0])) hdr_bad <= 1'b1;
				end
				if (!sd_ack) begin
					widx <= 8'd0;
					bcnt <= 2'd0;
					st <= L_WAIT;
				end
			end

			L_WAIT: begin
				if (hdr_bad) begin
					loading <= 1'b0;
					st <= S_IDLE;
				end
				else if (dl_idle && fmt_done) st <= L_B0;
			end

			L_B0: st <= L_B1;

			L_B1: begin
				word <= {word[23:0], bq};
				bcnt <= bcnt + 2'd1;
				if (bcnt == 2'd3) begin
					ld_req <= 1'b1;
					st <= L_WR;
				end
				else st <= L_B0;
			end

			L_WR: begin
				if (ld_ack) begin
					ld_req <= 1'b0;
					widx <= widx + 8'd1;
					if (widx[6:0] == 7'd127) begin
						lba <= lba + 6'd1;
						if (lba == 6'd63) begin
							loading <= 1'b0;
							st <= S_IDLE;
						end
						else st <= L_REQ;
					end
					else st <= L_B0;
				end
			end

			V_RD: begin
				nvram_rd <= 1'b1;
				tmo <= 4'd15;
				st <= V_RD1;
			end

			V_RD1: begin
				if (nvram_busy) st <= V_RD2;
				else if (tmo) tmo <= tmo - 4'd1;
				else st <= V_RD2;
			end

			V_RD2: begin
				if (!nvram_busy) begin
					nvram_rd <= 1'b0;
					bw <= 1'b1;
					bwa <= {widx, 1'b0};
					bwd <= nvram_dout[15:8];
					st <= V_ST;
				end
			end

			V_ST: begin
				bw <= 1'b1;
				bwa <= {widx, 1'b1};
				bwd <= nvram_dout[7:0];
				widx <= widx + 8'd1;
				st <= (widx == 8'd255) ? V_WR : V_RD;
			end

			V_WR: begin
				sd_lba <= {26'd0, lba};
				sd_wr <= 1'b1;
				if (sd_ack) begin
					sd_wr <= 1'b0;
					st <= V_WA;
				end
			end

			V_WA: begin
				if (!sd_ack) begin
					lba <= lba + 6'd1;
					widx <= 8'd0;
					st <= (lba == 6'd63) ? S_IDLE : V_RD;
				end
			end

			default: st <= S_IDLE;
		endcase
	end
endmodule
