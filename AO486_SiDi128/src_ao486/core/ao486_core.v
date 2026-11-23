// ao486 SoC
module ao486_core (
    input         clk_sys,
    input         reset,
	input  [27:0] clock_rate,
	input 		  clk_sdram_x2,		// 2x main clock for SDRAM

	output [1:0]  fdd_request,
	output [2:0]  ide0_request,
	output [2:0]  ide1_request,
	input  [1:0]  floppy_wp,

    // SDRAM interface
    inout  [15:0] sdram_dq,
    output [12:0] sdram_a,
    output [1:0]  sdram_ba,
    output [1:0]  sdram_dqm,
    output        sdram_nwe,
    output        sdram_nras,
    output        sdram_ncas,
    output        sdram_ncs,
    output        sdram_cke,
    input         refresh_allowed,

    // SD card
    output        spi_cs_n,
    output        spi_sck,
    output        spi_mosi,
    input         spi_miso,

	// Keyboard byte stream (for injecting PS/2 scancodes)
	input   [7:0] kbd_data,
	input         kbd_data_valid,
	output  [8:0] kbd_host_data,        // {valid, data}
	input         kbd_host_data_clear,

	// Mouse byte stream (for injecting PS/2 mouse packets)
	input   [7:0] mouse_data,
	input         mouse_data_valid,
	output  [8:0] mouse_host_cmd,	// PS/2 mouse host->device byte to UART bridge
	input         mouse_host_cmd_clear,

    // Debug stream up to UART bridge
    output  [7:0] dbg_uart_byte,
    output        dbg_uart_we,

	input   [5:0] bootcfg,
    input         uma_ram,
	output  [7:0] syscfg,

	input         clk_vga,
	input  [27:0] clock_rate_vga,

	output        video_ce,
	output        video_blank_n,
	output        video_hsync,
	output        video_vsync,
	output [7:0]  video_r,
	output [7:0]  video_g,
	output [7:0]  video_b,
	input         video_f60,
	output [7:0]  video_pal_a,
	output [17:0] video_pal_d,
	output        video_pal_we,
	output [19:0] video_start_addr,
	output [8:0]  video_width,
	output [10:0] video_height,
	output [3:0]  video_flags,
	output [8:0]  video_stride,
	output        video_off,
	input         video_fb_en,
	input         video_lores,
	input         video_border,

	input         clk_audio,		// 24.576Mhz
	output [15:0] sample_sb_l,
	output [15:0] sample_sb_r,
	output [15:0] sample_opl_l,
	output [15:0] sample_opl_r,
	input         sound_fm_mode,	// 0 = OPL2, 1 = OPL3
	input         sound_cms_en,	    // Creative CM-S music enable

	output        speaker_out,
	
	output        sbp,
	output  [4:0] vol_master_l,
	output  [4:0] vol_master_r,
	output  [4:0] vol_voice_l,
	output  [4:0] vol_voice_r,
	output  [4:0] vol_cd_l,
	output  [4:0] vol_cd_r,
	output  [4:0] vol_midi_l,
	output  [4:0] vol_midi_r,
	output  [4:0] vol_line_l,
	output  [4:0] vol_line_r,
	output  [1:0] vol_spk,
	output  [4:0] vol_en,

    // Debug outputs for LEDs
    output reg [2:0]  debug_boot_stage,
    output reg    debug_sd_error,
	output        debug_bios_loaded,
	output        debug_vga_bios_sig_bad,
	output        debug_vga_bios_sig_checked,
	output        debug_first_instruction,
	output [127:0] dbg,

	output reg        cd_cs,
	output reg        cd_we,
	output reg  [3:0] cd_a,
	output reg [15:0] cd_dout,
	input      [15:0] cd_din,
	input             cd_irq,
	output            midi_tx,
	input      [13:0] joy_dig_1,
	input      [13:0] joy_dig_2,
	input      [15:0] joy_ana_1,
	input      [15:0] joy_ana_2,
	input       [2:0] joy_mode,
	input             midi_rx,

	input         hd1_mounted,
	input  [31:0] hd1_sectors,
	input         hd1_grant,
	output        hd1_busy,
	output        hd1_rd,
	output        hd1_wr,
	output [31:0] hd1_lba,
	input         hd1_ack,
	input   [8:0] hd1_buff_addr,
	input   [7:0] hd1_buff_dout,
	input         hd1_buff_wr,
	output  [7:0] hd1_buff_din,
	input         fd_mounted,
	input  [31:0] fd_sectors,
	input         fd_mount_evt,
	input         fd_grant,
	output        fd_busy,
	output        fd_rd,
	output        fd_wr,
	output [31:0] fd_lba,
	input         fd_ack,
	input   [8:0] fd_buff_addr,
	input   [7:0] fd_buff_dout,
	input         fd_buff_wr,
	output  [7:0] fd_buff_din,

	input         gus_off,
	output [15:0] sample_gus_l,
	output [15:0] sample_gus_r,
	inout  [15:0] sdram2_dq,
	output [12:0] sdram2_a,
	output  [1:0] sdram2_dqm,
	output  [1:0] sdram2_ba,
	output        sdram2_ncs,
	output        sdram2_nwe,
	output        sdram2_nras,
	output        sdram2_ncas,
	output        sdram2_clk,
	output        sdram2_cke
);

parameter SYS_FREQ = 20_000_000;

// reset duplication to reduce fanout
reg [15:0] rst /* synthesis syn_preserve = "true" */;
always @(posedge clk_sys)
	rst <= {16{reset}};

wire        a20_enable;
wire  [7:0] dma_floppy_readdata;
wire        dma_floppy_tc;
wire  [7:0] dma_floppy_writedata;
wire        dma_floppy_req;
wire        dma_floppy_ack;
wire        dma_sb_req_8;
wire        dma_sb_req_16;
wire        dma_sb_ack_8;
wire        dma_sb_ack_16;
wire  [7:0] dma_sb_readdata_8;
wire [15:0] dma_sb_readdata_16;
wire [15:0] dma_sb_writedata;
wire [15:0] dma_readdata;
wire        dma_waitrequest;
wire [23:0] dma_address;
wire        dma_read;
wire        dma_readdatavalid;
wire        dma_write;
wire [15:0] dma_writedata;
wire        dma_16bit;

// Boot loader signals
reg [3:0]   boot_state;
reg [31:0]  boot_addr;
reg [15:0]  boot_sectors;        // Number of sectors remaining
reg [7:0]   boot_words_in_sector; // Number of words remaining in current sector
reg         boot_done;
reg  [1:0]  boot_phase;          // 0 = BIOS, 1 = VGA BIOS, 2 = CONFIG
reg         cpu_reset_n;
wire [95:0] sd_dbg;

// Debug registers for LED indicators
reg         bios_loaded;
reg         vga_bios_sig_bad;
reg         first_instruction_executed;
reg [15:0]  vga_bios_first_word;
reg         vga_bios_sig_checked;

// Debug signals from CPU
wire [31:0] debug_cpu_eip;
wire [15:0] debug_cpu_cs;

// Boot loader SD card interface signals
reg [1:0]   boot_sd_avs_address;
reg         boot_sd_avs_read;
reg         boot_sd_avs_read_r;
reg         boot_sd_avs_write;
reg [31:0]  boot_sd_avs_writedata;

localparam BOOT_IDLE        = 0;
localparam BOOT_SD_INIT     = 1;
localparam BOOT_SD_WAIT     = 2;
localparam BOOT_LOAD_START  = 3;  // Reusable for both BIOS and VGA BIOS
localparam BOOT_LOAD_SECTOR = 4;
localparam BOOT_LOAD_COUNT  = 5;
localparam BOOT_LOAD_READ   = 6;
localparam BOOT_LOAD_DATA   = 7;
localparam BOOT_COMPLETE    = 8;

// Management interface driven by SD sector 192
reg  [15:0] mgmt_address;
reg         mgmt_read = 1'b0;
wire [31:0] mgmt_readdata;
reg         mgmt_write;
reg  [31:0] mgmt_writedata;
wire        hd1_cfg_req; wire [15:0] hd1_cfg_addr; wire [31:0] hd1_cfg_data;
wire        hd1_cfg_ack     = hd1_cfg_req & ~mgmt_write;
wire        fd_mg_req, fd_mg_we; wire [15:0] fd_mg_addr, fd_mg_wdata;
wire        fd_mg_ack       = fd_mg_req & ~mgmt_write & ~hd1_cfg_req;
wire [15:0] mgmt_address_m  = mgmt_write ? mgmt_address   : hd1_cfg_req ? hd1_cfg_addr : fd_mg_addr;
wire [31:0] mgmt_writedata_m= mgmt_write ? mgmt_writedata : hd1_cfg_req ? hd1_cfg_data : {16'd0, fd_mg_wdata};
wire        mgmt_write_m    = mgmt_write | hd1_cfg_ack | (fd_mg_ack & fd_mg_we);
wire        mgmt_read_m     = mgmt_read  | (fd_mg_ack & ~fd_mg_we);

// Config sector parsing (phase 2)
// New format: 4-byte address (use [15:0]) + 4-byte data, repeated; terminated by address==0
reg         cfg_expect_addr;   // 1: next word is address, 0: next word is data
reg         cfg_terminated;
reg [15:0]  cfg_write_count;

wire [15:0] mgmt_fdd_readdata;
wire [15:0] mgmt_ide0_readdata;
wire [15:0] mgmt_ide1_readdata;
wire        mgmt_ide0_cs;
wire        mgmt_ide1_cs;
wire        mgmt_fdd_cs;
wire        mgmt_rtc_cs;

wire        interrupt_done;
wire        interrupt_do;
wire  [7:0] interrupt_vector;
reg  [15:0] interrupt;
wire        irq_0, irq_1, irq_2, irq_3, irq_4, 
		    irq_5 /* verilator public */, 
			irq_6, 
			irq_7 /* verilator public */, 
			irq_8, irq_9, irq_10, irq_12, irq_14, irq_15;

wire        cpu_io_read_do         /* verilator public */;
wire [15:0] cpu_io_read_address    /* verilator public */;
wire  [2:0] cpu_io_read_length;
wire [31:0] cpu_io_read_data       /* verilator public */;
wire        cpu_io_read_done       /* verilator public */;
wire        cpu_io_write_do        /* verilator public */;
wire [15:0] cpu_io_write_address   /* verilator public */;
wire  [2:0] cpu_io_write_length    /* verilator public */;
wire [31:0] cpu_io_write_data      /* verilator public */;
wire        cpu_io_write_done      /* verilator public */;
wire [15:0] iobus_address;
wire        iobus_write;
wire        iobus_read;
wire  [2:0] iobus_datasize;
wire [31:0] iobus_writedata;

reg         ide0_cs;
reg         ide1_cs;
wire        ide1_dev;
reg         cd_route = 1'b0;
reg  [31:0] cd_rdata = 32'd0;
wire        cd_wait;
reg         floppy0_cs;
reg         dma_master_cs;
reg         dma_page_cs;
reg         dma_slave_cs;
reg         pic_master_cs;
reg         pic_slave_cs;
reg         pit_cs;
reg         ps2_io_cs;
reg         ps2_ctl_cs;
reg         joy_cs;
reg         rtc_cs;
reg         fm_cs;
reg         sb_cs;
reg         gus_cs;
wire  [7:0] gus_readdata;
wire        gus_wait, gus_irq_raw, sb_irq5_sel;
wire        sb_irq, sb_irq7_en, sb_irq10_en;
wire        gus_irq = gus_irq_raw & ~gus_off;
wire        dma_gus_req, dma_gus_ack, dma_gus_tc;
wire [15:0] dma_gus_readdata, dma_gus_writedata;
reg         uart1_cs;
reg         uart2_cs;
reg         mpu_cs;
reg         vga_b_cs;
reg         vga_c_cs;
reg         vga_d_cs;
reg         sysctl_cs;

wire        fdd0_inserted;

wire  [7:0] sound_readdata;
wire  [7:0] floppy0_readdata;
wire [31:0] ide0_readdata;
wire [31:0] ide1_readdata;
wire  [7:0] joystick_readdata;
wire  [7:0] pit_readdata;
wire  [7:0] ps2_readdata;
wire  [7:0] rtc_readdata;
wire  [7:0] uart1_readdata;
wire  [7:0] uart2_readdata;
wire  [7:0] mpu_readdata;
wire  [7:0] dma_io_readdata;
wire  [7:0] pic_readdata;
wire  [7:0] vga_io_readdata;

// ao486 to main_memory
wire [29:0] avm_address /* verilator public */;      // dword address
wire [31:0] avm_writedata /* verilator public */;
wire [31:0] avm_readdata /* verilator public */;
wire  [3:0] avm_byteenable /* verilator public */;
wire  [3:0] avm_burstcount;
wire        avm_write /* verilator public */;
wire        avm_read;
wire        avm_waitrequest;
wire        avm_readdatavalid;

// main_memory to ddr/sdram
wire [31:0] mem_address;
wire [31:0] mem_din;
wire [31:0] mem_dout;
wire        mem_dout_ready;
wire [3:0]  mem_be;
wire [7:0]  mem_burstcount;
wire        mem_busy;
wire        mem_rd;
wire        mem_we;

wire [16:0] vga_address;
wire  [7:0] vga_readdata;
wire  [7:0] vga_writedata;
wire        vga_read;
wire        vga_write;
wire  [2:0] vga_memmode;
wire  [5:0] video_wr_seg;
wire  [5:0] video_rd_seg;
reg         fb_en = 1'b0;
always @(posedge clk_sys) fb_en <= ~video_flags[2] && (video_flags[1:0] == 2'b01);
wire        vga_dot_ce, vga_blank_n_o, vga_hsync_o, vga_vsync_o;
wire  [7:0] vga_r_o, vga_g_o, vga_b_o;
wire        fb_sd_req, fb_sd_ack, fb_sd_ready;
wire [25:0] fb_sd_addr;
wire  [3:0] fb_sd_burst;
wire [31:0] fb_sd_dout;

ao486 ao486 (
    .clk               (clk_sys),
    .rst_n             (cpu_reset_n),

	.cache_disable     (1'b0),

	.avm_address       (avm_address),
	.avm_writedata     (avm_writedata),
	.avm_byteenable    (avm_byteenable),
	.avm_burstcount    (avm_burstcount),
	.avm_write         (avm_write),
	.avm_read          (avm_read),

	.avm_waitrequest   (avm_waitrequest),
	.avm_readdatavalid (avm_readdatavalid),
	.avm_readdata      (avm_readdata),

	.interrupt_do      (interrupt_do),
	.interrupt_vector  (interrupt_vector),
	.interrupt_done    (interrupt_done),

	.io_read_do        (cpu_io_read_do),
	.io_read_address   (cpu_io_read_address),
	.io_read_length    (cpu_io_read_length),
	.io_read_data      (cpu_io_read_data),
	.io_read_done      (cpu_io_read_done),

	.io_write_do       (cpu_io_write_do),
	.io_write_address  (cpu_io_write_address),
	.io_write_length   (cpu_io_write_length),
	.io_write_data     (cpu_io_write_data),
	.io_write_done     (cpu_io_write_done),

	.a20_enable        (a20_enable),

	.dma_address       (dma_address),
	.dma_16bit         (dma_16bit),
	.dma_write         (dma_write),
	.dma_writedata     (dma_writedata),
	.dma_read          (dma_read),
	.dma_readdata      (dma_readdata),
	.dma_readdatavalid (dma_readdatavalid),
	.dma_waitrequest   (dma_waitrequest),

	// Debug outputs for LED indicators
	.debug_eip         (debug_cpu_eip),
	.debug_cs          (debug_cpu_cs)

	// .dbg_reg_wr        (dbg_reg_wr),
	// .dbg_reg_addr      (dbg_reg_addr),
	// .dbg_reg_din       (dbg_reg_din),
	// .dbg_reg_rd        (dbg_reg_rd),
	// .dbg_reg_dout      (dbg_reg_dout)
);


// Main memory access through SDRAM/DDR and VGA memory hole

wire is_rom = avm_address[29:16] == 14'h3;

main_memory main_memory (
    .clk               (clk_sys),
    .reset             (1'b0),
   
    .cpu_addr          (boot_done ? {avm_address, 2'b00} : sd_avm_address),
    .cpu_din           (boot_done ? avm_writedata : sd_avm_writedata),
    .cpu_dout          (avm_readdata),
    .cpu_dout_ready    (avm_readdatavalid),
    .cpu_be            (boot_done ? avm_byteenable : 4'b1111),
    .cpu_burstcount    (avm_burstcount),
    .cpu_busy          (avm_waitrequest),
    .cpu_rd            (avm_read),
    .cpu_we            (boot_done ? avm_write & ~is_rom : sd_avm_write),  // protect ROM when CPU is running

    // DDR/SDRAM interface
	.mem_addr          (mem_address),
	.mem_din           (mem_din),
	.mem_dout          (mem_dout),
	.mem_dout_ready    (mem_dout_ready),
	.mem_be            (mem_be),
	.mem_burstcount    (mem_burstcount),
	.mem_busy          (mem_busy),
	.mem_rd            (mem_rd),
	.mem_we            (mem_we),

    // VGA interface - cpu accessing mapped VGA memory goes through here to vga.v
	.vga_address       (vga_address),
	.vga_readdata      (vga_readdata),
	.vga_writedata     (vga_writedata),
	.vga_read          (vga_read),
	.vga_write         (vga_write),
	.vga_memmode       (vga_memmode),
	.vga_wr_seg        (video_wr_seg),
	.vga_rd_seg        (video_rd_seg),
	.vga_fb_en         (fb_en)
);

`ifndef AO486_L2_KB
 `define AO486_L2_KB 64
`endif
wire [31:0] sd_address, sd_din, sd_dout;
wire        sd_dout_ready, sd_busy, sd_rd, sd_we;
wire  [3:0] sd_be;
wire  [7:0] sd_burstcount;
generate if (`AO486_L2_KB != 0) begin : g_l2
l2_sdram_cache #(.KB(`AO486_L2_KB), .ABITS(26)) l2 (
	.clk            (clk_sys),
	.reset          (rst[0]),
	.cpu_addr       (mem_address),
	.cpu_din        (mem_din),
	.cpu_dout       (mem_dout),
	.cpu_dout_ready (mem_dout_ready),
	.cpu_be         (mem_be),
	.cpu_burstcount (mem_burstcount),
	.cpu_busy       (mem_busy),
	.cpu_rd         (mem_rd),
	.cpu_we         (mem_we),
	.sd_addr        (sd_address),
	.sd_din         (sd_din),
	.sd_dout        (sd_dout),
	.sd_dout_ready  (sd_dout_ready),
	.sd_be          (sd_be),
	.sd_burstcount  (sd_burstcount),
	.sd_busy        (sd_busy),
	.sd_rd          (sd_rd),
	.sd_we          (sd_we)
);
end else begin : g_nol2
assign sd_address = mem_address;  assign sd_din = mem_din;  assign sd_be = mem_be;
assign sd_burstcount = mem_burstcount;  assign sd_rd = mem_rd;  assign sd_we = mem_we;
assign mem_dout = sd_dout;  assign mem_dout_ready = sd_dout_ready;  assign mem_busy = sd_busy;
end endgenerate

wire mem_ack;
wire mem_req = ((sd_rd | sd_we) && !sd_busy) ? ~mem_req_r : mem_req_r;
reg mem_req_r = 1'b0;
always @(posedge clk_sys) mem_req_r <= mem_req;

`ifndef VERILATOR
sdram_x2_wrapper #(.FREQ_SYS(SYS_FREQ)) sdram_x2 (
	.clk_sys           (clk_sys),
	.clk_2x            (clk_sdram_x2),
`else
sdram #(.FREQ(SYS_FREQ)) sdram (
	.clk               (clk_sys),
`endif
	.resetn            (~rst[0]),
	.refresh_allowed   (1'b1),
	.busy              (sd_busy),

	.req0              (mem_req),
	.ack0              (mem_ack),
	.wr0               (sd_we),
	.addr0             (sd_address),
	.din0              (sd_din),
	.dout0             (sd_dout),
	.ready0            (sd_dout_ready),
	.be0               (sd_be),
	.burst_cnt0        (sd_burstcount),
	.burst_done0       (),

	.req1              (fb_sd_req),
	.ack1              (fb_sd_ack),
	.wr1               (1'b0),
	.addr1             (fb_sd_addr),
	.din1              (32'd0),
	.dout1             (fb_sd_dout),
	.ready1            (fb_sd_ready),
	.be1               (4'hF),
	.burst_cnt1        (fb_sd_burst),
	.burst_done1       (),

	// SDRAM side interface
    .SDRAM_DQ          (sdram_dq),
    .SDRAM_A           (sdram_a),
    .SDRAM_DQM         (sdram_dqm),
    .SDRAM_BA          (sdram_ba),
    .SDRAM_nWE         (sdram_nwe),
    .SDRAM_nRAS        (sdram_nras),
    .SDRAM_nCAS        (sdram_ncas),
    .SDRAM_nCS         (sdram_ncs),
    .SDRAM_CKE         (sdram_cke)
);

always @(posedge clk_sys) begin
	ide0_cs       <= ({iobus_address[15:3], 3'd0} == 16'h01F0) || ({iobus_address[15:0]} == 16'h03F6);
	ide1_cs       <= ({iobus_address[15:3], 3'd0} == 16'h0170) || ({iobus_address[15:0]} == 16'h0376);
	floppy0_cs    <= ({iobus_address[15:2], 2'd0} == 16'h03F0) || ({iobus_address[15:1], 1'd0} == 16'h03F4) || ({iobus_address[15:0]} == 16'h03F7) ;
	dma_master_cs <= ({iobus_address[15:5], 5'd0} == 16'h00C0);
	dma_page_cs   <= ({iobus_address[15:4], 4'd0} == 16'h0080);
	dma_slave_cs  <= ({iobus_address[15:4], 4'd0} == 16'h0000);
	pic_master_cs <= ({iobus_address[15:1], 1'd0} == 16'h0020);
	pic_slave_cs  <= ({iobus_address[15:1], 1'd0} == 16'h00A0);
	pit_cs        <= ({iobus_address[15:2], 2'd0} == 16'h0040) || (iobus_address == 16'h0061);
	ps2_io_cs     <= ({iobus_address[15:3], 3'd0} == 16'h0060);
	ps2_ctl_cs    <= ({iobus_address[15:4], 4'd0} == 16'h0090);
	rtc_cs        <= ({iobus_address[15:1], 1'd0} == 16'h0070);
	fm_cs         <= ({iobus_address[15:2], 2'd0} == 16'h0388);
	sb_cs         <= ({iobus_address[15:4], 4'd0} == 16'h0220);
	gus_cs        <= ~gus_off && (({iobus_address[15:4], 4'd0} == 16'h0240) || ({iobus_address[15:4], 4'd0} == 16'h0340));
	vga_b_cs      <= ({iobus_address[15:4], 4'd0} == 16'h03B0);
	vga_c_cs      <= ({iobus_address[15:4], 4'd0} == 16'h03C0);
	vga_d_cs      <= ({iobus_address[15:4], 4'd0} == 16'h03D0);
	sysctl_cs     <= ({iobus_address[15:0]      } == 16'h8888);
	mpu_cs        <= ({iobus_address[15:1], 1'd0} == 16'h0330);
	joy_cs        <= (iobus_address[15:0] == 16'h0201);
end

reg [7:0] ctlport = 0;
reg in_reset = 1;
always @(posedge clk_sys) begin
	if(reset) begin
		ctlport <= 8'hA2;
		in_reset <= 1;
	end
	else if((ide0_cs|ide1_cs|floppy0_cs) && in_reset) begin
		ctlport <= 0;
		in_reset <= 0;
	end
	else if(iobus_write && sysctl_cs && iobus_datasize == 2 && iobus_writedata[15:8] == 8'hA1) begin
		ctlport <= iobus_writedata[7:0];
		in_reset <= 0;
	end
end

assign syscfg = ctlport;

wire [7:0] iobus_readdata8 =
	( floppy0_cs                             ) ? floppy0_readdata  :
	( dma_master_cs|dma_slave_cs|dma_page_cs ) ? dma_io_readdata   :
	( pic_master_cs|pic_slave_cs             ) ? pic_readdata      :
	( pit_cs                                 ) ? pit_readdata      :
	( ps2_io_cs|ps2_ctl_cs                   ) ? ps2_readdata      :
	( rtc_cs                                 ) ? rtc_readdata      :
	( gus_cs                                 ) ? gus_readdata      :
	( sb_cs|fm_cs                            ) ? sound_readdata    :
	( vga_b_cs|vga_c_cs|vga_d_cs             ) ? vga_io_readdata   :
	( mpu_cs                                 ) ? mpu_readdata      :
	( joy_cs                                 ) ? joystick_readdata :
	                                             8'hFF;

iobus iobus
(
	.clk               (clk_sys),
	.reset             (rst[0]),

	.cpu_read_do       (cpu_io_read_do),
	.cpu_read_address  (cpu_io_read_address),
	.cpu_read_length   (cpu_io_read_length),
	.cpu_read_data     (cpu_io_read_data),
	.cpu_read_done     (cpu_io_read_done),
	.cpu_write_do      (cpu_io_write_do),
	.cpu_write_address (cpu_io_write_address),
	.cpu_write_length  (cpu_io_write_length),
	.cpu_write_data    (cpu_io_write_data),
	.cpu_write_done    (cpu_io_write_done),

	.bus_address       (iobus_address),
	.bus_write         (iobus_write),
	.bus_read          (iobus_read),
	.bus_io32          (((ide0_cs | ide1_cs) & ~iobus_address[9]) | sysctl_cs),
	.bus_datasize      (iobus_datasize),
	.bus_writedata     (iobus_writedata),
	.bus_readdata      (ide0_cs ? ide0_readdata : ide1_cs ? (cd_route ? cd_rdata : ide1_readdata) : iobus_readdata8),
	.bus_wait          (ide0_wait | ide1_wait | cd_wait | (gus_wait & ~gus_off))
);

dma dma
(
	.clk               (clk_sys),
	.rst_n             (~rst[1]),

	.mem_address       (dma_address),
	.mem_16bit         (dma_16bit),
	.mem_waitrequest   (dma_waitrequest),
	.mem_read          (dma_read),
	.mem_readdatavalid (dma_readdatavalid),
	.mem_readdata      (dma_readdata),
	.mem_write         (dma_write),
	.mem_writedata     (dma_writedata),

	.io_address        (iobus_address[4:0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read),
	.io_write          (iobus_write),
	.io_readdata       (dma_io_readdata),
	.io_master_cs      (dma_master_cs),
	.io_slave_cs       (dma_slave_cs),
	.io_page_cs        (dma_page_cs),

	.dma_2_req         (dma_floppy_req),
	.dma_2_ack         (dma_floppy_ack),
	.dma_2_tc          (dma_floppy_tc),
	.dma_2_readdata    (dma_floppy_readdata),
	.dma_2_writedata   (dma_floppy_writedata),

	.dma_1_req         (dma_sb_req_8),
	.dma_1_ack         (dma_sb_ack_8),
	.dma_1_readdata    (dma_sb_readdata_8),
	.dma_1_writedata   (dma_sb_writedata[7:0]),

	.dma_5_req         (dma_sb_req_16),
	.dma_5_ack         (dma_sb_ack_16),
	.dma_5_readdata    (dma_sb_readdata_16),
	.dma_5_writedata   (dma_sb_writedata),

	.dma_7_req         (dma_gus_req & ~gus_off),
	.dma_7_ack         (dma_gus_ack),
	.dma_7_tc          (dma_gus_tc),
	.dma_7_readdata    (dma_gus_readdata),
	.dma_7_writedata   (dma_gus_writedata)
);

gus_x2 #(.CLK_HZ(SYS_FREQ * 2)) gus
(
	.clk_sys           (clk_sys),
	.clk_gus           (clk_sdram_x2),
	.reset             (rst[7]),
	.io_address8       (iobus_address[8]),
	.io_address        (iobus_address[3:0]),
	.writedata         (iobus_writedata[7:0]),
	.readdata          (gus_readdata),
	.gus_cs            (gus_cs),
	.fm_cs             (fm_cs & ~gus_off),
	.write             (iobus_write),
	.read              (iobus_read),
	.io_wait           (gus_wait),
	.dma_req           (dma_gus_req),
	.dma_ack           (dma_gus_ack),
	.dma_tc            (dma_gus_tc),
	.dma_readdata      (dma_gus_readdata),
	.dma_writedata     (dma_gus_writedata),
	.irq               (gus_irq_raw),
	.audio_l           (sample_gus_l),
	.audio_r           (sample_gus_r),
	.SDRAM_DQ          (sdram2_dq),
	.SDRAM_A           (sdram2_a),
	.SDRAM_DQML        (sdram2_dqm[0]),
	.SDRAM_DQMH        (sdram2_dqm[1]),
	.SDRAM_BA          (sdram2_ba),
	.SDRAM_nCS         (sdram2_ncs),
	.SDRAM_nWE         (sdram2_nwe),
	.SDRAM_nRAS        (sdram2_nras),
	.SDRAM_nCAS        (sdram2_ncas),
	.SDRAM_CLK         (sdram2_clk),
	.SDRAM_CKE         (sdram2_cke)
);

floppy floppy
(
	.clk               (clk_sys),
	.rst_n             (~rst[2]),

	.clock_rate        (clock_rate),

	.io_address        (iobus_address[2:0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read & floppy0_cs),
	.io_write          (iobus_write & floppy0_cs),
	.io_readdata       (floppy0_readdata),

	.fdd0_inserted     (fdd0_inserted),

	.dma_req           (dma_floppy_req),
	.dma_ack           (dma_floppy_ack),
	.dma_tc            (dma_floppy_tc),
	.dma_readdata      (dma_floppy_readdata),
	.dma_writedata     (dma_floppy_writedata),

	.mgmt_address      (mgmt_address_m[3:0]),
	.mgmt_fddn         (mgmt_address_m[7]),
	.mgmt_writedata    (mgmt_writedata_m),
	.mgmt_readdata     (mgmt_fdd_readdata),
	.mgmt_write        (mgmt_write_m & mgmt_fdd_cs),
	.mgmt_read         (mgmt_read_m & mgmt_fdd_cs),

	.wp                (floppy_wp),

	.request           (fdd_request),
	.irq               (irq_6)
);

wire [3:0] ide_address = {iobus_address[9],iobus_address[2:0]};

wire ide0_nodata;
reg  ide0_wait = 0;
always @(posedge clk_sys) begin
	if(iobus_read & ide0_cs & ide0_nodata & !ide_address) ide0_wait <= 1;
	if(~ide0_nodata) ide0_wait <= 0;
end

wire [3:0] sd_avs_address;
wire sd_avs_read;
wire sd_avs_write;
wire [31:0] sd_avs_writedata;
wire [31:0] sd_avs_readdata;
reg sd_avs_readdatavalid;
always @(posedge clk_sys) sd_avs_readdatavalid <= sd_avs_read;

wire [31:0] sd_avm_address;
wire sd_avm_read;
reg sd_avm_readdatavalid;
wire [31:0] sd_avm_readdata;
wire sd_avm_write;
wire [31:0] sd_avm_writedata;

always @(posedge clk_sys) sd_avm_readdatavalid <= sd_avm_read;

ao486_ide ide0
(
	.clk               (clk_sys),
	.rst_n             (~rst[3]),

	.io_address        (ide_address),
	.io_writedata      (iobus_writedata),
	.io_read           ((iobus_read & ide0_cs) | ide0_wait),
	.io_write          (iobus_write & ide0_cs),
	.io_readdata       (ide0_readdata),
	.io_32             (iobus_datasize[2]),

	// .use_fast          (1),
	// .no_data           (ide0_nodata),

	.mgmt_address      (mgmt_address_m[3:0]),
	.mgmt_writedata    (mgmt_writedata_m),
	.mgmt_write        (mgmt_write_m & mgmt_ide0_cs),
	// .mgmt_readdata     (mgmt_ide0_readdata),
	// .mgmt_read         (mgmt_read & mgmt_ide0_cs),

	// .request           (ide0_request),
	.irq               (irq_14),

	.sd_master_address (sd_avs_address),
	.sd_master_waitrequest (1'b0),
	.sd_master_read (sd_avs_read),
	.sd_master_readdatavalid (boot_done ? sd_avs_readdatavalid : 1'b0),  // make sure 0 before boot is done
	.sd_master_readdata (sd_avs_readdata),
	.sd_master_write (sd_avs_write),
	.sd_master_writedata (sd_avs_writedata),

    .sd_slave_address (sd_avm_address),
    .sd_slave_read (sd_avm_read),
    .sd_slave_readdata (sd_avm_readdata),
    .sd_slave_write (sd_avm_write),
    .sd_slave_writedata (sd_avm_writedata)
);

driver_sd driver_sd
(
	.clk               (clk_sys),
	.rst_n             (~rst[4]),

	.avs_address       (boot_done ? sd_avs_address[3:2] : boot_sd_avs_address),
	.avs_read 		   (boot_done ? sd_avs_read : boot_sd_avs_read),
	.avs_readdata      (sd_avs_readdata),
	.avs_write 	       (boot_done ? sd_avs_write : boot_sd_avs_write),
	.avs_writedata     (boot_done ? sd_avs_writedata : boot_sd_avs_writedata),

	.avm_address 	   (sd_avm_address),
	.avm_waitrequest   (boot_done ? 1'b0 : avm_waitrequest),    // after boot, avm_waitrequest is always 0 as we are writing to IDE FIFO
	.avm_read 		   (sd_avm_read),
	.avm_readdatavalid (sd_avm_readdatavalid),
	.avm_readdata      (sd_avm_readdata),
	.avm_write         (sd_avm_write),
	.avm_writedata     (sd_avm_writedata),

    .spi_cs_n          (spi_cs_n),
    .spi_sck           (spi_sck),
    .spi_mosi          (spi_mosi),
    .spi_miso          (spi_miso),
    .dbg               (sd_dbg)
);

assign dbg = { sd_dbg,
               mem_busy, boot_done, cpu_reset_n, avm_waitrequest, boot_state[3:0], boot_phase[1:0], 6'd0,
               boot_sectors[15:0] };

reg   [3:0] cd_st = 4'd0;
reg         cd_two, cd_is_rd;
reg  [15:0] cd_hiword;
reg         cd_srst = 1'b0;
assign      cd_wait = (cd_st != 4'd0);
wire        cd_acc  = (iobus_read | iobus_write) & ide1_cs;
wire        cd_alt  = iobus_address[9];
wire        cd_dat  = ~cd_alt && ide_address[2:0] == 3'd0;
wire        cd_cmd  = ~cd_alt && ide_address[2:0] == 3'd7;
always @(posedge clk_sys) begin
	cd_cs <= 1'b0;
	if (rst[5]) begin
		cd_st <= 0; cd_route <= 0; cd_srst <= 0;
	end else case (cd_st)
	4'd0: if (cd_acc) begin
		cd_route <= iobus_read & ide1_dev;
		cd_is_rd <= iobus_read;
		cd_two   <= cd_dat && iobus_datasize == 3'd4;
		cd_hiword<= iobus_writedata[31:16];
		cd_a     <= cd_alt ? 4'hE : {1'b0, ide_address[2:0]};
		cd_we    <= iobus_write;
		cd_dout  <= iobus_writedata[15:0];
		if (iobus_read) begin
			if (ide1_dev) begin cd_cs <= 1'b1; cd_st <= 4'd2; end
		end else if (cd_alt) begin
			cd_srst <= iobus_writedata[2];
			if (cd_srst && !iobus_writedata[2]) cd_st <= 4'd8;
		end else if ((cd_dat || cd_cmd) ? ide1_dev : 1'b1) begin
			cd_cs <= 1'b1; cd_st <= 4'd2;
		end
	end
	4'd2: begin
		if (cd_is_rd) cd_rdata <= {16'd0, cd_din};
		cd_st <= cd_two ? 4'd3 : 4'd0;
	end
	4'd3: begin cd_cs <= 1'b1; cd_dout <= cd_hiword; cd_st <= 4'd4; end
	4'd4: begin if (cd_is_rd) cd_rdata[31:16] <= cd_din; cd_st <= 4'd0; end
	4'd8:  begin cd_cs <= 1'b1; cd_we <= 1'b1; cd_a <= 4'd2; cd_dout <= 16'h0001; cd_st <= 4'd9;  end
	4'd9:  cd_st <= 4'd10;
	4'd10: begin cd_cs <= 1'b1; cd_a <= 4'd3; cd_dout <= 16'h0001; cd_st <= 4'd11; end
	4'd11: cd_st <= 4'd12;
	4'd12: begin cd_cs <= 1'b1; cd_a <= 4'd4; cd_dout <= 16'h0014; cd_st <= 4'd13; end
	4'd13: cd_st <= 4'd14;
	4'd14: begin cd_cs <= 1'b1; cd_a <= 4'd5; cd_dout <= 16'h00EB; cd_st <= 4'd15; end
	4'd15: cd_st <= 4'd0;
	default: cd_st <= 4'd0;
	endcase
end

wire ide1_nodata;
reg  ide1_wait = 0;
always @(posedge clk_sys) begin
	if(iobus_read & ide1_cs & ide1_nodata & !ide_address) ide1_wait <= 1;
	if(~ide1_nodata) ide1_wait <= 0;
end

wire [31:0] hd1_avs_address, hd1_avs_writedata, hd1_avs_readdata;
wire        hd1_avs_read, hd1_avs_write;
reg         hd1_avs_readdatavalid;
wire [31:0] hd1_avm_address, hd1_avm_readdata, hd1_avm_writedata;
wire        hd1_avm_read, hd1_avm_write;
reg         hd1_avm_readdatavalid;
ao486_ide ide1
(
	.clk               (clk_sys),
	.rst_n             (~rst[5]),

	.io_address        (ide_address),
	.io_writedata      (iobus_writedata),
	.io_read           ((iobus_read & ide1_cs) | ide1_wait),
	.io_write          (iobus_write & ide1_cs),
	.io_readdata       (ide1_readdata),
	.io_32             (iobus_datasize[2]),

	// .use_fast          (1),
	// .no_data           (ide1_nodata),

	.mgmt_address      (mgmt_address_m[3:0]),
	.mgmt_write        (mgmt_write_m & mgmt_ide1_cs),
	.mgmt_writedata    (mgmt_writedata_m),
	// .mgmt_readdata     (mgmt_ide1_readdata),
	// .mgmt_read         (mgmt_read & mgmt_ide1_cs),

	// .request           (ide1_request),
	.irq               (irq_15),
	.drive_sel         (ide1_dev),

	.sd_master_address       (hd1_avs_address),
	.sd_master_waitrequest   (1'b0),
	.sd_master_read          (hd1_avs_read),
	.sd_master_readdatavalid (hd1_avs_readdatavalid),
	.sd_master_readdata 	 (hd1_avs_readdata),
	.sd_master_write 	     (hd1_avs_write),
	.sd_master_writedata     (hd1_avs_writedata),

    .sd_slave_address        (hd1_avm_address[8:0]),
    .sd_slave_read 			 (hd1_avm_read),
    .sd_slave_readdata 		 (hd1_avm_readdata),
    .sd_slave_write 		 (hd1_avm_write),
    .sd_slave_writedata      (hd1_avm_writedata)
);

always @(posedge clk_sys) begin hd1_avs_readdatavalid <= hd1_avs_read; hd1_avm_readdatavalid <= hd1_avm_read; end

fdd_uio fdd_uio
(
	.clk               (clk_sys),
	.rst_n             (~rst[2]),
	.boot_done         (boot_done),
	.request           (fdd_request),
	.mg_req            (fd_mg_req),
	.mg_we             (fd_mg_we),
	.mg_addr           (fd_mg_addr),
	.mg_wdata          (fd_mg_wdata),
	.mg_ack            (fd_mg_ack),
	.mg_rdata          (mgmt_fdd_readdata),
	.mounted           (fd_mounted),
	.img_sectors       (fd_sectors),
	.mount_evt         (fd_mount_evt),
	.grant             (fd_grant),
	.busy              (fd_busy),
	.uio_rd            (fd_rd),
	.uio_wr            (fd_wr),
	.uio_lba           (fd_lba),
	.uio_ack           (fd_ack),
	.buff_addr         (fd_buff_addr),
	.buff_dout         (fd_buff_dout),
	.buff_wr           (fd_buff_wr),
	.buff_din          (fd_buff_din)
);

hdd_uio hdd_uio
(
	.clk               (clk_sys),
	.rst_n             (~rst[5]),
	.avs_address       (hd1_avs_address[3:2]),
	.avs_read          (hd1_avs_read),
	.avs_readdata      (hd1_avs_readdata),
	.avs_write         (hd1_avs_write),
	.avs_writedata     (hd1_avs_writedata),
	.avm_address       (hd1_avm_address),
	.avm_read          (hd1_avm_read),
	.avm_readdata      (hd1_avm_readdata),
	.avm_readdatavalid (hd1_avm_readdatavalid),
	.avm_write         (hd1_avm_write),
	.avm_writedata     (hd1_avm_writedata),
	.cfg_req           (hd1_cfg_req),
	.cfg_addr          (hd1_cfg_addr),
	.cfg_data          (hd1_cfg_data),
	.cfg_ack           (hd1_cfg_ack),
	.mounted           (hd1_mounted),
	.img_sectors       (hd1_sectors),
	.grant             (hd1_grant),
	.busy              (hd1_busy),
	.uio_rd            (hd1_rd),
	.uio_wr            (hd1_wr),
	.uio_lba           (hd1_lba),
	.uio_ack           (hd1_ack),
	.buff_addr         (hd1_buff_addr),
	.buff_dout         (hd1_buff_dout),
	.buff_wr           (hd1_buff_wr),
	.buff_din          (hd1_buff_din)
);

mpu401 mpu
(
	.clk               (clk_sys),
	.rst_n             (~rst[6]),
	.clock_rate        (clock_rate),

	.io_address        (iobus_address[0]),
	.io_read           (iobus_read & mpu_cs),
	.io_readdata       (mpu_readdata),
	.io_write          (iobus_write & mpu_cs),
	.io_writedata      (iobus_writedata[7:0]),

	.irq               (irq_9),
	.midi_tx           (midi_tx),
	.midi_rx           (midi_rx)
);

joystick joystick
(
	.clk               (clk_sys),
	.rst_n             (~rst[6]),
	.clock_rate        (clock_rate),
	.read              (iobus_read & joy_cs),
	.write             (iobus_write & joy_cs),
	.readdata          (joystick_readdata),
	.dis               (2'b00),
	.dig_1             (joy_dig_1),
	.dig_2             (joy_dig_2),
	.ana_1             (joy_ana_1),
	.ana_2             (joy_ana_2),
	.mode              (joy_mode),
	.timed             (2'd0)
);

// timers
pit pit
(
	.clk               (clk_sys),
	.rst_n             (~rst[6]),

	.clock_rate        (clock_rate),

	.io_address        ({iobus_address[5],iobus_address[1:0]}),
	.io_writedata      (iobus_writedata[7:0]),
	.io_readdata       (pit_readdata),
	.io_read           (iobus_read & pit_cs),
	.io_write          (iobus_write & pit_cs),

	.speaker_out       (speaker_out),
	.irq               (irq_0)
);

// Internal PS/2 wires from keyboard device to controller
wire kbd_ps2_clk;
wire kbd_ps2_dat;
wire ps2_kbclk_out;
wire ps2_kbdat_out;
// Internal PS/2 wires from mouse device to controller
wire mouse_ps2_clk;
wire mouse_ps2_dat;
wire ps2_mouseclk_out;
wire ps2_mousedat_out;
wire ps2_reset_n;

ps2 ps2
(
	.clk               (clk_sys),
	.rst_n             (~rst[7]),

	.io_address        (iobus_address[3:0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read),
	.io_write          (iobus_write),
	.io_readdata       (ps2_readdata),
	.io_cs             (ps2_io_cs),
	.ctl_cs            (ps2_ctl_cs),

	.ps2_kbclk         (kbd_ps2_clk),
	.ps2_kbdat         (kbd_ps2_dat),
	.ps2_kbclk_out     (ps2_kbclk_out),
	.ps2_kbdat_out     (ps2_kbdat_out),

	// Route mouse via internal PS/2 device generator
	.ps2_mouseclk      (mouse_ps2_clk),
	.ps2_mousedat      (mouse_ps2_dat),
	.ps2_mouseclk_out  (ps2_mouseclk_out),
	.ps2_mousedat_out  (ps2_mousedat_out),

	.output_a20_enable (),
	.output_reset_n    (ps2_reset_n),
	.a20_enable        (a20_enable),

	.irq_keyb          (irq_1),
	.irq_mouse         (irq_12)
);

rtc rtc
(
	.clk               (clk_sys),
	.rst_n             (~rst[8]),

	.clock_rate        (clock_rate),

	.io_address        (iobus_address[0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read & rtc_cs),
	.io_write          (iobus_write & rtc_cs),
	.io_readdata       (rtc_readdata),

	.mgmt_address      (mgmt_address_m[7:0]),
	.mgmt_write        (mgmt_write_m & mgmt_rtc_cs),
	.mgmt_writedata    (mgmt_writedata_m[7:0]),

	.bootcfg           ({bootcfg[5:2], bootcfg[1:0] ? bootcfg[1:0] : {~fdd0_inserted, fdd0_inserted}}),

	.irq               (irq_8)
);

sound sound
(
	.clk               (clk_sys),
	.clk_audio         (clk_audio),
	.rst_n             (~rst[15]),

	.clock_rate        (clock_rate),

	.address           (iobus_address[3:0]),
	.writedata         (iobus_writedata[7:0]),
	.read              (iobus_read),
	.write             (iobus_write),
	.readdata          (sound_readdata),
	.sb_cs             (sb_cs),
	.fm_cs             (fm_cs),

	.dma_req8          (dma_sb_req_8),
	.dma_req16         (dma_sb_req_16),
	.dma_ack           (dma_sb_ack_16 | dma_sb_ack_8),
	.dma_readdata      (dma_sb_req_16 ? dma_sb_readdata_16 : dma_sb_readdata_8),
	.dma_writedata     (dma_sb_writedata),

	.sbp               (sbp),
	.vol_master_l      (vol_master_l),
	.vol_master_r      (vol_master_r),
	.vol_voice_l       (vol_voice_l),
	.vol_voice_r       (vol_voice_r),
	.vol_cd_l          (vol_cd_l),
	.vol_cd_r          (vol_cd_r),
	.vol_midi_l        (vol_midi_l),
	.vol_midi_r        (vol_midi_r),
	.vol_line_l        (vol_line_l),
	.vol_line_r        (vol_line_r),
	.vol_spk           (vol_spk),
	.vol_en            (vol_en),

	.sample_cms_l      (),
	.sample_cms_r      (),
	.sample_sb_l       (sample_sb_l),
	.sample_sb_r       (sample_sb_r),
	.sample_opl_l      (sample_opl_l),
	.sample_opl_r      (sample_opl_r),

	.fm_mode           (sound_fm_mode),
	.cms_en            (sound_cms_en),

	.irq               (sb_irq),
	.irq_5_en          (sb_irq5_sel),
	.irq_7_en          (sb_irq7_en),
	.irq_10_en         (sb_irq10_en)
);
assign irq_5  = sb_irq & sb_irq5_sel;
assign irq_7  = sb_irq & sb_irq7_en;
assign irq_10 = sb_irq & sb_irq10_en;

vga vga
(
	.clk_sys           (clk_sys),
	.rst_n             (~rst[9]),

	.clk_vga           (clk_vga),
	.clock_rate_vga    (clock_rate_vga),

	.io_address        (iobus_address[3:0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read),
	.io_write          (iobus_write),
	.io_readdata       (vga_io_readdata),
	.io_b_cs           (vga_b_cs),
	.io_c_cs           (vga_c_cs),
	.io_d_cs           (vga_d_cs),

	.mem_address       (vga_address),
	.mem_read          (vga_read),
	.mem_readdata      (vga_readdata),
	.mem_write         (vga_write),
	.mem_writedata     (vga_writedata),

	.vga_ce            (video_ce),
	.vga_dot_ce        (vga_dot_ce),
	.vga_blank_n       (vga_blank_n_o),
	.vga_horiz_sync    (vga_hsync_o),
	.vga_vert_sync     (vga_vsync_o),
	.vga_r             (vga_r_o),
	.vga_g             (vga_g_o),
	.vga_b             (vga_b_o),
	.vga_f60           (video_f60),
	.vga_memmode       (vga_memmode),
	.vga_pal_a         (video_pal_a),
	.vga_pal_d         (video_pal_d),
	.vga_pal_we        (video_pal_we),
	.vga_start_addr    (video_start_addr),
	.vga_wr_seg        (video_wr_seg),
	.vga_rd_seg        (video_rd_seg),
	.vga_width         (video_width),
	.vga_height        (video_height),
	.vga_flags         (video_flags),
	.vga_stride        (video_stride),
	.vga_off           (video_off),
	.vga_lores         (video_lores),
	.vga_border        (video_border),

	.irq               (irq_2)
);

svga_fb svga_fb
(
	.clk_sys           (clk_sys),
	.reset             (rst[0]),
	.fb_en             (fb_en),
	.start_addr        (video_start_addr),
	.stride            (video_stride),
	.width             (video_width),
	.dscan             (video_flags[3]),
	.pal_a             (video_pal_a),
	.pal_d             (video_pal_d),
	.pal_we            (video_pal_we),
	.sd_req            (fb_sd_req),
	.sd_ack            (fb_sd_ack),
	.sd_addr           (fb_sd_addr),
	.sd_burst          (fb_sd_burst),
	.sd_ready          (fb_sd_ready),
	.sd_dout           (fb_sd_dout),
	.clk_vga           (clk_vga),
	.ce                (vga_dot_ce),
	.in_blank_n        (vga_blank_n_o),
	.in_hs             (vga_hsync_o),
	.in_vs             (vga_vsync_o),
	.in_r              (vga_r_o),
	.in_g              (vga_g_o),
	.in_b              (vga_b_o),
	.out_blank_n       (video_blank_n),
	.out_hs            (video_hsync),
	.out_vs            (video_vsync),
	.out_r             (video_r),
	.out_g             (video_g),
	.out_b             (video_b),
	.active            ()
);

pic pic
(
	.clk               (clk_sys),
	.rst_n             (~rst[10]),

	.io_address        (iobus_address[0]),
	.io_writedata      (iobus_writedata[7:0]),
	.io_read           (iobus_read),
	.io_write          (iobus_write),
	.io_readdata       (pic_readdata),
	.io_master_cs      (pic_master_cs),
	.io_slave_cs       (pic_slave_cs),

	.interrupt_vector  (interrupt_vector),
	.interrupt_done    (interrupt_done),
	.interrupt_do      (interrupt_do),
	.interrupt_input   (interrupt)
);

always @* begin
	interrupt = 0;

	interrupt[0]  = irq_0;
	interrupt[1]  = irq_1;
	interrupt[3]  = irq_3;
	interrupt[4]  = irq_4;
	interrupt[5]  = irq_5 | (~sb_irq5_sel & gus_irq);
	interrupt[6]  = irq_6;
	interrupt[7]  = irq_7 | ( sb_irq5_sel & gus_irq);
	interrupt[8]  = irq_8;
	interrupt[9]  = irq_9 | irq_2;
	interrupt[10] = irq_10;
	interrupt[12] = irq_12;
	interrupt[14] = irq_14;
	interrupt[15] = irq_15 | cd_irq;
end

assign mgmt_ide0_cs  = (mgmt_address_m[15:8] == 8'hF0);
assign mgmt_ide1_cs  = (mgmt_address_m[15:8] == 8'hF1);
assign mgmt_fdd_cs   = (mgmt_address_m[15:8] == 8'hF2);
assign mgmt_rtc_cs   = (mgmt_address_m[15:8] == 8'hF4);
assign mgmt_readdata = mgmt_ide0_cs ? mgmt_ide0_readdata : mgmt_ide1_cs ? mgmt_ide1_readdata : mgmt_fdd_readdata;

// Debug output assignments
assign debug_bios_loaded = bios_loaded;
assign debug_vga_bios_sig_bad = vga_bios_sig_bad;
assign debug_vga_bios_sig_checked = vga_bios_sig_checked;
assign debug_first_instruction = first_instruction_executed;

// Detect first instruction execution at reset vector f000:fff0
// exe_eip points to next instruction, so when exe_eip >= 0xFFF1, we're executing at 0xFFF0
always @(posedge clk_sys) begin
    if (reset) begin
        first_instruction_executed <= 0;
    end else if (cpu_reset_n && !first_instruction_executed && debug_cpu_cs == 16'hF000 && debug_cpu_eip >= 32'hFFF1 && debug_cpu_eip <= 32'hFFFF) begin
        first_instruction_executed <= 1;
        $display("DEBUG: First instruction executed at reset vector F000:FFF0 (exe_eip = %08x)", debug_cpu_eip);
    end
end


// PS/2 keyboard device: convert incoming bytes to PS/2 wires
logic clk_ps2;
localparam PS2DIV = 800;       // ~12.5kHz from 20MHz
always_ff @(posedge clk_sys) begin
    integer cnt;
    cnt <= cnt + 1;
    if (cnt == PS2DIV) begin
        clk_ps2 <= ~clk_ps2;
        cnt <= 0;
    end
end

ps2_device ps2_kbd (
    .clk_sys      (clk_sys),
    .reset        (rst[11]),
    .ps2_clk      (clk_ps2),
    .wdata        (kbd_data),
    .we           (kbd_data_valid),
    .ps2_clk_out  (kbd_ps2_clk),
    .ps2_dat_out  (kbd_ps2_dat),
    .tx_empty     (),
    .ps2_clk_in   (ps2_kbclk_out),   // feedback from controller
    .ps2_dat_in   (ps2_kbdat_out),
    .rdata        (kbd_host_data),
    .rd           (kbd_host_data_clear)
);

    // PS/2 mouse device: translate UART-injected mouse bytes to PS/2 lines
// Also expose host->device bytes via rdata so we can forward them over UART
// wire [8:0] mouse_host_cmd;
// rd comes from top-level uart2ps2
// reg        mouse_host_cmd_rd;
ps2_device ps2_mouse (
    .clk_sys      (clk_sys),
    .reset        (rst[12]),
    .ps2_clk      (clk_ps2),
    .wdata        (mouse_data),
    .we           (mouse_data_valid),
    .ps2_clk_out  (mouse_ps2_clk),
    .ps2_dat_out  (mouse_ps2_dat),
    .tx_empty     (),
    .ps2_clk_in   (ps2_mouseclk_out),
    .ps2_dat_in   (ps2_mousedat_out),
    .rdata        (mouse_host_cmd),
    .rd           (mouse_host_cmd_clear)
);

//
// Boot loader FSM - loads BIOS and VGA BIOS from SD card to DDR memory
//
localparam REG_BASE_ADDRESS_STATUS = 2'd0;  // writes to base address and reads status
localparam REG_SD_ADDRESS = 2'd1;
localparam REG_SD_BLOCK_COUNT = 2'd2;
localparam REG_CONTROL = 2'd3;
localparam CONTROL_INIT = 32'd1;
localparam CONTROL_READ = 32'd2;
localparam CONTROL_WRITE = 32'd3;
localparam STATUS_INIT       = 3'd0;
localparam STATUS_INIT_ERROR = 3'd1;
localparam STATUS_IDLE = 3'd2;
always @(posedge clk_sys) begin
    if (rst[13]) begin
        boot_state <= BOOT_IDLE;
        boot_done <= 0;
        boot_phase <= 0;        // Start with BIOS phase
        cpu_reset_n <= 0;
        boot_sd_avs_read <= 0;
        boot_sd_avs_write <= 0;
        boot_sd_avs_read_r <= 0;
        boot_sectors <= 0;
        boot_words_in_sector <= 0;
		debug_boot_stage <= 0;
        bios_loaded <= 0;
        vga_bios_sig_bad <= 0;
        vga_bios_sig_checked <= 0;
		debug_sd_error <= 0;

        // config parser
        cfg_expect_addr <= 1;
        cfg_terminated <= 0;
        mgmt_write <= 0;
        mgmt_address <= 16'd0;
    end else begin
        boot_sd_avs_read <= 0;
        boot_sd_avs_write <= 0;
		boot_sd_avs_read_r <= boot_sd_avs_read;
        mgmt_write <= 0;  // default, strobe on parsed writes
        
        case (boot_state)
            BOOT_IDLE: if (!mem_busy) begin             // start boot when memory is ready
                // Start SD card initialization first
                $display("BOOT: Initializing SD card...");
                boot_state <= BOOT_SD_INIT;
            end
            
            BOOT_SD_INIT: begin
                // Send SD card initialization command
				debug_boot_stage <= 1;
                boot_sd_avs_address <= REG_CONTROL;     // Control register
                boot_sd_avs_writedata <= CONTROL_INIT;  // INIT command (CONTROL_INIT = 1)
                boot_sd_avs_write <= 1;
                boot_state <= BOOT_SD_WAIT;
            end
            
            BOOT_SD_WAIT: begin
                // Wait for SD card initialization to complete
                boot_sd_avs_address <= 2'd0;     // Status register
                boot_sd_avs_read <= 1;
                // STATUS_IDLE = 2 means initialization complete
                if (boot_sd_avs_read_r) begin
					if (sd_avs_readdata[2:0] == STATUS_IDLE) begin
						// Start first load phase (BIOS)
						boot_phase <= 0;  // BIOS phase
						boot_addr <= 32'hF0000;  // BIOS load address
						boot_sectors <= 16'd128;  // 64KB = 128 sectors
						$display("BOOT: SD card initialized, starting BIOS load from sector 0 to 0xF0000");
						debug_sd_error <= 0;
						boot_state <= BOOT_LOAD_START;
					end else if (sd_avs_readdata[2:0] == STATUS_INIT_ERROR) begin
						$display("BOOT: SD card initialization failed");
						debug_sd_error <= 1;
						boot_state <= BOOT_SD_INIT;
					end
                end
            end
            
            BOOT_LOAD_START: begin
                // Set up memory base address first
                if (boot_phase == 0) begin
                    debug_boot_stage <= 2;  // BIOS loading
                end else if (boot_phase == 1) begin
                    debug_boot_stage <= 3;  // VGA BIOS loading
                end else begin
                    debug_boot_stage <= 4;  // Config sector parsing
                end
                boot_sd_avs_address <= REG_BASE_ADDRESS_STATUS;  // memory address register
                boot_sd_avs_writedata <= boot_addr;  // Current memory address
                boot_sd_avs_write <= 1;
                boot_state <= BOOT_LOAD_SECTOR;

                // Reset the config parser once, before the first config sector.
                // The config stream spans sectors 192..194 and must be parsed
                // continuously across sector boundaries.
                if (boot_phase == 2 && boot_sectors == 16'd3) begin
                    cfg_expect_addr <= 1;
                    cfg_terminated <= 0;
                    mgmt_address <= 16'd0;
                    cfg_write_count <= 0;
                    $display("CFG: Start parsing config from sectors 192-194");
                end
            end
            
            BOOT_LOAD_SECTOR: begin
                // Set up SD sector address based on phase
                boot_sd_avs_address <= REG_SD_ADDRESS;  // sector address register
                if (boot_phase == 0) begin
                    // BIOS phase: sectors 0-127
                    boot_sd_avs_writedata <= 32'd128 - boot_sectors;  // Current BIOS sector
                end else if (boot_phase == 1) begin
                    // VGA BIOS phase: sectors 128-191  
                    boot_sd_avs_writedata <= 32'd128 + (64 - boot_sectors);  // Current VGA sector
                end else begin
                    // CONFIG phase: sectors 192..194
                    boot_sd_avs_writedata <= 32'd192 + (32'd3 - boot_sectors);
                end
                boot_sd_avs_write <= 1;
                boot_state <= BOOT_LOAD_COUNT;
            end
            
            BOOT_LOAD_COUNT: begin
				// Set up sector count
				boot_sd_avs_address <= REG_SD_BLOCK_COUNT;  // sector count register
				boot_sd_avs_writedata <= 32'd1;  // Read 1 sector at a time
				boot_sd_avs_write <= 1;
				boot_words_in_sector <= 8'd128;  // 512 bytes = 128 words per sector
				boot_state <= BOOT_LOAD_READ;
			end
            
			BOOT_LOAD_READ: begin
				// Start read operation and immediately go to data state
				boot_sd_avs_address <= REG_CONTROL;  // control register
				boot_sd_avs_writedata <= CONTROL_READ;  // READ command
				boot_sd_avs_write <= 1;
				boot_state <= BOOT_LOAD_DATA;  // Go directly to data state
			end

            BOOT_LOAD_DATA: begin
				// wait for sd controller to become idle again
				// data is transferred to memory through the main_memory module
				boot_sd_avs_address <= REG_BASE_ADDRESS_STATUS;
				boot_sd_avs_read <= 1;

				if (boot_sd_avs_read_r && sd_avs_readdata[2:0] == STATUS_IDLE) begin
					boot_sectors <= boot_sectors - 1;    // load next sector
					boot_addr <= boot_addr + 512;
					boot_state <= BOOT_LOAD_START;
					if (boot_sectors == 1) begin
						if (boot_phase == 0) begin
							// BIOS phase complete, start VGA BIOS phase
							$display("BOOT: BIOS load complete, starting VGA BIOS load from sector 128 to 0xC0000");
							bios_loaded <= 1;  // Set BIOS loaded flag for LED
							boot_phase <= 1;   // Switch to VGA BIOS phase
							boot_addr <= 32'hC0000;  // VGA BIOS load address
							boot_sectors <= 16'd64;
							boot_state <= BOOT_LOAD_START;
						end else if (boot_phase == 1) begin
							// VGA BIOS phase complete - start CONFIG phase
							$display("BOOT: VGA BIOS load complete, applying configuration from sectors 192-194");
							boot_phase <= 2;   // Switch to CONFIG phase
							boot_addr <= 32'h80000;  // scratch address for SD DMA during config
							boot_sectors <= 16'd3;   // three sectors of config
							boot_state <= BOOT_LOAD_START;
						end else begin
							// CONFIG phase complete - all done!
							$display("BOOT: Config applied, releasing CPU reset (mgmt writes=%0d)", cfg_write_count);
							debug_boot_stage <= 5;
							boot_state <= BOOT_COMPLETE;
						end
					end
				end
            end
            
            BOOT_COMPLETE: begin
                boot_done <= 1;
                cpu_reset_n <= 1;  // Release CPU reset
				debug_boot_stage <= 5;
            end
        endcase

		// check VGA BIOS signature
		if (sd_avm_write && !avm_waitrequest && sd_avm_address == 32'hC0000) begin
			vga_bios_sig_checked <= 1;
			vga_bios_sig_bad <= sd_avm_writedata[15:0] != 16'hAA55;
		end

        // During CONFIG phase, parse SD DMA stream, only on accepted beats
        // Accepted when driver_sd asserts write and memory accepts (waitrequest deasserted)
        if (boot_phase == 2 && sd_avm_write && (boot_done ? 1'b1 : ~avm_waitrequest) && !cfg_terminated) begin
            if (cfg_expect_addr) begin
                if (sd_avm_writedata == 32'd0) begin
                    cfg_terminated <= 1'b1;
                    cfg_expect_addr <= 1; // wait for next (ignored) address
                    $display("CFG: Termination encountered");
                end else begin
                    mgmt_address <= sd_avm_writedata[15:0];
                    cfg_expect_addr <= 0;
                    // $display("CFG: addr=%04h", sd_avm_writedata[15:0]);
                end
            end else begin
                // data word received; perform mgmt write using latched mgmt_address
                mgmt_writedata <= sd_avm_writedata;
                mgmt_write <= 1'b1;  // one-cycle strobe per pair
                cfg_expect_addr <= 1;
                cfg_write_count <= cfg_write_count + 1'd1;
                $display("CFG: mgmt[%04h] <= %08h", mgmt_address, sd_avm_writedata);
            end
        end
    end
end

// Export debug byte for UART bridge to wrap as type 0x07
wire bios_dbg_write = iobus_write && sysctl_cs && (iobus_datasize == 3'd1);
assign dbg_uart_byte = iobus_writedata[7:0];
assign dbg_uart_we   = bios_dbg_write;

// ---------------------------------------------------------------------------- VGA resolution detection

// Simple frame size estimator using VGA signals.
// - Counts active pixels while `vga_de` is high (gated by `vga_ce`) to determine width.
// - Counts number of active lines per frame to determine height.
// - Latches measurements on the rising edge of VSYNC.

reg  [10:0] fb_width;
reg   [9:0] fb_height;
wire        fb_size_valid;

reg  [10:0] cur_line_width;
reg  [10:0] max_line_width;
reg   [9:0] line_count;
reg         de_r;
reg         vs_r;

assign fb_size_valid = (fb_width != 0) && (fb_height != 0);

always @(posedge clk_vga) begin
    if (rst[14]) begin
        fb_width       <= 0;
        fb_height      <= 0;
        cur_line_width <= 0;
        max_line_width <= 0;
        line_count     <= 0;
        de_r           <= 0;
        vs_r           <= 0;
    end else begin
        if (video_ce) begin
            de_r <= video_blank_n;
            vs_r <= video_vsync;

            // Count active pixels in the line
            if (video_blank_n) begin
				if (!de_r)      // start of line
					cur_line_width <= 1;
				else
                	cur_line_width <= cur_line_width + 1'b1;
            end
            // End of active portion of a line
            if (!video_blank_n && de_r) begin
                if (cur_line_width > max_line_width)
                    max_line_width <= cur_line_width;
                if (cur_line_width != 0)
                    line_count <= line_count + 1'b1;
            end
            // Rising edge of VSYNC: latch frame size and reset counters
            if (video_vsync && !vs_r) begin
                fb_width       <= max_line_width;
                fb_height      <= line_count;
                cur_line_width <= 0;
                max_line_width <= 0;
                line_count     <= 0;
            end
        end
    end
end


endmodule
