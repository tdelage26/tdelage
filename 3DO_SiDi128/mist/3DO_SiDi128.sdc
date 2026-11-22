set_time_format -unit ns -decimal_places 3

create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

derive_pll_clocks
derive_clock_uncertainty

set clk_sys {pll_sys|altpll_component|auto_generated|pll1|clk[0]}
set clk_mem {pll_sys|altpll_component|auto_generated|pll1|clk[1]}
set sdram_clk {pll_sys|altpll_component|auto_generated|pll1|clk[2]}
set sdram2_clk {pll_sys|altpll_component|auto_generated|pll1|clk[3]}
set clk_vid {pll_vid|altpll_component|auto_generated|pll1|clk[0]}

set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.6 [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.5 [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_n* SDRAM_DQM* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_n* SDRAM_DQM* SDRAM_CKE}]

set_input_delay  -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 6.6 [get_ports {SDRAM2_DQ[*]}]
set_input_delay  -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min 3.5 [get_ports {SDRAM2_DQ[*]}]
set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 1.5 [get_ports {SDRAM2_DQ[*] SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_n* SDRAM2_DQM* SDRAM2_CKE}]
set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min -0.8 [get_ports {SDRAM2_DQ[*] SDRAM2_A[*] SDRAM2_BA[*] SDRAM2_n* SDRAM2_DQM* SDRAM2_CKE}]

set_multicycle_path -from [get_clocks $sdram_clk]  -to [get_clocks $clk_mem] -setup 2
set_multicycle_path -from [get_clocks $sdram2_clk] -to [get_clocks $clk_mem] -setup 2

set_clock_groups -asynchronous \
	-group [get_clocks {SPI_SCK}] \
	-group [get_clocks {pll_sys|altpll_component|auto_generated|pll1|clk[*]}] \
	-group [get_clocks {pll_vid|altpll_component|auto_generated|pll1|clk[*]}]

set_false_path -to [get_ports {SDRAM_CLK SDRAM2_CLK}]
set_false_path -to [get_ports {AUDIO_L AUDIO_R LED}]

set_false_path -to [get_registers {P3DO:p3do|MADAM:madam|MATH_M[*]}]

set cpu_regs [get_registers {P3DO:p3do|ARM6_CORE:cpu|*}]
set cpu_src  [remove_from_collection $cpu_regs [get_registers {P3DO:p3do|ARM6_CORE:cpu|RES_SYNC}]]
set_multicycle_path -setup 2 -from $cpu_src -to $cpu_regs
set_multicycle_path -hold  1 -from $cpu_src -to $cpu_regs

set m  {P3DO:p3do|MADAM:madam}
set se "$m|MADAM_SE:SE"
set ag "$m|MADAM_AG:AG"
set c  {P3DO:p3do|CLIO:clio}
set ce_src $cpu_src
foreach p [list "$m|MADAM_ARB:ARB|DMA_CTL2*" "$m|MADAM_ARB:ARB|CPU_GRANT" "$m|MADAM_ARB:ARB|EXTP_GRANT" \
                "$m|MADAM_ARB:ARB|SE_GRANT" "$m|MADAM_ARB:ARB|SPORT_GRANT" "$m|MADAM_ARB:ARB|PLAYER_GRANT" \
                "$m|MADAM_ARB:ARB|BUS_PB" "$ag|DMA_ADDR_FF_0*" "$ag|DMA_ADDR_FF_1*" \
                {P3DO:p3do|ARM6_CORE:cpu|STATE*} \
                "$se|DOLO_CYCLE*" "$se|DST_WRITE_B" "$ag|MADAM_DMA_STACK:DMA_STACK|altdpram_lut:altdpram_component|mem*" \
                "$m|MADAM_CPUIF:CPUIF|STRETCH" "$m|MADAM_CPUIF:CPUIF|BREAK" "$m|MADAM_CPUIF:CPUIF|NCYCLE" \
                "$m|MADAM_CPUIF:CPUIF|SCYCLE" "$m|MADAM_CPUIF:CPUIF|ICYCLE*" \
                "$m|MADAM_PLAYER:PLAYER|BUS_STATE_FF*" "$m|MADAM_ARB:ARB|PHASE1" "$m|MADAM_ARB:ARB|PHASE2" \
                "$m|MADAM_CPUIF:CPUIF|nRW_FF" "$m|MADAM_CPUIF:CPUIF|nWB_FF"] {
    set r [get_registers -nowarn $p]
    if {[get_collection_size $r] > 0} { set ce_src [add_to_collection $ce_src $r] }
}

proc ce_regs {prefix names} {
    set r {}
    foreach n $names { lappend r "$prefix|$n" "$prefix|$n.*" "$prefix|$n\[*\]" }
    return $r
}
set pats [list \
  "$se|MADAM_PIP:PIP|*" "$se|MADAM_PIP:PIP_B|*" \
  "$se|MADAM_SPRYTE_DATA_FIFO:SPR_FIFO_A|altdpram_lut:altdpram_component|*" \
  "$se|MADAM_SPRYTE_DATA_FIFO:SPR_FIFO_B|altdpram_lut:altdpram_component|*" \
  "$se|MADAM_MATH_STACK:MATH_REG_STACK|*" \
  "$ag|MADAM_DMA_STACK:DMA_STACK|*" \
  "$m|MADAM_MATH_MATRIX:MATH_MATRIX|*" \
  "$m|MADAM_MATH_VECTOR:MATH_VECTOR0|*" "$m|MADAM_MATH_VECTOR:MATH_VECTOR1|*" \
  "$c|CLIO_DSP_EIRAM:EIRAM|*" "$c|CLIO_DSP_NRAM:NRAM|*" ]
set pats [concat $pats \
  [ce_regs $se {SCOB_PRE0 SCOB_PRE1 SCOB_FLAG SCOBCTL PPMPCA PPMPCB REGCTL0 REGCTL1 REGCTL2 REGCTL3 CFBD_PIPE_A CFBD_PIPE_B SUB_H SUB_V LOAD_BUF}] \
  [ce_regs $ag {REG_ZERO BYPASS_FF OFFS_FF REG_OVF CURR1_LATCH V480 PFL CF CURR_FETCHED}] \
  [ce_regs $m  {MCTL MSYS MATH_DIV_N MATH_MODE MATH_CTRL MATH_START MATH_WORK_BANK MATH_BANK}] \
  [ce_regs "$m|MADAM_SPORT:SPORT" {CLUT_DMACTL}] \
  [ce_regs $c  {EIFIFO_BUF DMAEN INT0_PEND INT1_PEND INT0_EN INT1_EN INT_MODE DSP_SEMAPHORE DMA_BUF IO_DI_LATCH TM_CNT TM_RELOAD TM_CTRL HDELAY UNCLE_BITS VINT0 VINT1 FIFOINIT DSP_GW CSTAT}] \
  [ce_regs {P3DO:p3do} {CPU_DO_FF}] ]
set_multicycle_path -setup 2 -from $ce_src -to $cpu_regs
set_multicycle_path -hold  1 -from $ce_src -to $cpu_regs

foreach p $pats {
    set d [get_keepers -nowarn $p]
    if {[get_collection_size $d] > 0} {
        set_multicycle_path -setup 2 -from $ce_src -to $d
        set_multicycle_path -hold  1 -from $ce_src -to $d
    }
}

set ioa [get_registers -nowarn {ddram_sidi:ddram|io_read_addr[*]}]
if {[get_collection_size $ioa] > 0} {
    set_multicycle_path -end -setup 2 -from [get_clocks $clk_sys] -to $ioa
    set_multicycle_path -end -hold  1 -from [get_clocks $clk_sys] -to $ioa
}

set vcache [get_registers -nowarn {ddram_sidi:ddram|ddr_cache_ram_sidi:*|altdpram_lut:altdpram_component|mem*}]
if {[get_collection_size $vcache] > 0} {
    set_multicycle_path -start -setup 2 -from $vcache -to [get_clocks $clk_sys]
    set_multicycle_path -start -hold  1 -from $vcache -to [get_clocks $clk_sys]
}

set voffs [get_registers -nowarn {sdBRAM4_OFFS[*] sdBRAM1_OFFS[*] sd4_known sd1_known cdBRAM4_OFFS[*] cdBRAM2_OFFS[*] cdBRAM1_OFFS[*]}]
if {[get_collection_size $voffs] > 0} {
    set_multicycle_path -end -setup 2 -from $voffs
    set_multicycle_path -end -hold  1 -from $voffs
}
set iow [get_registers -nowarn {ddram_sidi:ddram|io_write_addr[*] ddram_sidi:ddram|io_write_data[*] ddram_sidi:ddram|io_write_be[*]}]
if {[get_collection_size $iow] > 0} {
    set_multicycle_path -end -setup 2 -from [get_clocks $clk_sys] -to $iow
    set_multicycle_path -end -hold  1 -from [get_clocks $clk_sys] -to $iow
}
set srcl [get_keepers -nowarn {P3DO_VRAM:vram_l|altsyncram:src_lane*|altsyncram_*:auto_generated|ram_block1a* P3DO_VRAM:vram_r|altsyncram:src_lane*|altsyncram_*:auto_generated|ram_block1a*}]
set bwd [get_registers -nowarn {ddram_sidi:ddram|ram_din_b[*] ddram_sidi:ddram|bin_save[*]}]
if {[get_collection_size $srcl] > 0 && [get_collection_size $bwd] > 0} {
    set_multicycle_path -setup 2 -from $srcl -to $bwd
    set_multicycle_path -hold  1 -from $srcl -to $bwd
}
