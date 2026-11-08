// SPDX-License-Identifier: GPL-3.0-or-later
//
// ssbus_stub.sv — MiST build stub for the MiSTer savestate bus.
//
// The MiST port has no savestate (no DDR3). All ssbus_if ports are tied off
// here: the interface still compiles correctly because every game RTL module
// that uses ssbus_if was written with SS_IDX = -1 as the "no savestate" sentinel
// (in that case the adaptor is a transparent pass-through and the ssbus port
// is never driven). This file provides the interface + all adaptor modules.
//
// Modules supplied:
//   ssbus_if          -- SystemVerilog interface (required by every module that
//                        accepts .slave ports)
//   ssbus_mux         -- N-to-1 MUX (instantiated in Raiden_MiST.sv with 1 dummy slave)
//   ss_ram_adaptor    -- 8-bit RAM savestate adaptor (transparent pass-through)
//   ss_ram16_adaptor  -- 16-bit RAM savestate adaptor (transparent pass-through)

`timescale 1ns / 1ps

// ── ssbus_if ────────────────────────────────────────────────────────────────
interface ssbus_if();
    logic [63:0] data;
    logic [31:0] addr;
    logic  [7:0] select;
    logic        write;
    logic        read;
    logic        query;
    logic [63:0] data_out;
    logic        ack;

    function logic access(int idx);
        return (select == idx[7:0]) & ~query & (read | write);
    endfunction

    task setup(int idx, input [31:0] count, int width);
        ack <= 0;
        if (select == idx[7:0]) begin
            if (query) begin
                data_out <= { idx[7:0], 22'b0, width[1:0], count };
                ack <= 1;
            end
        end
    endtask

    task read_response(int idx, input [63:0] dout);
        if (select == idx[7:0]) begin
            data_out <= dout;
            ack <= 1;
        end
    endtask

    task write_ack(int idx);
        if (select == idx[7:0]) begin
            ack <= 1;
        end
    endtask

    modport master(
        output data, addr, select, write, read, query,
        input  data_out, ack
    );

    modport slave(
        input  data, addr, select, write, read, query,
        output data_out, ack,
        import access,
        import setup,
        import read_response,
        import write_ack
    );
endinterface

// ── ssbus_mux ───────────────────────────────────────────────────────────────
module ssbus_mux #(parameter COUNT = 1)(
    input clk,
    ssbus_if.master masters[COUNT],
    ssbus_if.slave  slave
);
    genvar gi;
    generate
        for (gi = 0; gi < COUNT; gi = gi + 1) begin : gen_loop
            always_comb begin
                masters[gi].data   = slave.data;
                masters[gi].addr   = slave.addr;
                masters[gi].select = slave.select;
                masters[gi].write  = slave.write;
                masters[gi].read   = slave.read;
                masters[gi].query  = slave.query;
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        slave.data_out <= 64'd0;
        slave.ack      <= 1'b0;
    end
endmodule

// ── ss_ram_adaptor (8-bit) ───────────────────────────────────────────────────
// MiST: transparent pass-through (SS_IDX ignored, savestate never runs).
module ss_ram_adaptor #(
    parameter WIDTH   = 8,
    parameter WIDTHAD = 10,
    parameter SS_IDX  = -1
)(
    input  wire              clk,
    input  wire              wren_in,
    input  wire [WIDTHAD-1:0] addr_in,
    input  wire [WIDTH-1:0]  wdata_in,
    output wire              wren_out,
    output wire [WIDTHAD-1:0] addr_out,
    output wire [WIDTH-1:0]  wdata_out,
    input  wire [WIDTH-1:0]  q_in,
    ssbus_if.slave            ssbus
);
    assign wren_out  = wren_in;
    assign addr_out  = addr_in;
    assign wdata_out = wdata_in;

    always_ff @(posedge clk) begin
        ssbus.ack      <= 1'b0;
        ssbus.data_out <= 64'd0;
    end
endmodule

// ── ss_ram16_adaptor (16-bit) ────────────────────────────────────────────────
module ss_ram16_adaptor #(
    parameter WIDTHAD = 14,
    parameter SS_IDX  = -1
)(
    input  wire              clk,
    input  wire              we_lo_in,
    input  wire              we_hi_in,
    input  wire [WIDTHAD-1:0] addr_in,
    input  wire [15:0]       wdata_in,
    output wire              we_lo_out,
    output wire              we_hi_out,
    output wire [WIDTHAD-1:0] addr_out,
    output wire [15:0]       wdata_out,
    input  wire [15:0]       q_in,
    ssbus_if.slave            ssbus
);
    assign we_lo_out  = we_lo_in;
    assign we_hi_out  = we_hi_in;
    assign addr_out   = addr_in;
    assign wdata_out  = wdata_in;

    always_ff @(posedge clk) begin
        ssbus.ack      <= 1'b0;
        ssbus.data_out <= 64'd0;
    end
endmodule
