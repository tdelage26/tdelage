// SPDX-License-Identifier: GPL-3.0-or-later
//
// raiden_oki_rom_adapter.sv
//
// Bridges jt6295's byte-at-a-time OKI ROM interface (18-bit byte address,
// 8-bit data, ok pulse) to sdram_4w's 64-bit burst `sample` port (toggle
// req/ack, 22-bit word address, 64-bit data).
//
// Protocol:
//   jt6295 side : rom_addr stable while rom_ok not asserted; once rom_ok
//                 pulses (1 cycle) jt6295 latches rom_data and drops the
//                 address.  jt6295_rom.v actually holds rom_cs high while
//                 waiting; we treat any NEW address as a new request.
//
//   sdram_4w sample port (toggle):
//     sample_req XOR sample_ack = pending
//     sample_addr = word address [22:1] (64-bit burst = 8 bytes → 4 words)
//     sample_q    = 64 bits {byte7..byte0} in LITTLE-ENDIAN order
//
// Implementation:
//   1. Detect a new address from jt6295 (rising edge of rom_cs or address
//      change while cs is high).
//   2. Issue a toggle on sample_req.  The burst returns 8 consecutive bytes
//      aligned to the 8-byte boundary containing rom_addr.
//   3. On ack, select the correct byte from the 64-bit burst word and pulse
//      rom_ok for exactly one clock.
//
// Note: sdram_4w `sample` port address granularity is 16-bit words.
// A 64-bit burst covers 4 consecutive 16-bit words = 8 bytes.
// We align to the 8-byte (4-word) boundary:
//   sample_addr[22:2] = rom_addr[17:7]   (upper 16 bits, 8-byte aligned)
//   -- actually: word_addr = rom_addr >> 1  (byte→word)
//              burst_base_word = word_addr & ~3  (align to 4-word boundary)
//   byte_sel = rom_addr[2:0]  (selects one of 8 bytes in the burst)

module raiden_oki_rom_adapter (
    input  wire        clk,
    input  wire        reset,

    // jt6295 side
    input  wire [17:0] rom_addr,    // byte address within OKI ROM region
    input  wire        rom_cs,      // 1 = OKI actively requesting this byte
    output reg   [7:0] rom_data,
    output reg         rom_ok,

    // sdram_4w sample port
    output reg         sample_req,
    input  wire        sample_ack,
    output reg  [22:1] sample_addr, // word address (16-bit granularity)
    input  wire [63:0] sample_q
);

    // Internal state
    reg         pending;
    reg  [17:0] req_addr_q;     // address that was sent to SDRAM
    reg         cs_prev;

    // Detect new OKI request: rising edge of cs OR address changed while cs high
    wire new_req = rom_cs && (!cs_prev || (rom_addr != req_addr_q && !pending));

    always @(posedge clk) begin
        if (reset) begin
            sample_req   <= 1'b0;
            pending      <= 1'b0;
            rom_ok       <= 1'b0;
            rom_data     <= 8'hFF;
            cs_prev      <= 1'b0;
            req_addr_q   <= 18'd0;
            sample_addr  <= 22'd0;
        end else begin
            rom_ok  <= 1'b0;
            cs_prev <= rom_cs;

            if (new_req && !pending) begin
                // Align to 8-byte burst boundary:
                //   word_addr = rom_addr[17:1]  (byte → 16-bit word)
                //   burst base = word_addr[16:2] * 4  (clear low 2 word bits)
                //   sample_addr[22:1] = { word_addr[16:2], 2'b00 }
                sample_addr <= { rom_addr[17:3], 2'b00 };
                sample_req  <= ~sample_req;
                pending     <= 1'b1;
                req_addr_q  <= rom_addr;
            end

            // Completion: ack catches up
            if (pending && (sample_ack == sample_req)) begin
                // Select the correct byte from the 64-bit burst word.
                // sample_q is little-endian: byte 0 = sample_q[7:0], byte 7 = sample_q[63:56]
                // byte_index = req_addr_q[2:0]  (position within the 8-byte aligned block)
                case (req_addr_q[2:0])
                    3'd0: rom_data <= sample_q[ 7: 0];
                    3'd1: rom_data <= sample_q[15: 8];
                    3'd2: rom_data <= sample_q[23:16];
                    3'd3: rom_data <= sample_q[31:24];
                    3'd4: rom_data <= sample_q[39:32];
                    3'd5: rom_data <= sample_q[47:40];
                    3'd6: rom_data <= sample_q[55:48];
                    3'd7: rom_data <= sample_q[63:56];
                endcase
                rom_ok  <= 1'b1;
                pending <= 1'b0;
            end
        end
    end

endmodule
