module driver_sd #(
	parameter CLKDIV=2, parameter ADDR_IS_BLOCK=1, parameter BYTE0_LSB=1
)(
	input clk, input rst_n,
	input [1:0] avs_address, input avs_read, output [31:0] avs_readdata,
	input avs_write, input [31:0] avs_writedata,
	output [31:0] avm_address, input avm_waitrequest, output avm_read,
	input [31:0] avm_readdata, input avm_readdatavalid,
	output avm_write, output [31:0] avm_writedata,
	output reg spi_cs_n, output reg spi_sck, output reg spi_mosi, input spi_miso,
	output [95:0] dbg
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

	reg write_start, write_next; reg [31:0] write_data; wire write_done;
	reg read_start, read_next;
	wire [31:0] read_data; wire read_done;
	avalon_master master(.clk(clk), .rst_n(rst_n),
		.avm_address(avm_address), .avm_waitrequest(avm_waitrequest),
		.avm_read(avm_read), .avm_readdata(avm_readdata),
		.avm_readdatavalid(avm_readdatavalid),
		.avm_write(avm_write), .avm_writedata(avm_writedata),
		.avalon_address_base(avalon_address_base),
		.read_start(read_start), .read_next(read_next), .read_data(read_data), .read_done(read_done),
		.write_start(write_start), .write_next(write_next),
		.write_data(write_data), .write_done(write_done));

	reg [7:0] tx_byte, rx_byte; reg spi_go, spi_busy, spi_done;
	reg [3:0] bitcnt; reg [7:0] divcnt, shreg;
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin spi_sck<=0; spi_mosi<=1; spi_busy<=0; spi_done<=0;
			bitcnt<=0; divcnt<=0; shreg<=8'hFF; rx_byte<=0;
		end else begin
			spi_done<=0;
			if(!spi_busy) begin spi_sck<=0;
				if(spi_go) begin spi_busy<=1; bitcnt<=4'd8; divcnt<=0;
					shreg<=tx_byte; spi_mosi<=tx_byte[7]; end
			end else if(divcnt!=CLKDIV) divcnt<=divcnt+1'b1;
			else begin divcnt<=0;
				if(!spi_sck) spi_sck<=1'b1;
				else begin spi_sck<=1'b0; rx_byte<={rx_byte[6:0],spi_miso}; bitcnt<=bitcnt-1'b1;
					if(bitcnt==4'd1) begin spi_busy<=0; spi_done<=1; end
					else begin shreg<={shreg[6:0],1'b0}; spi_mosi<=shreg[6]; end
				end
			end
		end
	end

	localparam ST_IDLE=0,ST_PWRUP=1,ST_INIT=2,ST_CMD=3,ST_R1=4,ST_RDCMD=5,
	           ST_RTOK=6,ST_RDBYTE=7,ST_RDEMIT=8,ST_RDCRC=9,ST_WRERR=10,
	           ST_DRAIN=11,ST_RCHK=12,ST_RECOV=13,
	           ST_WRCMD=14,ST_WCHK=15,ST_WGAP=16,ST_WTOKEN=17,ST_WFETCH=18,ST_WBYTE=19,
	           ST_WCRC=20,ST_WRESP=21,ST_WBUSY=22,ST_WRECOV=23;
	reg [4:0] st, st_ret, drain_ret;
	reg fetch_req; reg [4:0] wresp_cnt; reg [21:0] wbusy; reg [2:0] init_step, cmdb, extra;
	reg [7:0] cmd_i, cmd_crc, r1; reg [31:0] cmd_a, cur_sector;
	reg [9:0] dcnt; reg [1:0] bsel, crccnt; reg [31:0] wword;
	reg [8:0] pwr; reg sp, got_r1, emit_done, first_word;
	reg [9:0] drain_cnt; reg [5:0] r1polls; reg [15:0] tokwait; reg [7:0] n_retry;

	function [7:0] cmdbyte; input [2:0] n;
		cmdbyte = (n==0)? {2'b01,cmd_i[5:0]} : (n==1)? cmd_a[31:24] :
		          (n==2)? cmd_a[23:16] : (n==3)? cmd_a[15:8] :
		          (n==4)? cmd_a[7:0] : cmd_crc;
	endfunction
	task issue; input [7:0] b; begin tx_byte<=b; spi_go<=1'b1; sp<=1'b1; end endtask
	task send_cmd; input [7:0] idx; input [31:0] arg; input [7:0] crc; input [2:0] ex; input [4:0] ret;
		begin cmd_i<=idx; cmd_a<=arg; cmd_crc<=crc; extra<=ex; cmdb<=0; got_r1<=0; r1polls<=0; st_ret<=ret; st<=ST_CMD; end
	endtask

	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			st<=ST_IDLE; st_ret<=ST_IDLE; drain_ret<=ST_IDLE; spi_go<=0; spi_cs_n<=1'b1;
			init_step<=0; cmdb<=0; sp<=0; dcnt<=0; bsel<=0; extra<=0; crccnt<=0;
			write_start<=0; write_next<=0; write_data<=0; got_r1<=0; emit_done<=0; first_word<=0;
			read_start<=0; read_next<=0; fetch_req<=0; wresp_cnt<=0; wbusy<=0;
			operation_sector_update<=0; operation_finished_ok<=0;
			operation_finished_with_error<=0; pwr<=0; cur_sector<=0; wword<=0; r1<=8'hFF;
			drain_cnt<=0; r1polls<=0; tokwait<=0; n_retry<=0;
			cmd_i<=0; cmd_a<=0; cmd_crc<=8'hFF;
		end else begin
			spi_go<=0; write_start<=0; write_next<=0; read_start<=0; read_next<=0;
			operation_sector_update<=0; operation_finished_ok<=0;
			operation_finished_with_error<=0;
			case(st)
			ST_IDLE: begin sp<=0; cmdb<=0; got_r1<=0;
				if(operation_finished_ok || operation_finished_with_error) ;
				else if(operation_init) begin spi_cs_n<=1'b1; pwr<=9'd160; st<=ST_PWRUP; end
				else if(operation_read) begin cur_sector<=sd_address; first_word<=1'b1; st<=ST_RDCMD; end
				else if(operation_write) begin cur_sector<=sd_address; first_word<=1'b1; st<=ST_WRCMD; end
			end
			ST_PWRUP: if(!spi_busy && !spi_go) begin
				if(pwr!=0) begin issue(8'hFF); sp<=0; pwr<=pwr-1'b1; end
				else begin spi_cs_n<=1'b0; init_step<=0; st<=ST_INIT; end
			end
			ST_INIT: case(init_step)
				0: begin init_step<=1; drain_ret<=ST_INIT; send_cmd(8'd12, 32'h0, 8'hFF, 3'd0, ST_DRAIN); end
				1: begin init_step<=2; send_cmd(8'd0, 32'h0, 8'h95, 3'd0, ST_INIT); end
				2: if(r1==8'h01) begin init_step<=3; send_cmd(8'd8, 32'h1AA, 8'h87, 3'd4, ST_INIT); end
				   else begin init_step<=0; n_retry<=n_retry+1'd1; end
				3: if(r1==8'h01 && rx_byte==8'hAA) begin init_step<=4; send_cmd(8'd55, 32'h0, 8'hFF, 3'd0, ST_INIT); end
				   else begin init_step<=0; n_retry<=n_retry+1'd1; end
				4: if(r1[7:1]==7'd0) begin init_step<=5; send_cmd(8'd41, 32'h40000000, 8'hFF, 3'd0, ST_INIT); end
				   else begin init_step<=0; n_retry<=n_retry+1'd1; end
				5: if(r1==8'h00) begin operation_finished_ok<=1; st<=ST_IDLE; end
				   else if(r1==8'h01) begin init_step<=4; send_cmd(8'd55, 32'h0, 8'hFF, 3'd0, ST_INIT); end
				   else begin init_step<=0; n_retry<=n_retry+1'd1; end
				default: init_step<=0;
			endcase
			ST_DRAIN: if(!spi_busy && !spi_go) begin
				if(sp) sp<=0;
				if(drain_cnt==0) begin drain_cnt<=10'd600; end
				if(drain_cnt==10'd1) begin drain_cnt<=0; st<=drain_ret; end
				else begin issue(8'hFF); sp<=0; if(drain_cnt!=0) drain_cnt<=drain_cnt-1'b1; end
			end
			ST_RECOV: begin n_retry<=n_retry+1'd1; drain_ret<=ST_RDCMD; send_cmd(8'd12, 32'h0, 8'hFF, 3'd0, ST_DRAIN); end
			ST_RDCMD: send_cmd(8'd17, ADDR_IS_BLOCK ? cur_sector : (cur_sector<<9), 8'hFF, 3'd0, ST_RCHK);
			ST_RCHK: if(r1==8'h00) begin tokwait<=0; st<=ST_RTOK; end else st<=ST_RECOV;
			ST_CMD: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(cmdbyte(cmdb)); end
				else if(spi_done) begin sp<=0;
					if(cmdb==3'd5) begin cmdb<=0; st<=ST_R1; end else cmdb<=cmdb+1'b1;
				end
			end
			ST_R1: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(!got_r1) begin
						if(!rx_byte[7]) begin r1<=rx_byte; got_r1<=1'b1;
							if(extra==0) begin got_r1<=0; st<=st_ret; end end
						else if(r1polls==6'd40) begin r1<=8'hFF; got_r1<=0; st<=st_ret; end
						else r1polls<=r1polls+1'd1;
					end else begin
						if(extra<=3'd1) begin got_r1<=0; st<=st_ret; end
						extra<=extra-1'b1;
					end
				end
			end
			ST_RTOK: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(rx_byte==8'hFE) begin dcnt<=0; bsel<=0; st<=ST_RDBYTE; end
					else if(rx_byte!=8'hFF || (&tokwait)) st<=ST_RECOV;
					else tokwait<=tokwait+1'd1;
				end
			end
			ST_RDBYTE: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(BYTE0_LSB) wword[8*bsel +: 8] <= rx_byte;
					else          wword[8*(2'd3-bsel) +: 8] <= rx_byte;
					dcnt<=dcnt+1'b1;
					if(bsel==2'd3) st<=ST_RDEMIT; else bsel<=bsel+1'b1;
				end
			end
			ST_RDEMIT: begin
				if(!emit_done) begin write_data<=wword;
					if(first_word) write_start<=1'b1; else write_next<=1'b1;
					first_word<=1'b0;
					emit_done<=1'b1;
				end else if(write_done) begin emit_done<=1'b0; bsel<=0;
					if(dcnt==10'd512) begin crccnt<=0; st<=ST_RDCRC; end else st<=ST_RDBYTE;
				end
			end
			ST_RDCRC: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(crccnt==2'd1) begin operation_sector_update<=1'b1;
						if(operation_sector_last) begin operation_finished_ok<=1'b1; st<=ST_IDLE; end
						else begin cur_sector<=cur_sector+1'b1; st<=ST_RDCMD; end
					end else crccnt<=crccnt+1'b1;
				end
			end
			ST_WRERR: begin operation_finished_with_error<=1'b1; st<=ST_IDLE; end
			ST_WRCMD: send_cmd(8'd24, ADDR_IS_BLOCK ? cur_sector : (cur_sector<<9), 8'hFF, 3'd0, ST_WCHK);
			ST_WCHK:  if(r1==8'h00) st<=ST_WGAP; else st<=ST_WRECOV;
			ST_WRECOV: if(n_retry[3:0]==4'hF) begin n_retry<=n_retry+1'd1; st<=ST_WRERR; end
			           else begin n_retry<=n_retry+1'd1; drain_ret<=ST_WRCMD; send_cmd(8'd12, 32'h0, 8'hFF, 3'd0, ST_DRAIN); end
			ST_WGAP: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0; st<=ST_WTOKEN; end
			end
			ST_WTOKEN: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFE); end
				else if(spi_done) begin sp<=0; dcnt<=0; bsel<=0; fetch_req<=0; st<=ST_WFETCH; end
			end
			ST_WFETCH: begin
				if(!fetch_req) begin fetch_req<=1'b1;
					if(first_word) read_start<=1'b1; else read_next<=1'b1;
					first_word<=1'b0;
				end else if(read_done) begin fetch_req<=1'b0; wword<=read_data; bsel<=0; st<=ST_WBYTE; end
			end
			ST_WBYTE: begin
				if(sp==0) begin if(!spi_busy && !spi_go)
					issue(BYTE0_LSB ? wword[8*bsel +: 8] : wword[8*(2'd3-bsel) +: 8]); end
				else if(spi_done) begin sp<=0; dcnt<=dcnt+1'b1;
					if(bsel!=2'd3) bsel<=bsel+1'b1;
					else if(dcnt==10'd511) begin crccnt<=0; st<=ST_WCRC; end
					else st<=ST_WFETCH;
				end
			end
			ST_WCRC: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(crccnt==2'd1) begin wresp_cnt<=0; st<=ST_WRESP; end else crccnt<=crccnt+1'b1;
				end
			end
			ST_WRESP: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(!rx_byte[4] && rx_byte[0]) begin
						if(rx_byte[3:1]==3'b010) begin wbusy<=0; st<=ST_WBUSY; end
						else st<=ST_WRERR;
					end else if(&wresp_cnt) st<=ST_WRERR;
					else wresp_cnt<=wresp_cnt+1'd1;
				end
			end
			ST_WBUSY: begin
				if(sp==0) begin if(!spi_busy && !spi_go) issue(8'hFF); end
				else if(spi_done) begin sp<=0;
					if(rx_byte==8'hFF) begin operation_sector_update<=1'b1;
						if(operation_sector_last) begin operation_finished_ok<=1'b1; st<=ST_IDLE; end
						else begin cur_sector<=cur_sector+1'b1; st<=ST_WRCMD; end
					end else if(&wbusy) st<=ST_WRERR;
					else wbusy<=wbusy+1'd1;
				end
			end
			default: st<=ST_IDLE;
			endcase
		end
	end
	reg [15:0] n_sect, n_cmd, n_wr;
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin n_sect<=0; n_cmd<=0; n_wr<=0; end
		else begin
			if(operation_sector_update) n_sect<=n_sect+1'd1;
			if(st==ST_CMD && sp && spi_done && cmdb==3'd5) n_cmd<=n_cmd+1'd1;
			if(write_done || read_done) n_wr<=n_wr+1'd1;
		end
	end
	assign dbg = { st[3:0], init_step[2:0], spi_busy, spi_cs_n, spi_sck, spi_mosi, spi_miso,
	               got_r1, emit_done, first_word, st[4],
	               r1, rx_byte,
	               n_sect, n_cmd, n_wr,
	               cmd_i, n_retry };
endmodule
