module ddram_sdr3
(
	input             clk,
	input             quiet,
	input             inval,

	output            DDRAM_BUSY,
	input      [ 7:0] DDRAM_BURSTCNT,
	input      [28:0] DDRAM_ADDR,
	output reg [63:0] DDRAM_DOUT,
	output reg        DDRAM_DOUT_READY,
	input             DDRAM_RD,
	input      [63:0] DDRAM_DIN,
	input      [ 7:0] DDRAM_BE,
	input             DDRAM_WE,

	input      [15:0] SDRAM_DQ_I,
	output     [15:0] SDRAM_DQ_O,
	output            SDRAM_DQ_OE,
	output reg [12:0] SDRAM_A,
	output            SDRAM_DQML,
	output            SDRAM_DQMH,
	output reg [ 1:0] SDRAM_BA,
	output            SDRAM_nCS,
	output reg        SDRAM_nWE,
	output reg        SDRAM_nRAS,
	output reg        SDRAM_nCAS,
	output            SDRAM_CKE,

	output reg        c1_req = 0,
	input             c1_own,
	output reg [ 2:0] x1_cmd = 3'b111,
	output     [12:0] x1_a,
	output     [ 1:0] x1_ba,
	output reg [15:0] x1_dq,
	output reg        x1_oe = 0,
	output reg [ 1:0] x1_dqm = 2'b11,
	input      [15:0] x1_din
);

	localparam [12:0] MODE = 13'b000_1_00_010_0_000;

	localparam CMD_NOP       = 3'b111;
	localparam CMD_ACTIVE    = 3'b011;
	localparam CMD_READ      = 3'b101;
	localparam CMD_WRITE     = 3'b100;
	localparam CMD_PRECHARGE = 3'b010;
	localparam CMD_REFRESH   = 3'b001;
	localparam CMD_LOADMODE  = 3'b000;

	localparam RFS_PERIOD = 10'd760;
	localparam CAP = 4;
	localparam TMO = 6'd48;
	localparam WQ  = 6'd10;

	localparam S_INIT    = 4'd0;
	localparam S_IDLE    = 4'd1;
	localparam S_DEC1    = 4'd2;
	localparam S_DEC     = 4'd3;
	localparam S_WRITE   = 4'd4;
	localparam S_READ    = 4'd5;
	localparam S_RDEND   = 4'd6;
	localparam S_FILLEND = 4'd7;
	localparam S_PRE     = 4'd8;
	localparam S_WAIT    = 4'd9;

	reg  [ 3:0] st = S_INIT;
	reg  [15:0] init_cnt = 16'd0;
	reg  [ 9:0] rfs_cnt = 10'd0;
	reg  [ 2:0] rfs_pend = 3'd0;
	reg  [ 3:0] wait_cnt;
	reg  [ 3:0] ras_cnt = 0;

	reg         l_we;
	reg  [22:0] idx;
	reg  [ 7:0] left;
	reg         l_vram, l_big, l_full;
	reg  [ 9:0] l_blk;
	reg         mir = 0;
	reg         rd2 = 0;
	reg         fill = 0;
	reg         wfull;
	reg  [ 1:0] phase;
	reg  [63:0] wbuf;
	reg  [ 7:0] wbe;
	reg  [ 5:0] wt;

	reg  [CAP:0] rd_v = 0;
	reg  [CAP:0] rd_m = 0;
	reg  [ 1:0] rd_j [0:CAP];
	reg  [ 9:0] rd_c [0:CAP];
	reg  [ 7:0] rd_left = 0;
	reg  [63:0] acc;
	integer     k;

	(* ramstyle = "M9K" *) reg vbm [0:1023];
	reg         vb_we = 0, vb_wd;
	reg  [ 9:0] vb_wa, vb_ra;
	reg         vb_q;
	always @(posedge clk) begin
		if (vb_we) vbm[vb_wa] <= vb_wd;
		vb_q <= vbm[vb_ra];
	end
	reg         sweep = 1;
	reg  [ 9:0] sw_cnt = 0;

	reg  [ 2:0] x_cmd = CMD_NOP;
	reg  [12:0] x_a = 0;
	reg  [ 1:0] x_ba = 0;
	reg  [15:0] x2_dq;
	reg         x2_oe = 0;
	reg  [ 1:0] x2_dqm = 2'b11;
	reg  [12:0] x1_ar = 0;
	assign x1_a  = x1_ar;
	assign x1_ba = 2'd2;

	reg  [15:0] dq_out;
	reg         dq_oe = 0;
	reg  [ 1:0] dqm = 2'b11;
	reg         cs_n = 1;
	reg  [15:0] dq2_in;
	assign SDRAM_DQ_O  = dq_out;
	assign SDRAM_DQ_OE = dq_oe;
	assign SDRAM_nCS  = cs_n;
	assign SDRAM_CKE  = 1'b1;
	assign {SDRAM_DQMH, SDRAM_DQML} = dqm;
	always @(posedge clk) begin
		{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= x_cmd;
		cs_n     <= (x_cmd == CMD_NOP);
		SDRAM_A  <= x_a;
		SDRAM_BA <= x_ba;
		dq_out   <= x2_dq;
		dq_oe    <= x2_oe;
		dqm      <= x2_dqm;
		dq2_in   <= SDRAM_DQ_I;
	end

	reg  ready_cmd = 0, ready_beat = 0;
	assign DDRAM_BUSY = ~(ready_cmd | ready_beat | DDRAM_DOUT_READY);
	wire take_cmd  = ready_cmd  & (DDRAM_RD | DDRAM_WE);
	wire take_beat = ready_beat & DDRAM_WE;

	wire c1_ok    = c1_own & c1_req;
	wire elig     = l_vram && l_big && !sweep;
	wire give_up  = (!quiet && wt >= WQ) || (wt >= TMO);

	function [15:0] lane(input [63:0] d, input [1:0] n);
		case (n)
			2'd0: lane = d[63:48];
			2'd1: lane = d[47:32];
			2'd2: lane = d[31:16];
			2'd3: lane = d[15:0];
		endcase
	endfunction
	function [1:0] lbe(input [7:0] be, input [1:0] n);
		case (n)
			2'd0: lbe = ~be[7:6];
			2'd1: lbe = ~be[5:4];
			2'd2: lbe = ~be[3:2];
			2'd3: lbe = ~be[1:0];
		endcase
	endfunction
	wire [1:0] cb        = rd2 ? {phase[0], 1'b1} : phase;
	wire       last_beat = rd2 ? phase[0] : (phase == 2'd3);

	always @(posedge clk) begin
		reg [ 2:0] cmd;
		reg        c1;
		reg [12:0] na;
		cmd = CMD_NOP;
		c1  = 0;
		na  = x_a;

		x2_oe  <= 0;
		x1_oe  <= 0;
		x2_dqm <= 2'b11;
		x1_dqm <= 2'b11;
		vb_we  <= 0;
		DDRAM_DOUT_READY <= 0;
		if (ras_cnt != 4'hF) ras_cnt <= ras_cnt + 1'd1;

		if (inval) begin sweep <= 1; sw_cnt <= 0; end
		else if (sweep) begin
			vb_we <= 1; vb_wa <= sw_cnt; vb_wd <= 1'b0;
			sw_cnt <= sw_cnt + 1'd1;
			if (&sw_cnt) sweep <= 0;
		end

		if (st != S_INIT) begin
			rfs_cnt <= rfs_cnt + 1'd1;
			if (rfs_cnt == RFS_PERIOD) begin
				rfs_cnt <= 0;
				if (rfs_pend != 3'd7) rfs_pend <= rfs_pend + 1'd1;
			end
		end

		rd_v <= {rd_v[CAP-1:0], 1'b0};
		rd_m <= {rd_m[CAP-1:0], 1'b0};
		for (k = CAP; k > 0; k = k - 1) begin rd_j[k] <= rd_j[k-1]; rd_c[k] <= rd_c[k-1]; end
		if (rd_v[CAP]) begin
			if (rd_m[CAP]) begin
				if (!rd_j[CAP][0]) begin acc[47:32] <= dq2_in; acc[63:48] <= x1_din; end
				else begin
					DDRAM_DOUT <= {acc[63:48], acc[47:32], x1_din, dq2_in};
					DDRAM_DOUT_READY <= 1;
					rd_left <= rd_left - 1'd1;
				end
			end else case (rd_j[CAP])
				2'd0: acc[63:48] <= dq2_in;
				2'd1: acc[47:32] <= dq2_in;
				2'd2: acc[31:16] <= dq2_in;
				2'd3: begin
					DDRAM_DOUT <= {acc[63:16], dq2_in};
					DDRAM_DOUT_READY <= 1;
					rd_left <= rd_left - 1'd1;
				end
			endcase
		end

		ready_cmd  <= 0;
		ready_beat <= 0;

		case (st)
			S_INIT: begin
				init_cnt <= init_cnt + 1'd1;
				case (init_cnt)
					16'd2000: cmd = CMD_PRECHARGE;
					16'd2004, 16'd2012, 16'd2020, 16'd2028,
					16'd2036, 16'd2044, 16'd2052, 16'd2060: cmd = CMD_REFRESH;
					16'd2068: cmd = CMD_LOADMODE;
					16'd2072: st <= S_IDLE;
					default: ;
				endcase
				na = (init_cnt == 16'd2068) ? MODE : 13'b0010000000000;
				x_ba <= 2'b00;
			end

			S_IDLE: begin
				mir <= 0; rd2 <= 0; fill <= 0;
				if (take_cmd) begin
					l_we   <= DDRAM_WE;
					idx    <= DDRAM_ADDR[22:0];
					left   <= (DDRAM_BURSTCNT == 0) ? 8'd1 : DDRAM_BURSTCNT;
					l_vram <= (DDRAM_ADDR[24:17] == 8'd0);
					l_big  <= (DDRAM_BURSTCNT >= 8'd64);
					l_full <= (DDRAM_ADDR[6:0] == 7'd0) && (DDRAM_BURSTCNT == 8'd128);
					l_blk  <= DDRAM_ADDR[16:7];
					vb_ra  <= DDRAM_ADDR[16:7];
					wbuf   <= DDRAM_DIN;
					wbe    <= DDRAM_BE;
					wt     <= 0;
					if (!sweep && DDRAM_ADDR[24:17] == 8'd0 && DDRAM_BURSTCNT >= 8'd64)
						st <= S_DEC1;
					else begin
						if (DDRAM_ADDR[24:17] == 8'd0 && DDRAM_WE && !sweep && !inval) begin
							vb_we <= 1; vb_wa <= DDRAM_ADDR[16:7]; vb_wd <= 1'b0;
						end
						wfull <= 1'b0;
						cmd = CMD_ACTIVE;
						na  = DDRAM_ADDR[20:8];
						x_ba <= DDRAM_ADDR[22:21];
						ras_cnt <= 0;
						phase <= 2'd0;
						rd_left <= DDRAM_WE ? 8'd0 : ((DDRAM_BURSTCNT == 0) ? 8'd1 : DDRAM_BURSTCNT);
						wait_cnt <= 4'd1;
						st <= DDRAM_WE ? S_WRITE : S_READ;
					end
				end
				else if (rfs_pend != 0) begin
					cmd = CMD_REFRESH;
					rfs_pend <= rfs_pend - 1'd1 + ((rfs_cnt == RFS_PERIOD && rfs_pend != 3'd7) ? 1'd1 : 1'd0);
					wait_cnt <= 4'd7;
					st <= S_WAIT;
				end
				else ready_cmd <= 1;
			end

			S_DEC1: begin
				if (!(&wt)) wt <= wt + 1'd1;
				st <= S_DEC;
			end

			S_DEC: begin
				if (!(&wt)) wt <= wt + 1'd1;
				if (!elig || c1_ok || give_up) begin
					mir  <= elig && c1_ok;
					rd2  <= elig && c1_ok && !l_we &&  vb_q;
					fill <= elig && c1_ok && !l_we && !vb_q;
					wfull <= elig && c1_ok && l_we && l_full && wbe[7:6] == 2'b11 && wbe[3:2] == 2'b11;
					if (l_vram && l_we && !(elig && c1_ok) && !sweep && !inval) begin
						vb_we <= 1; vb_wa <= l_blk; vb_wd <= 1'b0;
					end
					cmd = CMD_ACTIVE;
					c1  = elig && c1_ok;
					na  = idx[20:8];
					x_ba <= idx[22:21];
					ras_cnt <= 0;
					phase <= 2'd0;
					rd_left <= l_we ? 8'd0 : left;
					wait_cnt <= 4'd1;
					st <= l_we ? S_WRITE : S_READ;
				end
			end

			S_WRITE: begin
				if (wait_cnt) wait_cnt <= wait_cnt - 1'd1;
				else begin
					cmd = CMD_WRITE;
					c1  = mir && !phase[0];
					na  = {3'b000, idx[7:0], phase};
					x2_dq <= lane(wbuf, phase);  x2_oe <= 1;   x2_dqm <= lbe(wbe, phase);
					x1_dq <= lane(wbuf, phase);  x1_oe <= mir && !phase[0];  x1_dqm <= lbe(wbe, phase);
					phase <= phase + 1'd1;
					if (phase == 2'd2 && left != 1) ready_beat <= 1;
					if (phase == 2'd3) begin
						idx  <= idx + 1'd1;
						left <= left - 1'd1;
						if (left == 1) begin
							wait_cnt <= 4'd2;
							st       <= S_PRE;
							if (wfull && !sweep && !inval) begin vb_we <= 1; vb_wa <= l_blk; vb_wd <= 1'b1; end
						end
					end
				end
				if (take_beat) begin
					wbuf <= DDRAM_DIN;
					wbe  <= DDRAM_BE;
					if (DDRAM_BE[7:6] != 2'b11 || DDRAM_BE[3:2] != 2'b11) wfull <= 1'b0;
				end
			end

			S_READ: begin
				c1 = rd2;
				x2_dqm <= 2'b00;
				x1_dqm <= 2'b00;
				if (wait_cnt) wait_cnt <= wait_cnt - 1'd1;
				else begin
					cmd = CMD_READ;
					na  = {3'b000, idx[7:0], cb};
					rd_v[0] <= 1'b1; rd_m[0] <= rd2; rd_j[0] <= phase; rd_c[0] <= {idx[7:0], cb};
					phase <= last_beat ? 2'd0 : phase + 1'd1;
					if (last_beat) begin
						idx  <= idx + 1'd1;
						left <= left - 1'd1;
						if (left == 1) st <= S_RDEND;
					end
				end
			end

			S_RDEND: begin
				x2_dqm <= 2'b00;
				x1_dqm <= 2'b00;
				wait_cnt <= 4'd0;
				st <= fill ? S_FILLEND : S_PRE;
			end

			S_FILLEND: begin
				x2_dqm <= 2'b00;
				if (rd_v == 0) begin
					wait_cnt <= 4'd3;
					st <= S_PRE;
					if (l_full && !sweep && !inval) begin vb_we <= 1; vb_wa <= l_blk; vb_wd <= 1'b1; end
				end
			end

			S_PRE: begin
				if (wait_cnt) wait_cnt <= wait_cnt - 1'd1;
				else if (ras_cnt >= 4'd5) begin
					cmd = CMD_PRECHARGE;
					c1  = mir;
					na  = 13'd0;
					wait_cnt <= 4'd2;
					st <= S_WAIT;
				end
			end

			S_WAIT: begin
				if (wait_cnt) wait_cnt <= wait_cnt - 1'd1;
				else if (rd_v == 0 && rd_left == 0) begin
					st <= S_IDLE;
					if (rfs_pend == 0) ready_cmd <= 1;
				end
			end

			default: st <= S_IDLE;
		endcase

		x_cmd  <= cmd;
		x_a    <= na;
		x1_cmd <= c1 ? cmd : CMD_NOP;
		x1_ar  <= (cmd == CMD_READ || cmd == CMD_WRITE) ? {na[12:1], 1'b0} : na;
		if (fill && rd_v[CAP] && !rd_m[CAP] && !rd_j[CAP][0]) begin
			x1_cmd <= CMD_WRITE;
			x1_ar  <= {3'b000, rd_c[CAP]};
			x1_dq  <= dq2_in;
			x1_oe  <= 1'b1;
			x1_dqm <= 2'b00;
		end

		if (st == S_INIT) c1_req <= 0;
		else c1_req <= ((st == S_DEC1 || st == S_DEC) && elig && !give_up) ||
		               (st == S_DEC && elig && c1_ok) ||
		               (mir && st != S_IDLE);
	end

endmodule
