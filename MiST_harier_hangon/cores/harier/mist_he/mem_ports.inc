`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    input cen_pcm8, cen_pcm, // 15999999 = 50318176*15702/49381 Hz 
    input cen_nc, cen_mcu, // 7999999 = 50318176*7851/49381 Hz 
    input cen_fm2, cen_fm, // 4000000 = 50318176*5123/64445 Hz 

    // Audio channels
    output mute,
    
    output signed [15:0] fm,output signed [15:0] opn_l,
    output signed [15:0] opn_r,
    output [ 9:0] psg,output signed [15:0] pcm_l,
    output signed [15:0] pcm_r,
    // Memory ports
`ifdef JTFRAME_SDRAM_XL
    input   [23:0]  prog_addr,
`elsif JTFRAME_SDRAM_LARGE
    input   [22:0]  prog_addr,
`else
    input   [21:0]  prog_addr,
`endif
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
`ifdef JTFRAME_SDRAM_XL
    input   [26:0]  ioctl_addr,
`else
    input   [25:0]  ioctl_addr,
`endif
    input           prom_we,
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_ram,
    input           ioctl_cart,
    // Explicit ports
    output   [15:0] main_dout,
    input   [15:0] roadram_dout,
    output   [1:0] roadram_we,
    output   [11:1] rdram_addr,
    input   [15:0] objram_dout,
    input   [15:0] pal_dout,
    input   [15:0] pal_vdata,
    output   [1:0] main_dsn,
    output    sub_ram_cs,
    output   [1:0] sub_dsn,
    output    gfx_cs,
    input   [15:0] rdram_dout,
    input   [15:0] objdma_dout,
    output   [1:0] pal_we,
    output   [11:1] pal_vaddr,
    output   [15:0] sub_cpu_dout,
    output    subrom_cs_main,
    output   [11:1] roadram_addr,
    output   [15:0] roadram_din,
    output   [1:0] objram_we,
    output   [11:1] objdma_addr,
    output   [10:0] zoom_addr,
    input   [7:0] zoom_data,
    // Buses to BRAM

    
    
    
    
    // Buses to SDRAM
    input    [15:0] xram_data,
    output          xram_cs,
    output   [16:1] xram_addr,
    output          xram_we,
    input           xram_ok,

    input    [15:0] shram_data,
    output          shram_we,
    input           shram_ok,

    input    [15:0] main_data,
    output          main_cs,
    output   [17:1] main_addr,
    input           main_ok,

    input    [15:0] map1_data,
    output   [15:1] map1_addr,
    input           map1_ok,

    input    [15:0] map2_data,
    output   [15:1] map2_addr,
    input           map2_ok,

    input    [15:0] subrom_data,
    output          subrom_cs,
    output   [15:1] subrom_addr,
    input           subrom_ok,

    input    [ 7:0] snd_data,
    output          snd_cs,
    output   [14:0] snd_addr,
    input           snd_ok,

    input    [ 7:0] pcm_data,
    output          pcm_cs,
    output   [18:0] pcm_addr,
    input           pcm_ok,

    input    [15:0] subrom2_data,
    input           subrom2_ok,

    input    [31:0] char_data,
    output   [16:2] char_addr,
    input           char_ok,

    input    [31:0] scr1_data,
    output   [16:2] scr1_addr,
    input           scr1_ok,

    input    [31:0] scr2_data,
    output   [16:2] scr2_addr,
    input           scr2_ok,

    input    [31:0] obj_data,
    output          obj_cs,
    output   [19:2] obj_addr,
    input           obj_ok,

    input    [15:0] road_data,
    output          road_cs,
    output   [14:1] road_addr,
    input           road_ok
