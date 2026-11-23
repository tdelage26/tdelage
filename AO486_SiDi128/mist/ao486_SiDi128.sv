// SiDi128 TOP module for ao486.

module ao486_SiDi128(
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
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

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
`ifdef USE_MIDI_PINS
	output        MIDI_OUT,
	input         MIDI_IN,
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

`ifdef USE_AUDIO_IN
localparam bit USE_AUDIO_IN = 1;
`else
localparam bit USE_AUDIO_IN = 0;
`endif

`include "build_id.v"

parameter CONF_STR = {
	"AO486;;",
	"S0U,VHDIMG,Mount C: (boot);",
	"S1U,VHDIMG,Mount D: (VHD);",
	"S2U,IMGIMAVFD,Mount A: (floppy);",
	"S3C,CUEISO,Mount CD;",
	"OA,Gravis Ultrasound,On,Off;",
	`SEP
	"O8,Swap joysticks,No,Yes;",
	"OBC,Joystick,2 buttons,4 buttons,None;",
	`SEP
	"T0,Reset;",
	"V,",`BUILD_DATE
};

wire        joyswap   = status[8];
wire  [1:0] joytype   = status[12:11];
wire        adlibhide = status[10];

// core's raw video 
wire  [5:0] core_r, core_g, core_b;
wire        core_hs, core_vs;
wire        core_blank, core_vb;

`ifdef AO486_CPU40
localparam  CPU_MHZ = 40;
localparam  [31:0] CPU_HZ = 32'd40_000_000;
`elsif AO486_CPU33
localparam  CPU_MHZ = 33;
localparam  [31:0] CPU_HZ = 32'd33_333_333;
`else
localparam  CPU_MHZ = 25;
localparam  [31:0] CPU_HZ = 32'd25_000_000;
`endif

wire        clk_25, clk_sdr;
wire        clk_cpu, clk_aud;
wire        clk_sys = clk_25;

assign SDRAM_CKE = 1'b1;

dcm dcm_system (
	.inclk0(CLOCK_27),
	.c0(SDRAM_CLK),
	.c1(clk_sdr),
	.c2(clk_cpu),
	.c3()
);

dcm_misc dcm_misc (
	.inclk0(CLOCK_27),
	.c0(clk_aud),
	.c1(),
	.c2()
);

wire        clk_vga50;
dcm_cpu dcm_cpu_inst (
	.inclk0(CLOCK_27),
	.c0(clk_25),
	.c1(clk_vga50)
);

reg  reset;
    
// user io
wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;

wire        ps2_kbd_clk, ps2_kbd_clk_i;
wire        ps2_kbd_dat, ps2_kbd_dat_i;
wire        ps2_mouse_clk, ps2_mouse_clk_i;
wire        ps2_mouse_dat, ps2_mouse_dat_i;

// conections between user_io (implementing the SPI communication 
// to the io controller) and the legacy SD Card wrapper
wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [3:0] uio_rd, uio_wr, uio_ack_x, uio_img_mounted;
wire  [7:0] ioctl_index;
wire        uio_ack;
wire [31:0] uio_lba;
wire  [7:0] uio_din;
wire        hd1_busy, hd1_rd, hd1_wr;
wire [31:0] hd1_lba;
wire  [7:0] hd1_buff_din;
reg         hd1_mounted = 1'b0;
reg  [31:0] hd1_sectors = 32'd0;
wire        fd_busy, fd_rd, fd_wr;
wire [31:0] fd_lba;
wire  [7:0] fd_buff_din;
reg         fd_mounted = 1'b0;
reg  [31:0] fd_sectors = 32'd0;
reg         fd_mount_evt = 1'b0;
wire        sd_conf;
wire        sd_sdhc; 
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire        sd_din_strobe;
wire  [8:0] sd_buff_addr;
wire        sd_ack_conf;
wire        img_mounted;
wire [63:0] img_size;

wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;

wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;

assign LED = ~led_out[0];

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

user_io_v6 #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(4), .PS2DIV(2000), .PS2BIDIR(1'b1), .FEATURES(32'h800 | (BIG_OSD << 13) | (HDMI << 14)) ) user_io(
	.conf_str        ( CONF_STR      ),
	.leds           ( 8'd0          ),
	.clk_sys         ( clk_cpu       ),
	.clk_sd          ( clk_cpu       ),

	// the spi interface
	.SPI_CLK         ( SPI_SCK       ),
	.SPI_SS_IO       ( CONF_DATA0    ),
	.SPI_MISO        ( SPI_DO        ),   // tristate handling inside user_io
	.SPI_MOSI        ( SPI_DI        ),

	.joystick_0        ( joystick_0 ),
	.joystick_1        ( joystick_1 ),
	.joystick_analog_0 ( joystick_analog_0 ),
	.joystick_analog_1 ( joystick_analog_1 ),

`ifdef USE_HDMI
	.i2c_start       ( i2c_start     ),
	.i2c_read        ( i2c_read      ),
	.i2c_addr        ( i2c_addr      ),
	.i2c_subaddr     ( i2c_subaddr   ),
	.i2c_dout        ( i2c_dout      ),
	.i2c_din         ( i2c_din       ),
	.i2c_ack         ( i2c_ack       ),
	.i2c_end         ( i2c_end       ),
`endif
	.status          ( status        ),
	.switches        ( switches      ),
	.buttons         ( buttons       ),
	.scandoubler_disable ( scandoubler_disable ),
	.ypbpr           ( ypbpr         ),
	.no_csync        ( no_csync      ),

   // interface to embedded legacy sd card wrapper
	.sd_lba          ( uio_lba       ),
	.sd_rd           ( uio_rd        ),
	.sd_wr           ( uio_wr        ),
	.sd_ack          ( uio_ack       ),
	.sd_ack_x        ( uio_ack_x     ),
	.sd_conf         ( sd_conf       ),
	.sd_sdhc         ( sd_sdhc       ),
	.sd_dout         ( sd_dout       ),
	.sd_dout_strobe  ( sd_dout_strobe),
	.sd_din          ( uio_din       ),
	.sd_din_strobe   ( sd_din_strobe ),
	.sd_buff_addr    ( sd_buff_addr  ),
	.sd_ack_conf     ( sd_ack_conf   ),

	.img_mounted     ( uio_img_mounted ),
	.img_size        ( img_size      ),

	.ps2_kbd_clk     ( ps2_kbd_clk   ), 
	.ps2_kbd_data    ( ps2_kbd_dat   ),
	.ps2_kbd_clk_i   ( ps2_kbd_clk_i ),
	.ps2_kbd_data_i  ( ps2_kbd_dat_i ),
	.ps2_mouse_clk   ( ps2_mouse_clk ), 
	.ps2_mouse_clk_i ( ps2_mouse_clk_i ), 
	.ps2_mouse_data  ( ps2_mouse_dat ),
	.ps2_mouse_data_i( ps2_mouse_dat_i )
);

// wire the sd card to the user port
wire sd_sck;
wire sd_cs;
wire sd_sdi;
reg  sd_sdi_r;
wire sd_sdo;

always @(posedge clk_cpu) sd_sdi_r <= sd_sdi;

wire sd_busy_w;
assign img_mounted = uio_img_mounted[0];
assign uio_rd  = {1'b0, fd_rd, hd1_rd, sd_rd & ~hd1_busy & ~fd_busy};
assign uio_wr  = {1'b0, fd_wr, hd1_wr, sd_wr & ~hd1_busy & ~fd_busy};
assign uio_lba = hd1_busy ? hd1_lba : fd_busy ? fd_lba : sd_lba;
assign uio_din = hd1_busy ? hd1_buff_din : fd_busy ? fd_buff_din : sd_din;
assign sd_ack  = uio_ack & ~hd1_busy & ~fd_busy;
wire   hd1_ack   = uio_ack & uio_ack_x[1];
wire   fd_ack    = uio_ack & uio_ack_x[2];
reg    uio_turn = 1'b0;
always @(posedge clk_cpu) uio_turn <= ~uio_turn;
wire   uio_free  = ~sd_rd & ~sd_wr & ~sd_busy_w & ~uio_ack;
wire   hd1_grant = uio_free & ~fd_busy  & ~uio_turn;
wire   fd_grant  = uio_free & ~hd1_busy &  uio_turn;
reg  [5:0] dio_idx1, dio_idx2;
always @(posedge clk_cpu) begin dio_idx1 <= ioctl_index[5:0]; dio_idx2 <= dio_idx1; end
wire       cd_mount  = (dio_idx2 == 6'd3);
wire [1:0] disk_mounted = {uio_img_mounted[1] & ~cd_mount, uio_img_mounted[0]};
always @(posedge clk_cpu) begin
	fd_mount_evt <= uio_img_mounted[2];
	if (uio_img_mounted[2]) begin
		fd_mounted <= |img_size;
		fd_sectors <= (|img_size[63:41]) ? 32'hFFFFFFFF : img_size[40:9];
	end
end
always @(posedge clk_cpu) if (disk_mounted[1]) begin
	hd1_mounted <= |img_size;
	hd1_sectors <= (|img_size[63:41]) ? 32'hFFFFFFFF : img_size[40:9];
end

reg fw_up = 1'b0, st0_d = 1'b0;
always @(posedge clk_cpu) begin
	st0_d <= status[0];
	if ((st0_d & ~status[0]) | img_mounted) fw_up <= 1'b1;
	reset <= status[0] | buttons[1] | (|disk_mounted) | ~fw_up;
end

sd_card sd_card (
	// connection to io controller
	.clk_sys      ( clk_cpu        ),
	.sd_lba       ( sd_lba         ),
	.sd_rd        ( sd_rd          ),
	.sd_wr        ( sd_wr          ),
	.sd_ack       ( sd_ack         ),
	.sd_ack_conf  ( sd_ack_conf    ),
	.sd_conf      ( sd_conf        ),
	.sd_sdhc      ( sd_sdhc        ),
	.sd_buff_dout ( sd_dout        ),
	.sd_buff_wr   ( sd_dout_strobe ),
	.sd_buff_din  ( sd_din         ),
	.sd_buff_addr ( sd_buff_addr   ),
	.img_mounted  ( img_mounted    ),
	.img_size     ( img_size       ),
	.sd_busy      ( sd_busy_w      ),
	.allow_sdhc   ( 1'b1           ),
 
	// connection to local CPU
	.sd_cs   ( sd_cs          ),
	.sd_sck  ( sd_sck         ),
	.sd_sdi  ( sd_sdi_r       ),
	.sd_sdo  ( sd_sdo         )
);

///// VIDEO OUT /////

mist_video #(.COLOR_DEPTH(6), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (
	.clk_sys     ( clk_sys    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( 1'b1 ), // already VGA
	// disable csync without scandoubler
	.no_csync    ( 1'b1       ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( core_r     ),
	.G           ( core_g     ),
	.B           ( core_b     ),

	.HSync       ( ~core_hs   ),
	.VSync       ( ~core_vs   ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(50_000_000) i2c_master (
	.CLK         (clk_cpu),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(6), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) hdmi_video (
	.clk_sys     ( clk_25     ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( 1'b1 ), // already VGA
	// disable csync without scandoubler
	.no_csync    ( 1'b1       ),
	// YPbPr always uses composite sync
	.ypbpr       ( 1'b0       ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( core_r     ),
	.G           ( core_g     ),
	.B           ( core_b     ),

	.HSync       ( ~core_hs   ),
	.VSync       ( ~core_vs   ),
	.HBlank      ( core_blank ),
	.VBlank      ( core_vb    ),

	// MiST video output signals
	.VGA_R       ( HDMI_R     ),
	.VGA_G       ( HDMI_G     ),
	.VGA_B       ( HDMI_B     ),
	.VGA_VS      ( HDMI_VS    ),
	.VGA_HS      ( HDMI_HS    ),
	.VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_25;

`endif

////// DATA_IO / IDE /////

wire        ioctl_downl;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire        hdd_cmd_req;
wire        hdd_dat_req;
wire        hdd_cdda_req;
wire        hdd_cdda_wr;
wire        hdd_status_wr;

wire  [2:0] hdd_addr;
wire        hdd_wr;

wire [15:0] hdd_data_out;
wire [15:0] hdd_data_in;
wire        hdd_data_rd;
wire        hdd_data_wr;

wire [15:0] cdda_l;
wire [15:0] cdda_r;

data_io #(.ENABLE_IDE(1'b1)) data_io(
	.clk_sys       ( clk_sdr      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   ),

	.hdd_clk       ( clk_cpu      ),
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_cdda_req  ( hdd_cdda_req ),
	.hdd_cdda_wr   ( hdd_cdda_wr  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

////////////// IDE INTERFACES ///////
wire [15:0] IDE_DAT_O;
wire [15:0] IDE_DAT_I;
wire  [3:0] IDE_A;
wire        IDE_WE;
wire  [1:0] IDE_CS;
reg   [1:0] IDE_INT;

wire  [1:0] ide_irq_ack;

assign ide_irq_ack[1] = IDE_CS[1] && IDE_A == 4'd7;
assign ide_irq_ack[0] = IDE_CS[0] && IDE_A == 4'd7;

ide ide (
	.clk(clk_cpu), // system clock
	.clk_en(1'b1),
	.reset(reset),

	// cpu interface
	.address_in((~IDE_WE && IDE_A == 4'hE) ? 3'd7 : IDE_A[2:0]),
	.sel_secondary(IDE_CS[1]),
	.data_in({IDE_DAT_O[7:0], IDE_DAT_O[15:8]}),
	.data_out({IDE_DAT_I[7:0], IDE_DAT_I[15:8]}),
	.rd((|IDE_CS) & ~IDE_WE),
	.hwr((|IDE_CS) & IDE_WE),
	.lwr((|IDE_CS) & IDE_WE),
	.sel_ide(|IDE_CS),
	.intreq(IDE_INT),
	.intreq_ack(ide_irq_ack),  // interrupt clear
	.nrdy(),				// fifo is not ready for reading 
	.hdd0_ena(2'b00),
	.hdd1_ena(2'b10),
	.fifo_rd(),
	.fifo_wr(),

	// io controller interface
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

cdda_fifo cdda_fifo (
	.clk_sys       ( clk_cpu      ),
	.clk_en        ( 1'b1         ),
	.cen_44100     ( cen_44100    ),
	.reset         ( reset        ),

	.hdd_cdda_req  ( hdd_cdda_req ),
	.hdd_cdda_wr   ( hdd_cdda_wr  ),
	.hdd_data_out  ( hdd_data_out ),

	.cdda_l        ( cdda_l       ),
	.cdda_r        ( cdda_r       )
);

////////////// JOYSTICKS /////////////
wire  [7:0] joy1   = joyswap ? joystick_1 : joystick_0;
wire  [7:0] joy2   = joyswap ? joystick_0 : joystick_1;
wire [15:0] joy1_a = joyswap ? joystick_analog_1 : joystick_analog_0;
wire [15:0] joy2_a = joyswap ? joystick_analog_0 : joystick_analog_1;

////// AO486 ///////////////

wire [7:0] led_out;
wire mpu_Rx, mpu_Tx;

assign UART_TX = mpu_Tx;
`ifdef USE_MIDI_PINS
assign MIDI_OUT = mpu_Tx;
assign mpu_Rx = UART_RX & MIDI_IN;
`else
assign mpu_Rx = UART_RX;
`endif

reg         cen_44100;
reg  [31:0] cen_44100_cnt;
wire [31:0] cen_44100_cnt_next = cen_44100_cnt + 16'd44100;
always @(posedge clk_cpu) begin
	cen_44100 <= 0;
	cen_44100_cnt <= cen_44100_cnt_next;
	if (cen_44100_cnt_next >= CPU_HZ) begin
		cen_44100 <= 1;
		cen_44100_cnt <= cen_44100_cnt_next - CPU_HZ;
	end
end

wire [15:0] laudio, raudio;

system sys_inst (
	.clk_25(clk_25),
	.clk_vga50(clk_vga50),
	.clk_sdr(clk_sdr),
	.clk_cpu(clk_cpu),
	.clk_dsp(clk_aud),

	.adlibhide(adlibhide),

	.VGA_R(core_r),
	.VGA_G(core_g),
	.VGA_B(core_b),
	.VGA_HSYNC(core_hs),
	.VGA_VSYNC(core_vs),
	.VGA_BLANK(core_blank),
	.VGA_VBLANK(core_vb),

	.sdr_n_CS_WE_RAS_CAS({SDRAM_nCS, SDRAM_nWE, SDRAM_nRAS, SDRAM_nCAS}),
	.sdr_BA(SDRAM_BA),
	.sdr_ADDR(SDRAM_A),
	.sdr_DATA(SDRAM_DQ),
	.sdr_DQM({SDRAM_DQMH, SDRAM_DQML}),

	.LED(led_out),

	.BTN_RESET(reset),

	.MPU_RX(mpu_Rx),
	.MPU_TX(mpu_Tx),

	.SD_n_CS(sd_cs),
	.SD_DI(sd_sdi),
	.SD_CK(sd_sck),
	.SD_DO(sd_sdo),

	.CDDA_L(cdda_l),
	.CDDA_R(cdda_r),

	.AUD_L(AUDIO_L),
	.AUD_R(AUDIO_R),
	.LAUDIO(laudio),
	.RAUDIO(raudio),

	.PS2_CLK1_I(ps2_kbd_clk),
	.PS2_CLK1_O(ps2_kbd_clk_i),
	.PS2_CLK2_I(ps2_mouse_clk),
	.PS2_CLK2_O(ps2_mouse_clk_i),
	.PS2_DATA1_I(ps2_kbd_dat),
	.PS2_DATA1_O(ps2_kbd_dat_i),
	.PS2_DATA2_I(ps2_mouse_dat),
	.PS2_DATA2_O(ps2_mouse_dat_i),

	.JOY1(joy1),
	.JOY2(joy2),
	.JOY1_A(joy1_a),
	.JOY2_A(joy2_a),
	.JOY_MODE(joytype == 2'd2 ? 3'd3 : {2'b00, joytype[0]}),

	.IDE_DAT_O(IDE_DAT_O),
	.IDE_DAT_I(IDE_DAT_I),
	.IDE_A(IDE_A),
	.IDE_WE(IDE_WE),
	.IDE_CS(IDE_CS),
	.IDE_INT(IDE_INT),

	.hd1_mounted(hd1_mounted),
	.hd1_sectors(hd1_sectors),
	.hd1_grant(hd1_grant),
	.hd1_busy(hd1_busy),
	.hd1_rd(hd1_rd),
	.hd1_wr(hd1_wr),
	.hd1_lba(hd1_lba),
	.hd1_ack(hd1_ack),
	.hd1_buff_addr(sd_buff_addr),
	.hd1_buff_dout(sd_dout),
	.hd1_buff_wr(sd_dout_strobe),
	.hd1_buff_din(hd1_buff_din),
	.fd_mounted(fd_mounted),
	.fd_sectors(fd_sectors),
	.fd_mount_evt(fd_mount_evt),
	.fd_grant(fd_grant),
	.fd_busy(fd_busy),
	.fd_rd(fd_rd),
	.fd_wr(fd_wr),
	.fd_lba(fd_lba),
	.fd_ack(fd_ack),
	.fd_buff_addr(sd_buff_addr),
	.fd_buff_dout(sd_dout),
	.fd_buff_wr(sd_dout_strobe),
	.fd_buff_din(fd_buff_din)
`ifdef DUAL_SDRAM
	,.SDRAM2_A(SDRAM2_A), .SDRAM2_DQ(SDRAM2_DQ), .SDRAM2_DQML(SDRAM2_DQML), .SDRAM2_DQMH(SDRAM2_DQMH),
	.SDRAM2_nWE(SDRAM2_nWE), .SDRAM2_nCAS(SDRAM2_nCAS), .SDRAM2_nRAS(SDRAM2_nRAS), .SDRAM2_nCS(SDRAM2_nCS),
	.SDRAM2_BA(SDRAM2_BA), .SDRAM2_CLK(SDRAM2_CLK), .SDRAM2_CKE(SDRAM2_CKE)
`endif
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_cpu),
	.clk_rate(CPU_HZ),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(laudio),
	.right_chan(raudio)
);
`endif

`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_cpu) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_cpu),
	.rst_i(1'b0),
	.clk_rate_i(CPU_HZ),
	.spdif_o(SPDIF),
	.sample_i({raudio, laudio})
);
`endif

endmodule
