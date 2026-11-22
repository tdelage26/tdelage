module threedo_sidi128_top
(
	output        LED,
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        AUDIO_L,
	output        AUDIO_R,

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,
	input         CLOCK_50,

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE

`ifdef USE_HDMI
	,
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT
`endif
`ifdef I2S_AUDIO
	,
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA
`endif
`ifdef I2S_AUDIO_HDMI
	,
	output        HDMI_MCLK,
	output reg    HDMI_BCK,
	output reg    HDMI_LRCK,
	output reg    HDMI_SDATA
`endif
);

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

wire clk_sys, clk_mem, clk_vid;
wire pll_locked, pll_vid_locked;

pll_3do_sys pll_sys
(
	.inclk0 (CLOCK_50),
	.c0     (clk_sys),
	.c1     (clk_mem),
	.c2     (SDRAM_CLK),
	.c3     (SDRAM2_CLK),
	.locked (pll_locked)
);

pll_3do_vid pll_vid
(
	.inclk0 (CLOCK_50),
	.c0     (clk_vid),
	.locked (pll_vid_locked)
);

localparam CONF_STR = {
	"3DO;;",
	"F1,ROMBIN,Load BIOS;",
	"F3,ROMBIN,Load Kanji ROM;",
	"SC,CUEISO,Insert Disc;",
	"-;",
	"O45,Region,BIOS,NTSC,PAL;",
	"O6,Pads,1,2;",
	"O7,Swap Joysticks,No,Yes;",
	"-;",
	"O23,Scanlines,Off,25%,50%,75%;",
	"-;",
	"T8,Save NVRAM;",
	"T0,Reset;",
	"V,v0.2"
};

wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire [31:0] joystick_0, joystick_1;
wire  [1:0] img_mounted;
wire [63:0] img_size;
wire [31:0] sd_lba;
wire        sd_rd, sd_wr, sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_dout, sd_din;
wire        sd_dout_strobe;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(2), .FEATURES(32'h00040000 | 32'h00002000 | (HDMI << 14))) user_io
(
	.clk_sys        (clk_sys    ),
	.conf_str       (CONF_STR   ),
	.SPI_CLK        (SPI_SCK    ),
	.SPI_SS_IO      (CONF_DATA0 ),
	.SPI_MISO       (SPI_DO     ),
	.SPI_MOSI       (SPI_DI     ),
	.buttons        (buttons    ),
	.switches       (switches   ),
	.scandoubler_disable(scandoublerD),
	.ypbpr          (ypbpr      ),
	.no_csync       (no_csync   ),
	.joystick_0     (joystick_0 ),
	.joystick_1     (joystick_1 ),
	.status         (status     ),
	.clk_sd         (clk_sys    ),
	.sd_conf        (1'b0       ),
	.sd_sdhc        (1'b1       ),
	.sd_lba         (sd_lba     ),
	.sd_rd          ({sd_rd, 1'b0}),
	.sd_wr          ({sd_wr, 1'b0}),
	.sd_ack         (sd_ack     ),
	.sd_buff_addr   (sd_buff_addr),
	.sd_dout        (sd_dout    ),
	.sd_dout_strobe (sd_dout_strobe),
	.sd_din         (sd_din     ),
	.sd_cnt         (8'd0       ),
	.img_mounted    (img_mounted),
	.img_size       (img_size   )
`ifdef USE_HDMI
	,
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        )
`endif
);

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_data;

data_io #(.DOUT_16(1'b1)) data_io
(
	.clk_sys       (clk_sys       ),
	.SPI_SCK       (SPI_SCK       ),
	.SPI_SS2       (SPI_SS2       ),
	.SPI_DI        (SPI_DI        ),
	.SPI_DO        (SPI_DO        ),
	.clkref_n      (1'b0          ),
	.ioctl_download(ioctl_download),
	.ioctl_index   (ioctl_index   ),
	.ioctl_wr      (ioctl_wr      ),
	.ioctl_addr    (ioctl_addr    ),
	.ioctl_dout    (ioctl_data    )
);

wire bios_download  = ioctl_download & (ioctl_index[5:2] == 4'b0000 && ioctl_index[1:0] != 2'h3);
wire kanji_download = ioctl_download & (ioctl_index[5:2] == 4'b0000 && ioctl_index[1:0] == 2'h3);

reg reset = 1, mem_rst = 1;
wire dl_active;
wire sv_hold_rst;
wire c1_req;
always @(posedge clk_sys) begin
	reg        reset_cond, reset_cond_old;
	reg [12:0] reset_delay;

	reset_cond = ~pll_locked | status[0] | buttons[1];
	reset_cond_old <= reset_cond;
	if (reset_cond && !reset_cond_old) reset_delay <= '1;
	else if (reset_delay) reset_delay <= reset_delay - 13'd1;

	reset   <= reset_cond | |reset_delay | dl_active | sv_hold_rst | (reset & c1_req);
	mem_rst <= (reset_cond | |reset_delay) & ~dl_active;
end

reg PAL = 0;
always @(posedge clk_sys) begin
	reg  [31:0] cs;
	reg         bios_download_old;
	reg         bios_pal = 0;

	bios_download_old <= bios_download;
	if (bios_download && !bios_download_old) cs <= '0;
	if (bios_download && ioctl_wr) cs <= cs + {16'h0000, ioctl_data};
	if (!bios_download && bios_download_old) bios_pal <= (cs == 32'hD63EC5E9 || cs == 32'hD5CFD1C5);

	case (status[5:4])
		2'h0:    PAL <= bios_pal;
		2'h1:    PAL <= 0;
		default: PAL <= 1;
	endcase
end

wire [64:0] cd_cmd;
wire [15:0] cdd_data;
wire        cdd_wr, cdd_dten, cdd_dien;
wire        cdinfo_wr;
wire [11:0] cdinfo_addr;
wire [15:0] cdinfo_data;

data_io_3do data_io_3do
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK), .SPI_SS2(SPI_SS2), .SPI_DI(SPI_DI), .SPI_DO(SPI_DO),
	.reset(reset),
	.cd_in(cd_cmd),
	.CDD_DATA(cdd_data), .CDD_WR(cdd_wr), .CDD_DTEN(cdd_dten), .CDD_DIEN(cdd_dien),
	.info_wr(cdinfo_wr), .info_addr(cdinfo_addr), .info_data(cdinfo_data)
);

reg [3:0] cdBRAM4_OFFS = 4'h0;
reg [3:0] cdBRAM2_OFFS = 4'h4;
reg [3:0] cdBRAM1_OFFS = 4'h6;
reg       NEED_DSP_PAUSE = 1'b0;
reg [3:0] sdBRAM4_OFFS = 4'h0;
reg [3:0] sdBRAM1_OFFS = 4'h6;
reg       sd4_known = 1'b0, sd1_known = 1'b0;
always @(posedge clk_sys) begin
	reg [31:0] msf, id;

	if (cdinfo_wr) begin
		if (cdinfo_addr == 12'h004) msf[31:16] <= {cdinfo_data[7:0],cdinfo_data[15:8]};
		if (cdinfo_addr == 12'h006) msf[15:0]  <= {cdinfo_data[7:0],cdinfo_data[15:8]};
		if (cdinfo_addr == 12'h458) id[31:16]  <= {cdinfo_data[7:0],cdinfo_data[15:8]};
		if (cdinfo_addr == 12'h45A) id[15:0]   <= {cdinfo_data[7:0],cdinfo_data[15:8]};
		if (cdinfo_addr == 12'h480) begin
			{cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h0,4'h4,4'h6};
			NEED_DSP_PAUSE <= 0;
			sd4_known <= 0;
			sd1_known <= 0;
			if (id == 32'h29E4D882) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'hC,4'hA,4'h9};//3D Atlas (US)
			if (id == 32'h274E924C) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h4,4'h2,4'h8};//Alone in the Dark (US)
			if (id == 32'h0340842C) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'hC,4'hA,4'h9};//Cannon Fodder (US)
			if (id == 32'h2D731C98) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'hC,4'hA,4'h9};//FIFA International Soccer (US, Korea)
			if (id == 32'h2584F855) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h8,4'hC,4'hE};//Psychic Detective (US) (Disc 1)
			if (id == 32'h031BED09) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h8,4'h6,4'hC};//Quarantine (US)
			if (id == 32'h06DE0DC2) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'hC,4'hA,4'h9};//Road & Track Presents - The Need for Speed (US, EU)
			if (id == 32'h2D95DCB6) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h8,4'h6,4'hC};//Seal of the Pharaoh (US)
			if (id == 32'h07732394) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h0,4'h6,4'h4};//Space Hulk - Vengeance of the Blood Angels (US)
			if (id == 32'h0387DF78) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h4,4'h8,4'hA};//Bodyconscious Digital Rave! Part 1 - Shinjuku & Takasaki (Japan)
			if (id == 32'h213128DD) {cdBRAM4_OFFS,cdBRAM2_OFFS,cdBRAM1_OFFS} <= {4'h8,4'hC,4'hE};//Live! 3DO Magazine CD-ROM 1 (Japan)

			if (id == 32'h274E924C) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h3}; end
			if (id == 32'h31328D35) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h9}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h2}; end
			if (id == 32'h38FB630E) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h4}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h0}; end
			if (id == 32'h2A87E53E) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'hC}; end
			if (id == 32'h0340842C) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'hB}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h0}; end
			if (id == 32'h16B97F04) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end
			if (id == 32'h1E562F34) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h4}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h1}; end
			if (id == 32'h30DD747F) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end
			if (id == 32'h34FA5D4F) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end
			if (id == 32'h1034058C) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'hC}; end
			if (id == 32'h3A734D20) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h1}; end
			if (id == 32'h135E3507) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h4}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h0}; end
			if (id == 32'h07D205F9) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h4}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h0}; end
			if (id == 32'h29D28DED) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h4}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h0}; end
			if (id == 32'h15208F9C) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end
			if (id == 32'h3FF066B0) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'hC}; end
			if (id == 32'h28685880) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'hC}; end
			if (id == 32'h2CC753DB) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end
			if (id == 32'h398E8184) begin {sd4_known,sdBRAM4_OFFS} <= {1'b1,4'h0}; {sd1_known,sdBRAM1_OFFS} <= {1'b1,4'h4}; end

			if (id == 32'h25609184                       ) NEED_DSP_PAUSE <= 1;//Blade Force (US)
			if (id == 32'h043DCD69 && msf == 32'h69026900) NEED_DSP_PAUSE <= 1;//Decathlon (US) (Unl)
			if (id == 32'h0A9B739E                       ) NEED_DSP_PAUSE <= 1;//Killing Time (US) (RE1)
			if (id == 32'h06065D10                       ) NEED_DSP_PAUSE <= 1;//Snow Job Starring Tracy Scoggins (US)
			if (id == 32'h3AC732DE                       ) NEED_DSP_PAUSE <= 1;//BattleSport (USA) (Beta) (1995-09-22)
		end
	end
end

wire [3:0] BRAM4_OFFS = sd4_known ? sdBRAM4_OFFS : cdBRAM4_OFFS;
wire [3:0] BRAM2_OFFS = cdBRAM2_OFFS;
wire [3:0] BRAM1_OFFS = sd1_known ? sdBRAM1_OFFS : cdBRAM1_OFFS;

wire [23: 2] LA;
wire         LRAS0_N, LRAS2_N, LRAS3_N, LCAS_N;
wire [ 1: 0] LWE_N;
wire         LOE_N, LDSF, LSC, LQSF;
wire [ 3: 0] LCODE;
wire [23: 2] RA;
wire         RRAS0_N, RRAS2_N, RRAS3_N, RCAS_N;
wire [ 1: 0] RWE_N;
wire         ROE_N, RDSF, RSC, RQSF;
wire [ 3: 0] RCODE;
wire [31: 0] RAM_DI;
wire [31: 0] RAM_DO;
wire         PBDIN, PBDOUT, PBCLK;
wire [19: 0] PA;
wire [31: 0] PDI;
wire [ 7: 0] PDO;
wire         ROMCS_N, SRAMW_N, SRAMR_N;
wire         ROM_SEL;
wire [ 7: 0] CDDI, CDDO;
wire         CDEN_N, CDCMD_N, CDHWR_N, CDHRD_N, CDRST_N, CDSTEN_N, CDDTEN_N, CDMDCHG;
wire [31: 0] VRAM_SQ;
wire         P3DO_FIELD;
wire [ 7: 0] R, G, B;
wire         HS_N, VS_N, DCLK, HBL_N, VBL_N;
wire         MCLK_CE;
wire [15: 0] AUDIO_L_3DO, AUDIO_R_3DO;

wire [31:0] in_clk = 50000000;

bit CLK_DIV;
always @(posedge clk_sys) CLK_DIV <= ~CLK_DIV;
wire CE_R =  CLK_DIV;
wire CE_F = ~CLK_DIV;

wire VCE;
CEGen VCE_CEGen (.CLK(clk_sys), .RST_N(1'b1), .IN_CLK(in_clk), .IN_CE(1'b1), .OUT_CLK(24545400), .CE(VCE));
wire ACLK_CE;
CEGen AUD_CEGen (.CLK(clk_sys), .RST_N(1'b1), .IN_CLK(in_clk), .IN_CE(1'b1), .OUT_CLK(16934400), .CE(ACLK_CE));

reg POWER_ON;
always @(posedge clk_sys) begin
	if (reset) POWER_ON <= 1;
	else if (CE_R) POWER_ON <= 0;
end

reg pause;

wire vram_cpu_xfer;
P3DO p3do
(
	.RST_N(~reset), .CLK(clk_sys), .VCLK(clk_vid), .EN(1'b1), .VRAM_CPU_XFER(vram_cpu_xfer),
	.PAUSE(pause), .DSP_PAUSE(pause & NEED_DSP_PAUSE), .PAL(PAL),
	.CE_F(CE_F), .CE_R(CE_R), .PON(POWER_ON),
	.LA(LA), .LRAS0_N(LRAS0_N), .LRAS2_N(LRAS2_N), .LRAS3_N(LRAS3_N), .LCAS_N(LCAS_N),
	.LWE_N(LWE_N), .LOE_N(LOE_N), .LDSF(LDSF), .LSC(LSC), .LQSF(LQSF), .LCODE(LCODE),
	.RA(RA), .RRAS0_N(RRAS0_N), .RRAS2_N(RRAS2_N), .RRAS3_N(RRAS3_N), .RCAS_N(RCAS_N),
	.RWE_N(RWE_N), .ROE_N(ROE_N), .RDSF(RDSF), .RSC(RSC), .RQSF(RQSF), .RCODE(RCODE),
	.DI(RAM_DI), .DO(RAM_DO),
	.PBDIN(PBDIN), .PBDOUT(PBDOUT), .PBCLK(PBCLK),
	.PA(PA), .PDI(PDI), .PDO(PDO), .ROMCS_N(ROMCS_N), .SRAMW_N(SRAMW_N), .SRAMR_N(SRAMR_N),
	.ROM_SEL(ROM_SEL),
	.CDDI(CDDI), .CDDO(CDDO), .CDEN_N(CDEN_N), .CDCMD_N(CDCMD_N), .CDHWR_N(CDHWR_N), .CDHRD_N(CDHRD_N),
	.CDRST_N(CDRST_N), .CDSTEN_N(CDSTEN_N), .CDDTEN_N(CDDTEN_N), .CDMDCHG(CDMDCHG),
	.S(VRAM_SQ), .FIELD(P3DO_FIELD),
	.VCE(VCE), .RGB({R,G,B}), .HS_N(HS_N), .VS_N(VS_N), .HBLK_N(HBL_N), .VBLK_N(VBL_N), .DCLK(DCLK),
	.ACLK_CE(ACLK_CE), .AUDIOL(AUDIO_L_3DO), .AUDIOR(AUDIO_R_3DO),
	.MCLK_CE(MCLK_CE),
	.HINTREPOL_DISABLE(1'b1), .VINTREPOL_DISABLE(1'b1),
	.SCRN_EN(3'b111), .DBG_EXT(8'hFF)
);

wire [35:0] EXT_BUS;

P3DO_CDROM cdrom
(
	.RST_N(~reset), .CLK(clk_sys), .EN(1'b1), .CE(CE_R),
	.CDDI(CDDO), .CDDO(CDDI), .CDEN_N(CDEN_N), .CDCMD_N(CDCMD_N), .CDHWR_N(CDHWR_N), .CDHRD_N(CDHRD_N),
	.CDRST_N(CDRST_N), .CDSTEN_N(CDSTEN_N), .CDDTEN_N(CDDTEN_N), .CDMDCHG(CDMDCHG),
	.CDD_DATA(cdd_data), .CDD_WR(cdd_wr), .CDD_DTEN(cdd_dten), .CDD_DIEN(cdd_dien),
	.EXT_BUS(EXT_BUS), .TRAY_OPEN(1'b0),
	.CD_IN(cd_cmd)
);

wire [31:0] joy_a = status[7] ? joystick_1 : joystick_0;
wire [31:0] joy_b = status[7] ? joystick_0 : joystick_1;
function [12:0] mist2mister(input [31:0] j);
	mist2mister = {1'b0, 1'b0, j[10], j[11], j[6], j[7], j[8], j[5], j[4], j[3:0]};
endfunction

HPS2PAD pad
(
	.RST(reset), .CLK(clk_sys), .CE(CE_R),
	.PBDIN(PBDIN), .PBDOUT(PBDOUT), .PBCLK(PBCLK), .EXPBDIN(1'b1), .EXPBDOUT(),
	.PAD_SEL(status[6] ? 3'd2 : 3'd1), .ARCADE_SEL(2'd0), .STICK_EN(1'b0), .MOUSE_EN(1'b0), .ARCADE_SERVICE(1'b0),
	.joystick_0(mist2mister(joy_a)), .joystick_1(mist2mister(joy_b)), .joystick_2(13'd0), .joystick_3(13'd0),
	.joy0_x0(8'd0), .joy0_y0(8'd0), .joy0_x1(8'd0), .joy0_y1(8'd0),
	.joy1_x0(8'd0), .joy1_y0(8'd0), .joy1_x1(8'd0), .joy1_y1(8'd0),
	.ps2_mouse(25'd0)
);

wire [31:0] sdr_dout;
wire        c1_own, x1_oe;
wire [ 2:0] x1_cmd;
wire [12:0] x1_a;
wire [ 1:0] x1_ba, x1_dqm;
wire [15:0] x1_dq, x1_din;
sdram_sidi sdram1
(
	.SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), .SDRAM_DQ(SDRAM_DQ), .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_nCS(SDRAM_nCS), .SDRAM_nWE(SDRAM_nWE), .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_CKE(SDRAM_CKE),
	.clk_sys(clk_sys), .clk(clk_mem), .init(~pll_locked), .sync(MCLK_CE),
	.laddr({2'b00,~LRAS3_N,LA[19:2]}), .lwe(~LWE_N), .lras(!LRAS2_N || !LRAS3_N), .lcode(LCODE),
	.raddr({2'b00,~RRAS3_N,RA[19:2]}), .rwe(~RWE_N), .rras(!RRAS2_N || !RRAS3_N), .rcode(RCODE),
	.din(RAM_DO), .dout(sdr_dout),
	.rfs(!LRAS0_N || !RRAS0_N),
	.x_quiet(reset | pause), .x_req(c1_req), .x_own(c1_own),
	.x_cmd(x1_cmd), .x_a(x1_a), .x_ba(x1_ba), .x_dq(x1_dq), .x_oe(x1_oe), .x_dqm(x1_dqm), .x_din(x1_din)
);

wire [31: 0] VRAM_Q;
wire         VRAM_LRDY, VRAM_RRDY;
wire         vram_l_early, vram_r_early;
wire [31: 0] vram_bldata, vram_brdata;

wire [31: 0] ddr_do;
wire [17: 0] ddr_bladdr, ddr_braddr;
wire [17: 0] ddr_blwaddr, ddr_brwaddr;
wire         ddr_blwr, ddr_brwr, ddr_blrd, ddr_brrd, ddr_bfw;
wire         ddr_blwte, ddr_brwte, ddr_blwbusy, ddr_brwbusy;
wire [63: 0] ddr_bin = {vram_bldata[31:16],vram_brdata[31:16],vram_bldata[15:0],vram_brdata[15:0]};
wire [15: 0] vram_blfwd, vram_brfwd;
wire [63: 0] ddr_bout;
wire         ddr_blte, ddr_brte, ddr_bbusy;

wire         vram_l_uni, vram_r_uni;
P3DO_VRAM #(.USE_BRAM(1), .USE_BRAM2(0)) vram_l
(
	.CLK(clk_sys), .CLK_MEM(clk_mem), .RST_N(~reset),
	.A(LA[19:2]), .D(RAM_DO[31:16]), .Q(VRAM_Q[31:16]),
	.RAS_N(LRAS0_N), .CAS_N(LCAS_N), .WE_N(LWE_N), .OE_N(LOE_N), .DSF1(LDSF),
	.SC(LSC), .SE_N(1'b0), .SQ(VRAM_SQ[31:16]), .QSF(LQSF),
	.RDY(VRAM_LRDY), .STALL_EARLY(vram_l_early), .SR_UNI(vram_l_uni), .SR_UNI_OTHER(vram_r_uni), .CPU_XFER(vram_cpu_xfer),
	.EQ(ddr_do[31:16]), .ESADDR(ddr_bladdr), .ESDATA(vram_bldata), .ESWR(ddr_blwr), .ESRD(ddr_blrd), .ESFW(ddr_bfw), .ESFWD(vram_blfwd),
	.ESQ({ddr_bout[63:48],ddr_bout[31:16]}), .ESTE(ddr_blte), .EWADDR(ddr_blwaddr), .EWTE(ddr_blwte), .EWBUSY(ddr_blwbusy),
	.BRAM4_OFFS(BRAM4_OFFS), .BRAM2_OFFS(BRAM2_OFFS), .BRAM1_OFFS(BRAM1_OFFS)
);

P3DO_VRAM #(.USE_BRAM(1), .USE_BRAM2(0)) vram_r
(
	.CLK(clk_sys), .CLK_MEM(clk_mem), .RST_N(~reset),
	.A(RA[19:2]), .D(RAM_DO[15:0]), .Q(VRAM_Q[15:0]),
	.RAS_N(RRAS0_N), .CAS_N(RCAS_N), .WE_N(RWE_N), .OE_N(ROE_N), .DSF1(RDSF),
	.SC(RSC), .SE_N(1'b0), .SQ(VRAM_SQ[15:0]), .QSF(RQSF),
	.RDY(VRAM_RRDY), .STALL_EARLY(vram_r_early), .SR_UNI(vram_r_uni), .SR_UNI_OTHER(vram_l_uni), .CPU_XFER(vram_cpu_xfer),
	.EQ(ddr_do[15:0]), .ESADDR(ddr_braddr), .ESDATA(vram_brdata), .ESWR(ddr_brwr), .ESRD(ddr_brrd), .ESFW(), .ESFWD(vram_brfwd),
	.ESQ({ddr_bout[47:32],ddr_bout[15:0]}), .ESTE(ddr_brte), .EWADDR(ddr_brwaddr), .EWTE(ddr_brwte), .EWBUSY(ddr_brwbusy),
	.BRAM4_OFFS(BRAM4_OFFS), .BRAM2_OFFS(BRAM2_OFFS), .BRAM1_OFFS(BRAM1_OFFS)
);

assign RAM_DI = !LRAS0_N || !RRAS0_N ? VRAM_Q : sdr_dout;

wire [31: 0] ddr_io_do;
wire         ddr_io_busy;
wire [15: 0] ddr_nvram_do;
wire         ddr_nvram_busy;
wire         ddr_busy, ddr_busy_early;
wire         ddr_pf_hold;

assign PDI = !SRAMR_N ? (ddr_io_do>>{~PA[3:2],3'b000}) & 32'h000000FF : ddr_io_do;

wire [19:0] dlw_addr;
wire [31:0] dlw_din;
wire [ 3:0] dlw_we;
wire        dlw_idle;
wire [19:0] nv_addr;
wire [31:0] nv_din;
wire [ 3:0] nv_we;
wire        nv_active, nv_ready;
wire        sv_ld_hold, sv_ld_req, sv_ld_ack;
wire [12:0] sv_ld_addr;
wire [31:0] sv_ld_din;
wire [14:1] sv_nvram_addr;
wire        sv_nvram_rd;
assign dl_active = bios_download | kanji_download | ~dlw_idle | nv_active;

reg         nv_bios_seen = 0, nv_started = 0;
always @(posedge clk_sys) begin
	if (bios_download) nv_bios_seen <= 1;
	if (nv_bios_seen && !bios_download && !kanji_download && dlw_idle && !nv_started) nv_started <= 1;
end
nv_init nv_init
(
	.clk(clk_sys), .start(nv_bios_seen && !bios_download && !kanji_download && dlw_idle && !nv_started),
	.io_busy(ddr_io_busy), .io_addr(nv_addr), .io_din(nv_din), .io_we(nv_we), .active(nv_active),
	.ready(nv_ready), .ld_hold(sv_ld_hold), .ld_req(sv_ld_req), .ld_addr(sv_ld_addr), .ld_din(sv_ld_din), .ld_ack(sv_ld_ack)
);

nv_save nv_save
(
	.clk(clk_sys), .img_mounted(img_mounted[1]), .img_size(img_size),
	.fmt_done(nv_started & nv_ready), .dl_idle(~bios_download & ~kanji_download & dlw_idle),
	.save_req(status[8]), .hold_rst(sv_hold_rst),
	.sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack), .sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_dout), .sd_dout_strobe(sd_dout_strobe), .sd_din(sd_din),
	.ld_hold(sv_ld_hold), .ld_req(sv_ld_req), .ld_addr(sv_ld_addr), .ld_din(sv_ld_din), .ld_ack(sv_ld_ack),
	.nvram_addr(sv_nvram_addr), .nvram_rd(sv_nvram_rd), .nvram_dout(ddr_nvram_do), .nvram_busy(ddr_nvram_busy)
);

dl_writer dl_writer
(
	.clk(clk_sys), .download(bios_download | kanji_download), .kanji(kanji_download),
	.ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr), .ioctl_data(ioctl_data),
	.io_busy(ddr_io_busy), .io_addr(dlw_addr), .io_din(dlw_din), .io_we(dlw_we),
	.idle(dlw_idle)
);

wire ddr_luse = ~((LA[19:2] >= ({BRAM4_OFFS+0,16'h0000}>>2) && LA[19:2] <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) || (LA[19:2] >= ({BRAM1_OFFS+0,16'h0000}>>2) && LA[19:2] <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (LA[19:2] >= (20'hFC000>>2)));
wire ddr_ruse = ~((RA[19:2] >= ({BRAM4_OFFS+0,16'h0000}>>2) && RA[19:2] <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) || (RA[19:2] >= ({BRAM1_OFFS+0,16'h0000}>>2) && RA[19:2] <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (RA[19:2] >= (20'hFC000>>2)));

wire         DDRAM_BUSY, DDRAM_DOUT_READY, DDRAM_RD, DDRAM_WE;
wire [ 7: 0] DDRAM_BURSTCNT, DDRAM_BE;
wire [28: 0] DDRAM_ADDR;
wire [63: 0] DDRAM_DOUT, DDRAM_DIN;

ddram_sidi ddram
(
	.clk_sys(clk_sys), .busy_early(ddr_busy_early), .pf_hold(ddr_pf_hold),
	.DDRAM_CLK(), .DDRAM_BUSY(DDRAM_BUSY), .DDRAM_BURSTCNT(DDRAM_BURSTCNT), .DDRAM_ADDR(DDRAM_ADDR),
	.DDRAM_DOUT(DDRAM_DOUT), .DDRAM_DOUT_READY(DDRAM_DOUT_READY), .DDRAM_RD(DDRAM_RD),
	.DDRAM_DIN(DDRAM_DIN), .DDRAM_BE(DDRAM_BE), .DDRAM_WE(DDRAM_WE),
	.clk(clk_mem), .rst(mem_rst),

	.io_addr(nv_active ? nv_addr : dl_active ? dlw_addr : !SRAMW_N || !SRAMR_N ? {1'b1,6'b000000,PA[16:4]} : {1'b0,ROM_SEL,PA[19:2]}),
	.io_din (nv_active ? nv_din : dl_active ? dlw_din : {4{PDO}}),
	.io_we  (nv_active ? nv_we : dl_active ? dlw_we : !SRAMW_N ? (4'h8>>PA[3:2])&{4{MCLK_CE}} : 4'b0000),
	.io_rd  (dl_active ? 1'b0 : (~ROMCS_N|~SRAMR_N)&MCLK_CE),
	.io_dout(ddr_io_do),
	.io_busy(ddr_io_busy),

	.nvram_addr(sv_nvram_addr), .nvram_din(16'd0), .nvram_wr(1'b0), .nvram_rd(sv_nvram_rd),
	.nvram_dout(ddr_nvram_do), .nvram_busy(ddr_nvram_busy),

	.sclk(CE_R),
	.d_laddr(LA[19:2]), .d_ldin(RAM_DO[31:16]), .d_lras(!LRAS0_N), .d_lwe(ddr_luse ? ~LWE_N : 2'b00), .d_lrd(ddr_luse ? ~LOE_N : 1'b0), .ldout(ddr_do[31:16]),
	.d_raddr(RA[19:2]), .d_rdin(RAM_DO[15:0]),  .d_rras(!RRAS0_N), .d_rwe(ddr_ruse ? ~RWE_N : 2'b00), .d_rrd(ddr_ruse ? ~ROE_N : 1'b0), .rdout(ddr_do[15:0]),
	.busy(ddr_busy),

	.bladdr(ddr_bladdr), .blwr(ddr_blwr), .blrd(ddr_blrd), .braddr(ddr_braddr), .brwr(ddr_brwr), .brrd(ddr_brrd),
	.bfw(ddr_bfw), .bfwd({vram_blfwd,vram_brfwd}), .ba(), .bin(ddr_bin), .bout(ddr_bout), .blte(ddr_blte), .brte(ddr_brte), .bbusy(ddr_bbusy),
	.blwaddr(ddr_blwaddr), .brwaddr(ddr_brwaddr), .blwte(ddr_blwte), .brwte(ddr_brwte), .blwbusy(ddr_blwbusy), .brwbusy(ddr_brwbusy)
);

wire         cBUSY, cDOUT_READY, cRD, cWE;
wire [ 7: 0] cBURSTCNT, cBE;
wire [28: 0] cADDR;
wire [63: 0] cDOUT, cDIN;

ddram_cache ddram_cache
(
	.clk(clk_mem), .rst(mem_rst),
	.s_BUSY(DDRAM_BUSY), .s_BURSTCNT(DDRAM_BURSTCNT), .s_ADDR(DDRAM_ADDR),
	.s_DOUT(DDRAM_DOUT), .s_DOUT_READY(DDRAM_DOUT_READY),
	.s_RD(DDRAM_RD), .s_DIN(DDRAM_DIN), .s_BE(DDRAM_BE), .s_WE(DDRAM_WE),
	.pf_hold(ddr_pf_hold),
	.m_BUSY(cBUSY), .m_BURSTCNT(cBURSTCNT), .m_ADDR(cADDR), .m_DOUT(cDOUT), .m_DOUT_READY(cDOUT_READY),
	.m_RD(cRD), .m_DIN(cDIN), .m_BE(cBE), .m_WE(cWE)
);

wire [15: 0] sdr2_dqo;
wire         sdr2_dqoe;
assign SDRAM2_DQ = sdr2_dqoe ? sdr2_dqo : 16'hZZZZ;

ddram_sdr3 ddram_sdr
(
	.clk(clk_mem), .quiet(pause), .inval(reset),
	.DDRAM_BUSY(cBUSY), .DDRAM_BURSTCNT(cBURSTCNT), .DDRAM_ADDR(cADDR),
	.DDRAM_DOUT(cDOUT), .DDRAM_DOUT_READY(cDOUT_READY), .DDRAM_RD(cRD),
	.DDRAM_DIN(cDIN), .DDRAM_BE(cBE), .DDRAM_WE(cWE),
	.SDRAM_A(SDRAM2_A), .SDRAM_BA(SDRAM2_BA), .SDRAM_DQ_I(SDRAM2_DQ), .SDRAM_DQ_O(sdr2_dqo), .SDRAM_DQ_OE(sdr2_dqoe), .SDRAM_DQML(SDRAM2_DQML), .SDRAM_DQMH(SDRAM2_DQMH),
	.SDRAM_nCS(SDRAM2_nCS), .SDRAM_nWE(SDRAM2_nWE), .SDRAM_nRAS(SDRAM2_nRAS), .SDRAM_nCAS(SDRAM2_nCAS), .SDRAM_CKE(SDRAM2_CKE),
	.c1_req(c1_req), .c1_own(c1_own), .x1_cmd(x1_cmd), .x1_a(x1_a), .x1_ba(x1_ba), .x1_dq(x1_dq), .x1_oe(x1_oe), .x1_dqm(x1_dqm), .x1_din(x1_din)
);

always @(posedge clk_sys) begin
	bit cond;
	if (reset) begin
		pause <= 0;
	end else if (CE_F) begin
		cond = ddr_io_busy || ddr_busy || !VRAM_LRDY || !VRAM_RRDY || ddr_busy_early || vram_l_early || vram_r_early || (c1_req && pause);
		if (cond && !pause) pause <= 1;
		if (!cond && pause) pause <= 0;
	end
end

wire [1:0] scanlines = status[3:2];

mist_video #(.COLOR_DEPTH(8), .OUT_COLOR_DEPTH(8), .SD_HCNT_WIDTH(11), .BIG_OSD(1'b1)) mist_video
(
	.clk_sys       (clk_vid      ),
	.SPI_SCK       (SPI_SCK      ),
	.SPI_SS3       (SPI_SS3      ),
	.SPI_DI        (SPI_DI       ),
	.scanlines     (scanlines    ),
	.ce_divider    (3'd3         ),
	.scandoubler_disable(scandoublerD),
	.no_csync      (no_csync     ),
	.ypbpr         (ypbpr        ),
	.rotate        (2'b00        ),
	.blend         (1'b0         ),
	.R             (R            ),
	.G             (G            ),
	.B             (B            ),
	.HBlank        (~HBL_N       ),
	.VBlank        (~VBL_N       ),
	.HSync         (~HS_N        ),
	.VSync         (~VS_N        ),
	.VGA_R         (VGA_R        ),
	.VGA_G         (VGA_G        ),
	.VGA_B         (VGA_B        ),
	.VGA_VS        (VGA_VS       ),
	.VGA_HS        (VGA_HS       )
);

`ifdef USE_HDMI
i2c_master #(50_000_000) i2c_master
(
	.CLK         (clk_sys    ),
	.I2C_START   (i2c_start  ),
	.I2C_READ    (i2c_read   ),
	.I2C_ADDR    (i2c_addr   ),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout   ),
	.I2C_RDATA   (i2c_din    ),
	.I2C_END     (i2c_end    ),
	.I2C_ACK     (i2c_ack    ),
	.I2C_SCL     (HDMI_SCL   ),
	.I2C_SDA     (HDMI_SDA   )
);

mist_video #(.COLOR_DEPTH(8), .OUT_COLOR_DEPTH(8), .SD_HCNT_WIDTH(11), .USE_BLANKS(1), .VIDEO_CLEANER(1), .BIG_OSD(1'b1)) hdmi_video
(
	.clk_sys       (clk_vid      ),
	.SPI_SCK       (SPI_SCK      ),
	.SPI_SS3       (SPI_SS3      ),
	.SPI_DI        (SPI_DI       ),
	.scanlines     (scanlines    ),
	.ce_divider    (3'd3         ),
	.scandoubler_disable(1'b0    ),
	.no_csync      (1'b1         ),
	.ypbpr         (1'b0         ),
	.rotate        (2'b00        ),
	.blend         (1'b0         ),
	.R             (R            ),
	.G             (G            ),
	.B             (B            ),
	.HBlank        (~HBL_N       ),
	.VBlank        (~VBL_N       ),
	.HSync         (~HS_N        ),
	.VSync         (~VS_N        ),
	.VGA_R         (HDMI_R       ),
	.VGA_G         (HDMI_G       ),
	.VGA_B         (HDMI_B       ),
	.VGA_VS        (HDMI_VS      ),
	.VGA_HS        (HDMI_HS      ),
	.VGA_DE        (HDMI_DE      )
);
assign HDMI_PCLK = clk_vid;
`endif

reg [15:0] aud_l, aud_r;
always @(posedge clk_sys) begin
	aud_l <= {~AUDIO_L_3DO[15], AUDIO_L_3DO[14:0]};
	aud_r <= {~AUDIO_R_3DO[15], AUDIO_R_3DO[14:0]};
end
dac #(.C_bits(16)) dac_l (.clk_i(clk_sys), .res_n_i(1'b1), .dac_i(aud_l), .dac_o(AUDIO_L));
dac #(.C_bits(16)) dac_r (.clk_i(clk_sys), .res_n_i(1'b1), .dac_i(aud_r), .dac_o(AUDIO_R));

`ifdef I2S_AUDIO
i2s i2s
(
	.reset      (1'b0          ),
	.clk        (clk_sys       ),
	.clk_rate   (32'd50_000_000),
	.sclk       (I2S_BCK       ),
	.lrclk      (I2S_LRCK      ),
	.sdata      (I2S_DATA      ),
	.left_chan  (AUDIO_L_3DO   ),
	.right_chan (AUDIO_R_3DO   )
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 1'b0;
always @(posedge clk_sys) begin
	HDMI_BCK   <= I2S_BCK;
	HDMI_LRCK  <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

assign LED = ~(bios_download | kanji_download);

endmodule
