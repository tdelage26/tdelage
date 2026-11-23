module system (
	input  clk_25, input  clk_vga50, input  clk_sdr, input  clk_dsp, input  clk_cpu,
	input  adlibhide,
	output [3:0]sdr_n_CS_WE_RAS_CAS, output [1:0]sdr_BA, output [12:0]sdr_ADDR,
	inout [15:0]sdr_DATA, output [1:0]sdr_DQM,
	output reg [5:0]VGA_R, output reg [5:0]VGA_G, output reg [5:0]VGA_B,
	output wire VGA_HSYNC, output wire VGA_VSYNC,
	output reg VGA_BLANK, output wire VGA_VBLANK,
	input BTN_RESET, output [7:0]LED,
	input MPU_RX, output MPU_TX,
	output reg SD_n_CS, output wire SD_DI, output reg SD_CK, input SD_DO,
	input [15:0] CDDA_L, input [15:0] CDDA_R,
	output AUD_L, output AUD_R, output [15:0] LAUDIO, output [15:0] RAUDIO,
	input PS2_CLK1_I, output PS2_CLK1_O, input PS2_CLK2_I, output PS2_CLK2_O,
	input PS2_DATA1_I, output PS2_DATA1_O, input PS2_DATA2_I, output PS2_DATA2_O,
	input  [7:0] JOY1, input [7:0] JOY2, input [15:0] JOY1_A, input [15:0] JOY2_A, input [2:0] JOY_MODE,
	output [15:0] IDE_DAT_O, input [15:0] IDE_DAT_I, output [3:0] IDE_A,
	output IDE_WE, output [1:0] IDE_CS, input [1:0] IDE_INT,
	input hd1_mounted, input [31:0] hd1_sectors, input hd1_grant, output hd1_busy,
	output hd1_rd, output hd1_wr, output [31:0] hd1_lba, input hd1_ack,
	input [8:0] hd1_buff_addr, input [7:0] hd1_buff_dout, input hd1_buff_wr, output [7:0] hd1_buff_din,
	input fd_mounted, input [31:0] fd_sectors, input fd_mount_evt, input fd_grant, output fd_busy,
	output fd_rd, output fd_wr, output [31:0] fd_lba, input fd_ack,
	input [8:0] fd_buff_addr, input [7:0] fd_buff_dout, input fd_buff_wr, output [7:0] fd_buff_din,
	output [12:0] SDRAM2_A, inout [15:0] SDRAM2_DQ, output SDRAM2_DQML, output SDRAM2_DQMH,
	output SDRAM2_nWE, output SDRAM2_nCAS, output SDRAM2_nRAS, output SDRAM2_nCS,
	output [1:0] SDRAM2_BA, output SDRAM2_CLK, output SDRAM2_CKE
);
`ifdef AO486_CPU40
	localparam integer SYS_HZ = 40_000_000;
`elsif AO486_CPU33
	localparam integer SYS_HZ = 33_333_333;
`else
	localparam integer SYS_HZ = 25_000_000;
`endif
	wire clk_sys=clk_cpu, clk_sdram_x2=clk_sdr;
	reg [7:0] rstc=8'hFF;
	always @(posedge clk_sys) if(BTN_RESET) rstc<=8'hFF; else if(|rstc) rstc<=rstc-1'b1;
	wire reset=|rstc;

	wire sdram_nwe,sdram_nras,sdram_ncas,sdram_ncs,sdram_cke; wire [1:0] sdram_ba,sdram_dqm; wire [12:0] sdram_a;
	assign sdr_n_CS_WE_RAS_CAS={sdram_ncs,sdram_nwe,sdram_nras,sdram_ncas};
	assign sdr_BA=sdram_ba; assign sdr_ADDR=sdram_a; assign sdr_DQM=sdram_dqm;

	wire sd_cs,sd_sck,sd_mosi;
	always @(posedge clk_sys) begin SD_n_CS<=sd_cs; SD_CK<=sd_sck; end
	assign SD_DI=sd_mosi;

	wire [7:0] kbd_data,mouse_data; wire kbd_dv,mouse_dv;
	wire [8:0] kbd_host,mouse_host; wire kbd_clr,mouse_clr;
	ps2_io #(.CLK_HZ(SYS_HZ)) ps2(.clk(clk_sys), .reset(reset),
		.kb_clk_i(PS2_CLK1_I), .kb_clk_o(PS2_CLK1_O), .kb_dat_i(PS2_DATA1_I), .kb_dat_o(PS2_DATA1_O),
		.ms_clk_i(PS2_CLK2_I), .ms_clk_o(PS2_CLK2_O), .ms_dat_i(PS2_DATA2_I), .ms_dat_o(PS2_DATA2_O),
		.kbd_data(kbd_data), .kbd_data_valid(kbd_dv),
		.kbd_host_data(kbd_host), .kbd_host_data_clear(kbd_clr),
		.mouse_data(mouse_data), .mouse_data_valid(mouse_dv),
		.mouse_host_cmd(mouse_host), .mouse_host_cmd_clear(mouse_clr));

	wire cd_cs, cd_we; wire [3:0] cd_a; wire [15:0] cd_dout;

	wire video_ce,video_blank_n,video_hsync,video_vsync; wire [7:0] video_r,video_g,video_b;

	wire [15:0] sb_l,sb_r,opl_l,opl_r,gus_l,gus_r; wire spk;
	wire sbp; wire [4:0] vol_master_l,vol_master_r,vol_voice_l,vol_voice_r,vol_midi_l,vol_midi_r,vol_cd_l,vol_cd_r;
	wire [4:0] vol_en; wire [1:0] vol_spk;
	wire [15:0] gus_la,gus_ra,cd_la,cd_ra;
	cdc_vector_handshake_continuous #(.DATA_WIDTH(64)) aud_in_cdc(.clk_in(clk_sys), .clk_out(clk_dsp),
		.data_in({gus_l,gus_r,CDDA_L,CDDA_R}), .data_out({gus_la,gus_ra,cd_la,cd_ra}));
	reg [1:0] spk_a = 2'b00;
	always @(posedge clk_dsp) spk_a <= {spk_a[0], spk};
	wire [16:0] spk_lvl = spk_a[1] ? (17'd8192 >> ~vol_spk) : 17'd0;

	wire [15:0] mix_pre_l, mix_pre_r;
	wire [15:0] master_l,master_r,sbv_l,sbv_r,oplv_l,oplv_r,cdv_l,cdv_r; wire vol_valid;
	sb_volume #(.NUM_CH(8), .SAMPLE_WIDTH(16)) sb_vol(
		.clk(clk_dsp), .sbp(sbp),
		.volumes_in({vol_master_l,vol_master_r, vol_voice_l,vol_voice_r, vol_midi_l,vol_midi_r, vol_cd_l,vol_cd_r}),
		.samples_in({mix_pre_l,mix_pre_r, sb_l,sb_r, opl_l,opl_r, cd_la,cd_ra}),
		.samples_out({master_l,master_r, sbv_l,sbv_r, oplv_l,oplv_r, cdv_l,cdv_r}),
		.valid(vol_valid));
	reg [16:0] mix_tmp_l = 0, mix_tmp_r = 0;
	reg [15:0] mix_dry_l = 0, mix_dry_r = 0, aud_l = 0, aud_r = 0;
	always @(posedge clk_dsp) begin
		if (vol_valid) begin
			aud_l <= master_l; aud_r <= master_r;
			mix_tmp_l <= spk_lvl + {sbv_l[15],sbv_l} + {oplv_l[15],oplv_l} + (vol_en[2] ? {cdv_l[15],cdv_l} : 17'd0) + {gus_la[15],gus_la};
			mix_tmp_r <= spk_lvl + {sbv_r[15],sbv_r} + {oplv_r[15],oplv_r} + (vol_en[1] ? {cdv_r[15],cdv_r} : 17'd0) + {gus_ra[15],gus_ra};
		end
		mix_dry_l <= (^mix_tmp_l[16:15]) ? {mix_tmp_l[16], {15{mix_tmp_l[15]}}} : mix_tmp_l[15:0];
		mix_dry_r <= (^mix_tmp_r[16:15]) ? {mix_tmp_r[16], {15{mix_tmp_r[15]}}} : mix_tmp_r[15:0];
	end
	assign mix_pre_l = mix_dry_l; assign mix_pre_r = mix_dry_r;
	cdc_vector_handshake_continuous #(.DATA_WIDTH(32)) aud_out_cdc(.clk_in(clk_dsp), .clk_out(clk_sys),
		.data_in({aud_l,aud_r}), .data_out({LAUDIO,RAUDIO}));
	reg [15:0] al_s, ar_s;
	always @(posedge clk_sdram_x2) begin
		al_s <= LAUDIO; ar_s <= RAUDIO;
	end
	wire [15:0] al_u = {~al_s[15], al_s[14:0]};
	wire [15:0] ar_u = {~ar_s[15], ar_s[14:0]};
	reg [16:0] sd_l = 0, sd_r = 0;
	always @(posedge clk_sdram_x2) begin
		sd_l <= {1'b0, sd_l[15:0]} + {1'b0, al_u};
		sd_r <= {1'b0, sd_r[15:0]} + {1'b0, ar_u};
	end
	assign AUD_L = sd_l[16]; assign AUD_R = sd_r[16];

	wire [2:0] boot_stage; wire sd_err,bios_loaded,vga_sig_bad,first_instr;

	ao486_core #(.SYS_FREQ(SYS_HZ)) core(
		.clk_sys(clk_sys), .reset(reset), .clock_rate(SYS_HZ), .clk_sdram_x2(clk_sdram_x2),
		.fdd_request(), .ide0_request(), .ide1_request(), .floppy_wp(2'b00),
		.sdram_dq(sdr_DATA), .sdram_a(sdram_a), .sdram_ba(sdram_ba), .sdram_dqm(sdram_dqm),
		.sdram_nwe(sdram_nwe), .sdram_nras(sdram_nras), .sdram_ncas(sdram_ncas),
		.sdram_ncs(sdram_ncs), .sdram_cke(sdram_cke), .refresh_allowed(1'b1),
		.spi_cs_n(sd_cs), .spi_sck(sd_sck), .spi_mosi(sd_mosi), .spi_miso(SD_DO),
		.kbd_data(kbd_data), .kbd_data_valid(kbd_dv),
		.kbd_host_data(kbd_host), .kbd_host_data_clear(kbd_clr),
		.mouse_data(mouse_data), .mouse_data_valid(mouse_dv),
		.mouse_host_cmd(mouse_host), .mouse_host_cmd_clear(mouse_clr),
		.dbg_uart_byte(), .dbg_uart_we(),
		.bootcfg(6'd0), .uma_ram(1'b0), .syscfg(),
		.clk_vga(clk_vga50), .clock_rate_vga(28'd50_000_000),
		.video_ce(video_ce), .video_blank_n(video_blank_n),
		.video_hsync(video_hsync), .video_vsync(video_vsync),
		.video_r(video_r), .video_g(video_g), .video_b(video_b), .video_f60(1'b0),
		.video_pal_a(), .video_pal_d(), .video_pal_we(),
		.video_start_addr(), .video_width(), .video_height(), .video_flags(),
		.video_stride(), .video_off(),
		.video_fb_en(1'b0), .video_lores(1'b0), .video_border(1'b0),
		.clk_audio(clk_dsp),
		.sample_sb_l(sb_l), .sample_sb_r(sb_r), .sample_opl_l(opl_l), .sample_opl_r(opl_r),
		.sound_fm_mode(1'b1), .sound_cms_en(1'b0), .speaker_out(spk),
		.sbp(sbp), .vol_master_l(vol_master_l), .vol_master_r(vol_master_r),
		.vol_voice_l(vol_voice_l), .vol_voice_r(vol_voice_r), .vol_cd_l(vol_cd_l), .vol_cd_r(vol_cd_r),
		.vol_midi_l(vol_midi_l), .vol_midi_r(vol_midi_r),
		.vol_line_l(), .vol_line_r(), .vol_spk(vol_spk), .vol_en(vol_en),
		.debug_boot_stage(boot_stage), .debug_sd_error(sd_err),
		.debug_bios_loaded(bios_loaded), .debug_vga_bios_sig_bad(vga_sig_bad),
		.debug_vga_bios_sig_checked(), .debug_first_instruction(first_instr),
		.dbg(),
		.hd1_mounted(hd1_mounted), .hd1_sectors(hd1_sectors), .hd1_grant(hd1_grant), .hd1_busy(hd1_busy),
		.hd1_rd(hd1_rd), .hd1_wr(hd1_wr), .hd1_lba(hd1_lba), .hd1_ack(hd1_ack),
		.hd1_buff_addr(hd1_buff_addr), .hd1_buff_dout(hd1_buff_dout), .hd1_buff_wr(hd1_buff_wr),
		.hd1_buff_din(hd1_buff_din),
		.fd_mounted(fd_mounted), .fd_sectors(fd_sectors), .fd_mount_evt(fd_mount_evt), .fd_grant(fd_grant), .fd_busy(fd_busy),
		.fd_rd(fd_rd), .fd_wr(fd_wr), .fd_lba(fd_lba), .fd_ack(fd_ack),
		.fd_buff_addr(fd_buff_addr), .fd_buff_dout(fd_buff_dout), .fd_buff_wr(fd_buff_wr), .fd_buff_din(fd_buff_din),
		.cd_cs(cd_cs), .cd_we(cd_we), .cd_a(cd_a), .cd_dout(cd_dout), .cd_din(IDE_DAT_I), .cd_irq(IDE_INT[1]), .midi_tx(MPU_TX), .midi_rx(MPU_RX),
		.joy_dig_1({6'd0, JOY1}), .joy_dig_2({6'd0, JOY2}),
		.joy_ana_1({JOY1_A[7:0], JOY1_A[15:8]}), .joy_ana_2({JOY2_A[7:0], JOY2_A[15:8]}),
		.joy_mode(JOY_MODE),
		.gus_off(adlibhide),
		.sample_gus_l(gus_l), .sample_gus_r(gus_r),
		.sdram2_dq(SDRAM2_DQ), .sdram2_a(SDRAM2_A), .sdram2_dqm({SDRAM2_DQMH, SDRAM2_DQML}), .sdram2_ba(SDRAM2_BA),
		.sdram2_ncs(SDRAM2_nCS), .sdram2_nwe(SDRAM2_nWE), .sdram2_nras(SDRAM2_nRAS), .sdram2_ncas(SDRAM2_nCAS),
		.sdram2_clk(SDRAM2_CLK), .sdram2_cke(SDRAM2_CKE));

	reg [24:0] blink = 0;
	always @(posedge clk_sys) blink <= blink + 1'd1;
	wire led0 = (sd_err | vga_sig_bad) ? blink[21] : (boot_stage != 3'd5) ? blink[24] : first_instr;
	assign LED = {7'd0, led0};

	localparam integer PIX_DELAY = 40;
	reg [18:0] pdl [0:PIX_DELAY-1];
	integer pi;
	always @(posedge clk_25) begin
		pdl[0] <= {video_blank_n, video_r[7:2], video_g[7:2], video_b[7:2]};
		for (pi = 1; pi < PIX_DELAY; pi = pi + 1) pdl[pi] <= pdl[pi-1];
	end
	wire       pd_bn = pdl[PIX_DELAY-1][18];
	wire [5:0] pd_r  = pdl[PIX_DELAY-1][17:12];
	wire [5:0] pd_g  = pdl[PIX_DELAY-1][11:6];
	wire [5:0] pd_b  = pdl[PIX_DELAY-1][5:0];
	always @(posedge clk_25) begin
		VGA_BLANK <= ~pd_bn;
		VGA_R <= pd_bn ? pd_r : 6'd0;
		VGA_G <= pd_bn ? pd_g : 6'd0;
		VGA_B <= pd_bn ? pd_b : 6'd0;
	end

	assign VGA_HSYNC  = ~video_hsync;
	assign VGA_VSYNC  = ~video_vsync;
	vb_from_blank vb_split(.clk(clk_25), .blank(~pd_bn), .vb(VGA_VBLANK));

	assign IDE_DAT_O = cd_dout; assign IDE_A = cd_a; assign IDE_WE = cd_we; assign IDE_CS = {cd_cs, 1'b0};
endmodule
