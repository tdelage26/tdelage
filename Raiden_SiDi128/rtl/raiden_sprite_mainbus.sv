// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) Umberto Parisi (rmonic79). GPL v3 or later.
//
// Raiden sprite RAM bus (pattern Irem M72 board_b_d-style + BUFFERED_SPRITERAM16)
// Gestisce spriteram (Main side, $07000-$07FFF, 4KB = 2K word) con:
// - Porta A: Main V30 R/W
// - Buffer: copia spriteram → buf su rising vblank (MAME BUFFERED_SPRITERAM16)
// - Porta B (buffer): renderer R-only
//
// MAME memory map Main:
//   $07000-$07FFF  spriteram (4KB) — share "spriteram" (BUFFERED_SPRITERAM16)
//
// Pattern M72: DOUT_VALID = MRD & sprite_memrq.

module raiden_sprite_mainbus #(parameter SS_IDX = -1)
(
	input  wire        clk,
	input  wire        reset,

	// CPU Main interface
	input  wire [19:0] cpu_addr,
	input  wire        cpu_rd,
	input  wire        cpu_wr,
	input  wire  [1:0] cpu_be,
	input  wire [15:0] cpu_dout,

	// memrq da raiden_addr_main
	input  wire        sprite_memrq,

	// CPU read mux output
	output wire [15:0] DOUT,
	output wire        DOUT_VALID,

	// Vblank rising → copia spriteram → buffer
	input  wire        vblank_rising,

	// Renderer porta B (read buffer)
	input  wire [10:0] spr_vram_addr,
	output wire [15:0] spr_vram_data,

	// Savestate slave (salvo il CPU bank spr_lo/hi; i buffer si ricostruiscono a vblank)
	ssbus_if.slave     ss_spr
);

// Word index (4KB / 2 byte = 2K word)
wire [10:0] spr_word_addr = cpu_addr[11:1];

// Byte enable
wire wr_lo = cpu_wr && cpu_be[0] && !cpu_be[1] && !cpu_addr[0];
wire wr_hi = cpu_wr && cpu_be[0] && !cpu_be[1] &&  cpu_addr[0];
wire wr_w  = cpu_wr && cpu_be[0] &&  cpu_be[1];

// ─── Sprite RAM CPU bank ────────────────────────────────────────────────
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_lo [0:2047];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_hi [0:2047];
initial begin integer i; for (i=0; i<2048; i=i+1) begin spr_lo[i]=0; spr_hi[i]=0; end end

reg [15:0] spr_cpu_rdata;
wire        spr_we_lo_cpu = sprite_memrq && (wr_lo || wr_w);
wire        spr_we_hi_cpu = sprite_memrq && (wr_hi || wr_w);
wire [15:0] spr_wdata_cpu = wr_w ? cpu_dout : {cpu_dout[7:0], cpu_dout[7:0]};
wire [10:0] spr_idx;
wire        spr_we_lo, spr_we_hi;
wire [15:0] spr_wdata_eff;
ss_ram16_adaptor #(.WIDTHAD(11), .SS_IDX(SS_IDX)) u_ss_spr (
	.clk(clk), .we_lo_in(spr_we_lo_cpu), .we_hi_in(spr_we_hi_cpu),
	.addr_in(spr_word_addr), .wdata_in(spr_wdata_cpu),
	.we_lo_out(spr_we_lo), .we_hi_out(spr_we_hi), .addr_out(spr_idx), .wdata_out(spr_wdata_eff),
	.q_in(spr_cpu_rdata), .ssbus(ss_spr)
);
always @(posedge clk) begin
	if (spr_we_lo) spr_lo[spr_idx] <= spr_wdata_eff[7:0];
	if (spr_we_hi) spr_hi[spr_idx] <= spr_wdata_eff[15:8];
	spr_cpu_rdata <= {spr_hi[spr_idx], spr_lo[spr_idx]};
end

// v110: DOPPIO buffer cascade — sprite a renderer è ritardato di N-2 invece
// di N-1. Test: sprite "anticipa" il BG visivamente, quindi rallentandolo
// di 1 frame extra dovrebbe allinearsi.
// Buffer1 ← spriteram a vblank_rising. Buffer2 ← Buffer1 al successivo
// vblank_rising. Renderer legge Buffer2.

// ─── Sprite RAM Buffer 1 (intermedio, copy on vblank) ───────────────────
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_lo_buf [0:2047];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_hi_buf [0:2047];
initial begin integer i; for (i=0; i<2048; i=i+1) begin spr_lo_buf[i]=0; spr_hi_buf[i]=0; end end

// ─── Sprite RAM Buffer 2 (renderer reads, copy from Buffer1 on vblank) ──
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_lo_buf2 [0:2047];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] spr_hi_buf2 [0:2047];
initial begin integer i; for (i=0; i<2048; i=i+1) begin spr_lo_buf2[i]=0; spr_hi_buf2[i]=0; end end

// Copy FSM: su rising vblank, copy in due stadi pipeline: spriteram->buf1
// (stadio1) e buf1->buf2 (stadio2, un ciclo dopo). Scritto in due always
// block separati, uno per stadio: spr_lo_buf/spr_hi_buf vengono così scritti
// in un blocco e letti (a indirizzo diverso, di un ciclo indietro) in un
// altro, invece di essere letti e riscritti nello STESSO blocco alla STESSA
// cella nello stesso ciclo. Quest'ultimo pattern impediva a Quartus di
// inferire spr_lo_buf/spr_hi_buf come altsyncram (M9K): finivano sintetizzati
// come 2x2048x8 register array (~47k ALUT / ~61k registri), causando
// l'overflow di LAB in fitting. Il pattern qui sotto è identico a quello già
// funzionante per spr_lo_buf2/spr_hi_buf2 (scrittura in un blocco, lettura
// registrata in un altro).
reg        copying;
reg [11:0] copy_idx;
reg        copying_d;
reg [11:0] copy_idx_d;

always @(posedge clk) begin
	if (reset) begin
		copying  <= 1'b0;
		copy_idx <= 12'd0;
	end else if (vblank_rising) begin
		copying  <= 1'b1;
		copy_idx <= 12'd0;
	end else if (copying) begin
		if (copy_idx == 12'd2047) copying <= 1'b0;
		copy_idx <= copy_idx + 12'd1;
	end
	// stadio 2 segue lo stadio 1 di un ciclo
	copying_d  <= copying;
	copy_idx_d <= copy_idx;
end

// Stadio 1: spriteram (CPU bank) -> buffer1. Blocco dedicato, sola scrittura.
reg [7:0] cp_spr_lo, cp_spr_hi;
reg [7:0] cp_b1_lo,  cp_b1_hi;

always @(posedge clk) begin
	cp_spr_lo <= spr_lo[copy_idx[10:0]];
	cp_spr_hi <= spr_hi[copy_idx[10:0]];
end

always @(posedge clk) begin
	if (copying_d) begin
		spr_lo_buf[copy_idx_d[10:0]] <= cp_spr_lo;
		spr_hi_buf[copy_idx_d[10:0]] <= cp_spr_hi;
	end
end
// Stadio 2: buffer1 -> buffer2, un ciclo dopo lo stadio 1 (indice ritardato,
// quindi indirizzo diverso da quello scritto nello stesso ciclo dallo
// stadio 1 -> nessun hazard read/write). Blocco dedicato, sola scrittura.
always @(posedge clk) begin
	cp_b1_lo <= spr_lo_buf[copy_idx[10:0]];
	cp_b1_hi <= spr_hi_buf[copy_idx[10:0]];
end

always @(posedge clk) begin
	if (copying_d) begin
		spr_lo_buf2[copy_idx_d[10:0]] <= cp_b1_lo;
		spr_hi_buf2[copy_idx_d[10:0]] <= cp_b1_hi;
	end
end

// Renderer porta B → legge buf2 (= N-2 lag)
reg [15:0] spr_vram_rdata;
always @(posedge clk) spr_vram_rdata <= {spr_hi_buf2[spr_vram_addr], spr_lo_buf2[spr_vram_addr]};
assign spr_vram_data = spr_vram_rdata;

// ─── DOUT_VALID + DOUT (pattern M72) ────────────────────────────────────
reg sprite_rd_lat;
reg cpu_addr_lo_lat;

always @(posedge clk) begin
	if (reset) begin
		sprite_rd_lat   <= 1'b0;
		cpu_addr_lo_lat <= 1'b0;
	end else begin
		sprite_rd_lat   <= cpu_rd & sprite_memrq;
		cpu_addr_lo_lat <= cpu_addr[0];
	end
end

assign DOUT_VALID = sprite_rd_lat;
assign DOUT       = cpu_addr_lo_lat ? {spr_cpu_rdata[7:0], spr_cpu_rdata[15:8]} : spr_cpu_rdata;

endmodule
