create_clock -name CLOCK_27 -period 37.037 [get_ports {CLOCK_27}]
create_clock -name SPI_SCK  -period 41.666 [get_ports {SPI_SCK}]
create_clock -name QSCK     -period 20.000 [get_ports {QSCK}]

derive_pll_clocks
derive_clock_uncertainty

set clk_sys [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}]

set_clock_groups -asynchronous \
	-group [get_clocks {SPI_SCK}] \
	-group [get_clocks {QSCK}] \
	-group $clk_sys

set_multicycle_path -setup -from [get_registers {*Raiden_audio_z80*}] -to [get_registers {*Raiden_audio_z80*}] 24
set_multicycle_path -hold  -from [get_registers {*Raiden_audio_z80*}] -to [get_registers {*Raiden_audio_z80*}] 23

foreach cpu {Raiden_main_top Raiden_sub_top} {
	set cpu_all [get_registers "*${cpu}*u_cpu*cpu*"]
	set cpu_div [get_registers "*${cpu}*u_cpu*divider:idivider*"]
	set cpu_dst [remove_from_collection $cpu_all $cpu_div]
	set_multicycle_path -setup -from $cpu_all -to $cpu_dst 2
	set_multicycle_path -hold  -from $cpu_all -to $cpu_dst 1
}
foreach cpu {Raiden_main_top Raiden_sub_top} {
	set exe_from [get_registers [list \
		"*${cpu}*u_cpu*cpu:u_cpu|regs.*" \
		"*${cpu}*u_cpu*cpu:u_cpu|source1.*" "*${cpu}*u_cpu*cpu:u_cpu|source2.*" \
		"*${cpu}*u_cpu*cpu:u_cpu|fetch1Val*" "*${cpu}*u_cpu*cpu:u_cpu|fetch2Val*" \
		"*${cpu}*u_cpu*cpu:u_cpu|memFetchValue*" "*${cpu}*u_cpu*cpu:u_cpu|stringLoad*" \
		"*${cpu}*u_cpu*cpu:u_cpu|MODRM_value_reg*" "*${cpu}*u_cpu*cpu:u_cpu|immidiate8*" \
		"*${cpu}*u_cpu*cpu:u_cpu|aluop.*" "*${cpu}*u_cpu*cpu:u_cpu|opsize*" \
		"*${cpu}*u_cpu*cpu:u_cpu|popval*" "*${cpu}*u_cpu*cpu:u_cpu|memAddr*" ]]
	set exe_to [get_registers [list \
		"*${cpu}*u_cpu*cpu:u_cpu|regs.*" \
		"*${cpu}*u_cpu*cpu:u_cpu|bus_dw_exe*" ]]
	set_multicycle_path -setup -from $exe_from -to $exe_to 4
	set_multicycle_path -hold  -from $exe_from -to $exe_to 3
}

set_multicycle_path -setup -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*raiden_video_subbus*pal_*}] 4
set_multicycle_path -hold  -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*raiden_video_subbus*pal_*}] 3
set_multicycle_path -setup -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*pal_b_addr*}] 4
set_multicycle_path -hold  -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*pal_b_addr*}] 3
set_multicycle_path -setup -from [get_registers {*Raiden_main_top*ctrl_reg[6]*}] -to [get_registers {*pal_b_addr*}] 4
set_multicycle_path -hold  -from [get_registers {*Raiden_main_top*ctrl_reg[6]*}] -to [get_registers {*pal_b_addr*}] 3
set_multicycle_path -setup -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*is_backdrop_d*}] 4
set_multicycle_path -hold  -from [get_registers {*Raiden_video_timing*hpos*}] -to [get_registers {*is_backdrop_d*}] 3
set_multicycle_path -setup -from [get_registers {*Raiden_main_top*ctrl_reg[6]*}] -to [get_registers {*is_backdrop_d*}] 4
set_multicycle_path -hold  -from [get_registers {*Raiden_main_top*ctrl_reg[6]*}] -to [get_registers {*is_backdrop_d*}] 3

foreach cpu {Raiden_main_top Raiden_sub_top} {
	set wram [get_registers [list "*${cpu}*altsyncram:ram_*" "*raiden_shared_ram*altsyncram:mem_*"]]
	set cpu_all [get_registers "*${cpu}*u_cpu*cpu*"]
	set_multicycle_path -setup -from $wram -to $cpu_all 2
	set_multicycle_path -hold  -from $wram -to $cpu_all 1
}

set_false_path -to   [get_ports {SDRAM_* SDRAM2_*}]
set_false_path -from [get_ports {SDRAM_DQ[*] SDRAM2_DQ[*]}]

set_false_path -to   [get_ports {VGA_* AUDIO_L AUDIO_R I2S_* LED SPI_DO}]

set_false_path -to   [get_ports {HDMI_R[*] HDMI_G[*] HDMI_B[*] HDMI_HS HDMI_VS HDMI_DE HDMI_PCLK}]
set_false_path -to   [get_ports {HDMI_SDA HDMI_SCL HDMI_RST HDMI_MCLK HDMI_BCK HDMI_LRCK HDMI_SDATA}]
set_false_path -from [get_ports {HDMI_SDA HDMI_SCL HDMI_INT}]
set_false_path -from [get_ports {SPI_DI SPI_SS2 SPI_SS3 CONF_DATA0 QCSn QDAT[*]}]
