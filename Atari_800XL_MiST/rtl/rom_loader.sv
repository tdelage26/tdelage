module rom_loader
#(
	parameter [24:0] ROM_STORE = 25'h1F00000,
	parameter  [5:0] CART_IDX  = 6'd5,
	parameter [24:0] CART_BASE = 25'h0800000
)
(
	input             clk,
	input             reset,

	input             ioctl_download,
	input       [7:0] ioctl_index,
	input             ioctl_wr,
	input      [26:0] ioctl_addr,
	input       [7:0] ioctl_dout,
	input      [31:0] ioctl_filesize,

	output reg [13:0] osxl_off = 0,
	output reg [13:0] osa_off = 0,
	output reg [13:0] osb_off = 0,

	output reg        load_req = 0,
	output reg [24:0] load_addr,
	output reg [31:0] load_data,
	output reg        load_width32,
	input             load_ack,

	output reg        load_reset = 0,
	output reg        cart_set = 0,
	output reg  [7:0] cart_mode = 0,
	output            busy_any
);

wire [5:0] idx = ioctl_index[5:0];

reg        tgt_valid;
reg [15:0] tgt_offs;
reg [24:0] tgt_addr;
wire       is_cart = (idx == CART_IDX);
wire [26:0] cart_offs = ioctl_addr - 27'd16;
wire combined = (idx == 0) || ((idx <= 4) && (ioctl_filesize >= 32'd32768));

always @(*) begin
	tgt_valid = 0;
	tgt_offs  = 0;
	case(combined ? 6'd0 : idx)
		0: begin
				tgt_valid = (ioctl_addr[26:16] == 0) && (ioctl_addr[15:13] != 3'b001);
				tgt_offs  = ioctl_addr[15:0];
			end
		1: begin tgt_valid = ioctl_addr[26:14] == 0; tgt_offs = {2'b01, ioctl_addr[13:0]}; end
		2: begin tgt_valid = ioctl_addr[26:13] == 0; tgt_offs = {3'b000, ioctl_addr[12:0]}; end
		3: begin tgt_valid = ioctl_addr[26:14] == 0; tgt_offs = {2'b10, ioctl_addr[13:0]}; end
		4: begin tgt_valid = ioctl_addr[26:14] == 0; tgt_offs = {2'b11, ioctl_addr[13:0]}; end
		default: ;
	endcase
	tgt_addr = {ROM_STORE[24:16], tgt_offs};
	if(is_cart) begin
		tgt_valid = (ioctl_addr >= 27'd16) && (ioctl_addr < 27'h400010);
		tgt_addr  = CART_BASE + {3'b000, cart_offs[21:0]};
	end
end

wire byte_in = ioctl_download & ioctl_wr & tgt_valid;

reg  [3:0] asm_mask = 0;
reg [22:0] asm_offs;
reg [31:0] asm_data;

localparam FIFO_BITS = 9;
localparam FW = 23+4+32;
reg [FW-1:0] fifo[0:(2**FIFO_BITS)-1];
reg [FIFO_BITS-1:0] wptr = 0, rptr = 0;
wire fifo_empty = (wptr == rptr);
reg [FW-1:0] fifo_q;
reg          push = 0;
reg [FW-1:0] push_data;

always @(posedge clk) begin
	if(push) fifo[wptr] <= push_data;
	fifo_q <= fifo[rptr];
end

reg old_download = 0;

always @(posedge clk) begin
	reg  [3:0] m;
	reg [31:0] d;

	push <= 0;

	if(reset) begin
		asm_mask <= 0;
		wptr <= 0;
		old_download <= 0;
	end
	else begin
		old_download <= ioctl_download;
		if(push) wptr <= wptr + 1'd1;

		if(byte_in) begin
			m = asm_mask;
			d = asm_data;
			if(|m && tgt_addr[24:2] != asm_offs) begin
				push <= 1;
				push_data <= {asm_offs, asm_mask, asm_data};
				m = 0;
			end
			m[tgt_addr[1:0]] = 1'b1;
			d[{tgt_addr[1:0], 3'b000} +: 8] = ioctl_dout;
			asm_offs <= tgt_addr[24:2];
			asm_data <= d;
			if(&m) begin
				push <= 1;
				push_data <= {tgt_addr[24:2], m, d};
				asm_mask <= 0;
			end
			else asm_mask <= m;

			if(!is_cart) case(combined ? 6'd0 : idx)
				0: begin
						if(ioctl_addr[15:14] == 2'b01) osxl_off <= 0;
						if(ioctl_addr[15:14] == 2'b10) osa_off <= 0;
						if(ioctl_addr[15:14] == 2'b11) osb_off <= 0;
					end
				1: osxl_off <= 14'h3FFF - ioctl_addr[13:0];
				3: osa_off  <= 14'h3FFF - ioctl_addr[13:0];
				4: osb_off  <= 14'h3FFF - ioctl_addr[13:0];
				default: ;
			endcase
		end
		else if(old_download && !ioctl_download && |asm_mask) begin
			push <= 1;
			push_data <= {asm_offs, asm_mask, asm_data};
			asm_mask <= 0;
		end
	end
end

reg        busy = 0;
reg        fetch = 0;
reg        have = 0;
reg [22:0] cur_offs;
reg  [3:0] cur_mask;
reg [31:0] cur_data;

assign busy_any = ioctl_download | ~fifo_empty | push | (|asm_mask) | busy | fetch | have;

reg       pending_reset = 0;
reg [9:0] reset_cnt = 0;

reg  [7:0] car_type = 0;
reg  [3:0] car_magic = 0;
reg        cart_pending = 0;
wire [7:0] car_mode;
cart_type_map cart_type_map(.car_type(car_type), .mode(car_mode));
always @(posedge clk) begin
	reg [1:0] lane;

	load_req <= 0;
	cart_set <= 0;

	if(reset) begin
		cart_pending <= 0;
		rptr <= 0;
		busy <= 0;
		fetch <= 0;
		have <= 0;
		load_reset <= 0;
		pending_reset <= 0;
	end
	else begin
		if(busy) begin
			if(load_ack) busy <= 0;
		end
		else if(have) begin
			if(&cur_mask) begin
				load_addr    <= {cur_offs, 2'b00};
				load_data    <= cur_data;
				load_width32 <= 1;
				load_req     <= 1;
				busy         <= 1;
				have         <= 0;
			end
			else begin
				lane = cur_mask[0] ? 2'd0 : cur_mask[1] ? 2'd1 : cur_mask[2] ? 2'd2 : 2'd3;
				load_addr    <= {cur_offs, lane};
				load_data    <= {4{cur_data[{lane, 3'b000} +: 8]}};
				load_width32 <= 0;
				load_req     <= 1;
				busy         <= 1;
				cur_mask[lane] <= 1'b0;
				if(cur_mask == (4'b0001 << lane)) have <= 0;
			end
		end
		else if(fetch) begin
			fetch <= 0;
			have <= 1;
			{cur_offs, cur_mask, cur_data} <= fifo_q;
			rptr <= rptr + 1'd1;
		end
		else if(!fifo_empty) begin
			fetch <= 1;
		end

		if(is_cart && ioctl_download) begin
			if(!old_download) begin
				car_magic <= 0;
				car_type <= 0;
				cart_mode <= 0;
				cart_set <= 1;
			end
			if(ioctl_wr) begin
				if(ioctl_addr == 27'd0) car_magic[0] <= (ioctl_dout == "C");
				if(ioctl_addr == 27'd1) car_magic[1] <= (ioctl_dout == "A");
				if(ioctl_addr == 27'd2) car_magic[2] <= (ioctl_dout == "R");
				if(ioctl_addr == 27'd3) car_magic[3] <= (ioctl_dout == "T");
				if(ioctl_addr == 27'd7) car_type <= ioctl_dout;
			end
		end
		if(old_download && !ioctl_download && (idx <= 4 || is_cart)) begin
			pending_reset <= 1;
			cart_pending <= is_cart;
		end

		if(pending_reset && !ioctl_download && fifo_empty && !push && !asm_mask && !busy && !fetch && !have) begin
			pending_reset <= 0;
			load_reset <= 1;
			reset_cnt <= 0;
			if(cart_pending) begin
				cart_pending <= 0;
				cart_mode <= (&car_magic) ? car_mode : 8'h00;
				cart_set <= 1;
			end
		end
		else if(load_reset) begin
			reset_cnt <= reset_cnt + 1'd1;
			if(&reset_cnt) load_reset <= 0;
		end
	end
end

endmodule
