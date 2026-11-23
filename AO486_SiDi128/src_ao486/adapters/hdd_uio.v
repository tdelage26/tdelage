module hdd_uio (
	input             clk,
	input             rst_n,

	input       [1:0] avs_address,
	input             avs_read,
	output     [31:0] avs_readdata,
	input             avs_write,
	input      [31:0] avs_writedata,

	output     [31:0] avm_address,
	output            avm_read,
	input      [31:0] avm_readdata,
	input             avm_readdatavalid,
	output            avm_write,
	output     [31:0] avm_writedata,

	output reg        cfg_req,
	output reg [15:0] cfg_addr,
	output reg [31:0] cfg_data,
	input             cfg_ack,

	input             mounted,
	input      [31:0] img_sectors,
	input             grant,
	output reg        busy,
	output reg        uio_rd,
	output reg        uio_wr,
	output reg [31:0] uio_lba,
	input             uio_ack,
	input       [8:0] buff_addr,
	input       [7:0] buff_dout,
	input             buff_wr,
	output reg  [7:0] buff_din
);

	wire operation_init, operation_read, operation_write, operation_sector_last;
	reg  operation_sector_update, operation_finished_ok, operation_finished_with_error;
	wire [31:0] sd_address, avalon_address_base;
	avalon_slave slave(.clk(clk), .rst_n(rst_n),
		.avs_address(avs_address), .avs_read(avs_read), .avs_readdata(avs_readdata),
		.avs_write(avs_write), .avs_writedata(avs_writedata),
		.operation_init(operation_init), .operation_read(operation_read),
		.operation_write(operation_write),
		.operation_sector_update(operation_sector_update),
		.operation_sector_last(operation_sector_last),
		.operation_finished_ok(operation_finished_ok),
		.operation_finished_with_error(operation_finished_with_error),
		.sd_address(sd_address), .avalon_address_base(avalon_address_base));

	reg write_start, write_next, read_start, read_next; reg [31:0] write_data;
	wire write_done, read_done; wire [31:0] read_data;
	avalon_master master(.clk(clk), .rst_n(rst_n),
		.avm_address(avm_address), .avm_waitrequest(1'b0),
		.avm_read(avm_read), .avm_readdata(avm_readdata),
		.avm_readdatavalid(avm_readdatavalid),
		.avm_write(avm_write), .avm_writedata(avm_writedata),
		.avalon_address_base(avalon_address_base),
		.read_start(read_start), .read_next(read_next), .read_data(read_data), .read_done(read_done),
		.write_start(write_start), .write_next(write_next),
		.write_data(write_data), .write_done(write_done));

	wire [31:0] cyl_full = img_sectors >> 12;
	wire [15:0] cyl      = (|cyl_full[31:16]) ? 16'hFFFF : cyl_full[15:0];
	wire [31:0] total    = img_sectors;

	function [15:0] idw; input [7:0] w;
		case (w)
			8'd0:   idw = 16'h0040;
			8'd1:   idw = cyl;
			8'd3:   idw = 16'd16;
			8'd4:   idw = 16'd0;
			8'd5:   idw = 16'd512;
			8'd6:   idw = 16'd256;
			8'd10:  idw = {"A","O"};  8'd11: idw = {"H","D"};  8'd12: idw = {"0","1"};
			8'd13:  idw = {"0","0"};  8'd14: idw = {"0"," "};
			8'd15, 8'd16, 8'd17, 8'd18, 8'd19: idw = {" "," "};
			8'd20:  idw = 16'd3;
			8'd21:  idw = 16'd512;
			8'd22:  idw = 16'd4;
			8'd27:  idw = {"A","O"};  8'd28: idw = {" ","D"};  8'd29: idw = {":"," "};
			8'd30:  idw = {"V","H"};  8'd31: idw = {"D"," "};
			8'd32, 8'd33, 8'd34, 8'd35, 8'd36, 8'd37, 8'd38, 8'd39, 8'd40,
			8'd41, 8'd42, 8'd43, 8'd44, 8'd45, 8'd46: idw = {" "," "};
			8'd47:  idw = 16'd16;
			8'd48:  idw = 16'd1;
			8'd49:  idw = 16'h0200;
			8'd51:  idw = 16'h0200;
			8'd52:  idw = 16'h0200;
			8'd53:  idw = 16'h0007;
			8'd54:  idw = cyl;
			8'd55:  idw = 16'd16;
			8'd56:  idw = 16'd256;
			8'd57:  idw = total[15:0];
			8'd58:  idw = total[31:16];
			8'd60:  idw = total[15:0];
			8'd61:  idw = total[31:16];
			8'd65, 8'd66, 8'd67, 8'd68: idw = 16'd120;
			8'd80:  idw = 16'h007E;
			8'd82:  idw = 16'h4000;
			8'd83:  idw = 16'h7400;
			8'd84:  idw = 16'h4000;
			8'd85:  idw = 16'h4000;
			8'd86:  idw = 16'h7400;
			8'd87:  idw = 16'h4000;
			8'd93:  idw = 16'h6001;
			8'd100: idw = total[15:0];
			8'd101: idw = total[31:16];
			default: idw = 16'h0000;
		endcase
	endfunction

	reg  [7:0] cfg_step;
	reg        cfg_done;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cfg_step <= 8'd0; cfg_done <= 1'b0; cfg_req <= 1'b0; cfg_addr <= 16'd0; cfg_data <= 32'd0;
		end else if (!cfg_done) begin
			if (cfg_req) begin
				if (cfg_ack) begin cfg_req <= 1'b0; cfg_step <= cfg_step + 1'd1; end
			end else if (!mounted) cfg_done <= 1'b1;
			else begin
				cfg_req <= 1'b1;
				if (cfg_step < 8'd128) begin
					cfg_addr <= 16'hF100;
					cfg_data <= {idw({cfg_step[6:0], 1'b1}), idw({cfg_step[6:0], 1'b0})};
				end else case (cfg_step)
					8'd128: begin cfg_addr <= 16'hF102; cfg_data <= 32'd16;   end
					8'd129: begin cfg_addr <= 16'hF103; cfg_data <= 32'd256;  end
					8'd130: begin cfg_addr <= 16'hF104; cfg_data <= 32'd4096; end
					8'd131: begin cfg_addr <= 16'hF105; cfg_data <= total;    end
					8'd132: begin cfg_addr <= 16'hF106; cfg_data <= 32'd0;    end
					8'd133: begin cfg_addr <= 16'hF439; cfg_data <= 32'h10;   end
					8'd134: begin cfg_addr <= 16'hF101; cfg_data <= {16'd0, cyl}; end
					default: begin cfg_req <= 1'b0; cfg_done <= 1'b1; end
				endcase
			end
		end
	end

	reg [7:0] lane0 [0:127], lane1 [0:127], lane2 [0:127], lane3 [0:127];
	reg [6:0] wb_idx; reg wb_we; reg [31:0] wb_data;
	always @(posedge clk) if (wb_we) begin
		lane0[wb_idx] <= wb_data[7:0];   lane1[wb_idx] <= wb_data[15:8];
		lane2[wb_idx] <= wb_data[23:16]; lane3[wb_idx] <= wb_data[31:24];
	end
	reg [7:0] q0, q1, q2, q3; reg [1:0] qsel;
	always @(posedge clk) begin
		q0 <= lane0[buff_addr[8:2]]; q1 <= lane1[buff_addr[8:2]];
		q2 <= lane2[buff_addr[8:2]]; q3 <= lane3[buff_addr[8:2]];
		qsel <= buff_addr[1:0];
	end
	always @* case (qsel) 2'd0: buff_din = q0; 2'd1: buff_din = q1; 2'd2: buff_din = q2; default: buff_din = q3; endcase

	localparam S_IDLE=0, S_RD_REQ=1, S_RD_XFER=2, S_WR_FETCH=3, S_WR_WAIT=4, S_WR_REQ=5, S_WR_XFER=6, S_NEXT=7, S_ERR=8;
	reg [3:0]  st;
	reg [31:0] cur;
	reg        first_word, ack_d, fetch_pend;
	reg [31:0] rword;
	reg [7:0]  wcnt;
	reg [26:0] tmo;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			st <= S_IDLE; cur <= 0; first_word <= 0; ack_d <= 0; fetch_pend <= 0; rword <= 0; wcnt <= 0; tmo <= 0;
			busy <= 0; uio_rd <= 0; uio_wr <= 0; uio_lba <= 0;
			write_start <= 0; write_next <= 0; read_start <= 0; read_next <= 0; write_data <= 0;
			wb_we <= 0; wb_idx <= 0; wb_data <= 0;
			operation_sector_update <= 0; operation_finished_ok <= 0; operation_finished_with_error <= 0;
		end else begin
			write_start <= 0; write_next <= 0; read_start <= 0; read_next <= 0; wb_we <= 0;
			operation_sector_update <= 0; operation_finished_ok <= 0; operation_finished_with_error <= 0;
			ack_d <= uio_ack;
			case (st)
			S_IDLE: begin
				busy <= 0;
				if (operation_finished_ok || operation_finished_with_error) ;
				else if (operation_init) operation_finished_ok <= 1'b1;
				else if (operation_read)  begin cur <= sd_address; first_word <= 1'b1; st <= mounted ? S_RD_REQ  : S_ERR; end
				else if (operation_write) begin cur <= sd_address; first_word <= 1'b1; wcnt <= 0; fetch_pend <= 0; st <= mounted ? S_WR_FETCH : S_ERR; end
			end
			S_RD_REQ: if (grant) begin
				busy <= 1'b1; uio_lba <= cur; uio_rd <= 1'b1; wcnt <= 0; tmo <= 0; st <= S_RD_XFER;
			end
			S_RD_XFER: begin
				tmo <= tmo + 1'd1;
				if (uio_ack && !ack_d) uio_rd <= 1'b0;
				if (uio_ack && buff_wr) begin
					rword[8*buff_addr[1:0] +: 8] <= buff_dout;
					if (buff_addr[1:0] == 2'd3) begin
						write_data <= {buff_dout, rword[23:0]};
						if (first_word) write_start <= 1'b1; else write_next <= 1'b1;
						first_word <= 1'b0; wcnt <= wcnt + 1'd1;
					end
				end
				if (!uio_ack && ack_d) st <= (wcnt == 8'd128) ? S_NEXT : S_ERR;
				else if (&tmo) begin uio_rd <= 1'b0; st <= S_ERR; end
			end
			S_WR_FETCH: begin
				if (!fetch_pend) begin
					fetch_pend <= 1'b1;
					if (first_word) read_start <= 1'b1; else read_next <= 1'b1;
					first_word <= 1'b0;
				end else if (read_done) begin
					fetch_pend <= 1'b0;
					wb_we <= 1'b1; wb_idx <= wcnt[6:0]; wb_data <= read_data;
					wcnt <= wcnt + 1'd1;
					if (wcnt == 8'd127) st <= S_WR_REQ;
				end
			end
			S_WR_REQ: if (grant) begin
				busy <= 1'b1; uio_lba <= cur; uio_wr <= 1'b1; tmo <= 0; st <= S_WR_XFER;
			end
			S_WR_XFER: begin
				tmo <= tmo + 1'd1;
				if (uio_ack && !ack_d) uio_wr <= 1'b0;
				if (!uio_ack && ack_d) st <= S_NEXT;
				else if (&tmo) begin uio_wr <= 1'b0; st <= S_ERR; end
			end
			S_NEXT: begin
				busy <= 1'b0;
				operation_sector_update <= 1'b1;
				if (operation_sector_last) begin operation_finished_ok <= 1'b1; st <= S_IDLE; end
				else begin
					cur <= cur + 1'd1; wcnt <= 0;
					st <= operation_write ? S_WR_FETCH : S_RD_REQ;
				end
			end
			S_ERR: begin busy <= 1'b0; operation_finished_with_error <= 1'b1; st <= S_IDLE; end
			default: st <= S_IDLE;
			endcase
		end
	end
endmodule
