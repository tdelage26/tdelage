module P3DO_VRAM #(parameter USE_BRAM = 0, parameter USE_BRAM2 = USE_BRAM) (
	input          CLK,
	input          CLK_MEM,
	input          RST_N,
	
	input  [17: 0] A,
	input  [15: 0] D,
	output [15: 0] Q,
	input          RAS_N,
	input          CAS_N,
	input  [ 1: 0] WE_N,
	input          OE_N,
	input          DSF1,
	output         RDY,
	output         STALL_EARLY,
	output         SR_UNI,
	input          SR_UNI_OTHER,
	input          CPU_XFER,
	
	input          SC,
	input          SE_N,
	output [15: 0] SQ,
	output         QSF,
	
	input  [15: 0] EQ,
	output [17: 0] ESADDR,
	output [31: 0] ESDATA,
	output         ESWR,
	output         ESRD,
	output         ESFW,
	output [15: 0] ESFWD,
	input  [31: 0] ESQ,
	input          ESTE,
	output [17: 0] EWADDR,
	input          EWTE,
	input          EWBUSY,
	
	input  [ 3: 0] BRAM4_OFFS,
	input  [ 3: 0] BRAM2_OFFS,
	input  [ 3: 0] BRAM1_OFFS
);

	bit  [17: 0] A_FF;
	bit  [15: 0] D_FF;

	reg  [17: 0] rA;
	reg  [15: 0] rD;
	reg          rRAS_N, rCAS_N, rOE_N, rDSF1, rSC, rSE_N;
	reg          rCPU;
	reg  [ 1: 0] rWE_N;
	always @(posedge CLK) begin
		rA <= A; rD <= D; rRAS_N <= RAS_N; rCAS_N <= CAS_N; rWE_N <= WE_N; rCPU <= CPU_XFER;
		rOE_N <= OE_N; rDSF1 <= DSF1; rSC <= SC; rSE_N <= SE_N;
	end
	
	wire         USE_INT_RAM4 = (A >= ({BRAM4_OFFS+0,16'h0000}>>2) && A <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) && USE_BRAM;
	wire         USE_INT_RAM2 = (A >= ({BRAM2_OFFS+0,16'h0000}>>2) && A <= ({BRAM2_OFFS+1,16'hFFFF}>>2)) && USE_BRAM2;
	wire         USE_INT_RAM1 = (A >= ({BRAM1_OFFS+0,16'h0000}>>2) && A <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (A >= (20'hFC000>>2));
	wire         rUSE_INT_RAM4 = (rA >= ({BRAM4_OFFS+0,16'h0000}>>2) && rA <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) && USE_BRAM;
	wire         rUSE_INT_RAM2 = (rA >= ({BRAM2_OFFS+0,16'h0000}>>2) && rA <= ({BRAM2_OFFS+1,16'hFFFF}>>2)) && USE_BRAM2;
	wire         rUSE_INT_RAM1 = (rA >= ({BRAM1_OFFS+0,16'h0000}>>2) && rA <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (rA >= (20'hFC000>>2));

//	bit  [15: 0] MASK;
	bit  [15: 0] COLOR;
	
	bit  [ 8: 0] SR_WA;
	bit  [31: 0] SR_WD;
	bit          SR_WE;
	bit  [ 8: 0] SR_RA;
	wire [255: 0] SR_QC;

	bit  [ 8: 0] MEM_ROW;
	bit  [ 8: 0] MEM_COL;
	bit  [ 8: 0] SREG_POS;
	bit          RT_REQ;
	bit          RT_EXEC;	//read transfer
	bit          MWT_EXEC;	//masked write transfer
	bit          FW_EXEC;	//flash write
	bit          FW_UNI;
	reg          X_CPU;
	reg          RT_CPU;
	reg  [255:0] sr_cov;
	reg          sr_uni, sr_uv_set;
	reg  [ 15:0] sr_uv;
	reg          sr_uni_q;
	assign SR_UNI = sr_uni_q;
	reg  [ 15:0] sq_nx;
//	bit          SIM;			//serial input mode
	bit          SOM;			//serial output mode
	bit          SPLIT;		//serial split transfer mode
	bit          ISTE;
	bit        RT_PEND,MWT_PEND,FW_PEND,FW_PEND2,FW_OE_N;
	bit        FLASHWRITE,LOAD;
	bit        DRN, D_SPLIT;
	bit  [ 8:0] D_ROW, D_POS;
	wire       DRN_ALL = DRN | EWBUSY;
	wire       XFER_BUSY = RT_EXEC | MWT_EXEC | FW_EXEC | RT_PEND | MWT_PEND | FW_PEND | (FW_PEND2 & FLASHWRITE);
	wire       c_xfer_d  = (!OE_N || !WE_N || DSF1 || !(USE_INT_RAM4 || USE_INT_RAM2 || USE_INT_RAM1));
	wire       iw_d = ((RT_EXEC | MWT_EXEC | FW_EXEC) && ISTE && A[17:9] == MEM_ROW) ||
	                  RT_PEND || MWT_PEND || FW_PEND || (FW_PEND2 & FLASHWRITE);
	assign STALL_EARLY = !RAS_N && rRAS_N && ((XFER_BUSY && c_xfer_d) || iw_d || (DRN_ALL && c_xfer_d));
	wire       c_xfer_r  = (!rOE_N || !rWE_N || rDSF1 || !(rUSE_INT_RAM4 || rUSE_INT_RAM2 || rUSE_INT_RAM1));
	always @(posedge CLK_MEM or negedge RST_N) begin
		bit        RAS_N_OLD,CAS_N_OLD,SC_OLD;
		bit        RDY_OLD;
		
		if (!RST_N) begin
			{RT_PEND,MWT_PEND,FW_PEND,FW_PEND2} <= '0;
			RDY <= 1;
			MEM_ROW <= '0;
			MEM_COL <= '0;
			RT_REQ <= 0;
			{FLASHWRITE,LOAD} <= '0;
			{RT_EXEC,MWT_EXEC,FW_EXEC} <= '0;
//			SIM <= 0;
			SOM <= 0;
			SPLIT <= 0;
			SREG_POS <= '0;
			SR_WA <= '0;
			SR_WE <= 0;
			SR_RA <= '0;
			ISTE <= 0;
			{DRN,D_SPLIT} <= '0;
			D_ROW <= '0;
			D_POS <= '0;
		end else begin
			RT_REQ <= 0;
			
			A_FF <= rA;
			D_FF <= rD;
			RAS_N_OLD <= rRAS_N;
			CAS_N_OLD <= rCAS_N;
			RDY_OLD <= RDY;
			if ((!rRAS_N && RAS_N_OLD) || (RDY && !RDY_OLD)) begin
				if (RT_EXEC || MWT_EXEC || FW_EXEC) begin
					if (c_xfer_r || (ISTE && rA[17:9] == MEM_ROW)) RDY <= 0;
				end else if (DRN_ALL && c_xfer_r) begin
					RDY <= 0;
				end else if (!rOE_N && rWE_N) begin
					RT_PEND <= 1;
					X_CPU <= rCPU;
				end else if (!rOE_N && !rWE_N ) begin
					MWT_PEND <= 1;
					X_CPU <= rCPU;
				end else if (rOE_N && !rWE_N ) begin
					FW_PEND <= 1;
				end else if (rOE_N && rWE_N) begin
					if (rDSF1) LOAD <= 1;
				end
			end 
			else if (!RDY && !RT_EXEC && !MWT_EXEC && !FW_EXEC && !(DRN_ALL && c_xfer_r)) begin
				RDY <= 1;
			end
			if (!rCAS_N && CAS_N_OLD) begin
				FW_PEND2 <= 1;
				FW_OE_N <= rOE_N;
			end
			
			if (RT_PEND) begin
				RT_PEND <= 0;
				if ({MEM_ROW,MEM_COL[8]} != A_FF[17:8] || !rDSF1) begin
					{MEM_ROW,MEM_COL} <= A_FF[17:0];
					RT_EXEC <= 1;
					RT_REQ <= 1;
					RT_CPU <= X_CPU;
//					SIM <= 0;
					if (!X_CPU) SOM <= 1;
					SPLIT <= rDSF1;
					SREG_POS <= {A_FF[8:1],1'b0};
					ISTE <= rUSE_INT_RAM4 | rUSE_INT_RAM2 | rUSE_INT_RAM1;
				end
				if (!rDSF1 && !X_CPU) SR_RA <= A_FF[8:0];
			end else if (MWT_PEND) begin
				MWT_PEND <= 0;
				MEM_ROW <= A_FF[17:9];
//				MEM_COL <= A_FF[8:0];
//				MASK <= D_FF;
				if (!rSE_N && !rDSF1 && X_CPU && SR_UNI && SR_UNI_OTHER && !(rUSE_INT_RAM4 | rUSE_INT_RAM2 | rUSE_INT_RAM1)) begin
					FW_EXEC <= 1;
					FW_UNI <= 1;
				end else if (!(rUSE_INT_RAM4 | rUSE_INT_RAM2 | rUSE_INT_RAM1)) begin
					DRN <= !rSE_N;
					D_ROW <= A_FF[17:9];
					D_POS <= '0;
					D_SPLIT <= rDSF1;
				end else
				MWT_EXEC <= !rSE_N;
//				SIM <= 1;
				if (!X_CPU) SOM <= 0;
				SPLIT <= rDSF1;
				SREG_POS <= '0;
				ISTE <= rUSE_INT_RAM4 | rUSE_INT_RAM2 | rUSE_INT_RAM1;
			end else if (FW_PEND) begin
				FW_PEND <= 0;
				MEM_ROW <= A_FF[17:9];
//				MEM_COL <= A_FF[8:0];
				FLASHWRITE <= rDSF1;
				SPLIT <= 0;
				SREG_POS <= '0;
//				MASK <= D_FF;
			end
			if (FW_PEND2) begin
				FW_PEND2 <= 0;
				if (FLASHWRITE) begin
					FW_EXEC <= 1;
					FW_UNI <= 0;
					ISTE <= rUSE_INT_RAM4 | rUSE_INT_RAM2 | rUSE_INT_RAM1;
				end
				if (FW_OE_N) begin
					if (LOAD && rDSF1) COLOR <= D_FF;
				end
				FLASHWRITE <= 0;
				LOAD <= 0;
			end
			
			SC_OLD <= SC;
			if (!SC && SC_OLD && SOM) begin
				SR_RA <= SR_RA + 9'h1;
				SQ <= sq_nx;
			end

			if (DRN && EWTE) begin
				D_POS <= D_POS + 9'h2;
				if ((D_SPLIT && D_POS[7:0] == 8'hFE) || (!D_SPLIT && D_POS == 9'h1FE)) DRN <= 0;
			end
			
			SR_WE <= 0;
			if (FW_EXEC) begin
				SREG_POS <= SREG_POS + (ISTE ? 9'h10 : 9'h20);
				if ((SREG_POS[8:5] == 4'hF && !ISTE) || (SREG_POS[8:4] == 5'h1F && ISTE)) begin
					FW_EXEC <= 0;
					ISTE <= 0;
				end
			end else if ((RT_EXEC || MWT_EXEC) && (ESTE || ISTE)) begin
				SR_WA <= SREG_POS;
				SR_WD <= ESQ;
				SR_WE <= RT_EXEC;
				
				SREG_POS <= SREG_POS + (ISTE ? 9'h10 : 9'h2);
				if (((SREG_POS[7:0] == 8'hFE && ESTE) || (SREG_POS[7:4] == 4'hF && ISTE)) && SPLIT) begin
					RT_EXEC <= 0;
					ISTE <= 0;
				end
				if (((SREG_POS[8:0] == 9'h0FE && ESTE) || (SREG_POS[8:4] == 5'h0F && ISTE)) && !SPLIT) begin
					if (RT_EXEC) RT_REQ <= 1;
				end
				if (((SREG_POS[8:0] == 9'h1FE && ESTE) || (SREG_POS[8:4] == 5'h1F && ISTE)) && !SPLIT) begin
					RT_EXEC <= 0;
					MWT_EXEC <= 0;
					ISTE <= 0;
				end
			end
		end
	end
	
	bit        RAS_N_OLD,WE_N_OLD;
	always @(posedge CLK) begin
		RAS_N_OLD <= RAS_N;
		WE_N_OLD <= &WE_N;
	end
	
	wire         MEM4_SSEL = (ESADDR >= ({BRAM4_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) && USE_BRAM;
	wire         MEM2_SSEL = (ESADDR >= ({BRAM2_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM2_OFFS+1,16'hFFFF}>>2)) && USE_BRAM2;
	wire         MEM1_SSEL = (ESADDR >= ({BRAM1_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (ESADDR >= (20'hFC000>>2));
	
	wire [15: 4] MEM_SWADDR = ESADDR[15:4];
	wire[255: 0] MEM_SDATA = FW_EXEC ? {16{FW_UNI ? sr_uv : COLOR}} : {SR_QC[239:224],SR_QC[255:240],SR_QC[207:192],SR_QC[223:208],SR_QC[175:160],SR_QC[191:176],SR_QC[143:128],SR_QC[159:144],SR_QC[111:96],SR_QC[127:112],SR_QC[79:64],SR_QC[95:80],SR_QC[47:32],SR_QC[63:48],SR_QC[15:0],SR_QC[31:16]};
	wire         MEM4_SWREN = (MWT_EXEC | FW_EXEC) & MEM4_SSEL & ISTE;
	wire         MEM2_SWREN = (MWT_EXEC | FW_EXEC) & MEM2_SSEL & ISTE;
	wire         MEM1_SWREN = (MWT_EXEC | FW_EXEC) & MEM1_SSEL & ISTE;
	
	bit  [15: 0] MEM4_Q;
	bit [255: 0] MEM4_SQ;
	VRAM_MEM_SL #(16) mem4
	(
		.CLK(CLK),
		.ADDR(A[15:0]),
		.WHI(rA[15:13]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&rUSE_INT_RAM4}}),
		.Q(MEM4_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[15:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM4_SWREN),
		.SQ(MEM4_SQ)
	);
	
	bit  [15: 0] MEM2_Q;
	bit [255: 0] MEM2_SQ;
	VRAM_MEM_SL #(15) mem2
	(
		.CLK(CLK),
		.ADDR(A[14:0]),
		.WHI(rA[14:13]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&rUSE_INT_RAM2}}),
		.Q(MEM2_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[14:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM2_SWREN),
		.SQ(MEM2_SQ)
	);
	
	bit  [15: 0] MEM1_Q;
	bit [255: 0] MEM1_SQ;
	VRAM_MEM_SL #(14) mem1
	(
		.CLK(CLK),
		.ADDR(A[13:0]),
		.WHI(rA[13:13]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&rUSE_INT_RAM1}}),
		.Q(MEM1_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[13:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM1_SWREN),
		.SQ(MEM1_SQ)
	);
	assign Q = USE_INT_RAM4 ? MEM4_Q : USE_INT_RAM2 ? MEM2_Q : USE_INT_RAM1 ? MEM1_Q : EQ;

	(* altera_attribute = "-name MAX_FANOUT 32" *) bit ISTE_DELAYED;
	(* altera_attribute = "-name MAX_FANOUT 32" *) bit MEM4_SQ_SEL;
	(* altera_attribute = "-name MAX_FANOUT 32" *) bit MEM2_SQ_SEL;
	always @(posedge CLK_MEM) begin
		ISTE_DELAYED <= ISTE;
		MEM4_SQ_SEL <= MEM4_SSEL;
		MEM2_SQ_SEL <= MEM2_SSEL;
	end
	
	wire[255: 0] MEM_SQ = MEM4_SQ_SEL ? {MEM4_SQ[239:224],MEM4_SQ[255:240],MEM4_SQ[207:192],MEM4_SQ[223:208],MEM4_SQ[175:160],MEM4_SQ[191:176],MEM4_SQ[143:128],MEM4_SQ[159:144],MEM4_SQ[111:96],MEM4_SQ[127:112],MEM4_SQ[79:64],MEM4_SQ[95:80],MEM4_SQ[47:32],MEM4_SQ[63:48],MEM4_SQ[15:0],MEM4_SQ[31:16]} :
	                      MEM2_SQ_SEL ? {MEM2_SQ[239:224],MEM2_SQ[255:240],MEM2_SQ[207:192],MEM2_SQ[223:208],MEM2_SQ[175:160],MEM2_SQ[191:176],MEM2_SQ[143:128],MEM2_SQ[159:144],MEM2_SQ[111:96],MEM2_SQ[127:112],MEM2_SQ[79:64],MEM2_SQ[95:80],MEM2_SQ[47:32],MEM2_SQ[63:48],MEM2_SQ[15:0],MEM2_SQ[31:16]} :
	                                    {MEM1_SQ[239:224],MEM1_SQ[255:240],MEM1_SQ[207:192],MEM1_SQ[223:208],MEM1_SQ[175:160],MEM1_SQ[191:176],MEM1_SQ[143:128],MEM1_SQ[159:144],MEM1_SQ[111:96],MEM1_SQ[127:112],MEM1_SQ[79:64],MEM1_SQ[95:80],MEM1_SQ[47:32],MEM1_SQ[63:48],MEM1_SQ[15:0],MEM1_SQ[31:16]};

	wire         src_we0 = SR_WE & RT_CPU;
	reg          src_we, src_iste;
	reg  [  8:1] src_wa;
	reg  [255:0] src_d;
	always @(posedge CLK_MEM) begin
		src_we <= src_we0; src_iste <= ISTE_DELAYED; src_wa <= SR_WA[8:1];
		src_d  <= ISTE_DELAYED ? MEM_SQ : {8{SR_WD}};
		sr_uni_q <= sr_uni && (&sr_cov);
	end
	wire         srv_we = SR_WE & ~RT_CPU;

	reg          u_rst, u_we, u_iste;
	reg  [  8:1] u_wa;
	reg  [255:0] u_d;
	always @(posedge CLK_MEM) begin
		bit eq; bit [15:0] v0;
		u_rst  <= RT_PEND && X_CPU && ({MEM_ROW,MEM_COL[8]} != A_FF[17:8] || !rDSF1);
		u_we   <= src_we0;
		u_iste <= ISTE_DELAYED;
		u_wa   <= SR_WA[8:1];
		u_d    <= ISTE_DELAYED ? MEM_SQ : {8{SR_WD}};
		if (u_rst) begin
			sr_cov <= '0; sr_uni <= 1; sr_uv_set <= 0;
		end else if (u_we) begin
			v0 = sr_uv_set ? sr_uv : u_d[15:0];
			eq = 1;
			if (u_iste) begin
				for (int k = 0; k < 16; k++) if (u_d[k*16 +: 16] != v0) eq = 0;
				for (int k = 0; k < 8; k++) sr_cov[{u_wa[8:4], k[2:0]}] <= 1;
			end else begin
				if (u_d[31:16] != v0 || u_d[15:0] != v0) eq = 0;
				sr_cov[u_wa[8:1]] <= 1;
			end
			sr_uv <= v0; sr_uv_set <= 1;
			if (!eq) sr_uni <= 0;
		end
	end

	wire [255:0] SR_QV;
	reg          srv_we_q = 0, srv_iste_q = 0;
	reg  [  8:1] srv_wa_q = '0;
	reg  [255:0] srv_d_q;
	always @(posedge CLK_MEM) begin
		srv_we_q <= srv_we; srv_iste_q <= ISTE_DELAYED; srv_wa_q <= SR_WA[8:1];
		srv_d_q  <= ISTE_DELAYED ? MEM_SQ : {8{SR_WD}};
	end
	VRAM_SHIFTREG #(9) shiftreg
	(
		.CLK(CLK_MEM),
		.WADDR(srv_wa_q[8:4]),
		.DATA(srv_d_q),
		.WREN(srv_iste_q ? {8{srv_we_q}} : {7'b0000000,srv_we_q}<<srv_wa_q[3:1]),
		.RADDR(SR_RA[8:4]),
		.Q(SR_QV)
	);

	wire [  8:0] sreg_nx = (!RT_PEND && MWT_PEND) ? 9'd0 :
	                       DRN_ALL ? ((DRN && EWTE) ? D_POS + 9'h2 : D_POS) :
	                       (!FW_EXEC && MWT_EXEC && ISTE) ? SREG_POS + 9'h10 : SREG_POS;
	reg  [  7:0] src_lhot;
	always @(posedge CLK_MEM) src_lhot <= 8'd1 << sreg_nx[3:1];
	genvar gl;
	generate
		for (gl = 0; gl < 8; gl = gl + 1) begin : src_lane
			(* ramstyle = "M9K, no_rw_check" *) reg [31:0] mem [0:31];
			reg [31:0] q;
			wire we = src_we & (src_iste | (src_wa[3:1] == gl));
			always @(posedge CLK_MEM) begin
				if (we) mem[src_wa[8:4]] <= src_d[gl*32 +: 32];
				q <= mem[sreg_nx[8:4]];
			end
			assign SR_QC[gl*32 +: 32] = q;
		end
	endgenerate

	bit  [31: 0] SR_DATA, SR_DATA_C;
	always_comb begin
		case (SR_RA[3:1])
			3'h0: SR_DATA = SR_QV[031:000];
			3'h1: SR_DATA = SR_QV[063:032];
			3'h2: SR_DATA = SR_QV[095:064];
			3'h3: SR_DATA = SR_QV[127:096];
			3'h4: SR_DATA = SR_QV[159:128];
			3'h5: SR_DATA = SR_QV[191:160];
			3'h6: SR_DATA = SR_QV[223:192];
			3'h7: SR_DATA = SR_QV[255:224];
		endcase
		SR_DATA_C = '0;
		for (int k = 0; k < 8; k++) SR_DATA_C = SR_DATA_C | (SR_QC[k*32 +: 32] & {32{src_lhot[k]}});
	end

	reg  [255:0] sqv_q;
	reg  [  8:0] sq_ra;
	always @(posedge CLK_MEM) begin
		sqv_q <= SR_QV;
		sq_ra <= SR_RA;
		sq_nx <= sq_ra[0] ? sqv_q[{sq_ra[3:1], 5'd0} +: 16] : sqv_q[{sq_ra[3:1], 5'd16} +: 16];
	end

	assign ESADDR = {MEM_ROW,SREG_POS};
	assign ESDATA = FW_EXEC ? {2{FW_UNI ? sr_uv : COLOR}} : SR_DATA_C;
	assign ESWR = DRN;
	assign EWADDR = {D_ROW,D_POS};
	assign ESRD = RT_REQ & ~ISTE;
	assign ESFW = FW_EXEC & ~ISTE;
	assign ESFWD = FW_UNI ? sr_uv : COLOR;
	
	assign QSF = SR_RA[8];

endmodule

module VRAM_MEM_SL
#( parameter addr_width = 16 )
(
	input                     CLK,
	input  [addr_width-1:  0] ADDR,
	input  [addr_width-1: 13] WHI,
	input  [          15:  0] DATA,
	input  [           1:  0] WREN,
	output [          15:  0] Q,

	input                     SCLK,
	input  [addr_width-1:  4] SADDR,
	input  [         255:  0] SDATA,
	input                     SWREN,
	output [         255:  0] SQ
);

	localparam N = 2**(addr_width-13);

	wire [ 15: 0] q[N];
	wire [255: 0] sq[N];
	reg  [addr_width-1:13] ra_hi, sa_hi;
	always @(posedge CLK)  ra_hi <= ADDR[addr_width-1:13];
	always @(posedge SCLK) sa_hi <= SADDR[addr_width-1:13];

	genvar i;
	generate
		for (i = 0; i < N; i = i + 1) begin : sl
			wire wsel = (WHI == i);
			wire ssel = (SADDR[addr_width-1:13] == i);
			altsyncram	altsyncram_component (
						.address_a (ADDR[12:0]),
						.address_b (SADDR[12:4]),
						.clock0 (CLK),
						.clock1 (SCLK),
						.data_a (DATA),
						.data_b (SDATA),
						.wren_a (|WREN & wsel),
						.wren_b (SWREN & ssel),
						.q_a (q[i]),
						.q_b (sq[i]),
						.aclr0 (1'b0),
						.aclr1 (1'b0),
						.addressstall_a (1'b0),
						.addressstall_b (1'b0),
						.byteena_a (WREN),
						.byteena_b (1'b1),
						.clocken0 (1'b1),
						.clocken1 (1'b1),
						.clocken2 (1'b1),
						.clocken3 (1'b1),
						.eccstatus (),
						.rden_a (1'b1),
						.rden_b (1'b1));
			defparam
				altsyncram_component.address_reg_b = "CLOCK1",
				altsyncram_component.clock_enable_input_a = "BYPASS",
				altsyncram_component.clock_enable_input_b = "BYPASS",
				altsyncram_component.clock_enable_output_a = "BYPASS",
				altsyncram_component.clock_enable_output_b = "BYPASS",
				altsyncram_component.indata_reg_b = "CLOCK1",
				altsyncram_component.intended_device_family = "Cyclone V",
				altsyncram_component.lpm_type = "altsyncram",
				altsyncram_component.numwords_a = 8192,
				altsyncram_component.numwords_b = 512,
				altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
				altsyncram_component.outdata_aclr_a = "NONE",
				altsyncram_component.outdata_aclr_b = "NONE",
				altsyncram_component.outdata_reg_a = "UNREGISTERED",
				altsyncram_component.outdata_reg_b = "UNREGISTERED",
				altsyncram_component.power_up_uninitialized = "FALSE",
				altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
				altsyncram_component.read_during_write_mode_port_b = "DONT_CARE",
				altsyncram_component.widthad_a = 13,
				altsyncram_component.widthad_b = 9,
				altsyncram_component.width_a = 16,
				altsyncram_component.width_b = 256,
				altsyncram_component.width_byteena_a = 2,
				altsyncram_component.init_file = "";
		end
	endgenerate

	assign Q  = q[ra_hi];
	assign SQ = sq[sa_hi];

endmodule
