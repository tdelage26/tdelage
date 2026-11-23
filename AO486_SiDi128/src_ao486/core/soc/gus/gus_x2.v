module gus_x2 #(parameter integer CLK_HZ = 50_000_000) (
	input         clk_sys,
	input         clk_gus,
	input         reset,

	input         io_address8,
	input   [3:0] io_address,
	input   [7:0] writedata,
	output  [7:0] readdata,
	input         gus_cs,
	input         fm_cs,
	input         write,
	input         read,
	output        io_wait,

	output        dma_req,
	input         dma_ack,
	input         dma_tc,
	input  [15:0] dma_readdata,
	output [15:0] dma_writedata,

	output        irq,
	output [15:0] audio_l,
	output [15:0] audio_r,

	inout  [15:0] SDRAM_DQ,
	output [12:0] SDRAM_A,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output  [1:0] SDRAM_BA,
	output        SDRAM_nCS,
	output        SDRAM_nWE,
	output        SDRAM_nRAS,
	output        SDRAM_nCAS,
	output        SDRAM_CLK,
	output        SDRAM_CKE
);
	reg tog_s = 1'b0, tog_f = 1'b0;
	always @(posedge clk_sys) tog_s <= ~tog_s;
	always @(posedge clk_gus) tog_f <= tog_s;
	wire first = tog_f ^ tog_s;

	gus #(.SDRAM_REFRESH(CLK_HZ / 128_205)) gus
	(
		.clk           (clk_gus),
		.reset         (reset),
		.clock_rate    (CLK_HZ),

		.io_address8   (io_address8),
		.io_address    (io_address),
		.writedata     (writedata),
		.read          (read & first),
		.write         (write & first),
		.readdata      (readdata),
		.gus_cs        (gus_cs),
		.fm_cs         (fm_cs),
		.io_wait       (io_wait),

		.dma_req       (dma_req),
		.dma_ack       (dma_ack & first),
		.dma_tc        (dma_tc & first),
		.dma_readdata  (dma_readdata),
		.dma_writedata (dma_writedata),

		.audio_l       (audio_l),
		.audio_r       (audio_r),
		.irq           (irq),

		.pll_locked    (1'b1),
		.SDRAM_DQ      (SDRAM_DQ),
		.SDRAM_A       (SDRAM_A),
		.SDRAM_DQML    (SDRAM_DQML),
		.SDRAM_DQMH    (SDRAM_DQMH),
		.SDRAM_BA      (SDRAM_BA),
		.SDRAM_nCS     (SDRAM_nCS),
		.SDRAM_nWE     (SDRAM_nWE),
		.SDRAM_nRAS    (SDRAM_nRAS),
		.SDRAM_nCAS    (SDRAM_nCAS),
		.SDRAM_CLK     (SDRAM_CLK),
		.SDRAM_CKE     (SDRAM_CKE)
	);
endmodule
