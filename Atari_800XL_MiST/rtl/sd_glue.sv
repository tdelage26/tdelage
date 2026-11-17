module sd_glue
#(
	parameter [27:0] REPLAY_HOLD = 28'hC000000
)
(
	input             clk,
	input             reset,

	input             d1_boot,
	input             cart_stacked,
	input             force_readonly,
	input             drop_cart,

	input       [7:0] ioctl_index,

	output reg [31:0] sd_lba,
	output reg  [3:0] sd_rd = 0,
	output reg  [3:0] sd_wr = 0,
	input             sd_ack,
	input       [8:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	output      [7:0] sd_buff_din,
	input             sd_buff_wr,
	input       [3:0] img_mounted,
	input      [31:0] img_size,

	output      [7:0] ZPU_IN2,
	input      [31:0] ZPU_OUT2,
	output     [31:0] ZPU_IN3,
	input      [31:0] ZPU_OUT3,
	input      [15:0] ZPU_RD,
	input      [15:0] ZPU_WR
);

function [1:0] phys_slot(input [2:0] l);
	case(l)
		3'd0, 3'd6:       phys_slot = 2'd0;
		3'd1:             phys_slot = 2'd1;
		3'd2, 3'd3:       phys_slot = 2'd2;
		default:          phys_slot = 2'd3;
	endcase
endfunction

wire [7:0] zpu_buf_q;
reg  [8:0] zpu_buff_addr;
reg        zpu_buf_wr;

dpram_glue #(9,8) sdbuf
(
	.clock(clk),

	.address_a(sd_buff_addr),
	.data_a(sd_buff_dout),
	.wren_a(sd_buff_wr),
	.q_a(sd_buff_din),

	.address_b(zpu_buff_addr),
	.data_b(ZPU_OUT3[7:0]),
	.wren_b(zpu_buf_wr),
	.q_b(zpu_buf_q)
);

reg        zpu_io_done;
reg        zpu_mounted = 0;
reg  [2:0] zpu_fileno = 0;
reg  [1:0] zpu_filetype = 0;
reg        zpu_readonly = 0;
reg [31:0] zpu_filesize = 0;

assign ZPU_IN2 = {zpu_readonly, zpu_filetype, zpu_fileno, zpu_mounted, zpu_io_done};
assign ZPU_IN3 = zpu_lba ? zpu_filesize : {24'd0, zpu_buf_q};

wire       zpu_lba      = ZPU_OUT2[0];
wire       zpu_block_rd = ZPU_OUT2[1];
wire       zpu_block_wr = ZPU_OUT2[2];
wire [2:0] zpu_drv_num  = ZPU_OUT2[5:3];
wire       zpu_io_wr    = ZPU_WR[5];
wire       zpu_data_wr  = ZPU_WR[6];
wire       zpu_data_rd  = ZPU_RD[2];

reg  [3:0] slot_used = 0;
reg  [2:0] slot_log[0:3];
reg  [1:0] slot_type[0:3];
reg [31:0] slot_size[0:3];
reg  [3:0] slot_pending = 0;

initial begin
	slot_log[0] = 0; slot_log[1] = 1; slot_log[2] = 2; slot_log[3] = 4;
	slot_type[0] = 0; slot_type[1] = 0; slot_type[2] = 0; slot_type[3] = 0;
	slot_size[0] = 0; slot_size[1] = 0; slot_size[2] = 0; slot_size[3] = 0;
end

reg        ev_wait = 0;
reg [27:0] ev_timeout;

always @(posedge clk) begin
	reg old_wr, old_wr2, old_rd;
	reg old_blrd, old_blwr, old_ack;
	reg old_reset;
	reg [1:0] p;
	reg [2:0] l;
	reg [1:0] t;
	integer i;

	zpu_buf_wr <= 0;
	if(zpu_buf_wr) zpu_buff_addr <= zpu_buff_addr + 1'd1;

	old_wr <= zpu_data_wr;
	old_wr2 <= old_wr;
	if(~old_wr2 & old_wr) begin
		if(zpu_lba) sd_lba <= ZPU_OUT3;
		else zpu_buf_wr <= 1;
	end

	old_rd <= zpu_data_rd;
	if(old_rd & ~zpu_data_rd) begin
		zpu_buff_addr <= zpu_buff_addr + 1'd1;
		if(zpu_lba) ev_wait <= 0;
	end

	if(zpu_io_wr) zpu_buff_addr <= 0;

	old_blrd <= zpu_block_rd;
	if(~old_blrd & zpu_block_rd) begin
		zpu_io_done <= 0;
		sd_rd[phys_slot(zpu_drv_num)] <= 1;
	end

	old_blwr <= zpu_block_wr;
	if(~old_blwr & zpu_block_wr) begin
		zpu_io_done <= 0;
		sd_wr[phys_slot(zpu_drv_num)] <= 1;
	end

	if(sd_ack) {sd_rd, sd_wr} <= 0;

	old_ack <= sd_ack;
	if(old_ack & ~sd_ack) zpu_io_done <= 1;

	for(i = 0; i < 4; i = i + 1) begin
		if(img_mounted[i]) begin
			p = i[1:0];
			t = ioctl_index[7:6];
			case(p)
				2'd0: l = d1_boot ? 3'd6 : 3'd0;
				2'd1: l = 3'd1;
				2'd2: l = 3'd2;
				default: begin
					if(t == 2'd3) begin l = 3'd5; t = 2'd0; end
					else l = cart_stacked ? 3'd7 : 3'd4;
				end
			endcase
			if(img_size) begin
				slot_used[p] <= 1;
				slot_log[p] <= l;
				slot_type[p] <= t;
			end
			else begin
				slot_used[p] <= 0;
			end
			slot_size[p] <= img_size;
			slot_pending[p] <= 1;
		end
	end

	if(ev_wait) begin
		ev_timeout <= ev_timeout + 1'd1;
		if(&ev_timeout) ev_wait <= 0;
	end
	else if(|slot_pending && !reset) begin
		p = slot_pending[0] ? 2'd0 : slot_pending[1] ? 2'd1 : slot_pending[2] ? 2'd2 : 2'd3;
		slot_pending[p] <= 0;
		zpu_fileno   <= slot_log[p];
		zpu_filetype <= slot_type[p];
		zpu_filesize <= slot_size[p];
		zpu_readonly <= force_readonly | (slot_log[p] == 3'd4) | (slot_log[p] == 3'd5) | (slot_log[p] == 3'd7);
		zpu_mounted  <= ~zpu_mounted;
		ev_wait      <= 1;
		ev_timeout   <= 0;
	end

	if(drop_cart) slot_used[3] <= 0;
	old_reset <= reset;
	if(reset) begin
		ev_wait <= 0;
		zpu_io_done <= 0;
		sd_rd <= 0;
		sd_wr <= 0;
	end
	else if(old_reset) begin
		for(i = 0; i < 4; i = i + 1)
			if(slot_used[i] && slot_log[i] != 3'd5) slot_pending[i] <= 1;
		if(|(slot_used & {slot_log[3] != 3'd5, slot_log[2] != 3'd5, slot_log[1] != 3'd5, slot_log[0] != 3'd5})) begin
			ev_wait <= 1;
			ev_timeout <= REPLAY_HOLD;
		end
	end
end

endmodule

module dpram_glue #(parameter AW = 9, DW = 8)
(
	input               clock,

	input      [AW-1:0] address_a,
	input      [DW-1:0] data_a,
	input               wren_a,
	output reg [DW-1:0] q_a,

	input      [AW-1:0] address_b,
	input      [DW-1:0] data_b,
	input               wren_b,
	output reg [DW-1:0] q_b
);

reg [DW-1:0] ram[0:(1<<AW)-1];

always @(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end
	else q_a <= ram[address_a];
end

always @(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end
	else q_b <= ram[address_b];
end

endmodule
