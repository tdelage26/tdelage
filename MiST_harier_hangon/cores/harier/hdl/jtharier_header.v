/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2025 */

module jtharier_header(
    input            clk,
                     header, prog_we,
    
    output reg       i8751=0,
    output reg       fd1089=0,
    output reg       blank4=0,
    output reg       hangon=0,
    output reg       ym2151=0,
    output reg       cab1p=0,
    output reg       hicol=0,
    output reg [2:0] adc=0,
    input      [2:0] prog_addr,
    input      [7:0] prog_data
);

always @(posedge clk) begin
    if( header && prog_addr[2:0]==0 && prog_we )
        i8751 <= prog_data[0];
    if( header && prog_addr[2:0]==0 && prog_we )
        fd1089 <= prog_data[1];
    if( header && prog_addr[2:0]==0 && prog_we )
        blank4 <= prog_data[2];
    if( header && prog_addr[2:0]==0 && prog_we )
        hangon <= prog_data[3];
    if( header && prog_addr[2:0]==1 && prog_we )
        ym2151 <= prog_data[0];
    if( header && prog_addr[2:0]==2 && prog_we )
        cab1p <= prog_data[0];
    if( header && prog_addr[2:0]==3 && prog_we )
        hicol <= prog_data[0];
    if( header && prog_addr[2:0]==4 && prog_we )
        adc <= prog_data[2:0];
end

endmodule
