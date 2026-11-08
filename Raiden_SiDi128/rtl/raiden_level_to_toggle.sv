// SPDX-License-Identifier: GPL-3.0-or-later
//
// raiden_level_to_toggle.sv
//
// Bridges Raiden's native "level req / pulse ready" client protocol
// (main_rom_req+main_rom_ready, sub_rom_req+sub_rom_ready, tile_rom_arbiter's
// tile_req+tile_valid) onto sdram_4w.sv's "req XOR ack = pending" toggle
// protocol used by cpu2/cpu3/port1/port2/gfx1/gfx2/sample/sp.
//
// Only cpu1_rom on sdram_4w natively speaks the level/cs+valid protocol, so
// exactly one of {main, sub} CPU ROM rides it for free; every other client
// (sub CPU ROM on cpu3, tile_rom_arbiter on gfx1, and later Z80 ROM / text
// ROM / OKI once their external ports exist) needs one of these.
//
// Protocol contract:
//   client side : req held high while a fetch is outstanding, addr stable
//                 for the duration, ready pulses exactly 1 cycle when data
//                 is valid, req is expected to drop within that cycle or
//                 the next request will be treated as the same one.
//   sdram side  : req_tgl toggles once per new request, ack_tgl mirrors it
//                 (ack_tgl == req_tgl) exactly when q is valid.

module raiden_level_to_toggle #(
    parameter DATA_W = 16
)(
    input  wire              clk,
    input  wire               reset,

    // Client side (level req / pulse ready)
    input  wire               cl_req,
    output reg                cl_ready,
    output reg  [DATA_W-1:0]  cl_data,

    // sdram_4w side (toggle req / ack)
    output reg                sd_req_tgl,
    input  wire               sd_ack_tgl,
    input  wire [DATA_W-1:0]  sd_q
);

    reg req_d;
    reg pending;

    always @(posedge clk) begin
        if (reset) begin
            sd_req_tgl <= 1'b0;
            pending    <= 1'b0;
            cl_ready   <= 1'b0;
            req_d      <= 1'b0;
        end else begin
            cl_ready <= 1'b0;
            req_d    <= cl_req;

            // New request: rising edge of cl_req while nothing outstanding.
            if (cl_req && !req_d && !pending) begin
                sd_req_tgl <= ~sd_req_tgl;
                pending    <= 1'b1;
            end

            // Completion: ack has caught up to our last toggle.
            if (pending && (sd_ack_tgl == sd_req_tgl)) begin
                cl_data  <= sd_q;
                cl_ready <= 1'b1;
                pending  <= 1'b0;
            end
        end
    end

endmodule
