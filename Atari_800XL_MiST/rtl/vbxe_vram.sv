module vbxe_vram
(
	input             clk_sys,
	input             clk_mem,
	input             reset,

	input      [18:0] a_addr,
	input             a_req,
	output reg        a_ready = 0,
	output reg  [7:0] a_dout,
	input      [18:0] a_hint0,
	input      [18:0] a_hint1,
	input      [18:0] a_hint2,

	input      [18:0] addr,
	input       [7:0] din,
	input             req,
	input             we,
	output reg        ready = 0,
	output reg  [7:0] dout,

	output     [12:0] SDRAM_A,
	inout      [15:0] SDRAM_DQ,
	output            SDRAM_DQML,
	output            SDRAM_DQMH,
	output            SDRAM_nWE,
	output            SDRAM_nCAS,
	output            SDRAM_nRAS,
	output            SDRAM_nCS,
	output      [1:0] SDRAM_BA,
	output            SDRAM_CKE
);

localparam NL = 8;
localparam NA = 8;
localparam NW = 2;

reg          c_valid[NL];
reg   [14:0] c_tag[NL];
reg  [127:0] c_data[NL];
reg    [3:0] c_age[NL];

reg          a_valid[NA];
reg   [14:0] a_tag[NA];
reg  [127:0] a_data[NA];
reg    [3:0] a_age[NA];
reg          a_new[NA];

reg          w_valid[NW];
reg   [14:0] w_tag[NW];
reg  [127:0] w_data[NW];
reg   [15:0] w_mask[NW];
reg          w_old = 0;

reg          e_req_t = 0;
wire         e_done_t;
reg          e_flush;
reg   [14:0] e_line;
reg    [2:0] e_word;
reg  [127:0] e_wdata;
reg   [15:0] e_wmask;
wire [127:0] e_rdata;
wire         e_first_t;
wire  [15:0] e_rfirst;
reg          e_done_s = 0;
always @(posedge clk_sys) e_done_s <= e_done_t;
wire         e_busy = e_req_t ^ e_done_s;

reg          op_fill = 0;
reg          op_to_a;
reg    [2:0] op_slot;
reg   [14:0] op_line;
reg          op_demand = 0;
reg          op_demand_a = 0;

reg          ha_req = 0;
reg   [18:0] ra_addr;
wire  [14:0] ia_line = a_addr[18:4];
wire  [14:0] ra_line = ra_addr[18:4];

reg          have_req = 0;
reg   [18:0] r_addr;
reg    [7:0] r_din;
reg          r_we;

reg          pf_want = 0;
reg   [14:0] pf_line;

reg          q_valid = 0;
reg   [14:0] q_line;
reg    [2:0] h_valid = 0;
reg   [14:0] h_line[3];
reg   [14:0] h_last[3];
reg   [14:0] h_prev;

wire  [14:0] i_line = addr[18:4];
wire   [3:0] i_byte = addr[3:0];
wire  [14:0] r_line = r_addr[18:4];
wire   [3:0] r_byte = r_addr[3:0];

integer i;
initial begin
	for(i = 0; i < NL; i = i + 1) begin c_valid[i] = 0; c_age[i] = 4'd15; end
	for(i = 0; i < NA; i = i + 1) begin a_valid[i] = 0; a_age[i] = 4'd15; a_new[i] = 0; end
	for(i = 0; i < NW; i = i + 1) begin w_valid[i] = 0; w_mask[i] = 0; end
end

reg          p_valid;
reg   [14:0] p_line;
reg    [1:0] p_src;
always @(*) begin
	p_valid = 1; p_line = q_line; p_src = 3;
	if(q_valid) ;
	else if(h_valid[0]) begin p_line = h_line[0]; p_src = 0; end
	else if(h_valid[1]) begin p_line = h_line[1]; p_src = 1; end
	else if(h_valid[2]) begin p_line = h_line[2]; p_src = 2; end
	else p_valid = 0;
end

reg       aai_hit;  reg [2:0] aai_idx;
reg       aar_hit;  reg [2:0] aar_idx;
reg       car_hit;  reg [2:0] car_idx;
reg       war_hit;  reg       war_idx;
reg       aap_hit;
reg       cap_hit;  reg [2:0] cap_idx;
reg       wap_hit;  reg       wap_idx;
reg       ci_hit;   reg [2:0] ci_idx;
reg       wi_hit;   reg       wi_idx;
reg       ai_hit;   reg [2:0] ai_idx;
reg       cr_hit;   reg [2:0] cr_idx;
reg       wr_hit;   reg       wr_idx;
reg       ar_hit;   reg [2:0] ar_idx;
reg       pf_c_hit;
reg       pf_w_hit;
reg       pf_stream;
reg [2:0] victim;   reg [3:0] vage;
reg [2:0] a_victim; reg [3:0] a_vage;
reg       a_pin[NA];
always @(*) begin
	for(i = 0; i < NA; i = i + 1) a_pin[i] = a_tag[i] == h_last[0] || a_tag[i] == h_prev || a_tag[i] == h_last[1] || a_tag[i] == h_last[2];
	aai_hit = 0; aai_idx = 0;
	for(i = 0; i < NA; i = i + 1) if(a_valid[i] && a_tag[i] == ia_line) begin aai_hit = 1; aai_idx = i[2:0]; end
	aar_hit = 0; aar_idx = 0;
	for(i = 0; i < NA; i = i + 1) if(a_valid[i] && a_tag[i] == ra_line) begin aar_hit = 1; aar_idx = i[2:0]; end
	car_hit = 0; car_idx = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == ra_line) begin car_hit = 1; car_idx = i[2:0]; end
	war_hit = 0; war_idx = 0;
	for(i = 0; i < NW; i = i + 1) if(w_valid[i] && w_tag[i] == ra_line) begin war_hit = 1; war_idx = i[0]; end
	aap_hit = 0;
	for(i = 0; i < NA; i = i + 1) if(a_valid[i] && a_tag[i] == p_line) aap_hit = 1;
	cap_hit = 0; cap_idx = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == p_line) begin cap_hit = 1; cap_idx = i[2:0]; end
	wap_hit = 0; wap_idx = 0;
	for(i = 0; i < NW; i = i + 1) if(w_valid[i] && w_tag[i] == p_line) begin wap_hit = 1; wap_idx = i[0]; end
	ci_hit = 0; ci_idx = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == i_line) begin ci_hit = 1; ci_idx = i[2:0]; end
	wi_hit = 0; wi_idx = 0;
	for(i = 0; i < NW; i = i + 1) if(w_valid[i] && w_tag[i] == i_line) begin wi_hit = 1; wi_idx = i[0]; end
	ai_hit = 0; ai_idx = 0;
	for(i = 0; i < NA; i = i + 1) if(a_valid[i] && a_tag[i] == i_line) begin ai_hit = 1; ai_idx = i[2:0]; end
	cr_hit = 0; cr_idx = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == r_line) begin cr_hit = 1; cr_idx = i[2:0]; end
	wr_hit = 0; wr_idx = 0;
	for(i = 0; i < NW; i = i + 1) if(w_valid[i] && w_tag[i] == r_line) begin wr_hit = 1; wr_idx = i[0]; end
	ar_hit = 0; ar_idx = 0;
	for(i = 0; i < NA; i = i + 1) if(a_valid[i] && a_tag[i] == r_line) begin ar_hit = 1; ar_idx = i[2:0]; end
	pf_c_hit = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == pf_line) pf_c_hit = 1;
	pf_w_hit = 0;
	for(i = 0; i < NW; i = i + 1) if(w_valid[i] && w_tag[i] == pf_line) pf_w_hit = 1;
	pf_stream = 0;
	for(i = 0; i < NL; i = i + 1) if(c_valid[i] && c_tag[i] == pf_line - 15'd2) pf_stream = 1;
	victim = 0; vage = 0;
	for(i = 0; i < NL; i = i + 1) if(!c_valid[i] || c_age[i] >= vage) begin
		if(!c_valid[i]) vage = 4'd15; else vage = c_age[i];
		victim = i[2:0];
	end
	a_victim = 0; a_vage = 0;
	for(i = 0; i < NA; i = i + 1) if(!(op_fill && op_to_a && op_slot == i[2:0]) && (!a_valid[i] || (!a_pin[i] && a_age[i] >= a_vage))) begin
		if(!a_valid[i]) a_vage = 4'd15; else a_vage = a_age[i];
		a_victim = i[2:0];
	end
end

wire w_free0 = ~w_valid[0];
wire w_free1 = ~w_valid[1];
wire engine_free = !e_busy && !op_fill;
wire b_wr_ra = (req && we && i_line == ra_line) || (have_req && r_we && r_line == ra_line);
wire b_wr_p  = (req && we && i_line == p_line)  || (have_req && r_we && r_line == p_line);

reg       ta_en, tb_en, tn_en;
reg [2:0] ta_idx, tb_idx, tn_idx;

always @(posedge clk_sys) begin
	reg pf_new;
	reg eng_used;
	reg q_push;
	reg [14:0] q_push_line;
	reg a_slot_used;
	ready <= 0;
	a_ready <= 0;
	pf_new = 0;
	eng_used = 0;
	q_push = 0; q_push_line = 0;
	a_slot_used = 0;
	ta_en = 0; tb_en = 0; tn_en = 0; ta_idx = 0; tb_idx = 0; tn_idx = 0;

	for(i = 0; i < 3; i = i + 1) begin
		reg [14:0] hl;
		hl = (i == 0) ? a_hint0[18:4] : (i == 1) ? a_hint1[18:4] : a_hint2[18:4];
		if(hl != h_last[i]) begin
			h_last[i] <= hl;
			if(i == 0) h_prev <= h_last[0];
			h_line[i] <= hl;
			h_valid[i] <= 1;
		end
	end

	if(op_fill && !e_busy) begin
		op_fill <= 0;
		if(op_to_a) begin
			a_valid[op_slot] <= 1;
			a_tag[op_slot] <= op_line;
			a_data[op_slot] <= e_rdata;
			a_new[op_slot] <= 1;
			tn_en = 1; tn_idx = op_slot;
		end
		else begin
			c_valid[op_slot] <= 1;
			c_tag[op_slot] <= op_line;
			c_data[op_slot] <= e_rdata;
		end
	end

	if(reset) begin
		ha_req <= 0;
		op_demand_a <= 0;
		q_valid <= 0;
		h_valid <= 0;
		for(i = 0; i < NA; i = i + 1) a_valid[i] <= 0;
	end
	else if(ha_req) begin
		if(op_demand_a) begin
			if(e_first_t == e_req_t) begin
				op_demand_a <= 0;
				a_dout <= ra_addr[0] ? e_rfirst[15:8] : e_rfirst[7:0];
				a_ready <= 1;
				ha_req <= 0;
				q_push = 1; q_push_line = ra_line + 1'd1;
			end
		end
		else if(aar_hit) begin
			a_dout <= a_data[aar_idx][{ra_addr[3:0], 3'b000} +: 8];
			a_ready <= 1;
			ha_req <= 0;
			ta_en = 1; ta_idx = aar_idx;
			if(a_new[aar_idx]) begin a_new[aar_idx] <= 0; q_push = 1; q_push_line = ra_line + 1'd1; end
		end
		else if(car_hit && !b_wr_ra) begin
			a_slot_used = 1;
			a_valid[a_victim] <= 1;
			a_tag[a_victim] <= ra_line;
			a_data[a_victim] <= c_data[car_idx];
			a_new[a_victim] <= 0;
			tn_en = 1; tn_idx = a_victim;
			a_dout <= c_data[car_idx][{ra_addr[3:0], 3'b000} +: 8];
			a_ready <= 1;
			ha_req <= 0;
			q_push = 1; q_push_line = ra_line + 1'd1;
		end
		else if(op_fill && op_line == ra_line) ;
		else if(engine_free && !b_wr_ra) begin
			eng_used = 1;
			if(war_hit) begin
				e_flush <= 1;
				e_line <= w_tag[war_idx];
				e_wdata <= w_data[war_idx];
				e_wmask <= w_mask[war_idx];
				e_req_t <= ~e_req_t;
				w_valid[war_idx] <= 0;
				w_mask[war_idx] <= 0;
			end
			else begin
				e_flush <= 0;
				e_line <= ra_line;
				e_word <= ra_addr[3:1];
				e_req_t <= ~e_req_t;
				op_fill <= 1;
				op_to_a <= 1;
				op_demand_a <= 1;
				op_slot <= a_victim;
				op_line <= ra_line;
				a_valid[a_victim] <= 0;
				a_slot_used = 1;
			end
		end
	end
	else if(a_req) begin
		ra_addr <= a_addr;
		if(aai_hit) begin
			a_dout <= a_data[aai_idx][{a_addr[3:0], 3'b000} +: 8];
			a_ready <= 1;
			ta_en = 1; ta_idx = aai_idx;
			if(a_new[aai_idx]) begin a_new[aai_idx] <= 0; q_push = 1; q_push_line = ia_line + 1'd1; end
		end
		else ha_req <= 1;
	end

	if(!reset && p_valid && !a_slot_used && !(ha_req && !aar_hit)) begin
		if(aap_hit || (op_fill && op_line == p_line)) begin
			if(p_src == 3) q_valid <= 0; else h_valid[p_src] <= 0;
		end
		else if(b_wr_p) ;
		else if(cap_hit) begin
			a_valid[a_victim] <= 1;
			a_tag[a_victim] <= p_line;
			a_data[a_victim] <= c_data[cap_idx];
			a_new[a_victim] <= 1;
			tn_en = 1; tn_idx = a_victim;
			if(p_src == 3) q_valid <= 0; else h_valid[p_src] <= 0;
		end
		else if(engine_free && !eng_used) begin
			eng_used = 1;
			if(wap_hit) begin
				e_flush <= 1;
				e_line <= w_tag[wap_idx];
				e_wdata <= w_data[wap_idx];
				e_wmask <= w_mask[wap_idx];
				e_req_t <= ~e_req_t;
				w_valid[wap_idx] <= 0;
				w_mask[wap_idx] <= 0;
			end
			else begin
				e_flush <= 0;
				e_line <= p_line;
				e_word <= 0;
				e_req_t <= ~e_req_t;
				op_fill <= 1;
				op_to_a <= 1;
				op_slot <= a_victim;
				op_line <= p_line;
				a_valid[a_victim] <= 0;
				if(p_src == 3) q_valid <= 0; else h_valid[p_src] <= 0;
			end
		end
	end
	if(!reset && q_push) begin
		q_valid <= 1;
		q_line <= q_push_line;
	end

	if(ha_req && !op_demand_a && !aar_hit && !b_wr_ra) eng_used = 1;

	if(reset) begin
		have_req <= 0;
		op_fill <= 0;
		op_demand <= 0;
		pf_want <= 0;
		for(i = 0; i < NL; i = i + 1) c_valid[i] <= 0;
	end
	else if(have_req) begin
		if(op_demand) begin
			if(e_first_t == e_req_t) begin
				op_demand <= 0;
				dout <= r_addr[0] ? e_rfirst[15:8] : e_rfirst[7:0];
				ready <= 1;
				have_req <= 0;
				pf_want <= 1;
				pf_line <= r_line + 1'd1;
				pf_new = 1;
			end
		end
		else if(!r_we) begin
			if(cr_hit) begin
				dout <= c_data[cr_idx][{r_byte, 3'b000} +: 8];
				ready <= 1;
				have_req <= 0;
				tb_en = 1; tb_idx = cr_idx;
				pf_want <= 1;
				pf_line <= r_line + 1'd1;
				pf_new = 1;
			end
			else if(engine_free && !eng_used) begin
				eng_used = 1;
				if(wr_hit) begin
					e_flush <= 1;
					e_line <= w_tag[wr_idx];
					e_wdata <= w_data[wr_idx];
					e_wmask <= w_mask[wr_idx];
					e_req_t <= ~e_req_t;
					w_valid[wr_idx] <= 0;
					w_mask[wr_idx] <= 0;
				end
				else begin
					e_flush <= 0;
					e_line <= r_line;
					e_word <= r_addr[3:1];
					e_req_t <= ~e_req_t;
					op_fill <= 1;
					op_to_a <= 0;
					op_demand <= 1;
					op_slot <= victim;
					op_line <= r_line;
					c_valid[victim] <= 0;
				end
			end
		end
		else if(!(op_fill && op_line == r_line)) begin
			if(wr_hit || w_free0 || w_free1 || (engine_free && !eng_used)) begin
				if(cr_hit) begin c_data[cr_idx][{r_byte, 3'b000} +: 8] <= r_din; tb_en = 1; tb_idx = cr_idx; end
				if(ar_hit) a_data[ar_idx][{r_byte, 3'b000} +: 8] <= r_din;
				ready <= 1;
				have_req <= 0;
			end
			if(wr_hit) begin
				w_data[wr_idx][{r_byte, 3'b000} +: 8] <= r_din;
				w_mask[wr_idx][r_byte] <= 1;
			end
			else if(w_free0 || w_free1) begin
				w_valid[w_free0 ? 1'd0 : 1'd1] <= 1;
				w_tag[w_free0 ? 1'd0 : 1'd1] <= r_line;
				w_data[w_free0 ? 1'd0 : 1'd1][{r_byte, 3'b000} +: 8] <= r_din;
				w_mask[w_free0 ? 1'd0 : 1'd1] <= 16'd1 << r_byte;
				w_old <= w_free0 ? 1'd1 : 1'd0;
			end
			else if(engine_free && !eng_used) begin
				eng_used = 1;
				e_flush <= 1;
				e_line <= w_tag[w_old];
				e_wdata <= w_data[w_old];
				e_wmask <= w_mask[w_old];
				e_req_t <= ~e_req_t;
				w_tag[w_old] <= r_line;
				w_data[w_old][{r_byte, 3'b000} +: 8] <= r_din;
				w_mask[w_old] <= 16'd1 << r_byte;
				w_old <= ~w_old;
			end
		end
	end
	else if(req) begin
		r_addr <= addr;
		r_din <= din;
		r_we <= we;
		if(!we) begin
			if(ci_hit) begin
				dout <= c_data[ci_idx][{i_byte, 3'b000} +: 8];
				ready <= 1;
				tb_en = 1; tb_idx = ci_idx;
				if(i_byte[3]) begin
					pf_want <= 1;
					pf_line <= i_line + 1'd1;
					pf_new = 1;
				end
			end
			else have_req <= 1;
		end
		else if(!(op_fill && op_line == i_line) && (wi_hit || w_free0 || w_free1)) begin
			if(ci_hit) begin c_data[ci_idx][{i_byte, 3'b000} +: 8] <= din; tb_en = 1; tb_idx = ci_idx; end
			if(ai_hit) a_data[ai_idx][{i_byte, 3'b000} +: 8] <= din;
			if(wi_hit) begin
				w_data[wi_idx][{i_byte, 3'b000} +: 8] <= din;
				w_mask[wi_idx][i_byte] <= 1;
			end
			else begin
				w_valid[w_free0 ? 1'd0 : 1'd1] <= 1;
				w_tag[w_free0 ? 1'd0 : 1'd1] <= i_line;
				w_data[w_free0 ? 1'd0 : 1'd1][{i_byte, 3'b000} +: 8] <= din;
				w_mask[w_free0 ? 1'd0 : 1'd1] <= 16'd1 << i_byte;
				w_old <= w_free0 ? 1'd1 : 1'd0;
			end
			ready <= 1;
		end
		else have_req <= 1;
	end

	if(!reset && !have_req && !eng_used && engine_free && !p_valid) begin
		if(w_valid[0] && w_valid[1] && !req) begin
			e_flush <= 1;
			e_line <= w_tag[w_old];
			e_wdata <= w_data[w_old];
			e_wmask <= w_mask[w_old];
			e_req_t <= ~e_req_t;
			w_valid[w_old] <= 0;
			w_mask[w_old] <= 0;
			w_old <= ~w_old;
		end
		else if(pf_want && !(req && we)) begin
			if(!pf_new) pf_want <= 0;
			if(!pf_c_hit && !pf_w_hit && pf_stream) begin
				e_flush <= 0;
				e_line <= pf_line;
				e_word <= 0;
				e_req_t <= ~e_req_t;
				op_fill <= 1;
				op_to_a <= 0;
				op_slot <= victim;
				op_line <= pf_line;
				c_valid[victim] <= 0;
			end
		end
	end

	if(tb_en)
		for(i = 0; i < NL; i = i + 1)
			if(i[2:0] == tb_idx) c_age[i] <= 0;
			else if(c_age[i] != 4'd15) c_age[i] <= c_age[i] + 1'd1;
	if(ta_en || tn_en)
		for(i = 0; i < NA; i = i + 1)
			if((ta_en && i[2:0] == ta_idx) || (tn_en && i[2:0] == tn_idx)) a_age[i] <= 0;
			else if(a_age[i] != 4'd15) a_age[i] <= a_age[i] + 1'd1;
end

vbxe_sdram sdram
(
	.clk(clk_mem),
	.reset(reset),
	.req_t(e_req_t),
	.done_t(e_done_t),
	.flush(e_flush),
	.line(e_line),
	.word(e_word),
	.wdata(e_wdata),
	.wmask(e_wmask),
	.rdata(e_rdata),
	.first_t(e_first_t),
	.rfirst(e_rfirst),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_CKE(SDRAM_CKE)
);

endmodule

module vbxe_sdram
(
	input              clk,
	input              reset,

	input              req_t,
	output reg         done_t = 0,
	input              flush,
	input       [14:0] line,
	input        [2:0] word,
	input      [127:0] wdata,
	input       [15:0] wmask,
	output reg [127:0] rdata,
	output reg         first_t = 0,
	output reg  [15:0] rfirst,

	output reg  [12:0] SDRAM_A,
	inout       [15:0] SDRAM_DQ,
	output reg         SDRAM_DQML,
	output reg         SDRAM_DQMH,
	output             SDRAM_nWE,
	output             SDRAM_nCAS,
	output             SDRAM_nRAS,
	output             SDRAM_nCS,
	output reg   [1:0] SDRAM_BA,
	output reg         SDRAM_CKE = 0
);

localparam CMD_NOP   = 4'b0111;
localparam CMD_ACT   = 4'b0011;
localparam CMD_READ  = 4'b0101;
localparam CMD_WRITE = 4'b0100;
localparam CMD_PRE   = 4'b0010;
localparam CMD_REF   = 4'b0001;
localparam CMD_MRS   = 4'b0000;

reg  [3:0] cmd = CMD_NOP;
assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = cmd;

reg [15:0] dq_out;
reg        dq_oe = 0;
assign SDRAM_DQ = dq_oe ? dq_out : 16'bZ;
reg [15:0] dq_in;
always @(posedge clk) dq_in <= SDRAM_DQ;

localparam S_INIT = 0, S_IDLE = 1, S_FILL = 2, S_FLUSH = 3, S_REF = 4;
reg  [2:0] state = S_INIT;
reg [14:0] cnt = 0;
reg [10:0] ref_cnt = 0;
reg        ref_req = 0;
reg        seen_t = 0;
reg [14:0] l_line;
reg  [2:0] l_word;
reg [127:0] l_wdata;
reg  [15:0] l_wmask;
reg        l_flush;

wire [17:0] w_addr = {l_line, 3'b000};

always @(posedge clk) begin
	cmd <= CMD_NOP;
	dq_oe <= 0;
	SDRAM_DQML <= 1;
	SDRAM_DQMH <= 1;

	if(ref_cnt == 11'd800) ref_req <= 1;
	else ref_cnt <= ref_cnt + 1'd1;

	if(reset) begin
		state <= S_INIT;
		cnt <= 0;
		seen_t <= done_t;
		SDRAM_CKE <= 0;
		ref_req <= 0;
		ref_cnt <= 0;
	end
	else case(state)
		S_INIT: begin
			SDRAM_CKE <= 1;
			cnt <= cnt + 1'd1;
			case(cnt)
				15'd12000: begin cmd <= CMD_PRE; SDRAM_A[10] <= 1; end
				15'd12004: cmd <= CMD_REF;
				15'd12014: cmd <= CMD_REF;
				15'd12024: begin
					cmd <= CMD_MRS;
					SDRAM_BA <= 0;
					SDRAM_A <= 13'b000_0_00_011_0_011;
				end
				15'd12030: state <= S_IDLE;
				default: ;
			endcase
		end

		S_IDLE: begin
			cnt <= 0;
			if(ref_req) begin
				ref_req <= 0;
				ref_cnt <= 0;
				cmd <= CMD_REF;
				state <= S_REF;
			end
			else if(req_t != seen_t) begin
				seen_t <= req_t;
				l_line <= line;
				l_word <= flush ? 3'd0 : word;
				l_wdata <= wdata;
				l_wmask <= wmask;
				l_flush <= flush;
				state <= flush ? S_FLUSH : S_FILL;
				cmd <= CMD_ACT;
				SDRAM_BA <= line[7:6];
				SDRAM_A <= {6'd0, line[14:8]};
			end
		end

		S_REF: begin
			cnt <= cnt + 1'd1;
			if(cnt == 15'd8) state <= S_IDLE;
		end

		S_FILL: begin
			cnt <= cnt + 1'd1;
			if(cnt == 15'd2) begin
				cmd <= CMD_READ;
				SDRAM_A <= {2'b00, 1'b1, 1'b0, w_addr[8:3], l_word};
			end
			if(cnt <= 15'd12) begin
				SDRAM_DQML <= 0;
				SDRAM_DQMH <= 0;
			end
			if(cnt >= 15'd7 && cnt <= 15'd14) rdata[{cnt[2:0] - 3'd7 + l_word, 4'b0000} +: 16] <= dq_in;
			if(cnt == 15'd7) rfirst <= dq_in;
			if(cnt == 15'd8) first_t <= seen_t;
			if(cnt == 15'd15) done_t <= seen_t;
			if(cnt == 15'd18) state <= S_IDLE;
		end

		S_FLUSH: begin
			cnt <= cnt + 1'd1;
			if(cnt >= 15'd2 && cnt <= 15'd9) begin
				if(cnt == 15'd2) begin
					cmd <= CMD_WRITE;
					SDRAM_A <= {2'b00, 1'b1, 1'b0, w_addr[8:0]};
				end
				dq_oe <= 1;
				dq_out <= l_wdata[{cnt[2:0] - 3'd2, 4'b0000} +: 16];
				{SDRAM_DQMH, SDRAM_DQML} <= ~l_wmask[{cnt[2:0] - 3'd2, 1'b0} +: 2];
			end
			if(cnt == 15'd10) begin done_t <= seen_t; first_t <= seen_t; end
			if(cnt == 15'd16) state <= S_IDLE;
		end

		default: state <= S_INIT;
	endcase
end

endmodule
