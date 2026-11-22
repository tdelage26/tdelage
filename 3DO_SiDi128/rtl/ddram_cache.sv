module ddram_cache
(
	input             clk,
	input             rst,

	output            s_BUSY,
	input      [ 7:0] s_BURSTCNT,
	input      [28:0] s_ADDR,
	output     [63:0] s_DOUT,
	output            s_DOUT_READY,
	input             s_RD,
	input      [63:0] s_DIN,
	input      [ 7:0] s_BE,
	input             s_WE,
	input             pf_hold,

	input             m_BUSY,
	output     [ 7:0] m_BURSTCNT,
	output     [28:0] m_ADDR,
	input      [63:0] m_DOUT,
	input             m_DOUT_READY,
	output            m_RD,
	output     [63:0] m_DIN,
	output     [ 7:0] m_BE,
	output            m_WE
);

	localparam NE = 8;

	reg  [ 9:0] tag   [NE];
	reg  [ 7:0] cval  [NE];
	reg  [ 2:0] age   [NE];

	function [2:0] enc8(input [7:0] oh);
		enc8 = {|(oh & 8'hF0), |(oh & 8'hCC), |(oh & 8'hAA)};
	endfunction

	reg  [ 9:0] wr_a;
	reg  [63:0] wr_d;
	reg  [ 7:0] wr_be;
	reg         wr_en;
	reg  [ 9:0] rd_a;
	wire [63:0] rd_q;

	genvar gb;
	generate
		for (gb = 0; gb < 8; gb = gb + 1) begin : lane
			(* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram [0:1023];
			reg [7:0] q;
			always @(posedge clk) begin
				if (wr_en && wr_be[gb]) ram[wr_a] <= wr_d[gb*8 +: 8];
				q <= ram[rd_a];
			end
			assign rd_q[gb*8 +: 8] = q;
		end
	endgenerate

	localparam ST_IDLE = 3'd0, ST_HIT = 3'd1, ST_FWD = 3'd2, ST_PF = 3'd3, ST_LK = 3'd4, ST_DEC = 3'd5;
	reg  [ 2:0] st = ST_IDLE;

	reg         q_rd;
	reg  [ 9:0] q_blk, q_nblk;
	reg  [ 6:0] q_off;
	reg  [ 7:0] q_cnt;
	reg         q_cached;
	reg  [ 7:0] q_need;
	reg         q_big;
	reg         q_last_blk;

	reg  [ 7:0] l_m;
	reg  [ 7:0] l_full;
	reg  [ 7:0] l_nx;
	reg  [ 7:0] l_nxfull;
	reg  [ 7:0] l_pfe;
	reg  [ 7:0] l_vmiss;
	reg  [ 7:0] l_pfv_hit;
	reg  [ 7:0] l_pfv_miss;
	reg         l_pfdup;

	reg         f_rd;
	reg         f_cache;
	reg  [ 2:0] f_e;
	reg  [ 6:0] f_pos;
	reg  [ 3:0] f_start;
	reg  [ 2:0] f_c0;
	reg  [ 7:0] f_left;
	reg         f_acc;

	reg  [ 7:0] h_left;
	reg         h_v1 = 0, h_v2 = 0;
	reg         h_acc = 0;

	reg         pf_pend = 0;
	reg  [ 2:0] pf_e;
	reg  [ 9:0] pf_blk;
	reg  [ 2:0] pf_chunk;
	reg  [ 3:0] pf_cnt;
	reg         pf_issued;

	reg  [ 7:0] t1 = 0, t2 = 0;

	reg  [63:0] dout_r;
	reg         dready_r = 0;

	wire fwd = (st == ST_FWD);
	wire pf  = (st == ST_PF);

	assign m_BURSTCNT   = pf ? 8'd16 : s_BURSTCNT;
	assign m_ADDR       = pf ? {4'b0011, 8'd0, pf_blk, pf_chunk, 4'b0000} : s_ADDR;
	assign m_RD         = (fwd & f_rd & ~f_acc & s_RD) | (pf & ~pf_issued);
	assign m_WE         = fwd & ~f_rd & s_WE;
	assign m_DIN        = s_DIN;
	assign m_BE         = s_BE;

	assign s_BUSY       = fwd ? m_BUSY :
	                      (st == ST_HIT)  ? ~(dready_r | h_acc) :
	                      (st == ST_IDLE) ? (s_RD | s_WE) : 1'b1;
	assign s_DOUT       = fwd ? m_DOUT : dout_r;
	assign s_DOUT_READY = fwd ? m_DOUT_READY : dready_r;

	wire [ 7:0] s_cnt   = (s_BURSTCNT == 0) ? 8'd1 : s_BURSTCNT;
	wire [ 7:0] s_last  = {1'b0, s_ADDR[6:0]} + s_cnt - 8'd1;
	wire [ 2:0] c_first = s_ADDR[6:4];
	wire [ 2:0] c_last  = s_last[6:4];

	wire [ 7:0] d_hit_oh  = l_m & (~l_m + 1'd1);
	wire        d_hit_tag = |l_m;
	wire        d_hit     = q_rd && q_cached && |(l_full & d_hit_oh);
	wire [ 7:0] d_vmiss   = l_vmiss;
	wire [ 7:0] d_keep    = d_hit_tag ? d_hit_oh : d_vmiss;
	wire        d_dopf    = q_cached && q_big && q_rd && !q_last_blk && !l_pfdup;
	wire [ 7:0] d_nxm     = l_nx & ~d_keep;
	wire [ 7:0] d_nx_oh   = d_nxm & (~d_nxm + 1'd1);
	wire [ 7:0] d_pfvict  = d_hit_tag ? l_pfv_hit : l_pfv_miss;

	reg  [ 7:0] lk_m, lk_full, lk_nx, lk_nxfull, lk_a7, lk_a6, lk_pfe;
	always_comb begin
		for (int i = 0; i < NE; i++) begin
			lk_pfe[i]    = pf_pend && (pf_e == i[2:0]);
			lk_m[i]      = (tag[i] == q_blk) && (cval[i] != 0 || lk_pfe[i]);
			lk_full[i]   = (tag[i] == q_blk) && ((cval[i] & q_need) == q_need);
			lk_nx[i]     = (tag[i] == q_nblk) && (cval[i] != 0);
			lk_nxfull[i] = (cval[i] == 8'hFF);
			lk_a7[i]     = (age[i] == 3'd7);
			lk_a6[i]     = (age[i] == 3'd6);
		end
	end

	integer k;
	initial begin
		for (k = 0; k < NE; k = k + 1) begin tag[k] = 0; cval[k] = 0; age[k] = k[2:0]; end
	end

	always @(posedge clk) begin
		reg [2:0] at;
		at = 0;
		for (int i = 0; i < NE; i++) if (t1[i]) at = at | age[i];
		if (|t1) for (int i = 0; i < NE; i++)
			age[i] <= t1[i] ? 3'd0 : (age[i] < at) ? age[i] + 1'd1 : age[i];
		t1 <= t2;
		t2 <= 0;
		if (st == ST_DEC) begin
			t1 <= d_hit ? d_hit_oh : (q_cached && (d_hit_tag || q_rd)) ? d_keep : 8'd0;
			if (d_dopf) t2 <= |d_nxm ? d_nx_oh : d_pfvict;
		end
	end

	always @(posedge clk) begin
		wr_en    <= 0;
		dready_r <= 0;
		h_acc    <= 0;

		if (rst) begin
			st <= ST_IDLE;
			pf_pend <= 0;
			for (int i = 0; i < NE; i++) cval[i] <= 0;
			h_v1 <= 0; h_v2 <= 0;
		end else begin
			case (st)
				ST_IDLE: begin
					if ((s_RD || s_WE) && !t1 && !t2) begin
						q_rd       <= s_RD;
						q_blk      <= s_ADDR[16:7];
						q_nblk     <= s_ADDR[16:7] + 1'd1;
						q_last_blk <= &s_ADDR[16:7];
						q_off      <= s_ADDR[6:0];
						q_cnt      <= s_cnt;
						q_cached   <= (s_ADDR[24:17] == 8'd0) && !s_last[7];
						q_need     <= (8'hFF << c_first) & (8'hFF >> (3'd7 - c_last));
						q_big      <= (s_cnt > 8'd16);
						st         <= ST_LK;
					end
					else if (!(s_RD || s_WE) && pf_pend && !pf_hold) begin
						if (cval[pf_e][pf_chunk]) begin
							pf_chunk <= pf_chunk + 1'd1;
							if (pf_chunk == 3'd7) pf_pend <= 0;
						end else begin
							pf_issued <= 0;
							pf_cnt    <= 4'd0;
							st        <= ST_PF;
						end
					end
				end

				ST_LK: begin
					l_m        <= lk_m;
					l_full     <= lk_full;
					l_nx       <= lk_nx;
					l_nxfull   <= lk_nxfull;
					l_pfe      <= lk_pfe;
					l_vmiss    <= |(lk_a7 & lk_pfe) ? lk_a6 : lk_a7;
					l_pfv_miss <= |(lk_a7 & lk_pfe) ? lk_a7 : lk_a6;
					l_pfv_hit  <= |(lk_a7 & lk_m)   ? lk_a6 : lk_a7;
					l_pfdup    <= pf_pend && (pf_blk == q_nblk);
					st <= ST_DEC;
				end

				ST_DEC: begin
					if (d_hit) begin
						rd_a   <= {enc8(d_hit_oh), q_off};
						h_left <= q_cnt;
						h_v1   <= 1;
						h_acc  <= 1;
						st     <= ST_HIT;
					end else begin
						f_rd    <= q_rd;
						f_acc   <= 0;
						f_pos   <= q_off;
						f_start <= q_off[3:0];
						f_c0    <= q_off[6:4];
						f_left  <= q_cnt;
						f_cache <= 0;
						if (q_cached) begin
							if (d_hit_tag) begin
								f_cache <= 1; f_e <= enc8(d_hit_oh);
							end else if (q_rd) begin
								f_cache <= 1; f_e <= enc8(d_vmiss);
								tag[enc8(d_vmiss)]  <= q_blk;
								cval[enc8(d_vmiss)] <= 0;
								if (|(l_pfe & d_vmiss)) pf_pend <= 0;
							end
						end
						st <= ST_FWD;
					end

					if (d_dopf) begin
						if (|d_nxm) begin
							if (!(|(d_nx_oh & l_nxfull))) begin
								pf_e <= enc8(d_nx_oh); pf_blk <= q_nblk; pf_chunk <= 0; pf_pend <= 1;
							end
						end else begin
							pf_e     <= enc8(d_pfvict);
							pf_blk   <= q_nblk;
							pf_chunk <= 0;
							pf_pend  <= 1;
							tag[enc8(d_pfvict)]  <= q_nblk;
							cval[enc8(d_pfvict)] <= 0;
						end
					end
				end

				ST_HIT: begin
					if (h_v1) begin
						h_v2 <= 1;
						h_left <= h_left - 1'd1;
						if (h_left == 1) h_v1 <= 0;
						else rd_a[6:0] <= rd_a[6:0] + 1'd1;
					end else h_v2 <= 0;
					if (h_v2) begin
						dout_r   <= rd_q;
						dready_r <= 1;
					end
					if (!h_v1 && !h_v2) st <= ST_IDLE;
				end

				ST_FWD: begin
					if (m_RD && !m_BUSY) f_acc <= 1;
					if (f_rd ? m_DOUT_READY : (s_WE && !m_BUSY)) begin
						if (f_cache) begin
							wr_a  <= {f_e, f_pos};
							wr_d  <= f_rd ? m_DOUT : s_DIN;
							wr_be <= f_rd ? 8'hFF : s_BE;
							wr_en <= 1;
							if (f_rd && f_pos[3:0] == 4'hF && (f_pos[6:4] != f_c0 || f_start == 4'h0))
								cval[f_e][f_pos[6:4]] <= 1;
						end
						f_pos  <= f_pos + 1'd1;
						f_left <= f_left - 1'd1;
						if (f_left == 1) st <= ST_IDLE;
					end
				end

				ST_PF: begin
					if (!pf_issued && !m_BUSY) pf_issued <= 1;
					if (m_DOUT_READY) begin
						wr_a  <= {pf_e, pf_chunk, pf_cnt};
						wr_d  <= m_DOUT;
						wr_be <= 8'hFF;
						wr_en <= 1;
						pf_cnt <= pf_cnt + 1'd1;
						if (pf_cnt == 4'hF) begin
							cval[pf_e][pf_chunk] <= 1;
							pf_chunk <= pf_chunk + 1'd1;
							if (pf_chunk == 3'd7) pf_pend <= 0;
							st <= ST_IDLE;
						end
					end
				end

				default: st <= ST_IDLE;
			endcase
		end
	end

endmodule
