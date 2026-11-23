module l2_sdram_cache #(
    parameter integer KB    = 64,
    parameter integer ABITS = 25
) (
    input             clk,
    input             reset,

    input      [31:0] cpu_addr,
    input      [31:0] cpu_din,
    output reg [31:0] cpu_dout,
    output reg        cpu_dout_ready,
    input       [3:0] cpu_be,
    input       [7:0] cpu_burstcount,
    output            cpu_busy,
    input             cpu_rd,
    input             cpu_we,

    output     [31:0] sd_addr,
    output     [31:0] sd_din,
    input      [31:0] sd_dout,
    input             sd_dout_ready,
    output      [3:0] sd_be,
    output      [7:0] sd_burstcount,
    input             sd_busy,
    output            sd_rd,
    output            sd_we
);

localparam integer WORDS   = KB * 256;
localparam integer WBITS   = $clog2(WORDS);
localparam integer LBITS   = WBITS - 3;
localparam integer TAGW    = ABITS - 2 - WBITS;

localparam [2:0] S_INIT = 3'd0, S_IDLE = 3'd1, S_LOOK = 3'd2, S_FILL = 3'd3,
                 S_RELOOK = 3'd4, S_WRCHK = 3'd5;
reg  [2:0] state = S_INIT;

reg  [ABITS-3:0] cur;
reg        [7:0] beats;
reg  [ABITS-3:0] waddr;
reg       [31:0] wdata;
reg        [3:0] wbe;
reg  [LBITS-1:0] init_line;
reg  [ABITS-6:0] fill_line;
reg        [2:0] fill_cnt;
reg              fill_rd;

reg  [TAGW:0] tag_ram [0:(1<<LBITS)-1];
reg  [TAGW:0] tag_q;
reg  [LBITS-1:0] tag_raddr;
reg           tag_we;
reg  [LBITS-1:0] tag_waddr;
reg  [TAGW:0] tag_wdata;

reg  [7:0] dram0 [0:WORDS-1];
reg  [7:0] dram1 [0:WORDS-1];
reg  [7:0] dram2 [0:WORDS-1];
reg  [7:0] dram3 [0:WORDS-1];
reg  [31:0] data_q;
reg  [WBITS-1:0] data_raddr;
reg  [WBITS-1:0] data_waddr;
reg  [31:0] data_wdata;
reg   [3:0] data_we;

always @(posedge clk) begin
    if (tag_we) tag_ram[tag_waddr] <= tag_wdata;
    tag_q <= tag_ram[tag_raddr];
end
always @(posedge clk) begin
    if (data_we[0]) dram0[data_waddr] <= data_wdata[7:0];
    if (data_we[1]) dram1[data_waddr] <= data_wdata[15:8];
    if (data_we[2]) dram2[data_waddr] <= data_wdata[23:16];
    if (data_we[3]) dram3[data_waddr] <= data_wdata[31:24];
    data_q <= {dram3[data_raddr], dram2[data_raddr], dram1[data_raddr], dram0[data_raddr]};
end

wire [ABITS-3:0] cpu_dw   = cpu_addr[ABITS-1:2];
wire             hit      = tag_q[TAGW] && (tag_q[TAGW-1:0] == cur[ABITS-3:WBITS]);
wire             whit     = tag_q[TAGW] && (tag_q[TAGW-1:0] == waddr[ABITS-3:WBITS]);
wire             accept_rd = (state == S_IDLE) && cpu_rd;
wire             accept_we = (state == S_IDLE) && cpu_we && !cpu_rd;
wire             fill_beat = (state == S_FILL) && sd_dout_ready;
wire             fwd       = fill_beat && beats != 0 && cur[ABITS-3:3] == fill_line && cur[2:0] == fill_cnt;

reg [ABITS-3:0] next_cur;
always @* begin
    next_cur = cur;
    if (state == S_IDLE)                          next_cur = cpu_dw;
    else if (state == S_LOOK && hit && beats > 1) next_cur = cur + 1'd1;
    data_raddr = next_cur[WBITS-1:0];
    tag_raddr  = next_cur[WBITS-1:3];
end

assign sd_we         = (state == S_WRCHK);
assign sd_rd         = fill_rd;
assign sd_addr       = fill_rd ? {{(32-ABITS){1'b0}}, fill_line, 5'b00000} : {{(32-ABITS){1'b0}}, waddr, 2'b00};
assign sd_din        = wdata;
assign sd_be         = fill_rd ? 4'hF : wbe;
assign sd_burstcount = fill_rd ? 8'd8 : 8'd1;

assign cpu_busy      = (state != S_IDLE);

always @* begin
    tag_we     = 1'b0;
    tag_waddr  = init_line;
    tag_wdata  = {(TAGW+1){1'b0}};
    data_we    = 4'h0;
    data_waddr = waddr[WBITS-1:0];
    data_wdata = wdata;
    case (state)
    S_INIT:  tag_we = 1'b1;
    S_WRCHK: if (whit) data_we = wbe;
    S_FILL:  if (sd_dout_ready) begin
                 data_we    = 4'hF;
                 data_waddr = {fill_line[LBITS-1:0], fill_cnt};
                 data_wdata = sd_dout;
                 if (fill_cnt == 3'd7) begin
                     tag_we    = 1'b1;
                     tag_waddr = fill_line[LBITS-1:0];
                     tag_wdata = {1'b1, fill_line[ABITS-6:LBITS]};
                 end
             end
    default: ;
    endcase
end

always @(posedge clk) begin
    cpu_dout_ready <= 1'b0;

    if (fill_rd && !sd_busy) fill_rd <= 1'b0;

    if (reset) begin
        state     <= S_INIT;
        init_line <= 0;
        fill_rd   <= 1'b0;
    end else case (state)
    S_INIT: begin
        init_line <= init_line + 1'd1;
        if (&init_line) state <= S_IDLE;
    end

    S_IDLE: begin
        cur   <= cpu_dw;
        beats <= (cpu_burstcount == 8'd0) ? 8'd1 : cpu_burstcount;
        waddr <= cpu_dw;
        wdata <= cpu_din;
        wbe   <= cpu_be;
        if (accept_rd)      state <= S_LOOK;
        else if (accept_we) state <= S_WRCHK;
    end

    S_WRCHK: if (!sd_busy) state <= S_IDLE;

    S_LOOK: begin
        if (hit) begin
            cpu_dout       <= data_q;
            cpu_dout_ready <= 1'b1;
            beats          <= beats - 1'd1;
            if (beats > 1) cur <= cur + 1'd1;
            else           state <= S_IDLE;
        end else begin
            fill_line <= cur[ABITS-3:3];
            fill_cnt  <= 3'd0;
            fill_rd   <= 1'b1;
            state     <= S_FILL;
        end
    end

    S_FILL: if (sd_dout_ready) begin
        fill_cnt   <= fill_cnt + 1'd1;
        if (fwd) begin
            cpu_dout       <= sd_dout;
            cpu_dout_ready <= 1'b1;
            beats          <= beats - 1'd1;
            cur            <= cur + 1'd1;
        end
        if (fill_cnt == 3'd7) begin
            if ((fwd ? beats - 1'd1 : beats) != 0) state <= S_RELOOK;
            else                                   state <= S_IDLE;
        end
    end

    S_RELOOK: state <= S_LOOK;

    default: state <= S_IDLE;
    endcase
end

endmodule
