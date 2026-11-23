module fdd_uio (
	input             clk,
	input             rst_n,
	input             boot_done,

	input       [1:0] request,

	output reg        mg_req,
	output reg        mg_we,
	output reg [15:0] mg_addr,
	output reg [15:0] mg_wdata,
	input             mg_ack,
	input      [15:0] mg_rdata,

	input             mounted,
	input      [31:0] img_sectors,
	input             mount_evt,
	input             grant,
	output reg        busy,
	output reg        uio_rd,
	output reg        uio_wr,
	output reg [31:0] uio_lba,
	input             uio_ack,
	input       [8:0] buff_addr,
	input       [7:0] buff_dout,
	input             buff_wr,
	output reg  [7:0] buff_din
);

	reg [7:0] g_cyl, g_spt; reg [1:0] g_heads; reg [3:0] g_type; reg g_ok;
	always @* begin
		g_ok = 1'b1; g_heads = 2'd2; g_cyl = 8'd80; g_spt = 8'd18; g_type = 4'd4;
		case (img_sectors)
			32'd320:  begin g_cyl = 8'd40; g_spt = 8'd8;  g_heads = 2'd1; g_type = 4'd1; end
			32'd360:  begin g_cyl = 8'd40; g_spt = 8'd9;  g_heads = 2'd1; g_type = 4'd1; end
			32'd640:  begin g_cyl = 8'd40; g_spt = 8'd8;                  g_type = 4'd1; end
			32'd720:  begin g_cyl = 8'd40; g_spt = 8'd9;                  g_type = 4'd1; end
			32'd1440: begin g_cyl = 8'd80; g_spt = 8'd9;                  g_type = 4'd3; end
			32'd2400: begin g_cyl = 8'd80; g_spt = 8'd15;                 g_type = 4'd2; end
			32'd2880: begin g_cyl = 8'd80; g_spt = 8'd18;                 g_type = 4'd4; end
			32'd3360: begin g_cyl = 8'd80; g_spt = 8'd21;                 g_type = 4'd4; end
			32'd3444: begin g_cyl = 8'd82; g_spt = 8'd21;                 g_type = 4'd4; end
			32'd5760: begin g_cyl = 8'd80; g_spt = 8'd36;                 g_type = 4'd5; end
			default:  g_ok = 1'b0;
		endcase
	end
	wire present = mounted && g_ok;

	reg  [7:0] buf_mem [0:511];
	reg  [8:0] b_wa, b_ra; reg [7:0] b_wd; reg b_we;
	reg  [7:0] b_q;
	always @(posedge clk) begin
		if (b_we) buf_mem[b_wa] <= b_wd;
		b_q <= buf_mem[b_ra];
	end
	reg [7:0] u_q;
	always @(posedge clk) u_q <= buf_mem[buff_addr];
	always @* buff_din = u_q;

	localparam S_IDLE=0, S_CFG=1, S_LBA=2, S_RD_REQ=3, S_RD_XFER=4, S_PUSH_A=5, S_PUSH_B=6,
	           S_POP_W=7, S_POP=8, S_WR_REQ=9, S_WR_XFER=10, S_DROP=11;
	reg  [3:0]  st;
	reg  [3:0]  cstep;
	reg         cfg_media, cfg_cmos, booted_d;
	reg         dir_wr;
	reg  [9:0]  cnt;
	reg  [1:0]  gap;
	reg         ack_d;
	reg  [26:0] tmo;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			st <= S_IDLE; cstep <= 0; cfg_media <= 1'b1; cfg_cmos <= 1'b0; booted_d <= 1'b0;
			mg_req <= 0; mg_we <= 0; mg_addr <= 0; mg_wdata <= 0;
			busy <= 0; uio_rd <= 0; uio_wr <= 0; uio_lba <= 0; b_we <= 0; ack_d <= 0; tmo <= 0;
			cnt <= 0; gap <= 0; dir_wr <= 0;
		end else begin
			b_we  <= 1'b0;
			ack_d <= uio_ack;
			booted_d <= boot_done;
			if (mount_evt) cfg_media <= 1'b1;
			if (boot_done && !booted_d) cfg_cmos <= 1'b1;

			case (st)
			S_IDLE: begin
				busy <= 1'b0;
				if (cfg_media || cfg_cmos) begin
					cstep <= cfg_media ? 4'd0 : 4'd7; cfg_media <= 1'b0; st <= S_CFG;
				end else if (present && (request[0] || request[1])) begin
					dir_wr <= request[1];
					mg_req <= 1'b1; mg_we <= 1'b0; mg_addr <= 16'hF200;
					st <= S_LBA;
				end
			end

			S_CFG: if (!mg_req) begin
				mg_req <= 1'b1; mg_we <= 1'b1;
				case (cstep)
					4'd0: begin mg_addr <= 16'hF200; mg_wdata <= 16'd0;         end
					4'd1: begin mg_addr <= 16'hF201; mg_wdata <= 16'd0;         end
					4'd2: begin mg_addr <= 16'hF202; mg_wdata <= {8'd0, g_cyl}; end
					4'd3: begin mg_addr <= 16'hF203; mg_wdata <= {8'd0, g_spt}; end
					4'd4: begin mg_addr <= 16'hF204; mg_wdata <= img_sectors[15:0]; end
					4'd5: begin mg_addr <= 16'hF205; mg_wdata <= {14'd0, g_heads}; end
					4'd6: begin mg_addr <= 16'hF200; mg_wdata <= {15'd0, present}; end
					default: begin mg_addr <= 16'hF410; mg_wdata <= {8'd0, (present ? g_type : 4'd4), 4'd0}; end
				endcase
			end else if (mg_ack) begin
				mg_req <= 1'b0;
				if (cstep == 4'd7) begin cfg_cmos <= 1'b0; st <= S_IDLE; end
				else if (cstep == 4'd6 && !cfg_cmos) st <= S_IDLE;
				else cstep <= cstep + 1'd1;
			end

			S_LBA: if (mg_ack) begin
				mg_req  <= 1'b0;
				uio_lba <= {17'd0, mg_rdata[14:0]};
				cnt     <= 0; gap <= 0;
				st      <= dir_wr ? S_POP_W : S_RD_REQ;
			end

			S_RD_REQ: if (grant) begin
				busy <= 1'b1; uio_rd <= 1'b1; tmo <= 0; st <= S_RD_XFER;
			end
			S_RD_XFER: begin
				tmo <= tmo + 1'd1;
				if (uio_ack && !ack_d) uio_rd <= 1'b0;
				if (uio_ack && buff_wr) begin b_we <= 1'b1; b_wa <= buff_addr; b_wd <= buff_dout; end
				if (!uio_ack && ack_d) begin busy <= 1'b0; cnt <= 0; b_ra <= 9'd0; st <= S_PUSH_A; end
				else if (&tmo) begin uio_rd <= 1'b0; busy <= 1'b0; st <= S_DROP; end
			end
			S_PUSH_A: begin tmo <= 0; st <= S_PUSH_B; end
			S_PUSH_B: if (!mg_req) begin
				mg_req <= 1'b1; mg_we <= 1'b1; mg_addr <= 16'hF20F; mg_wdata <= {8'd0, b_q};
			end else if (mg_ack) begin
				mg_req <= 1'b0;
				if (cnt == 10'd511) st <= S_DROP;
				else begin cnt <= cnt + 1'd1; b_ra <= cnt[8:0] + 1'd1; st <= S_PUSH_A; end
			end

			S_POP_W: begin
				gap <= gap + 1'd1;
				if (gap == 2'd2) begin
					gap <= 0; mg_req <= 1'b1; mg_we <= 1'b0; mg_addr <= 16'hF20F; st <= S_POP;
				end
			end
			S_POP: if (mg_ack) begin
				mg_req <= 1'b0;
				b_we <= 1'b1; b_wa <= cnt[8:0]; b_wd <= mg_rdata[7:0];
				if (cnt == 10'd511) st <= S_WR_REQ;
				else begin cnt <= cnt + 1'd1; st <= S_POP_W; end
			end
			S_WR_REQ: if (grant) begin
				busy <= 1'b1; uio_wr <= 1'b1; tmo <= 0; st <= S_WR_XFER;
			end
			S_WR_XFER: begin
				tmo <= tmo + 1'd1;
				if (uio_ack && !ack_d) uio_wr <= 1'b0;
				if (!uio_ack && ack_d) begin busy <= 1'b0; st <= S_IDLE; end
				else if (&tmo) begin uio_wr <= 1'b0; busy <= 1'b0; st <= S_IDLE; end
			end

			S_DROP: begin
				tmo <= tmo + 1'd1;
				if (!request[0] && !request[1]) st <= S_IDLE;
				else if (&tmo[15:0]) st <= S_IDLE;
			end
			default: st <= S_IDLE;
			endcase
		end
	end
endmodule
