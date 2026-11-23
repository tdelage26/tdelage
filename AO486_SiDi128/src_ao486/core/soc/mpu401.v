module mpu401
(
	input             clk,
	input             rst_n,
	input      [27:0] clock_rate,

	input             io_address,
	input             io_read,
	output reg  [7:0] io_readdata,
	input             io_write,
	input       [7:0] io_writedata,

	output            irq,
	output reg        midi_tx = 1'b1,
	input             midi_rx
);

reg  [27:0] bacc = 0;
reg         tick16 = 0;
always @(posedge clk) begin
	tick16 <= 1'b0;
	if (bacc + 28'd500000 >= clock_rate) begin
		bacc   <= bacc + 28'd500000 - clock_rate;
		tick16 <= 1'b1;
	end else
		bacc   <= bacc + 28'd500000;
end

reg   [7:0] txq [0:63];
reg   [5:0] tx_wp = 0, tx_rp = 0;
reg         tx_full = 0;
wire        tx_empty = (tx_wp == tx_rp) && !tx_full;

reg   [7:0] rxq [0:15];
reg   [3:0] rx_wp = 0, rx_rp = 0;
reg         rx_full = 0;
wire        rx_empty = (rx_wp == rx_rp) && !rx_full;

reg         uart_mode = 0;

reg         q_put;
reg   [7:0] q_byte;
reg         q_put2;
reg   [7:0] q_byte2;

wire        wr_data = io_write && !io_address;
wire        wr_cmd  = io_write &&  io_address;
wire        rd_data = io_read  && !io_address;

reg   [3:0] tx_sub = 0;
reg   [3:0] tx_bit = 0;
reg   [7:0] tx_sh  = 0;
wire        tx_pop = (tx_bit == 0) && !tx_empty;

always @(posedge clk) begin
	if (!rst_n) begin
		tx_bit  <= 0;
		midi_tx <= 1'b1;
	end else if (tx_pop) begin
		tx_sh   <= txq[tx_rp];
		tx_bit  <= 1;
		tx_sub  <= 0;
		midi_tx <= 1'b0;
	end else if (tx_bit != 0 && tick16) begin
		tx_sub <= tx_sub + 1'd1;
		if (tx_sub == 4'd15) begin
			if (tx_bit == 10) begin
				tx_bit  <= 0;
				midi_tx <= 1'b1;
			end else begin
				tx_bit  <= tx_bit + 1'd1;
				if (tx_bit == 9) midi_tx <= 1'b1;
				else begin
					midi_tx <= tx_sh[0];
					tx_sh   <= {1'b1, tx_sh[7:1]};
				end
			end
		end
	end
end

always @(posedge clk) begin
	if (!rst_n) begin
		tx_wp <= 0; tx_rp <= 0; tx_full <= 0;
	end else begin
		if (wr_data && !tx_full) begin
			txq[tx_wp] <= io_writedata;
			tx_wp      <= tx_wp + 1'd1;
		end
		if (tx_pop) tx_rp <= tx_rp + 1'd1;
		if (wr_data && !tx_full && !tx_pop && (tx_wp + 1'd1) == tx_rp) tx_full <= 1'b1;
		else if (tx_pop) tx_full <= 1'b0;
	end
end

reg   [2:0] rx_sync = 3'b111;
always @(posedge clk) rx_sync <= {rx_sync[1:0], midi_rx};
wire        rx_in = rx_sync[2];

reg   [3:0] rx_sub = 0;
reg   [3:0] rx_bit = 0;
reg   [7:0] rx_sh  = 0;
reg         rx_done = 0;
always @(posedge clk) begin
	rx_done <= 1'b0;
	if (!rst_n) rx_bit <= 0;
	else if (tick16) begin
		if (rx_bit == 0) begin
			if (!rx_in) begin rx_bit <= 1; rx_sub <= 0; end
		end else begin
			rx_sub <= rx_sub + 1'd1;
			if (rx_sub == 4'd7) begin
				if (rx_bit == 1) begin
					if (rx_in) rx_bit <= 0;
					else       rx_bit <= 2;
				end else if (rx_bit == 10) begin
					rx_bit  <= 0;
					rx_done <= rx_in;
				end else begin
					rx_sh  <= {rx_in, rx_sh[7:1]};
					rx_bit <= rx_bit + 1'd1;
				end
			end
		end
	end
end

always @(*) begin
	q_put = 0; q_byte = 8'hFE; q_put2 = 0; q_byte2 = 8'h00;
	if (wr_cmd) begin
		q_put = 1'b1;
		if (io_writedata == 8'hAC) begin q_put2 = 1'b1; q_byte2 = 8'h15; end
		if (io_writedata == 8'hAD) begin q_put2 = 1'b1; q_byte2 = 8'h01; end
	end else if (rx_done && uart_mode) begin
		q_put = 1'b1; q_byte = rx_sh;
	end
end

reg   [7:0] pend = 0;
reg         pend_v = 0;

always @(posedge clk) begin
	if (!rst_n) begin
		rx_wp <= 0; rx_rp <= 0; rx_full <= 0; uart_mode <= 0; pend_v <= 0;
	end else begin : rxq_upd
		reg [3:0] wp; reg [3:0] rp; reg full;
		wp = rx_wp; rp = rx_rp; full = rx_full;
		if (wr_cmd) begin
			if (io_writedata == 8'hFF) begin
				uart_mode <= 1'b0;
				rp = wp; full = 0;
			end
			if (io_writedata == 8'h3F) uart_mode <= 1'b1;
		end
		if (rd_data && !(rp == wp && !full)) begin
			rp = rp + 1'd1; full = 0;
		end
		if (q_put && !full) begin
			rxq[wp] <= q_byte; wp = wp + 1'd1; if (wp == rp) full = 1;
		end else if (pend_v && !full) begin
			rxq[wp] <= pend;   wp = wp + 1'd1; if (wp == rp) full = 1;
		end
		if (q_put2)                 begin pend <= q_byte2; pend_v <= 1'b1; end
		else if (pend_v && !q_put)  pend_v <= 1'b0;
		rx_wp <= wp; rx_rp <= rp; rx_full <= full;
	end
end

always @(posedge clk) if (io_read) begin
	if (io_address) io_readdata <= {rx_empty, tx_full, 6'h3F};
	else            io_readdata <= rx_empty ? 8'hFE : rxq[rx_rp];
end

assign irq = !rx_empty;

endmodule
