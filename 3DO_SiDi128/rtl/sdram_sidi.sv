module sdram_sidi
(
	inout      [15: 0] SDRAM_DQ,
	output reg [12: 0] SDRAM_A,
	output             SDRAM_DQML,
	output             SDRAM_DQMH,
	output reg [ 1: 0] SDRAM_BA,
	output             SDRAM_nCS,
	output reg         SDRAM_nWE = 1,
	output reg         SDRAM_nRAS = 1,
	output reg         SDRAM_nCAS = 1,
	output             SDRAM_CKE,

	input              clk_sys,
	input              init,
	input              clk,
	input              sync,

	input      [22: 2] laddr,
	input      [ 1: 0] lwe,
	input              lras,
	input      [ 3: 0] lcode,
	input      [22: 2] raddr,
	input      [ 1: 0] rwe,
	input              rras,
	input      [ 3: 0] rcode,

	input      [31: 0] din,
	output     [31: 0] dout,

	input              rfs,

	input              x_quiet,
	input              x_req,
	output reg         x_own = 0,
	input      [ 2: 0] x_cmd,
	input      [12: 0] x_a,
	input      [ 1: 0] x_ba,
	input      [15: 0] x_dq,
	input              x_oe,
	input      [ 1: 0] x_dqm,
	output     [15: 0] x_din
);

	reg [22:2] laddr_r, raddr_r;
	reg [ 1:0] lwe_r, rwe_r;
	reg        lras_r, rras_r;
	reg [ 3:0] lcode_r, rcode_r;
	reg [31:0] din_r;
	reg        rfs_r, sync_r, init_r;
	reg        l_act, l_rd, l_wr, l_rf, r_act, r_rd, r_wr;
	always @(posedge clk_sys) begin
		laddr_r <= laddr; lwe_r <= lwe; lras_r <= lras; lcode_r <= lcode;
		raddr_r <= raddr; rwe_r <= rwe; rras_r <= rras; rcode_r <= rcode;
		din_r   <= din;   rfs_r <= rfs; sync_r <= sync; init_r <= init;
		l_act <= lras && lcode == 4'h8;
		l_rd  <= lras && lcode == 4'h1;
		l_wr  <= lras && lcode == 4'h2;
		l_rf  <= (lras && (lcode == 4'h4 || lcode == 4'hC)) || (!lras && !rras && lcode == 4'h2);
		r_act <= rras && rcode == 4'h8;
		r_rd  <= rras && rcode == 4'h1;
		r_wr  <= rras && rcode == 4'h2;
	end

	localparam RASCAS_DELAY   = 3'd2;
	localparam BURST          = 3'd0;
	localparam ACCESS_TYPE    = 1'd0;
	localparam CAS_LATENCY    = 3'd2;
	localparam OP_MODE        = 2'd0;
	localparam NO_WRITE_BURST = 1'd1;

	localparam bit [12:0] MODE = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST};

	localparam STATE_IDLE  = 3'd0;
	localparam STATE_START = STATE_IDLE+1'd1;
	localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
	localparam STATE_READY = STATE_CONT+CAS_LATENCY+1'd1;
	localparam STATE_LAST  = STATE_READY;

	localparam MODE_NORMAL = 2'b00;
	localparam MODE_RESET  = 2'b01;
	localparam MODE_LDM    = 2'b10;
	localparam MODE_PRE    = 2'b11;

	reg [2:0] init_state = '0;
	reg [1:0] mode;
	reg       init_done = 0;
	reg [4:0] init_reset = 5'h1f;
	reg       init_old = 0;
	always @(posedge clk) begin
		if(mode != MODE_NORMAL || init_state != STATE_IDLE || init_reset) begin
			init_state <= init_state + 1'd1;
			if (init_state == STATE_LAST) init_state <= STATE_IDLE;
		end

		init_old <= init_r;
		if (init_old & ~init_r) begin
			init_reset <= 5'h1f;
			init_done <= 0;
		end
		else if (init_state == STATE_LAST) begin
			if(init_reset != 0) begin
				init_reset <= init_reset - 5'd1;
				if (init_reset == 15 || init_reset == 14) begin mode <= MODE_PRE; end
				else if(init_reset == 4 || init_reset == 3) begin mode <= MODE_LDM; end
				else                mode <= MODE_RESET;
			end
			else begin
				mode <= MODE_NORMAL;
				init_done <= 1;
			end
		end
	end

	localparam CTRL_IDLE = 2'd0;
	localparam CTRL_RAS = 2'd1;
	localparam CTRL_CAS = 2'd2;
	localparam CTRL_PRE = 2'd3;

	typedef struct packed
	{
		bit [ 1:0] CMD;
		bit [ 1:0] BANK;
		bit [22:1] ADDR;
		bit [15:0] DATA;
		bit        RD;
		bit        WE;
		bit [ 1:0] BE;
		bit        RFS;
	} state_t;
	state_t state[6];
	reg [ 3: 0] st_num;

	reg sync_old;
	wire sync_edge = sync_r && !sync_old;

	reg       quiet_r;
	reg [3:0] q_cnt = 0;
	reg       gate = 0;
	reg [2:0] g_cnt = 0;
	always @(posedge clk) begin
		quiet_r <= x_quiet;
		if (!init_done || !x_req || !quiet_r || sync_edge) q_cnt <= 0;
		else if (q_cnt != 4'hF) q_cnt <= q_cnt + 1'd1;
		if (!x_req) begin
			gate <= 0; x_own <= 0; g_cnt <= 0;
		end else begin
			if (q_cnt >= 4'd9) gate <= 1;
			if (gate && g_cnt != 3'd7) g_cnt <= g_cnt + 1'd1;
			if (gate && g_cnt >= 3'd5) x_own <= 1;
		end
	end

	wire [3:0] st_nx = !init_done ? 4'd8 : sync_edge ? 4'd1 : (st_num < 4'd8) ? st_num + 4'd1 : st_num;
	reg  [7:0] ph = 8'd1;
	reg        ph_lw = 0, ph_rw = 0;
	always @(posedge clk) begin
		sync_old <= sync_r;
		st_num   <= st_nx;
		ph       <= 8'd1 << st_nx[2:0];
		ph_lw    <= st_nx[2:0] == 3'd2 || st_nx[2:0] == 3'd6;
		ph_rw    <= st_nx[2:0] == 3'd3 || st_nx[2:0] == 3'd7;
	end

	wire c_wr  = (ph_lw && l_wr && lpage_opened) || (ph_rw && r_wr && rpage_opened);
	wire c_rd  = (ph[0] && l_rd && lpage_opened) || (ph[1] && r_rd && rpage_opened);
	wire c_pre = (ph[0] && !lras_r && lpage_opened) || (ph[1] && !rras_r && rpage_opened);
	wire c_act = (ph[5] && l_act) || (ph[6] && r_act && !(l_wr && lpage_opened));
	wire c_rf  = ph[4] && l_rf;

	reg lpage_opened = 0, rpage_opened = 0;
	state_t st0;
	reg     lpage_set, lpage_clr, rpage_set, rpage_clr;
	always_comb begin
		st0 = '0;
		{lpage_set, lpage_clr, rpage_set, rpage_clr} = '0;
		if (!init_done) begin
			st0.CMD = init_state == STATE_START ? CTRL_RAS :
			          init_state == STATE_CONT  ? CTRL_CAS :
			                                      CTRL_IDLE;
			st0.RFS = 1;
		end else begin
			if (lras_r && lcode_r == 4'h8 && st_num[2:0] == 3'd5) begin
				st0.CMD  = CTRL_RAS;
				st0.ADDR = {laddr_r,1'b0};
				st0.BANK = 2'd0;
				lpage_set = 1;
			end
			if (rras_r && rcode_r == 4'h8 && st_num[2:0] == 3'd6) begin
				st0.CMD  = CTRL_RAS;
				st0.ADDR = {raddr_r,1'b0};
				st0.BANK = 2'd1;
				rpage_set = 1;
			end

			if (lras_r && lcode_r == 4'h1 && st_num[2:0] == 3'd0 && lpage_opened) begin
				st0.CMD  = CTRL_CAS;
				st0.ADDR = {laddr_r,1'b0};
				st0.RD   = 1;
				st0.BANK = 2'd0;
			end
			if (rras_r && rcode_r == 4'h1 && st_num[2:0] == 3'd1 && rpage_opened) begin
				st0.CMD  = CTRL_CAS;
				st0.ADDR = {raddr_r,1'b0};
				st0.RD   = 1;
				st0.BANK = 2'd1;
			end

			if (lras_r && lcode_r == 4'h2 && (st_num[2:0] == 3'd2 || st_num[2:0] == 3'd6) && lpage_opened) begin
				st0.CMD  = CTRL_CAS;
				st0.ADDR = {laddr_r,1'b0};
				st0.WE   = 1;
				st0.BE   = lwe_r;
				st0.DATA = din_r[31:16];
				st0.BANK = 2'd0;
			end
			if (rras_r && rcode_r == 4'h2 && (st_num[2:0] == 3'd3 || st_num[2:0] == 3'd7) && rpage_opened) begin
				st0.CMD  = CTRL_CAS;
				st0.ADDR = {raddr_r,1'b0};
				st0.WE   = 1;
				st0.BE   = rwe_r;
				st0.DATA = din_r[15:0];
				st0.BANK = 2'd1;
			end

			if (lras_r && (lcode_r == 4'h4 || lcode_r == 4'hC) && st_num[2:0] == 3'd4) begin
				st0.CMD  = CTRL_RAS;
				st0.BANK = 2'd0;
				st0.RFS  = 1;
			end
			else if (!lras_r && !rras_r && (lcode_r == 4'h2) && st_num[2:0] == 3'd4) begin
				st0.CMD  = CTRL_RAS;
				st0.BANK = 2'd0;
				st0.RFS  = 1;
			end

			if (!lras_r && lpage_opened && st_num[2:0] == 3'd0) begin
				st0.CMD  = CTRL_PRE;
				st0.BANK = 2'd0;
				lpage_clr = 1;
			end
			if (!rras_r && rpage_opened && st_num[2:0] == 3'd1) begin
				st0.CMD  = CTRL_PRE;
				st0.BANK = 2'd1;
				rpage_clr = 1;
			end
		end
	end

	always @(posedge clk) begin
		if (init_done && !gate) begin
			if (lpage_set) lpage_opened <= 1;
			if (lpage_clr) lpage_opened <= 0;
			if (rpage_set) rpage_opened <= 1;
			if (rpage_clr) rpage_opened <= 0;
		end
		state[0] <= gate ? '0 : st0;
		state[1] <= state[0];
		state[2] <= state[1];
		state[3] <= state[2];
		state[4] <= state[3];
		state[5] <= state[4];
	end

	wire [ 1:0] ctrl_cmd   = st0.CMD;
	wire [22:1] ctrl_addr  = st0.ADDR;
	wire [15:0] ctrl_data  = st0.DATA;
	wire        ctrl_we    = st0.WE;
	wire [ 1:0] ctrl_be    = st0.BE;
	wire [ 1:0] ctrl_bank  = st0.BANK;
	wire        ctrl_rfs   = st0.RFS;

	wire       out_read  = state[4].RD;
	reg [31:0] rbuf;
	assign x_din = rbuf[15:0];
	reg [31:0] dout_q;
	always @(posedge clk) begin
		rbuf <= {rbuf[15:0],SDRAM_DQ};
		if (out_read) dout_q <= rbuf;
	end
	assign dout = out_read ? rbuf : dout_q;

	localparam CMD_NOP             = 3'b111;
	localparam CMD_ACTIVE          = 3'b011;
	localparam CMD_READ            = 3'b101;
	localparam CMD_WRITE           = 3'b100;
	localparam CMD_BURST_TERMINATE = 3'b110;
	localparam CMD_PRECHARGE       = 3'b010;
	localparam CMD_AUTO_REFRESH    = 3'b001;
	localparam CMD_LOAD_MODE       = 3'b000;

	reg [15:0] dq_out;
	reg        dq_oe = 0;
	reg        own_q = 0;
	reg [ 1:0] x_dqm_q = 2'b11;
	assign SDRAM_DQ = dq_oe ? dq_out : 16'hZZZZ;

	wire [22:1] a = ctrl_addr;
	wire [15:0] d = ctrl_data;
	wire  [1:0] dqm = ~ctrl_be;
	always @(posedge clk) begin
		own_q   <= x_own;
		x_dqm_q <= x_dqm;
		if (x_own) begin
			{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= x_cmd;
			SDRAM_A  <= x_a;
			SDRAM_BA <= x_ba;
			dq_out   <= x_dq;
			dq_oe    <= x_oe;
		end else if (gate) begin
			{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
			dq_oe <= 0;
		end else begin
		if (ctrl_cmd == CTRL_RAS || ctrl_cmd == CTRL_CAS || ctrl_cmd == CTRL_PRE) SDRAM_BA <= (mode == MODE_NORMAL) ? ctrl_bank : 2'b00;

		if (init_done) begin
			SDRAM_nRAS <= ~(c_act | c_pre | c_rf);
			SDRAM_nCAS <= ~(c_wr | c_rd | c_rf);
			SDRAM_nWE  <= ~(c_wr | c_pre);
		end
		else if (init_state == STATE_START) begin
			case (mode)
				MODE_NORMAL: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;
				MODE_LDM:    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
				MODE_PRE:    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;
				default:     {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
			endcase
		end
		else {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;

		dq_out <= d;
		dq_oe  <= 0;
		casex({init_done,ctrl_rfs,ctrl_we,mode,ctrl_cmd})
			{3'b101, MODE_NORMAL, CTRL_CAS}: dq_oe <= 1;
			default: ;
		endcase

		if (mode == MODE_NORMAL) begin
			casex ({ctrl_we,ctrl_cmd})
				{1'bX,CTRL_RAS}: SDRAM_A <= {1'b0,a[22:11]};
				{1'b0,CTRL_CAS}: SDRAM_A <= {2'b00,1'b0,a[10:1]};
				{1'b1,CTRL_CAS}: SDRAM_A <= {dqm  ,1'b0,a[10:1]};
				default:         SDRAM_A <= 13'd0;
			endcase
		end
		else if (mode == MODE_LDM && ctrl_cmd == CTRL_RAS) SDRAM_A <= MODE;
		else if (mode == MODE_PRE && ctrl_cmd == CTRL_RAS) SDRAM_A <= 13'b0010000000000;
		else SDRAM_A <= '0;
		end
	end

	assign SDRAM_nCS  = 1'b0;
	assign SDRAM_CKE  = 1;
	assign {SDRAM_DQMH,SDRAM_DQML} = own_q ? x_dqm_q : SDRAM_A[12:11];

endmodule
