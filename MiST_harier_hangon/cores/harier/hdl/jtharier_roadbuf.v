/* SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-11-2026 */

//
//

module jtharier_roadbuf(
    input             rst,
    input             clk,

    input      [ 7:0] nx_idx,
    input             nx_stb,
    input      [ 7:0] cur_idx,
    input             cur_stb,

    input      [ 5:0] rd_addr,
    output     [15:0] rd_data,

    output reg [13:0] rom_addr,
    output reg        rom_cs,
    input      [15:0] rom_data,
    input             rom_ok
);

reg        front;
reg        wbuf;
reg  [7:0] tag[0:1];
reg        busy, wait1, nx_pend, bfront;
reg  [7:0] nx_l;
reg  [5:0] cnt;
reg        we;
reg  [15:0] wdata;
reg  [5:0] waddr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        front    <= 0;
        wbuf     <= 1;
        busy     <= 0;
        bfront   <= 0;
        wait1    <= 0;
        nx_pend  <= 0;
        nx_l     <= 0;
        cnt      <= 0;
        rom_cs   <= 0;
        rom_addr <= 0;
        we       <= 0;
        tag[0]   <= 8'hff;
        tag[1]   <= 8'hff;
    end else begin
        we <= 0;
        if( nx_stb ) begin
            nx_pend <= 1;
            nx_l    <= nx_idx;
        end
        if( cur_stb ) begin
            front <= ~front;
            if( busy ) bfront <= 1;
            if( tag[~front]!=cur_idx ) begin
                tag[~front] <= cur_idx;
                wbuf     <= ~front;
                busy     <= 1;
                bfront   <= 1;
                wait1    <= 1;
                cnt      <= 0;
                rom_cs   <= 1;
                rom_addr <= { cur_idx, 6'd0 };
            end
        end else if( nx_pend && !(busy && bfront) && !nx_stb ) begin
            nx_pend  <= 0;
            bfront   <= 0;
            tag[~front] <= nx_l;
            wbuf     <= ~front;
            busy     <= 1;
            wait1    <= 1;
            cnt      <= 0;
            rom_cs   <= 1;
            rom_addr <= { nx_l, 6'd0 };
        end else if( busy ) begin
            if( wait1 ) begin
                wait1 <= 0;
            end else if( rom_ok ) begin
                we    <= 1;
                wdata <= rom_data;
                waddr <= cnt;
                if( cnt==6'd63 ) begin
                    busy   <= 0;
                    rom_cs <= 0;
                end else begin
                    cnt      <= cnt + 6'd1;
                    rom_addr <= { rom_addr[13:6], cnt + 6'd1 };
                    wait1    <= 1;
                end
            end
        end
    end
end

jtframe_dual_ram #(.DW(16),.AW(7)) u_ram(
    .clk0   ( clk               ),
    .data0  ( wdata             ),
    .addr0  ( { wbuf, waddr }   ),
    .we0    ( we                ),
    .q0     (                   ),
    .clk1   ( clk               ),
    .data1  ( 16'd0             ),
    .addr1  ( { front, rd_addr }),
    .we1    ( 1'b0              ),
    .q1     ( rd_data           )
);

endmodule
