module ps2_host #(parameter CLK_HZ=30000000)(
	input clk, input reset,
	input ps2_clk_i, output reg ps2_clk_o,
	input ps2_dat_i, output reg ps2_dat_o,
	output reg [7:0] rx_data, output reg rx_valid,
	input  [7:0] tx_data, input tx_send, output reg tx_busy, output reg tx_done
);
	localparam integer INHIB = CLK_HZ/10000;
	localparam integer QUIET = CLK_HZ/5000;
	localparam integer RXTMO = CLK_HZ/500;

	reg [2:0] cq, dq;
	always @(posedge clk) begin cq<={cq[1:0],ps2_clk_i}; dq<={dq[1:0],ps2_dat_i}; end
	wire ps2d  = dq[2];
	wire cfall = cq[2] & ~cq[1];

	localparam S_IDLE=0,S_INHIB=1,S_BITS=2,S_STOP=3,S_ACK=4;
	reg [2:0] st;
	reg [3:0] bitpos;
	reg [3:0] txidx;
	reg [8:0] txframe;
	reg [15:0] tcnt;
	reg [16:0] quiet;
	reg        tx_pend;

	always @(posedge clk or posedge reset) begin
		if(reset) begin
			st<=S_IDLE; ps2_clk_o<=1; ps2_dat_o<=1; rx_valid<=0; rx_data<=0;
			bitpos<=0; txidx<=0; tx_busy<=0; tx_done<=0; tcnt<=0; txframe<=0; quiet<=0; tx_pend<=0;
		end else begin
			rx_valid<=0; tx_done<=0;
			if(cfall) quiet<=0; else if(~&quiet) quiet<=quiet+1'd1;
			if(tx_send && !tx_pend) begin
				tx_pend<=1; tx_busy<=1; txframe<={~(^tx_data), tx_data};
			end
			case(st)
			S_IDLE: begin
				ps2_clk_o<=1; ps2_dat_o<=1;
				if(tx_pend && bitpos==4'd0 && (quiet>=QUIET || rx_valid)) begin
					txidx<=0; tcnt<=INHIB[15:0]; ps2_clk_o<=0; st<=S_INHIB;
				end else if(cfall) begin
					if(bitpos==4'd0) begin
						if(!ps2d) bitpos<=4'd1;
					end else if(bitpos<=4'd8) begin
						rx_data<={ps2d, rx_data[7:1]};
						bitpos<=bitpos+4'd1;
					end else if(bitpos==4'd9) begin
						bitpos<=4'd10;
					end else begin
						rx_valid<=1'b1; bitpos<=4'd0;
					end
				end else if(bitpos!=4'd0 && quiet>=RXTMO) bitpos<=4'd0;
			end
			S_INHIB: begin
				if(tcnt!=0) tcnt<=tcnt-1'b1;
				else begin ps2_dat_o<=0; st<=S_BITS; quiet<=0; end
			end
			S_BITS: if(cfall) begin
				ps2_dat_o<=txframe[txidx];
				if(txidx==4'd8) st<=S_STOP; else txidx<=txidx+4'd1;
			end
			S_STOP: if(cfall) begin ps2_dat_o<=1; st<=S_ACK; end
			S_ACK:  if(cfall) begin ps2_clk_o<=1; tx_pend<=0; tx_busy<=0; tx_done<=1; st<=S_IDLE; end
			default: st<=S_IDLE;
			endcase
			if(st!=S_IDLE && st!=S_INHIB && quiet>=RXTMO) begin
				ps2_clk_o<=1; ps2_dat_o<=1; tx_pend<=0; tx_busy<=0; tx_done<=1; st<=S_IDLE;
			end
		end
	end
endmodule

module ps2_io #(parameter CLK_HZ=30000000)(
	input clk, input reset,
	input kb_clk_i, output kb_clk_o, input kb_dat_i, output kb_dat_o,
	input ms_clk_i, output ms_clk_o, input ms_dat_i, output ms_dat_o,
	output [7:0] kbd_data, output kbd_data_valid,
	input  [8:0] kbd_host_data, output reg kbd_host_data_clear,
	output [7:0] mouse_data, output mouse_data_valid,
	input  [8:0] mouse_host_cmd, output reg mouse_host_cmd_clear
);
	wire kb_busy, kb_done, ms_busy, ms_done;
	reg  kb_send, ms_send;

	ps2_host #(CLK_HZ) kb(.clk(clk), .reset(reset),
		.ps2_clk_i(kb_clk_i), .ps2_clk_o(kb_clk_o),
		.ps2_dat_i(kb_dat_i), .ps2_dat_o(kb_dat_o),
		.rx_data(kbd_data), .rx_valid(kbd_data_valid),
		.tx_data(kb_byte), .tx_send(kb_send),
		.tx_busy(kb_busy), .tx_done(kb_done));

	ps2_host #(CLK_HZ) ms(.clk(clk), .reset(reset),
		.ps2_clk_i(ms_clk_i), .ps2_clk_o(ms_clk_o),
		.ps2_dat_i(ms_dat_i), .ps2_dat_o(ms_dat_o),
		.rx_data(mouse_data), .rx_valid(mouse_data_valid),
		.tx_data(ms_byte), .tx_send(ms_send),
		.tx_busy(ms_busy), .tx_done(ms_done));

	reg  [7:0] kb_byte, ms_byte;
	reg        kb_wait, ms_wait;
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			kb_send<=0; ms_send<=0; kbd_host_data_clear<=0; mouse_host_cmd_clear<=0;
			kb_wait<=0; ms_wait<=0; kb_byte<=0; ms_byte<=0;
		end else begin
			kbd_host_data_clear<=0; mouse_host_cmd_clear<=0; kb_send<=0; ms_send<=0;
			if(!kbd_host_data[8]) kb_wait<=0;
			else if(!kb_wait && !kb_busy && !kb_send) begin
				kb_byte<=kbd_host_data[7:0]; kb_send<=1'b1; kbd_host_data_clear<=1'b1; kb_wait<=1'b1;
			end
			if(!mouse_host_cmd[8]) ms_wait<=0;
			else if(!ms_wait && !ms_busy && !ms_send) begin
				ms_byte<=mouse_host_cmd[7:0]; ms_send<=1'b1; mouse_host_cmd_clear<=1'b1; ms_wait<=1'b1;
			end
		end
	end
endmodule
