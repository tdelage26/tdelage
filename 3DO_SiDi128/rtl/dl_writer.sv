module dl_writer
(
	input             clk,
	input             download,
	input             kanji,
	input             ioctl_wr,
	input      [26:0] ioctl_addr,
	input      [15:0] ioctl_data,

	input             io_busy,
	output reg [19:0] io_addr,
	output reg [31:0] io_din,
	output reg [ 3:0] io_we,
	output            idle
);

	reg [15:0] hi;
	reg [50:0] fifo [0:31];
	reg [ 4:0] wp = 0, rp = 0;
	reg [ 5:0] fill = 0;

	wire       push = download && ioctl_wr && ioctl_addr[1];
	wire       pop;

	always @(posedge clk) begin
		if (download && ioctl_wr && !ioctl_addr[1]) hi <= {ioctl_data[7:0], ioctl_data[15:8]};
		if (push) begin
			fifo[wp] <= {kanji, ioctl_addr[19:2], hi, ioctl_data[7:0], ioctl_data[15:8]};
			wp <= wp + 1'd1;
		end
		if (pop) rp <= rp + 1'd1;
		fill <= fill + (push ? 6'd1 : 6'd0) - (pop ? 6'd1 : 6'd0);
	end

	reg [1:0] s = 0;
	reg [1:0] cnt;
	reg [3:0] tmo;
	assign pop  = (s == 2'd0) && (fill != 0);
	assign idle = (s == 2'd0) && (fill == 0);

	always @(posedge clk) begin
		case (s)
			2'd0: begin
				io_we <= 4'b0000;
				if (fill != 0) begin
					{io_addr, io_din} <= {1'b0, fifo[rp]};
					io_we <= 4'b1111;
					cnt <= 2'd2;
					tmo <= 4'd15;
					s <= 2'd1;
				end
			end
			2'd1: begin
				if (cnt) cnt <= cnt - 1'd1;
				else io_we <= 4'b0000;
				if (io_busy) s <= 2'd2;
				else if (!cnt) begin
					if (tmo) tmo <= tmo - 1'd1;
					else s <= 2'd2;
				end
			end
			2'd2: begin
				io_we <= 4'b0000;
				if (!io_busy) s <= 2'd0;
			end
			default: s <= 2'd0;
		endcase
	end

endmodule
