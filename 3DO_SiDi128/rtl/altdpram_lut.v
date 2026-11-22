module altdpram_lut (
	input  [width-1:0]         data,
	input                      inclock,
	input                      outclock,
	input  [widthad-1:0]       rdaddress,
	input  [widthad-1:0]       wraddress,
	input                      wren,
	output [width-1:0]         q,
	input                      aclr,
	input  [width_byteena-1:0] byteena,
	input                      inclocken,
	input                      outclocken,
	input                      rdaddressstall,
	input                      rden,
	input                      sclr,
	input                      wraddressstall
);
	parameter width          = 8;
	parameter widthad        = 4;
	parameter width_byteena  = 1;
	parameter byte_size      = 8;
	parameter numwords       = 0;
	parameter indata_aclr    = "OFF";
	parameter indata_reg     = "INCLOCK";
	parameter intended_device_family = "Cyclone 10 LP";
	parameter lpm_type       = "altdpram";
	parameter outdata_aclr   = "OFF";
	parameter outdata_reg    = "UNREGISTERED";
	parameter ram_block_type = "AUTO";
	parameter rdaddress_aclr = "OFF";
	parameter rdaddress_reg  = "UNREGISTERED";
	parameter rdcontrol_aclr = "OFF";
	parameter rdcontrol_reg  = "UNREGISTERED";
	parameter read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE";
	parameter wraddress_aclr = "OFF";
	parameter wraddress_reg  = "INCLOCK";
	parameter wrcontrol_aclr = "OFF";
	parameter wrcontrol_reg  = "INCLOCK";
	parameter power_up_uninitialized = "FALSE";
	parameter lpm_hint       = "UNUSED";
	parameter use_eab        = "ON";

	localparam LANE = (width_byteena > 1) ? byte_size : width;

	reg [width-1:0] mem [0:(2**widthad)-1] /* synthesis ramstyle = "logic" */;

	integer i;
	always @(posedge inclock) begin
		if (inclocken && wren && !wraddressstall) begin
			for (i = 0; i < width_byteena; i = i + 1)
				if (byteena[i])
					mem[wraddress][i*LANE +: LANE] <= data[i*LANE +: LANE];
		end
	end

	assign q = mem[rdaddress];

endmodule
