
set_time_format -unit ns -decimal_places 3

create_clock -name clk_27  -period 37.037 [get_ports {CLOCK_27}]
create_clock -name SPI_SCK -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

derive_pll_clocks
derive_clock_uncertainty

set mem_clk   "pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[0]"
set sys_clk   "pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[1]"
set sdram_clk "pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[2]"

set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -min 3.2 [get_ports SDRAM_DQ[*]]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup 2

if {[get_collection_size [get_cells -nowarn {*vbxe_vram|*}]] > 0} {
	set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM2_CLK] -max 6.4 [get_ports SDRAM2_DQ[*]]
	set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM2_CLK] -min 3.2 [get_ports SDRAM2_DQ[*]]
	set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM2_CLK] -max 1.5 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]
	set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM2_CLK] -min -0.8 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]
}

set_output_delay -clock [get_clocks $sys_clk] -max 0  [get_ports {VGA_*}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports {VGA_*}]
set_multicycle_path -to [get_ports {VGA_*}] -setup 2
set_multicycle_path -to [get_ports {VGA_*}] -hold 1

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {pll_switcher|*}]
set_clock_groups -asynchronous -group [get_clocks {clk_27}] -group [get_clocks {pll_switcher|*}]
set_clock_groups -asynchronous -group [get_clocks {reconfig_pll|*}] -group [get_clocks {pll_switcher|*}]
set_clock_groups -asynchronous -group [get_clocks {reconfig_pll|*}] -group [get_clocks {SPI_SCK}]

set_false_path -to [get_ports {AUDIO_L AUDIO_R LED UART_TX}]
set_false_path -from [get_ports {UART_RX}]

set_false_path -to [get_registers {pll_switcher|*CLKCTRLX*|*ena_reg}]

