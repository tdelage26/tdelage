module gus_spram #(parameter AW = 5, parameter DW = 8) (
	input               clock,
	input      [AW-1:0] address,
	input      [DW-1:0] data,
	input               wren,
	output reg [DW-1:0] q
);
	reg [DW-1:0] mem [0:(1<<AW)-1];
	always @(posedge clock) begin
		if (wren) begin mem[address] <= data; q <= data; end
		else q <= mem[address];
	end
endmodule
