module atari800_mist_top(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
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
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

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

`ifdef DUAL_SDRAM
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
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX
);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
wire QSCK = 1, QCSn = 1;
wire [3:0] QDAT = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef DUAL_SDRAM
`ifndef VBXE
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif
`endif

assign UART_TX = 1;

`include "build_id.v"

localparam CONF_STR = {
	"A800XL;;",
	`SEP
	"S0U,ATRXEXXFDATX,Mount D1;",
	"S1U,ATRXEXXFDATX,Mount D2;",
	"S2U,ATRXEXXFDIMG,Mount D3;",
	"S3U,CARROMBINXEX,Load Cart;",
	"F5,CAR,Load Cart (fast);",
	`SEP
	"P1,Drives & Loader;",
	"P2,Hardware & OS;",
	"P3,PBI;",
	"P4,Video & Audio;",
	`SEP
	"P1O3,D1 mount action,Mount & Boot,Mount only;",
	"P1OO,Cart slot,Main,Stacked;",
	"P1OIK,SIO drive speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"P1OL,ATX drive timing,1050,810;",
	"P1OM,XEX loader,Standard,Stack;",
	"P1ON,Mount read-only,No,Yes;",
	"P2O79,CPU speed,1x,2x,4x,8x,16x;",
	"P2On,Turbo at VBL only,Off,On;",
	"P2Oo,Keyboard,ISO,ANSI;",
	"P2OAB,Machine/BIOS,XL+Basic,XL,800/OS-A,800/OS-B;",
	"P2OCE,RAM XL,64K,128K,320K(Compy),320K(Rambo),576K(Compy),576K(Rambo),1MB,4MB(Axlon);",
	"P2OFH,RAM 800,8K,16K,32K,48K,52K,4MB(Axlon);",
	"P2F1,ROMBIN,Set XL OS;",
	"P2F2,ROMBIN,Set Basic;",
	"P2F3,ROMBIN,Set OS-A;",
	"P2F4,ROMBIN,Set OS-B;",
	"P3OP,PBI BIOS (XL),Disabled,Enabled;",
	"P3OQ,PBI splash,Disabled,Enabled;",
	"P3ORT,PBI boot drive,Default,APT,D1:,D2:,D3:,D4:,D5:,D6:;",
	"P3OUV,D1 mode,OS/Stock,PBI,HSIO;",
	"P3OWX,D2 mode,OS/Stock,PBI,HSIO;",
	"P3OYZ,D3 mode,OS/Stock,PBI,HSIO;",
	"P3Oab,D4 mode,OS/Stock,PBI,HSIO;",
	"P4O4,Video mode,PAL,NTSC;",
	"P4O56,Scanlines,None,25%,50%,75%;",
`ifdef VBXE
	"P4Oqr,VBXE,Disabled,$D640,$D740;",
	"P4Os,VBXE FX version,1.27,1.26a;",
	"P4Ot,VBXE Blitter,Normal,Turbo;",
	"P4Ou,GTIA xcolor,Off,On;",
`else
	"P4Oc,Hi-Res ANTIC,Disabled,Enabled;",
`endif
	"P4Od,NTSC artifacting,No,Yes;",
	"P4Oe,Artifacting colors,Set 1,Set 2;",
	"P4Of,Swap artif. colors,No,Yes;",
	"P4Og,Clip sides,Disabled,Enabled;",
`ifdef VBXE
	"P4Oh,PokeyMax,Off/Mono,Enabled;",
`else
	"P4Oh,Dual Pokey,Disabled,Enabled;",
`endif
	"P4Oij,Stereo mix,None,25%,50%,100%;",
	"Ok,Swap joysticks,No,Yes;",
	"Op,Paddles,Auto,Disabled;",
	"Olm,Debug LED,Drive,ZPU alive,Mount ack,SD read;",
	"T1,Warm reset (F9);",
	"T2,Cold reset (F10);",
	"V,v",`BUILD_DATE
};

wire clk_sys;
wire clk_mem;
wire pll_reset_n;
wire clk_reconfig;
wire reconfig_locked;

wire [63:0] status;
wire pal = ~status[4];

pll_reconfig reconfig_pll
(
	.inclk0(CLOCK_27),
	.c0(clk_reconfig),
	.locked(reconfig_locked)
);

reg rom_loaded = 0;
reg [1:0] download_sync;
wire loader_busy;
always @(posedge clk_reconfig or negedge reconfig_locked) begin
	if(!reconfig_locked) begin
		rom_loaded <= 0;
		download_sync <= 0;
	end else begin
		download_sync <= {download_sync[0], loader_busy};
		if(download_sync[1]) rom_loaded <= 1;
	end
end

wire [3:0] pll_clks;
assign clk_mem   = pll_clks[0];
assign clk_sys   = pll_clks[1];
assign SDRAM_CLK = pll_clks[2];

switch_pal_ntsc #(.CLOCKS(4), .SYNC_ON(1)) pll_switcher
(
	.RECONFIG_CLK(clk_reconfig),
	.RESET_N(reconfig_locked),
	.PAL(pal),
	.SWITCH_ENA(~download_sync[1] & rom_loaded),
	.INPUT_CLK(CLOCK_27),
	.PLL_CLKS(pll_clks),
	.RESET_N_OUT(pll_reset_n)
);

wire [31:0] clk_rate = pal ? 32'd28375000 : 32'd28636364;

wire [31:0] joystick_0, joystick_1, joystick_2, joystick_3;
wire [31:0] joystick_analog_0, joystick_analog_1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;
wire [63:0] rtc;

wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;
wire        key_strobe;

wire [31:0] sd_lba;
wire  [3:0] sd_rd;
wire  [3:0] sd_wr;
wire        sd_ack;
wire [16:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire [63:0] img_size;

wire        i2c_start, i2c_read, i2c_end, i2c_ack;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr, i2c_dout, i2c_din;

user_io #(
	.STRLEN($size(CONF_STR)>>3),
	.SD_IMAGES(4),
	.FEATURES({17'd0, HDMI, BIG_OSD, 13'd0})
)
user_io
(
	.clk_sys(clk_sys),
	.clk_sd(clk_sys),
	.conf_str(CONF_STR),

	.SPI_CLK(SPI_SCK),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_MISO(SPI_DO),
	.SPI_MOSI(SPI_DI),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_analog_0(joystick_analog_0),
	.joystick_analog_1(joystick_analog_1),
	.buttons(buttons),
	.switches(switches),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.status(status),
	.rtc(rtc),

	.i2c_start(i2c_start),
	.i2c_read(i2c_read),
	.i2c_addr(i2c_addr),
	.i2c_subaddr(i2c_subaddr),
	.i2c_dout(i2c_dout),
	.i2c_din(i2c_din),
	.i2c_ack(i2c_ack),
	.i2c_end(i2c_end),

	.conf_chr(8'd0),
	.ps2_kbd_clk_i(1'b1),
	.ps2_kbd_data_i(1'b1),
	.ps2_mouse_clk_i(1'b1),
	.ps2_mouse_data_i(1'b1),
	.kbd_out_data(8'd0),
	.kbd_out_strobe(1'b0),
	.leds(8'd0),
	.serial_data(8'd0),
	.serial_strobe(1'b0),

	.key_pressed(key_pressed),
	.key_extended(key_extended),
	.key_code(key_code),
	.key_strobe(key_strobe),

	.sd_lba(sd_lba),
	.sd_cnt(8'd1),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_conf(1'b0),
	.sd_sdhc(1'b1),
	.sd_dout(sd_buff_dout),
	.sd_dout_strobe(sd_buff_wr),
	.sd_din(sd_buff_din),
	.sd_buff_addr(sd_buff_addr),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire [31:0] ioctl_filesize;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD), .USE_QSPI(QSPI)) data_io
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_SS2(SPI_SS2),
	.SPI_SS4(SPI_SS4),
	.SPI_DI(SPI_DI),
	.SPI_DO(SPI_DO),
	.QSCK(QSCK),
	.QCSn(QCSn),
	.QDAT(QDAT),
	.clkref_n(1'b0),
	.ioctl_din(8'd0),
	.hdd_clk(1'b0),
	.hdd_cmd_req(1'b0),
	.hdd_cdda_req(1'b0),
	.hdd_dat_req(1'b0),
	.hdd_data_in(16'd0),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_filesize(ioctl_filesize)
);

reg [10:0] ps2_key;
always @(posedge clk_sys) if(key_strobe) ps2_key <= {~ps2_key[10], key_pressed, key_extended, key_code};

reg [64:0] rtc65;
always @(posedge clk_sys) if(rtc != rtc65[63:0]) rtc65 <= {~rtc65[64], rtc};

wire core_reset = (status[0] | buttons[1]) & ~loader_busy;
wire reset = ~pll_reset_n | core_reset;
wire areset;

wire [7:0] Ro,Go,Bo;
wire HBlank_o, VBlank_o, HSync_o, VSync_o;
wire ce_pix_raw;
wire cpu_halt;
wire drive_led;

wire [15:0] laudio, raudio;

wire  [7:0] ZPU_IN2;
wire [31:0] ZPU_OUT2;
wire [31:0] ZPU_IN3;
wire [31:0] ZPU_OUT3;
wire [15:0] ZPU_RD;
wire [15:0] ZPU_WR;

reg [5:0] cpu_speed;
always @(*) begin
	case(status[9:7])
		3'd0: cpu_speed = 6'd1;
		3'd1: cpu_speed = 6'd2;
		3'd2: cpu_speed = 6'd4;
		3'd3: cpu_speed = 6'd8;
		default: cpu_speed = 6'd16;
	endcase
end

function [13:0] mjoy(input [31:0] j);
	mjoy = {2'b00, j[9], j[6], j[7], j[11], j[10], j[8], j[5], j[4], j[3:0]};
endfunction

wire        joyswap = status[46];
wire [13:0] j1 = mjoy(joyswap ? joystick_1 : joystick_0);
wire [13:0] j2 = mjoy(joyswap ? joystick_0 : joystick_1);
wire [13:0] j3 = mjoy(joystick_2);
wire [13:0] j4 = mjoy(joystick_3);
wire [15:0] ja1 = joyswap ? joystick_analog_1[15:0] : joystick_analog_0[15:0];
wire [15:0] ja2 = joyswap ? joystick_analog_0[15:0] : joystick_analog_1[15:0];

reg  [1:0] rom_sel = 0;
reg        mode800 = 0;
reg        modepbi = 0;
reg        splashpbi = 0;
reg  [7:0] drivesmodepbi = 0;
reg  [2:0] bootpbi = 0;
reg  [2:0] ram_config = 0;

always @(posedge clk_sys) if(areset) begin
	rom_sel       <= status[11:10];
	mode800       <= status[11];
	modepbi       <= ~status[11] & status[25];
	splashpbi     <= status[26];
	bootpbi       <= status[29:27];
	drivesmodepbi <= status[37:30];
	ram_config    <= status[11] ? status[17:15] : status[14:12];
end

wire [13:0] osxl_off, osa_off, osb_off;
wire        load_req, load_ack, load_width32;
wire [24:0] load_addr;
wire [31:0] load_data;
wire        load_reset;
wire        cart_set;
wire  [7:0] cart_mode;

`ifdef VBXE
wire        vbxe_on = status[52] | status[53];
wire [18:0] vram_addr;
wire  [7:0] vram_din;
wire        vram_req, vram_ready;
wire [18:0] vram_b_addr;
wire  [7:0] vram_b_dout, vram_b_din;
wire        vram_b_req, vram_b_we, vram_b_ready;
wire [56:0] vram_hint;

wire [38:0] pokeymax_config = {
	3'b001,
	3'b000,
	2'b01,
	1'b0,
	2'b00,
	2'b00,
	3'b010,
	3'b010,
	1'b1,
	1'b1,
	1'b0,
	2'b11,
	1'b0,
	1'b1,
	1'b0,
	2'b10,
	2'b11,
	4'b1010,
	2'b11,
	1'b1,
	status[43]
};

vbxe_vram vbxe_vram
(
	.clk_sys(clk_sys),
	.clk_mem(clk_mem),
	.reset(~pll_reset_n),
	.a_addr(vram_addr),
	.a_req(vram_req),
	.a_ready(vram_ready),
	.a_dout(vram_din),
	.a_hint0(vram_hint[18:0]),
	.a_hint1(vram_hint[37:19]),
	.a_hint2(vram_hint[56:38]),
	.addr(vram_b_addr),
	.din(vram_b_dout),
	.req(vram_b_req),
	.we(vram_b_we),
	.ready(vram_b_ready),
	.dout(vram_b_din),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_DQML(SDRAM2_DQML),
	.SDRAM_DQMH(SDRAM2_DQMH),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nCAS(SDRAM2_nCAS),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_CKE(SDRAM2_CKE)
);
assign SDRAM2_CLK = pll_clks[2];
`else
wire vbxe_on = 0;
`endif

atari800top #(
	.CYCLE_LENGTH(16),
	.CLK_HZ_NTSC(28636364),
	.CLK_HZ_PAL(28375000)
)
atari800top
(
	.CLK(clk_sys),
	.CLK_SDRAM(clk_mem),
	.RESET_N(pll_reset_n),
	.CORE_RESET(core_reset),
	.CPU_HOLD(loader_busy),
	.ARESET(areset),

	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),

	.ROM_SEL(rom_sel),
	.OSXL_OFF(osxl_off),
	.OSA_OFF(osa_off),
	.OSB_OFF(osb_off),
	.LOAD_REQ(load_req),
	.LOAD_ADDR(load_addr),
	.LOAD_DATA(load_data),
	.LOAD_WIDTH32(load_width32),
	.LOAD_ACK(load_ack),

	.PAL(pal),
	.EXT_ANTIC(status[38]),
`ifdef VBXE
	.GTIA_XCOLOR(status[56]),
	.VBXE_MODE({status[55], ~status[54], status[53:52]}),
	.POKEYMAX_CONFIG(pokeymax_config),
	.VRAM_ADDR(vram_addr),
	.VRAM_DATA_OUT(),
	.VRAM_DATA_IN(vram_din),
	.VRAM_REQUEST(vram_req),
	.VRAM_WR_EN(),
	.VRAM_READY(vram_ready),
	.VRAM_B_ADDR(vram_b_addr),
	.VRAM_B_DATA_OUT(vram_b_dout),
	.VRAM_B_DATA_IN(vram_b_din),
	.VRAM_B_REQUEST(vram_b_req),
	.VRAM_B_WR_EN(vram_b_we),
	.VRAM_B_READY(vram_b_ready),
	.VRAM_HINT(vram_hint),
`endif
	.CLIP_SIDES(status[42]),
	.VGA_VS(VSync_o),
	.VGA_HS(HSync_o),
	.VGA_BLANK(),
	.VGA_B(Bo),
	.VGA_G(Go),
	.VGA_R(Ro),
	.VGA_PIXCE(ce_pix_raw),
	.HBLANK(HBlank_o),
	.VBLANK(VBlank_o),

	.CPU_SPEED(cpu_speed),
	.TURBO_VBLANK_ONLY(status[49]),
	.KEY_TYPE(status[50]),
	.PADDLE_DIS(status[51]),
	.RAM_SIZE(ram_config),
	.DRV_SPEED(status[20:18]),
	.XEX_LOC(status[22]),
	.OS_MODE_800(mode800),
	.PBI_MODE(modepbi),
	.PBI_SPLASH(splashpbi),
	.PBI_DRIVES_MODE(drivesmodepbi),
	.PBI_BOOT(bootpbi),
	.ATX_MODE(~status[21]),
	.DRIVE_LED(drive_led),
	.WARM_RESET_MENU(status[1]),
	.COLD_RESET_MENU(status[2] | load_reset),
	.CART_FAST_SET(cart_set),
	.CART_FAST_MODE(cart_mode),
	.CART_FAST_CLEAR(img_mounted[3] | (img_mounted[0] & ~status[3])),
	.RTC(rtc65),

	.STEREO(status[43]),
	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

	.ZPU_IN2(ZPU_IN2),
	.ZPU_OUT2(ZPU_OUT2),
	.ZPU_IN3(ZPU_IN3),
	.ZPU_OUT3(ZPU_OUT3),
	.ZPU_RD(ZPU_RD),
	.ZPU_WR(ZPU_WR),

	.SIO_MODE(1'b0),
	.SIO_IN(1'b1),
	.SIO_OUT(),
	.SIO_CLKOUT(),
	.SIO_CLKIN(1'b1),
	.SIO_CMD(),
	.SIO_PROC(1'b1),
	.SIO_MOTOR(),
	.SIO_IRQ(1'b1),

	.CPU_HALT(cpu_halt),

	.PS2_KEY(ps2_key),

	.JOY1X(ja1[15:8]),
	.JOY1Y(ja1[7:0]),
	.JOY2X(ja2[15:8]),
	.JOY2Y(ja2[7:0]),
	.JOY3X(8'd0),
	.JOY3Y(8'd0),
	.JOY4X(8'd0),
	.JOY4Y(8'd0),

	.JOY1(j1),
	.JOY2(j2),
	.JOY3(j3),
	.JOY4(j4)
);

reg [22:0] zpu_act_cnt = 0;
reg        zpu_alive = 0;
reg [23:0] zpu_idle = 0;
reg        mount_ack = 0;
reg [23:0] sdrd_stretch = 0;
always @(posedge clk_sys) begin
	reg old_rd, old_rq;
	old_rd <= |ZPU_RD;
	if(~old_rd & |ZPU_RD) begin
		zpu_act_cnt <= zpu_act_cnt + 1'd1;
		zpu_idle <= 0;
	end
	else if(~&zpu_idle) zpu_idle <= zpu_idle + 1'd1;
	zpu_alive <= ~&zpu_idle;

	if(|img_mounted) mount_ack <= 0;
	else if(ZPU_RD[2] & ZPU_OUT2[0]) mount_ack <= 1;

	old_rq <= |(sd_rd | sd_wr);
	if(~old_rq & |(sd_rd | sd_wr)) sdrd_stretch <= 24'hFFFFFF;
	else if(|sdrd_stretch) sdrd_stretch <= sdrd_stretch - 1'd1;
end

reg led_dbg;
always @(*) begin
	case(status[48:47])
		2'd0: led_dbg = drive_led | ioctl_download;
		2'd1: led_dbg = zpu_alive & zpu_act_cnt[22];
		2'd2: led_dbg = mount_ack;
		default: led_dbg = |sdrd_stretch;
	endcase
end
assign LED = ~led_dbg;

rom_loader rom_loader
(
	.clk(clk_sys),
	.reset(~pll_reset_n),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_filesize(ioctl_filesize),

	.osxl_off(osxl_off),
	.osa_off(osa_off),
	.osb_off(osb_off),

	.load_req(load_req),
	.load_addr(load_addr),
	.load_data(load_data),
	.load_width32(load_width32),
	.load_ack(load_ack),

	.load_reset(load_reset),
	.cart_set(cart_set),
	.cart_mode(cart_mode),
	.busy_any(loader_busy)
);

sd_glue #(.REPLAY_HOLD(28'hE000000)) sd_glue
(
	.clk(clk_sys),
	.reset(reset),

	.d1_boot(~status[3]),
	.drop_cart(cart_set),
	.cart_stacked(status[24]),
	.force_readonly(status[23]),

	.ioctl_index(ioctl_index),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr[8:0]),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size[31:0]),

	.ZPU_IN2(ZPU_IN2),
	.ZPU_OUT2(ZPU_OUT2),
	.ZPU_IN3(ZPU_IN3),
	.ZPU_OUT3(ZPU_OUT3),
	.ZPU_RD(ZPU_RD),
	.ZPU_WR(ZPU_WR)
);

reg ce_pix_raw_old = 0;
wire ce_pix = ce_pix_raw & ~ce_pix_raw_old;
always @(posedge clk_sys) ce_pix_raw_old <= ce_pix_raw;

reg hsync_o, vsync_o;
always @(posedge clk_sys) begin
	if(ce_pix) begin
		hsync_o <= HSync_o;
		if(~hsync_o & HSync_o) vsync_o <= VSync_o;
	end
end

wire [7:0] R,G,B;
wire HBlank, VBlank, HSync, VSync;

articolor articolor
(
	.clk(clk_sys),
	.ce_pix(ce_pix),

	.enable(~pal & status[39] & ~vbxe_on),
	.colorset(~status[40]),
	.colorswap(status[41]),

	.r_in(Ro),
	.g_in(Go),
	.b_in(Bo),
	.hbl_in(HBlank_o),
	.vbl_in(VBlank_o),
	.hs_in(hsync_o),
	.vs_in(vsync_o),

	.r_out(R),
	.g_out(G),
	.b_out(B),
	.hbl_out(HBlank),
	.vbl_out(VBlank),
	.hs_out(HSync),
	.vs_out(VSync)
);

mist_video #(
	.COLOR_DEPTH(8),
	.SD_HCNT_WIDTH(10),
	.OSD_COLOR(3'b011),
	.OSD_AUTO_CE(1'b0),
	.USE_BLANKS(1'b1),
	.OUT_COLOR_DEPTH(VGA_BITS),
	.BIG_OSD(BIG_OSD)
)
mist_video
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.scanlines(status[6:5]),
	.ce_divider(3'd0),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.rotate(2'b00),
	.blend(1'b0),
	.R(R),
	.G(G),
	.B(B),
	.HBlank(HBlank),
	.VBlank(VBlank),
	.HSync(HSync),
	.VSync(VSync),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS)
);

`ifdef USE_HDMI
i2c_master #(28_000_000) i2c_master
(
	.CLK(clk_sys),
	.I2C_START(i2c_start),
	.I2C_READ(i2c_read),
	.I2C_ADDR(i2c_addr),
	.I2C_SUBADDR(i2c_subaddr),
	.I2C_WDATA(i2c_dout),
	.I2C_RDATA(i2c_din),
	.I2C_END(i2c_end),
	.I2C_ACK(i2c_ack),
	.I2C_SCL(HDMI_SCL),
	.I2C_SDA(HDMI_SDA)
);

mist_video #(
	.COLOR_DEPTH(8),
	.SD_HCNT_WIDTH(10),
	.OSD_COLOR(3'b011),
	.OSD_AUTO_CE(1'b0),
	.USE_BLANKS(1'b1),
	.OUT_COLOR_DEPTH(8),
	.BIG_OSD(BIG_OSD),
	.VIDEO_CLEANER(1'b1)
)
hdmi_video
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.scanlines(status[6:5]),
	.ce_divider(3'd0),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.blend(1'b0),
	.R(R),
	.G(G),
	.B(B),
	.HBlank(HBlank),
	.VBlank(VBlank),
	.HSync(HSync),
	.VSync(VSync),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_VS(HDMI_VS),
	.VGA_HS(HDMI_HS),
	.VGA_DE(HDMI_DE)
);

assign HDMI_PCLK = clk_sys;
`endif

wire signed [15:0] al = laudio;
wire signed [15:0] ar = status[43] ? raudio : laudio;

reg signed [15:0] mix_l, mix_r;
always @(posedge clk_sys) begin
	reg signed [19:0] l, r, sl, sr;
	l = al;
	r = ar;
	case(status[45:44])
		2'd0: begin sl = l <<< 3;             sr = r <<< 3;             end
		2'd1: begin sl = (l <<< 3) - l + r;   sr = (r <<< 3) - r + l;   end
		2'd2: begin sl = (l <<< 2) + (l <<< 1) + (r <<< 1); sr = (r <<< 2) + (r <<< 1) + (l <<< 1); end
		default: begin sl = (l + r) <<< 2;    sr = sl;                  end
	endcase
	mix_l <= sl[18:3];
	mix_r <= sr[18:3];
end

hq_dac dac_l
(
	.reset(reset),
	.clk(clk_sys),
	.clk_ena(1'b1),
	.pcm_in({mix_l, 4'd0}),
	.dac_out(AUDIO_L)
);

hq_dac dac_r
(
	.reset(reset),
	.clk(clk_sys),
	.clk_ena(1'b1),
	.pcm_in({mix_r, 4'd0}),
	.dac_out(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s
(
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(clk_rate),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan(mix_l),
	.right_chan(mix_r)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
assign HDMI_BCK = I2S_BCK;
assign HDMI_LRCK = I2S_LRCK;
assign HDMI_SDATA = I2S_DATA;
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.rst_i(1'b0),
	.clk_i(clk_sys),
	.clk_rate_i(clk_rate),
	.spdif_o(SPDIF),
	.sample_i({mix_r, mix_l})
);
`endif

endmodule
