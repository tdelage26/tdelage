// SPDX-License-Identifier: GPL-3.0-or-later
// Original: Martin Donlon (wickerwaka) - Arcade-TaitoF2 (ddram). Modified by Umberto Parisi.
//
// raiden_ddr_if.sv
// Bus DDRAM condiviso multi-client. Copia esatta del pattern taito_f2_baseline/rtl/ddram.sv.
//
// Client (modport from_host) chiede `acquire=1` quando vuole il bus.
// L'arbitro (ddr_mux) latcha chi acquire per primo, l'altro vede busy=1.

interface ddr_if;
	logic        acquire;
	logic [31:0] addr;
	logic [63:0] wdata;
	logic [63:0] rdata;
	logic        read;
	logic        write;
	logic  [7:0] burstcnt;
	logic  [7:0] byteenable;
	logic        busy;
	logic        rdata_ready;

	modport to_host(
		output addr, wdata, read, write, burstcnt, byteenable, acquire,
		input rdata, busy, rdata_ready
	);

	modport from_host(
		output rdata, busy, rdata_ready,
		input addr, wdata, read, write, burstcnt, byteenable, acquire
	);
endinterface
