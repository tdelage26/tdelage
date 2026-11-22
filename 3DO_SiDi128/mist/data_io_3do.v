// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
// Copyright (c) 2015-2017 Sorgelig
// Copyright (c) 2019-2023 György Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

module data_io_3do
(
	input             clk_sys,

	input             SPI_SCK,
	input             SPI_SS2,
	input             SPI_DI,
	output reg        SPI_DO,

	input             reset,

	input      [64:0] cd_in,

	output reg [15:0] CDD_DATA,
	output reg        CDD_WR,
	output            CDD_DTEN,
	output            CDD_DIEN,

	output reg        info_wr,
	output reg [11:0] info_addr,
	output reg [15:0] info_data
);

localparam CD_STAT_GET    = 8'h60;
localparam CD_COMMAND_GET = 8'h62;
localparam CD_DATA_SEND   = 8'h64;
localparam CD_INFO_SEND   = 8'h65;

reg       spi_receiver_strobe_r = 0;
reg       spi_transfer_end_r = 1;
reg [7:0] spi_byte_in;
reg [7:0] cmd;
reg [2:0] bit_cnt;
reg [3:0] byte_cnt;

always@(posedge SPI_SCK or posedge SPI_SS2) begin : data_input
	reg  [6:0] sbuf;

	if(SPI_SS2) begin
		spi_transfer_end_r <= 1;
		bit_cnt <= 0;
		cmd <= 0;
		byte_cnt <= 0;
	end else begin
		spi_transfer_end_r <= 0;
		bit_cnt <= bit_cnt + 1'd1;
		if(bit_cnt != 7) sbuf[6:0] <= { sbuf[5:0], SPI_DI };
		if(bit_cnt == 7) begin
			if (~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;
			if (cmd == 0) cmd <= { sbuf, SPI_DI};
			spi_byte_in <= { sbuf, SPI_DI};
			spi_receiver_strobe_r <= ~spi_receiver_strobe_r;
		end
	end
end

reg  [7:0] cd_req = 0, cd_seen = 0;
reg        cd_tog_old = 0;
always @(posedge clk_sys) begin
	cd_tog_old <= cd_in[64];
	if (cd_tog_old ^ cd_in[64]) cd_req <= cd_req + 1'd1;
end
reg  cd_reset_req = 1;
wire cmd_pending = (cd_req != cd_seen);
wire [7:0] cd_status = {6'd0, reset | cd_reset_req, cmd_pending};

always@(negedge SPI_SCK or posedge SPI_SS2) begin : data_output
	if(SPI_SS2) begin
		SPI_DO <= 1'bZ;
	end else begin
		if(cmd == CD_COMMAND_GET)
			SPI_DO <= cd_in[{ byte_cnt[2:0] - 1'd1, ~bit_cnt }];
		else if(cmd == 0 || cmd[7:4] == 4'h6)
			SPI_DO <= cd_status[~bit_cnt];
		else
			SPI_DO <= 1'bZ;
	end
end

reg  [7:0] acmd;
reg [11:0] abyte_cnt;
reg  [7:0] lo_byte;
reg        spi_receiver_strobe, spi_receiver_strobeD;
reg        spi_transfer_end, spi_transfer_endD, spi_transfer_end_old;

assign CDD_DTEN = (acmd == CD_DATA_SEND) && !spi_transfer_end;
assign CDD_DIEN = (acmd == CD_INFO_SEND) && !spi_transfer_end;

always @(posedge clk_sys) begin
	CDD_WR  <= 0;
	info_wr <= 0;

	if (reset) cd_reset_req <= 1;

	spi_receiver_strobeD <= spi_receiver_strobe_r;
	spi_receiver_strobe  <= spi_receiver_strobeD;
	spi_transfer_endD    <= spi_transfer_end_r;
	spi_transfer_end     <= spi_transfer_endD;
	spi_transfer_end_old <= spi_transfer_end;

	if (spi_transfer_end && !spi_transfer_end_old && acmd == CD_STAT_GET && !reset)
		cd_reset_req <= 0;

	if (spi_transfer_end) begin
		abyte_cnt <= 0;
		if (!spi_transfer_end_old) acmd <= 0;
	end else if (spi_receiver_strobeD ^ spi_receiver_strobe) begin
		if (~&abyte_cnt) abyte_cnt <= abyte_cnt + 1'd1;

		if (abyte_cnt == 0) begin
			acmd <= spi_byte_in;
			if (spi_byte_in == CD_COMMAND_GET) cd_seen <= cd_req;
		end else begin
			case (acmd)
				CD_DATA_SEND, CD_INFO_SEND:
					if (abyte_cnt[0]) lo_byte <= spi_byte_in;
					else begin
						CDD_DATA  <= {spi_byte_in, lo_byte};
						CDD_WR    <= 1;
						info_data <= {spi_byte_in, lo_byte};
						info_addr <= abyte_cnt - 12'd2;
						info_wr   <= (acmd == CD_INFO_SEND);
					end
				default: ;
			endcase
		end
	end
end

endmodule
