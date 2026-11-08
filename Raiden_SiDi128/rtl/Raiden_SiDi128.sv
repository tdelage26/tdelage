// SPDX-License-Identifier: GPL-3.0-or-later

module Raiden_SiDi128 (
	input         CLOCK_27,
	output        LED,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,

	input         QSCK,
	input         QCSn,
	input   [3:0] QDAT,

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
	output        SDRAM2_CKE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,
	output        HDMI_PCLK,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
	output        HDMI_RST,
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,

	output        AUDIO_L,
	output        AUDIO_R,
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA
);

`include "build_id.v"

localparam CONF_STR = {
	"RAIDEN;;",
	"O1,Refresh Rate,Original 59.4Hz,60Hz;",
	"O23,Scanlines,Off,25%,50%,75%;",
	"O4,Blending,Off,On;",
	"O5,Swap Joysticks,Off,On;",
	"OEF,Rotate Screen,Off,Right (CW),Left (CCW);",
	"O7,Rotate Filter,Off,On;",
	"O6,Pause,Off,On;",
	"O8A,FM Volume,Default,Mute,50%,75%,125%,150%,200%,300%;",
	"OBD,ADPCM Volume,Default,Mute,50%,75%,125%,150%,200%,300%;",
	"DIP;",
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire clk_sys;
wire pll_locked;
pll_sidi128 pll (
	.inclk0 (CLOCK_27),
	.c0     (clk_sys),
	.locked (pll_locked)
);

wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [31:0] joystick_0, joystick_1;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;
wire        key_pressed;
wire  [7:0] key_code;
wire        key_strobe;
wire        key_extended;

wire        i2c_start, i2c_read, i2c_end, i2c_ack;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr, i2c_wdata, i2c_rdata;

user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'h0000_4000)) user_io (
	.clk_sys            (clk_sys),
	.clk_sd             (clk_sys),
	.conf_str           (CONF_STR),
	.SPI_CLK            (SPI_SCK),
	.SPI_SS_IO          (CONF_DATA0),
	.SPI_MISO           (SPI_DO),
	.SPI_MOSI           (SPI_DI),
	.buttons            (buttons),
	.switches           (switches),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr              (ypbpr),
	.no_csync           (no_csync),
	.key_strobe         (key_strobe),
	.key_pressed        (key_pressed),
	.key_extended       (key_extended),
	.key_code           (key_code),
	.joystick_0         (joystick_0),
	.joystick_1         (joystick_1),
	.status             (status),
	.i2c_start          (i2c_start),
	.i2c_read           (i2c_read),
	.i2c_addr           (i2c_addr),
	.i2c_subaddr        (i2c_subaddr),
	.i2c_dout           (i2c_wdata),
	.i2c_din            (i2c_rdata),
	.i2c_end            (i2c_end),
	.i2c_ack            (i2c_ack)
);

i2c_master #(.CLK_Freq(80_000_000)) hdmi_i2c (
	.CLK        (clk_sys),
	.I2C_START  (i2c_start),
	.I2C_READ   (i2c_read),
	.I2C_ADDR   (i2c_addr),
	.I2C_SUBADDR(i2c_subaddr),
	.I2C_WDATA  (i2c_wdata),
	.I2C_RDATA  (i2c_rdata),
	.I2C_END    (i2c_end),
	.I2C_ACK    (i2c_ack),
	.I2C_SCL    (HDMI_SCL),
	.I2C_SDA    (HDMI_SDA)
);
assign HDMI_RST = 1'b1;

wire        ioctl_downl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;

data_io #(.ROM_DIRECT_UPLOAD(1'b0), .USE_QSPI(1'b1)) data_io (
	.clk_sys       (clk_sys),
	.SPI_SCK       (SPI_SCK),
	.SPI_SS2       (SPI_SS2),
	.SPI_SS4       (1'b1),
	.SPI_DI        (SPI_DI),
	.SPI_DO        (SPI_DO),
	.QCSn          (QCSn),
	.QSCK          (QSCK),
	.QDAT          (QDAT),
	.clkref_n      (1'b0),
	.ioctl_download(ioctl_downl),
	.ioctl_index   (ioctl_index),
	.ioctl_wr      (ioctl_wr),
	.ioctl_addr    (ioctl_addr),
	.ioctl_dout    (ioctl_dout),
	.ioctl_din     (8'h00)
);

wire        ld_active, ld_overflow;
wire        dl_wr, dl_busy;
wire [24:1] dl_waddr;
wire [15:0] dl_wdata;
wire [27:0] spr_dl_addr;
wire [15:0] spr_dl_data;
wire        spr_dl_req, spr_dl_ack;
wire        wide_wr;
wire [26:0] wide_addr;
wire [15:0] wide_dout;

raiden_sidi_loader u_loader (
	.clk           (clk_sys),
	.reset         (~pll_locked),
	.ioctl_download(ioctl_downl),
	.ioctl_index   (ioctl_index),
	.ioctl_wr      (ioctl_wr),
	.ioctl_addr    (ioctl_addr),
	.ioctl_dout    (ioctl_dout),
	.active        (ld_active),
	.overflow      (ld_overflow),
	.dl_wr         (dl_wr),
	.dl_waddr      (dl_waddr),
	.dl_wdata      (dl_wdata),
	.dl_busy       (dl_busy),
	.spr_waddr     (spr_dl_addr),
	.spr_wdata     (spr_dl_data),
	.spr_we_req    (spr_dl_req),
	.spr_we_ack    (spr_dl_ack),
	.wide_wr       (wide_wr),
	.wide_addr     (wide_addr),
	.wide_dout     (wide_dout)
);

assign LED = ~(ld_active | ld_overflow);

reg rom_loaded = 1'b0;
reg ld_active_d;
always @(posedge clk_sys) begin
	ld_active_d <= ld_active;
	if (ld_active_d & ~ld_active) rom_loaded <= 1'b1;
end

wire reset_cause = status[0] | buttons[1] | ~pll_locked | ld_active | ~rom_loaded;
reg [21:0] reset_hold_cnt = 22'h3FFFFF;
always @(posedge clk_sys) begin
	if (reset_cause)                  reset_hold_cnt <= 22'h3FFFFF;
	else if (reset_hold_cnt != 22'd0) reset_hold_cnt <= reset_hold_cnt - 22'd1;
end
wire reset = (reset_hold_cnt != 22'd0);
wire bridge_reset = ~pll_locked;
wire video_reset  = ~pll_locked;

wire [19:0] player1, player2;
wire  [8:0] controls;
arcade_inputs inputs (
	.clk         (clk_sys),
	.key_strobe  (key_strobe),
	.key_pressed (key_pressed),
	.key_code    (key_code),
	.joystick_0  (joystick_0[19:0]),
	.joystick_1  (joystick_1[19:0]),
	.joystick_2  (20'd0),
	.joystick_3  (20'd0),
	.rotate      (1'b0),
	.orientation (2'b00),
	.joyswap     (status[5]),
	.oneplayer   (1'b0),
	.controls    (controls),
	.player1     (player1),
	.player2     (player2),
	.player3     (),
	.player4     ()
);

wire start1 = controls[0] | player1[10];
wire start2 = controls[1] | player2[10];
wire coin1  = controls[4] | player1[11];
wire coin2  = controls[5] | player2[11];
wire [7:0] p1_input = {~start1, 1'b1, ~player1[5], ~player1[4],
                       ~player1[0], ~player1[1], ~player1[2], ~player1[3]};
wire [7:0] p2_input = {~start2, 1'b1, ~player2[5], ~player2[4],
                       ~player2[0], ~player2[1], ~player2[2], ~player2[3]};
wire [7:0] coin_input = {6'd0, coin2, coin1};

reg pause_toggle = 1'b0, pause_btn_d = 1'b0;
always @(posedge clk_sys) begin
	pause_btn_d <= player1[12] | player2[12];
	if ((player1[12] | player2[12]) && !pause_btn_d) pause_toggle <= ~pause_toggle;
end
wire pause_req = status[6] | pause_toggle;

wire [15:0] dip_sw = status[31:16];

wire HBlank, VBlank, HSync, VSync, video_de;
reg  vblank_prev_safe = 1'b0;
reg  paused_safe = 1'b0;
always @(posedge clk_sys) begin
	vblank_prev_safe <= VBlank;
	if (reset)                          paused_safe <= 1'b0;
	else if (VBlank && !vblank_prev_safe) paused_safe <= pause_req;
end

wire [24:1] sd_addr0, sd_addr1, sd_addr2, sd_addr3;
wire [15:0] sd_din0, sd_din1, sd_din2, sd_din3;
wire        sd_wrl0, sd_wrh0, sd_wrl1, sd_wrh1, sd_wrl2, sd_wrh2, sd_wrl3, sd_wrh3;
wire        sd_req0, sd_req1, sd_req2, sd_req3;
wire        sd_ack0, sd_ack1, sd_ack2, sd_ack3;
wire [15:0] sd_dout0, sd_dout1, sd_dout2, sd_dout3;
wire        sdram_ready;

sdram #(.DEVICE_FAMILY("Cyclone 10 LP")) sdram_ctrl (
	.SDRAM_DQ  (SDRAM_DQ),
	.SDRAM_A   (SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA  (SDRAM_BA),
	.SDRAM_nCS (SDRAM_nCS),
	.SDRAM_nWE (SDRAM_nWE),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_CLK (SDRAM_CLK),
	.SDRAM_CKE (SDRAM_CKE),
	.init      (~pll_locked),
	.clk       (clk_sys),
	.prio_mode (2'b00),
	.ready     (sdram_ready),
	.addr0(sd_addr0), .wrl0(sd_wrl0), .wrh0(sd_wrh0), .din0(sd_din0), .dout0(sd_dout0), .req0(sd_req0), .ack0(sd_ack0),
	.addr1(sd_addr1), .wrl1(sd_wrl1), .wrh1(sd_wrh1), .din1(sd_din1), .dout1(sd_dout1), .req1(sd_req1), .ack1(sd_ack1),
	.addr2(sd_addr2), .wrl2(sd_wrl2), .wrh2(sd_wrh2), .din2(sd_din2), .dout2(sd_dout2), .req2(sd_req2), .ack2(sd_ack2),
	.addr3(sd_addr3), .wrl3(sd_wrl3), .wrh3(sd_wrh3), .din3(sd_din3), .dout3(sd_dout3), .req3(sd_req3), .ack3(sd_ack3)
);

wire [23:0] game_tile_addr, game_main_addr, game_sub_addr;
wire        game_tile_req,  game_main_req,  game_sub_req;
wire  [2:0] game_tile_kind;
wire [31:0] game_tile_data;
wire        game_tile_valid;
wire [15:0] game_main_data, game_sub_data;
wire        game_main_ready, game_sub_ready;

wire [17:0] oki_rom_addr;
wire  [7:0] oki_rom_data;
wire        oki_rom_ok;

raiden_sidi_sdram_bridge bridge (
	.clk           (clk_sys),
	.reset         (bridge_reset),
	.sdram_ready   (sdram_ready),
	.dl_active     (ld_active),
	.dl_wr         (dl_wr),
	.dl_waddr      (dl_waddr),
	.dl_wdata      (dl_wdata),
	.dl_busy       (dl_busy),
	.tile_byte_addr(game_tile_addr),
	.tile_req      (game_tile_req),
	.gfx_kind      (game_tile_kind),
	.tile_data     (game_tile_data),
	.tile_valid    (game_tile_valid),
	.main_byte_addr(game_main_addr),
	.main_req      (game_main_req),
	.main_data     (game_main_data),
	.main_ready    (game_main_ready),
	.sub_byte_addr (game_sub_addr),
	.sub_req       (game_sub_req),
	.sub_data      (game_sub_data),
	.sub_ready     (game_sub_ready),
	.oki_byte_addr (oki_rom_addr),
	.oki_data      (oki_rom_data),
	.oki_ok        (oki_rom_ok),
	.sdram_addr0(sd_addr0), .sdram_din0(sd_din0), .sdram_wrl0(sd_wrl0), .sdram_wrh0(sd_wrh0),
	.sdram_req0(sd_req0), .sdram_ack0(sd_ack0), .sdram_dout0(sd_dout0),
	.sdram_addr1(sd_addr1), .sdram_din1(sd_din1), .sdram_wrl1(sd_wrl1), .sdram_wrh1(sd_wrh1),
	.sdram_req1(sd_req1), .sdram_ack1(sd_ack1), .sdram_dout1(sd_dout1),
	.sdram_addr2(sd_addr2), .sdram_din2(sd_din2), .sdram_wrl2(sd_wrl2), .sdram_wrh2(sd_wrh2),
	.sdram_req2(sd_req2), .sdram_ack2(sd_ack2), .sdram_dout2(sd_dout2),
	.sdram_addr3(sd_addr3), .sdram_din3(sd_din3), .sdram_wrl3(sd_wrl3), .sdram_wrh3(sd_wrh3),
	.sdram_req3(sd_req3), .sdram_ack3(sd_ack3), .sdram_dout3(sd_dout3)
);

ssbus_if ssb[12]();
genvar gs;
generate for (gs = 0; gs < 12; gs = gs + 1) begin : g_ss_idle
	assign ssb[gs].data   = 64'd0;
	assign ssb[gs].addr   = 32'd0;
	assign ssb[gs].select = 8'hFE;
	assign ssb[gs].write  = 1'b0;
	assign ssb[gs].read   = 1'b0;
	assign ssb[gs].query  = 1'b0;
end endgenerate

wire [9:0]  render_x;
wire [8:0]  render_y;
reg  [10:0] pal_b_addr;
wire [15:0] pal_word_raw;

wire [10:0] text_vram_addr;
wire [15:0] text_vram_data;

wire [511:0] scroll_words_flat;
wire [7:0] sr_b09 = scroll_words_flat[ 9*16 +: 8];
wire [7:0] sr_b0A = scroll_words_flat[10*16 +: 8];
wire [7:0] sr_b01 = scroll_words_flat[ 1*16 +: 8];
wire [7:0] sr_b02 = scroll_words_flat[ 2*16 +: 8];
wire [7:0] sr_b19 = scroll_words_flat[25*16 +: 8];
wire [7:0] sr_b1A = scroll_words_flat[26*16 +: 8];
wire [7:0] sr_b11 = scroll_words_flat[17*16 +: 8];
wire [7:0] sr_b12 = scroll_words_flat[18*16 +: 8];
wire [15:0] bg_scroll_x = {4'd0, sr_b09[7:4], sr_b0A[6:0], sr_b0A[7]};
wire [15:0] bg_scroll_y = {4'd0, sr_b01[7:4], sr_b02[6:0], sr_b02[7]};
wire [15:0] fg_scroll_x = {4'd0, sr_b19[7:4], sr_b1A[6:0], sr_b1A[7]};
wire [15:0] fg_scroll_y = {4'd0, sr_b11[7:4], sr_b12[6:0], sr_b12[7]};
wire        ctrl_bg_en, ctrl_fg_en, ctrl_tx_en, ctrl_sp_en, ctrl_flipscreen;

wire [11:1] main_shared_addr, sub_shared_addr;
wire        main_shared_cs,   sub_shared_cs;
wire  [1:0] main_shared_we,   sub_shared_we;
wire [15:0] main_shared_wdata, sub_shared_wdata;
wire [15:0] main_shared_rdata, sub_shared_rdata;

raiden_shared_ram #(.SS_IDX(-1)) u_shared (
	.clk       (clk_sys),
	.reset     (reset),
	.main_addr (main_shared_addr),
	.main_cs   (main_shared_cs),
	.main_din  (main_shared_wdata),
	.main_dout (main_shared_rdata),
	.main_we   (main_shared_we),
	.sub_addr  (sub_shared_addr),
	.sub_cs    (sub_shared_cs),
	.sub_din   (sub_shared_wdata),
	.sub_dout  (sub_shared_rdata),
	.sub_we    (sub_shared_we),
	.ss_shared (ssb[3])
);

wire        snd_cs;
wire  [3:1] snd_addr;
wire        snd_wr, snd_rd;
wire [15:0] snd_wdata, snd_rdata;

wire [3:0] pal_r4 = pal_word_raw[ 3:0];
wire [3:0] pal_g4 = pal_word_raw[ 7:4];
wire [3:0] pal_b4 = pal_word_raw[11:8];
wire [7:0] pal_b_r = {pal_r4, pal_r4};
wire [7:0] pal_b_g = {pal_g4, pal_g4};
wire [7:0] pal_b_b = {pal_b4, pal_b4};

function automatic [3:0] vol_code(input [2:0] o);
	case (o)
		3'd0: vol_code = 4'd0;  3'd1: vol_code = 4'd1;
		3'd2: vol_code = 4'd3;  3'd3: vol_code = 4'd4;
		3'd4: vol_code = 4'd6;  3'd5: vol_code = 4'd7;
		3'd6: vol_code = 4'd8;  default: vol_code = 4'd10;
	endcase
endfunction

wire signed [15:0] game_audio_l, game_audio_r;
Raiden_audio_z80 #(.SS_IDX_ZRAM(-1)) u_audio (
	.clk           (clk_sys),
	.reset         (reset),
	.pause         (paused_safe),
	.clk_sel       (2'd0),
	.fm_vol_sel    (vol_code(status[10:8])),
	.oki_vol_sel   (vol_code(status[13:11])),
	.ioctl_download(ld_active),
	.ioctl_wr      (wide_wr),
	.ioctl_addr    (wide_addr),
	.ioctl_dout    (wide_dout),
	.snd_cs        (snd_cs),
	.snd_addr      (snd_addr),
	.snd_wr        (snd_wr),
	.snd_rd        (snd_rd),
	.snd_wdata     (snd_wdata),
	.snd_rdata     (snd_rdata),
	.snd_nmi_n     (1'b1),
	.snd_reset_in  (1'b0),
	.coin_input    (coin_input),
	.oki_rom_addr  (oki_rom_addr),
	.oki_rom_data  (oki_rom_data),
	.oki_rom_ok    (oki_rom_ok),
	.audio_l       (game_audio_l),
	.audio_r       (game_audio_r),
	.ss_zram       (ssb[10])
);

wire main_cpu_idle, sub_cpu_idle;
wire main_cpu_pause = paused_safe & main_cpu_idle;
wire sub_cpu_pause  = paused_safe & sub_cpu_idle;

wire [10:0] spr_vram_addr;
wire [15:0] spr_vram_data;

Raiden_main_top #(.SS_IDX_SPR(-1), .SS_IDX_CPU(-1)) u_main (
	.clk              (clk_sys),
	.reset            (reset),
	.pause            (main_cpu_pause),
	.cpu_idle         (main_cpu_idle),
	.clk_sel          (3'd0),
	.p1_input         (p1_input),
	.p2_input         (p2_input),
	.dsw_input        (dip_sw),
	.main_rom_rdata   (game_main_data),
	.main_rom_ready   (game_main_ready),
	.main_rom_addr    (game_main_addr),
	.main_rom_req     (game_main_req),
	.vblank_in        (VBlank),
	.ioctl_download   (ld_active),
	.ctrl_bg_en       (ctrl_bg_en),
	.ctrl_fg_en       (ctrl_fg_en),
	.ctrl_tx_en       (ctrl_tx_en),
	.ctrl_sp_en       (ctrl_sp_en),
	.ctrl_flipscreen  (ctrl_flipscreen),
	.scroll_words_flat(scroll_words_flat),
	.snd_cs           (snd_cs),
	.snd_addr         (snd_addr),
	.snd_wr           (snd_wr),
	.snd_rd           (snd_rd),
	.snd_wdata        (snd_wdata),
	.snd_rdata        (snd_rdata),
	.text_vram_addr   (text_vram_addr),
	.text_vram_data   (text_vram_data),
	.spr_vram_addr    (spr_vram_addr),
	.spr_vram_data    (spr_vram_data),
	.main_shared_addr (main_shared_addr),
	.main_shared_cs   (main_shared_cs),
	.main_shared_we   (main_shared_we),
	.main_shared_wdata(main_shared_wdata),
	.main_shared_rdata(main_shared_rdata),
	.dbg_irq_pending  (),
	.ss_workram       (ssb[0]),
	.ss_txt           (ssb[1]),
	.ss_scroll        (ssb[2]),
	.ss_spr           (ssb[7]),
	.ss_cpu           (ssb[8]),
	.ss_cpu_reload    (1'b0)
);

wire [10:0] bg_vram_addr, fg_vram_addr;
wire [15:0] bg_vram_data, fg_vram_data;

Raiden_sub_top #(.SS_IDX_BG(-1), .SS_IDX_FG(-1), .SS_IDX_PAL(-1),
                 .SS_IDX_CPU(-1), .SS_IDX_SUBRAM(-1)) u_sub (
	.clk              (clk_sys),
	.reset            (reset),
	.pause            (sub_cpu_pause),
	.cpu_idle         (sub_cpu_idle),
	.clk_sel          (3'd0),
	.sub_rom_rdata    (game_sub_data),
	.sub_rom_ready    (game_sub_ready),
	.sub_rom_addr     (game_sub_addr),
	.sub_rom_req      (game_sub_req),
	.vblank_in        (VBlank),
	.sub_shared_addr  (sub_shared_addr),
	.sub_shared_cs    (sub_shared_cs),
	.sub_shared_we    (sub_shared_we),
	.sub_shared_wdata (sub_shared_wdata),
	.sub_shared_rdata (sub_shared_rdata),
	.bg_vram_addr     (bg_vram_addr),
	.bg_vram_data     (bg_vram_data),
	.fg_vram_addr     (fg_vram_addr),
	.fg_vram_data     (fg_vram_data),
	.pal_vram_addr    (pal_b_addr),
	.pal_vram_data    (pal_word_raw),
	.dbg_irq_pending  (),
	.dbg_cpu_addr     (),
	.dbg_cpu_dout     (),
	.dbg_cpu_be       (),
	.dbg_cpu_wr       (),
	.dbg_palette_memrq(),
	.ss_bg            (ssb[4]),
	.ss_fg            (ssb[5]),
	.ss_pal           (ssb[6]),
	.ss_cpu           (ssb[9]),
	.ss_cpu_reload    (1'b0),
	.ss_subram        (ssb[11])
);

wire        ce_pix;
wire [9:0]  timing_hpos;
wire [9:0]  timing_vpos;

Raiden_video_timing u_video_timing (
	.clk       (clk_sys),
	.reset     (video_reset),
	.mode_60hz (status[1]),
	.ce_pix    (ce_pix),
	.hpos      (timing_hpos),
	.vpos      (timing_vpos),
	.active_x  (render_x),
	.active_y  (render_y),
	.hblank    (HBlank),
	.vblank    (VBlank),
	.hsync     (HSync),
	.vsync     (VSync),
	.de        (video_de)
);

wire        flip_screen = ctrl_flipscreen;
localparam [9:0] H_VIS_START_TOP = 10'd48;
localparam [8:0] V_VIS_START_TOP = 9'd30;
wire [9:0]  hpos_logic    = timing_hpos - H_VIS_START_TOP;
wire [8:0]  vpos_logic    = timing_vpos[8:0] - V_VIS_START_TOP;
wire [8:0]  vpos_for_pf   = flip_screen ? (9'd222 - vpos_logic) : vpos_logic;
wire [9:0]  hpos_for_read = flip_screen ? (10'd255 - hpos_logic) : hpos_logic;

localparam signed [9:0] BG_XOFF  =  10'sd0, BG_YOFF  = 10'sd16;
localparam signed [9:0] FG_XOFF  =  10'sd0, FG_YOFF  = 10'sd16;
localparam signed [9:0] SPR_XOFF =  10'sd0, SPR_YOFF = -10'sd16;
localparam signed [9:0] TXT_XOFF = -10'sd1, TXT_YOFF = 10'sd0;

wire        text_opaque;
wire [10:0] text_pen;
wire        text_rom_dl_wr = wide_wr && (wide_addr >= 27'h0B0000) && (wide_addr < 27'h0C0000);

Raiden_text_renderer u_text (
	.clk         (clk_sys),
	.reset       (reset),
	.ce_pix      (ce_pix),
	.decode_mode (7'b0010000),
	.hpos        (hpos_logic),
	.vpos        (vpos_logic),
	.flip_screen (flip_screen),
	.de          (video_de),
	.layer_en    (ctrl_tx_en),
	.scroll_x    (16'd0),
	.scroll_y    (16'd16),
	.xoff        (TXT_XOFF),
	.yoff        (TXT_YOFF),
	.vram_addr   (text_vram_addr),
	.vram_data   (text_vram_data),
	.rom_dl_wr   (text_rom_dl_wr),
	.rom_dl_addr ({1'b0, wide_addr[15:0]}),
	.rom_dl_data (wide_dout),
	.opaque      (text_opaque),
	.pen_index   (text_pen)
);

wire        bg_opaque, fg_opaque;
wire [10:0] bg_pen, fg_pen;

reg [9:0] hpos_prev;
always @(posedge clk_sys) if (ce_pix) hpos_prev <= timing_hpos;
wire layer_new_line = ce_pix && (timing_hpos == 10'd0) && (hpos_prev != 10'd0);

wire        arb_bg_req,  arb_fg_req;
wire [23:0] arb_bg_addr, arb_fg_addr;
wire [31:0] arb_bg_data, arb_fg_data;
wire        arb_bg_valid, arb_fg_valid;

reg [4:0] bgfg_decode_mode_r;
reg [4:0] spr_decode_mode_r;
always @(posedge clk_sys) begin
	bgfg_decode_mode_r <= 5'b10001;
	spr_decode_mode_r  <= 5'b11110;
end

Raiden_tile_layer #(.COLOR_BASE(11'h000), .HAS_TRANSP(0), .HAS_GFX_BANK(0), .TILE_KIND(3'd0)) u_bg (
	.clk(clk_sys), .reset(reset), .ce_pix(ce_pix),
	.decode_mode(bgfg_decode_mode_r),
	.hpos(hpos_for_read), .vpos(vpos_for_pf),
	.de(video_de), .layer_en(ctrl_bg_en),
	.new_line(layer_new_line),
	.scroll_x(bg_scroll_x), .scroll_y(bg_scroll_y),
	.xoff(BG_XOFF), .yoff(BG_YOFF),
	.gfx_bank(16'd0),
	.vram_addr(bg_vram_addr), .vram_data(bg_vram_data),
	.rom_req(arb_bg_req), .rom_addr(arb_bg_addr),
	.rom_data(arb_bg_data), .rom_valid(arb_bg_valid),
	.opaque(bg_opaque), .pen_index(bg_pen)
);

Raiden_tile_layer #(.COLOR_BASE(11'h100), .HAS_TRANSP(1), .HAS_GFX_BANK(0), .TILE_KIND(3'd2)) u_fg (
	.clk(clk_sys), .reset(reset), .ce_pix(ce_pix),
	.decode_mode(bgfg_decode_mode_r),
	.hpos(hpos_for_read), .vpos(vpos_for_pf),
	.de(video_de), .layer_en(ctrl_fg_en),
	.new_line(layer_new_line),
	.scroll_x(fg_scroll_x), .scroll_y(fg_scroll_y),
	.xoff(FG_XOFF), .yoff(FG_YOFF),
	.gfx_bank(16'd0),
	.vram_addr(fg_vram_addr), .vram_data(fg_vram_data),
	.rom_req(arb_fg_req), .rom_addr(arb_fg_addr),
	.rom_data(arb_fg_data), .rom_valid(arb_fg_valid),
	.opaque(fg_opaque), .pen_index(fg_pen)
);

tile_rom_arbiter u_arb (
	.clk(clk_sys), .reset(reset), .hblank(HBlank),
	.r0_req(arb_bg_req), .r0_addr(arb_bg_addr), .r0_data(arb_bg_data), .r0_valid(arb_bg_valid),
	.r1_req(1'b0), .r1_addr(24'd0), .r1_data(), .r1_valid(),
	.r2_req(arb_fg_req), .r2_addr(arb_fg_addr), .r2_data(arb_fg_data), .r2_valid(arb_fg_valid),
	.r3_req(1'b0), .r3_addr(24'd0), .r3_data(), .r3_valid(),
	.r4_req(1'b0), .r4_addr(24'd0), .r4_data(), .r4_valid(),
	.tile_req(game_tile_req), .tile_addr(game_tile_addr), .tile_kind(game_tile_kind),
	.tile_data(game_tile_data), .tile_valid(game_tile_valid)
);

ddr_if ddr_spr();

wire [27:0] ddr_rdaddr;
wire [31:0] ddr_rdata;
wire        ddr_rd_req, ddr_rd_ack;

raiden_sprite_ddr_client u_ddram (
	.clk     (clk_sys),
	.wraddr  (spr_dl_addr),
	.din     (spr_dl_data),
	.we_byte (1'b0),
	.we_req  (spr_dl_req),
	.we_ack  (spr_dl_ack),
	.rdaddr  (ddr_rdaddr),
	.dout    (ddr_rdata),
	.rd_req  (ddr_rd_req),
	.rd_ack  (ddr_rd_ack),
	.ddr     (ddr_spr)
);

raiden_sdram2_ddrhost #(.DEVICE_FAMILY("Cyclone 10 LP")) u_sdram2 (
	.clk        (clk_sys),
	.init       (~pll_locked),
	.ddr        (ddr_spr),
	.SDRAM_DQ   (SDRAM2_DQ),
	.SDRAM_A    (SDRAM2_A),
	.SDRAM_DQML (SDRAM2_DQML),
	.SDRAM_DQMH (SDRAM2_DQMH),
	.SDRAM_BA   (SDRAM2_BA),
	.SDRAM_nCS  (SDRAM2_nCS),
	.SDRAM_nWE  (SDRAM2_nWE),
	.SDRAM_nRAS (SDRAM2_nRAS),
	.SDRAM_nCAS (SDRAM2_nCAS),
	.SDRAM_CLK  (SDRAM2_CLK),
	.SDRAM_CKE  (SDRAM2_CKE)
);

wire        spr_opaque;
wire [10:0] spr_pen;
wire  [1:0] spr_pri;

wire        spr_renderer_rom_req;
wire [23:0] spr_renderer_rom_addr;
reg         spr_renderer_rom_req_prev;
wire [31:0] spr_cache_data;
wire        spr_cache_valid;
always @(posedge clk_sys) spr_renderer_rom_req_prev <= spr_renderer_rom_req;

raiden_sprite_rom_cache #(.DDR_BASE_ADDR(28'h0000000)) u_spr_cache (
	.clk       (clk_sys),
	.reset     (reset),
	.req_addr  (spr_renderer_rom_addr),
	.req_pulse (spr_renderer_rom_req & ~spr_renderer_rom_req_prev),
	.resp_data (spr_cache_data),
	.resp_valid(spr_cache_valid),
	.ddr_addr  (ddr_rdaddr),
	.ddr_req   (ddr_rd_req),
	.ddr_data  (ddr_rdata),
	.ddr_ack   (ddr_rd_ack)
);

Raiden_sprite_renderer u_spr (
	.clk(clk_sys), .reset(reset), .ce_pix(ce_pix),
	.hpos(hpos_logic), .vpos(vpos_logic),
	.de(video_de), .layer_en(ctrl_sp_en),
	.new_line(layer_new_line),
	.flip_screen(flip_screen),
	.xoff(SPR_XOFF), .yoff(SPR_YOFF),
	.decode_mode(spr_decode_mode_r),
	.spr_addr(spr_vram_addr), .spr_data(spr_vram_data),
	.rom_req(spr_renderer_rom_req), .rom_addr(spr_renderer_rom_addr),
	.rom_data(spr_cache_data), .rom_valid(spr_cache_valid),
	.opaque(spr_opaque), .pen_index(spr_pen), .pri_code(spr_pri)
);

wire [10:0] backdrop_pen = 11'h000;
wire spr_above_fg = spr_opaque & (spr_pri >= 2'd2);
wire spr_above_bg = spr_opaque & (spr_pri == 2'd1);

wire [10:0] bg_pen_eff   = {bg_pen[10],   2'd0, bg_pen[7:0]};
wire [10:0] fg_pen_eff   = {fg_pen[10],   2'd1, fg_pen[7:0]};
wire [10:0] spr_pen_eff  = {spr_pen[10],  2'd2, spr_pen[7:0]};
wire [10:0] text_pen_eff = {text_pen[10], 2'd3, text_pen[7:0]};

wire [10:0] composite_pen =
	text_opaque  ? text_pen_eff :
	spr_above_fg ? spr_pen_eff  :
	fg_opaque    ? fg_pen_eff   :
	spr_above_bg ? spr_pen_eff  :
	bg_opaque    ? bg_pen_eff   :
	               backdrop_pen;
wire is_backdrop = !text_opaque & !spr_above_fg & !fg_opaque & !spr_above_bg & !bg_opaque;

reg video_de_d, is_backdrop_d;
always @(posedge clk_sys) begin
	pal_b_addr    <= ~video_de ? backdrop_pen : composite_pen;
	video_de_d    <= video_de;
	is_backdrop_d <= is_backdrop;
end

wire [7:0] video_r = (video_de_d & ~is_backdrop_d) ? pal_b_r : 8'h00;
wire [7:0] video_g = (video_de_d & ~is_backdrop_d) ? pal_b_g : 8'h00;
wire [7:0] video_b = (video_de_d & ~is_backdrop_d) ? pal_b_b : 8'h00;

wire [1:0] rotate_screen = status[15:14];
wire [7:0] hd_r, hd_g, hd_b;

wire VSync_sel = VSync;
reg [7:0] hs_dly = 8'd0, vs_dly = 8'd0;
always @(posedge clk_sys) begin
	hs_dly <= {hs_dly[6:0], HSync};
	vs_dly <= {vs_dly[6:0], VSync_sel};
end
wire HSync_v = hs_dly[7];
wire VSync_v = vs_dly[7];
wire       hd_hs, hd_vs, hd_de;

raiden_dual_video #(.COLOR_DEPTH(8), .OUT_COLOR_DEPTH(8), .SD_HCNT_WIDTH(10),
                    .USE_BLANKS(1'b1), .VIDEO_CLEANER(1'b1)) u_video (
	.clk_sys             (clk_sys),
	.SPI_SCK             (SPI_SCK),
	.SPI_SS3             (SPI_SS3),
	.SPI_DI              (SPI_DI),
	.scanlines           (status[3:2]),
	.ce_divider          (4'd15),
	.scandoubler_disable (scandoubler_disable),
	.rotateonly          (scandoubler_disable & (rotate_screen != 2'd0)),
	.no_csync            (no_csync),
	.ypbpr               (ypbpr),
	.rotate              (2'b00),
	.rotate_screen       (rotate_screen),
	.rotate_hfilter      (status[7]),
	.rotate_vfilter      (status[7]),
	.blend               (status[4]),
	.R                   (video_r),
	.G                   (video_g),
	.B                   (video_b),
	.HBlank              (HBlank),
	.VBlank              (VBlank),
	.HSync               (~HSync_v),
	.VSync               (~VSync_v),
	.VGA_R               (VGA_R),
	.VGA_G               (VGA_G),
	.VGA_B               (VGA_B),
	.VGA_VS              (VGA_VS),
	.VGA_HS              (VGA_HS),
	.VGA_HB              (),
	.VGA_VB              (),
	.VGA_DE              (),
	.HDMI_R              (hd_r),
	.HDMI_G              (hd_g),
	.HDMI_B              (hd_b),
	.HDMI_VS             (hd_vs),
	.HDMI_HS             (hd_hs),
	.HDMI_DE             (hd_de)
);

reg       hdmi_ph = 1'b0;
reg [7:0] hdmi_r_o, hdmi_g_o, hdmi_b_o;
reg       hdmi_hs_o, hdmi_vs_o, hdmi_de_o, hdmi_pclk_o;
always @(posedge clk_sys) begin
	hdmi_ph     <= ~hdmi_ph;
	hdmi_pclk_o <= ~hdmi_ph;
	if (hdmi_ph) begin
		hdmi_r_o  <= hd_r;
		hdmi_g_o  <= hd_g;
		hdmi_b_o  <= hd_b;
		hdmi_hs_o <= hd_hs;
		hdmi_vs_o <= hd_vs;
		hdmi_de_o <= hd_de;
	end
end
assign HDMI_R    = hdmi_r_o;
assign HDMI_G    = hdmi_g_o;
assign HDMI_B    = hdmi_b_o;
assign HDMI_HS   = hdmi_hs_o;
assign HDMI_VS   = hdmi_vs_o;
assign HDMI_DE   = hdmi_de_o;
assign HDMI_PCLK = hdmi_pclk_o;

dac #(.C_bits(16)) dac_l (
	.clk_i   (clk_sys),
	.res_n_i (1'b1),
	.dac_i   ({~game_audio_l[15], game_audio_l[14:0]}),
	.dac_o   (AUDIO_L)
);
dac #(.C_bits(16)) dac_r (
	.clk_i   (clk_sys),
	.res_n_i (1'b1),
	.dac_i   ({~game_audio_r[15], game_audio_r[14:0]}),
	.dac_o   (AUDIO_R)
);

i2s i2s (
	.reset      (1'b0),
	.clk        (clk_sys),
	.clk_rate   (32'd80_000_000),
	.sclk       (I2S_BCK),
	.lrclk      (I2S_LRCK),
	.sdata      (I2S_DATA),
	.left_chan  (game_audio_l),
	.right_chan (game_audio_r)
);

assign HDMI_MCLK  = 1'b0;
assign HDMI_BCK   = I2S_BCK;
assign HDMI_LRCK  = I2S_LRCK;
assign HDMI_SDATA = I2S_DATA;

endmodule
