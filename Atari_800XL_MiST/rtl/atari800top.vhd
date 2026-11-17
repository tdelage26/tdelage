--------------------------------------------------------------------------- -- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

ENTITY atari800top IS 
GENERIC
(
	CYCLE_LENGTH : integer := 16;
	CLK_HZ_NTSC  : integer := 28636364;
	CLK_HZ_PAL   : integer := 28375000;
	ROM_STORE_64K : integer := 16#1F0#
);
PORT
(
	CLK        : IN  STD_LOGIC;
	CLK_SDRAM  : IN  STD_LOGIC;
	RESET_N    : IN  STD_LOGIC;
	CORE_RESET : IN  STD_LOGIC := '0';
	CPU_HOLD   : IN  STD_LOGIC := '0';
	ARESET     : OUT STD_LOGIC;

	PAL        : IN  STD_LOGIC;
	EXT_ANTIC  : IN  STD_LOGIC;
	CLIP_SIDES : IN  STD_LOGIC;
	VGA_VS     : OUT STD_LOGIC;
	VGA_HS     : OUT STD_LOGIC;
	VGA_BLANK  : OUT STD_LOGIC;
	VGA_PIXCE  : OUT STD_LOGIC;
	VGA_B      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_G      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_R      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

	HBLANK     : OUT STD_LOGIC;
	VBLANK     : OUT STD_LOGIC;

	STEREO     : IN  STD_LOGIC;
	AUDIO_L    : OUT STD_LOGIC_VECTOR(15 downto 0);
	AUDIO_R    : OUT STD_LOGIC_VECTOR(15 downto 0);

	SDRAM_BA   : OUT STD_LOGIC_VECTOR(1 downto 0);
	SDRAM_nCS  : OUT STD_LOGIC;
	SDRAM_nRAS : OUT STD_LOGIC;
	SDRAM_nCAS : OUT STD_LOGIC;
	SDRAM_nWE  : OUT STD_LOGIC;
	SDRAM_DQMH : OUT STD_LOGIC;
	SDRAM_DQML : OUT STD_LOGIC;
	SDRAM_CKE  : OUT STD_LOGIC;
	SDRAM_A    : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
	SDRAM_DQ   : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);

	PS2_KEY    : IN  STD_LOGIC_VECTOR(10 downto 0);

	CPU_SPEED  : IN  STD_LOGIC_VECTOR(5 downto 0);
	TURBO_VBLANK_ONLY : IN STD_LOGIC := '0';
	KEY_TYPE   : IN  STD_LOGIC := '0';
	PADDLE_DIS : IN  STD_LOGIC := '0';
	RAM_SIZE   : IN  STD_LOGIC_VECTOR(2 downto 0);
	DRV_SPEED  : IN  STD_LOGIC_VECTOR(2 downto 0);
	XEX_LOC    : IN  STD_LOGIC;
	OS_MODE_800   : IN  STD_LOGIC;
	PBI_MODE      : IN  STD_LOGIC;
	PBI_SPLASH    : IN  STD_LOGIC;
	PBI_DRIVES_MODE : IN STD_LOGIC_VECTOR(7 downto 0);
	PBI_BOOT      : IN STD_LOGIC_VECTOR(2 downto 0);
	ATX_MODE   : IN  STD_LOGIC;
	DRIVE_LED  : OUT STD_LOGIC;
	WARM_RESET_MENU : IN STD_LOGIC;
	COLD_RESET_MENU : IN STD_LOGIC;
	CART_FAST_SET   : IN STD_LOGIC := '0';
	CART_FAST_MODE  : IN STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');
	CART_FAST_CLEAR : IN STD_LOGIC := '0';
	RTC        : IN STD_LOGIC_VECTOR(64 downto 0);

	CPU_HALT   : OUT STD_LOGIC;
	JOY1X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY1Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4Y      : IN  STD_LOGIC_VECTOR(7 downto 0);

	JOY1       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY2       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY3       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY4       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);

	ROM_SEL    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
	OSXL_OFF   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0) := (others=>'0');
	OSA_OFF    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0) := (others=>'0');
	OSB_OFF    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0) := (others=>'0');

	LOAD_REQ   : IN  STD_LOGIC := '0';
	LOAD_ADDR  : IN  STD_LOGIC_VECTOR(24 DOWNTO 0) := (others=>'0');
	LOAD_DATA  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (others=>'0');
	LOAD_WIDTH32 : IN STD_LOGIC := '0';
	LOAD_ACK   : OUT STD_LOGIC;

	SIO_MODE   : IN  STD_LOGIC := '0';
	SIO_IN     : IN  STD_LOGIC;
	SIO_OUT    : OUT STD_LOGIC;
	SIO_CLKOUT : OUT STD_LOGIC;
	SIO_CLKIN  : IN  STD_LOGIC;
	SIO_CMD    : OUT STD_LOGIC;
	SIO_PROC   : IN  STD_LOGIC;
	SIO_MOTOR  : OUT STD_LOGIC;
	SIO_IRQ    : IN  STD_LOGIC;

	ZPU_IN2    : IN  STD_LOGIC_VECTOR(7 downto 0);
	ZPU_OUT2   : OUT STD_LOGIC_VECTOR(31 downto 0);
	ZPU_IN3    : IN  STD_LOGIC_VECTOR(31 downto 0);
	ZPU_OUT3   : OUT STD_LOGIC_VECTOR(31 downto 0);
	ZPU_RD     : OUT STD_LOGIC_VECTOR(15 downto 0);
	ZPU_WR     : OUT STD_LOGIC_VECTOR(15 downto 0)
);

END atari800top;

ARCHITECTURE vhdl OF atari800top IS 

SIGNAL CONSOL_OPTION :  STD_LOGIC;
SIGNAL CONSOL_SELECT :  STD_LOGIC;
SIGNAL CONSOL_START :  STD_LOGIC;
SIGNAL FKEYS : std_logic_vector(11 downto 0);

signal capslock_pressed : std_logic;
signal capsheld_next : std_logic;
signal capsheld_reg : std_logic;

signal JOY1_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY2_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY3_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY4_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY    :  STD_LOGIC_VECTOR(13 DOWNTO 0);
signal JOY1_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY2_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY3_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY4_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY1_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY2_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY3_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY4_Y :  STD_LOGIC_VECTOR(7 downto 0);

SIGNAL KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);

signal SDRAM_REQUEST : std_logic;
signal SDRAM_REQUEST_COMPLETE : std_logic;
signal SDRAM_READ_ENABLE :  STD_LOGIC;
signal SDRAM_WRITE_ENABLE : std_logic;
signal SDRAM_ADDR : STD_LOGIC_VECTOR(24 DOWNTO 0);
signal SDRAM_DO : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_DI : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_WIDTH_8bit_ACCESS : std_logic;
signal SDRAM_WIDTH_16bit_ACCESS : std_logic;
signal SDRAM_WIDTH_32bit_ACCESS : std_logic;

signal SDRAM_REFRESH : std_logic;

signal SDRAM_RESET_N : std_logic;

-- dma/virtual drive
signal DMA_ADDR_FETCH : std_logic_vector(25 downto 0);
signal DMA_WRITE_DATA : std_logic_vector(31 downto 0);
signal DMA_FETCH : std_logic;
signal DMA_32BIT_WRITE_ENABLE : std_logic;
signal DMA_16BIT_WRITE_ENABLE : std_logic;
signal DMA_8BIT_WRITE_ENABLE : std_logic;
signal DMA_READ_ENABLE : std_logic;
signal DMA_MEMORY_READY : std_logic;
signal DMA_MEMORY_DATA : std_logic_vector(31 downto 0);

signal ZPU_ADDR_ROM : std_logic_vector(15 downto 0);
signal ZPU_ROM_DATA :  std_logic_vector(31 downto 0);

signal ZPU_OUT1 : std_logic_vector(31 downto 0);

signal zpu_pokey_enable : std_logic;
signal zpu_sio_txd : std_logic;
signal zpu_sio_rxd : std_logic;
signal zpu_sio_command : std_logic;
signal zpu_sio_clk : std_logic;
signal sio_rxd : std_logic;
signal sio_txd : std_logic;
signal sio_command : std_logic;
signal sio_clk : std_logic;

signal OLD_OUT : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal old_command : std_logic;
signal end_command : std_logic;

-- system control from zpu
signal reset_atari : std_logic;
signal reset_rnmi_atari : std_logic;
signal option_force : std_logic;
signal pause_atari : std_logic;
signal emulated_cartridge_select: std_logic_vector(7 downto 0);
signal emulated_cartridge2_select: std_logic_vector(7 downto 0);
signal fcart_active : std_logic := '0';
signal fcart_mode   : std_logic_vector(7 downto 0) := (others=>'0');
signal fcart_fw_last     : std_logic_vector(7 downto 0) := (others=>'0');

-- ps2
signal PS2_KEYS : STD_LOGIC_VECTOR(511 downto 0);

-- turbo freezer!
signal freezer_enable : std_logic;
signal freezer_activate: std_logic;

-- paddles
signal paddle_1 : std_logic_vector(2 downto 0);
signal paddle_2 : std_logic_vector(2 downto 0);
signal paddle_3 : std_logic_vector(2 downto 0);
signal paddle_4 : std_logic_vector(2 downto 0);

signal areset_n   : std_logic;
signal option_tmp : std_logic;
signal warm_reset_request : std_logic;
signal cold_reset_request : std_logic;

signal RAM_DATA : std_logic_vector(31 downto 0);

signal zpu_dma_addr_fetch : std_logic_vector(25 downto 0);
signal zpu_dma_write_data : std_logic_vector(31 downto 0);
signal zpu_dma_fetch : std_logic;
signal zpu_dma_32bit_write_enable : std_logic;
signal zpu_dma_16bit_write_enable : std_logic;
signal zpu_dma_8bit_write_enable : std_logic;
signal zpu_dma_read_enable : std_logic;
signal zpu_dma_memory_ready : std_logic;
signal load_grant : std_logic := '0';
signal load_busy  : std_logic;
signal load_pending : std_logic := '0';

signal rom_win      : std_logic;
signal rom_hi_win   : std_logic;
signal rom_os       : std_logic;
signal rom_basic    : std_logic;
signal rom_pbi      : std_logic;
signal rom_os_off   : unsigned(13 downto 0);
signal rom_os_idx   : unsigned(13 downto 0);
signal rom_os_base  : std_logic_vector(1 downto 0);
signal rom_ff       : std_logic;
signal rom_os_below : std_logic;
signal rom_bank     : std_logic_vector(8 downto 0);
signal rom_remap    : std_logic;
signal sdram_addr_phys : std_logic_vector(24 downto 0);
signal pbirom_do    : std_logic_vector(7 downto 0);


BEGIN

areset_n <= RESET_N and SDRAM_RESET_N and not reset_atari and not CORE_RESET;
areset <= not areset_n;

process(clk)
	variable cnt : integer := 0;
	variable old_reset : std_logic := '1';
begin
	if rising_edge(clk) then
		if (old_reset = '1' and areset_n = '0') then
			paddle_1 <= "000";
			paddle_2 <= "000";
			paddle_3 <= "000";
			paddle_4 <= "000";
			cnt := 0;
			option_tmp <= '0';
			warm_reset_request <= '0';
			cold_reset_request <= '0';
		else
			if JOY1(6 downto 4) /= "000" then paddle_1(0) <= '0';   end if;
			if JOY1(5) = '1'             then paddle_1(1) <= '1';   end if;
			if JOY1(6) = '1'             then paddle_1(2) <= '1';   end if;
			if JOY1(8 downto 7) /= "00"  then paddle_1    <= "001"; end if;

			if JOY2(6 downto 4) /= "000" then paddle_2(0) <= '0';   end if;
			if JOY2(5) = '1'             then paddle_2(1) <= '1';   end if;
			if JOY2(6) = '1'             then paddle_2(2) <= '1';   end if;
			if JOY2(8 downto 7) /= "00"  then paddle_2    <= "001"; end if;

			if JOY3(6 downto 4) /= "000" then paddle_3(0) <= '0';   end if;
			if JOY3(5) = '1'             then paddle_3(1) <= '1';   end if;
			if JOY3(6) = '1'             then paddle_3(2) <= '1';   end if;
			if JOY3(8 downto 7) /= "00"  then paddle_3    <= "001"; end if;

			if JOY4(6 downto 4) /= "000" then paddle_4(0) <= '0';   end if;
			if JOY4(5) = '1'             then paddle_4(1) <= '1';   end if;
			if JOY4(6) = '1'             then paddle_4(2) <= '1';   end if;
			if JOY4(8 downto 7) /= "00"  then paddle_4    <= "001"; end if;

			if cnt < 75000000 then
				cnt := cnt + 1;
				option_tmp <= option_tmp or option_force or JOY(5);
			else
				option_tmp <= '0';
			end if;
			warm_reset_request <= not(reset_rnmi_atari) and (warm_reset_request or warm_reset_menu);
			cold_reset_request <= cold_reset_request or cold_reset_menu;
		end if;

		old_reset := areset_n;
	end if;
end process;

JOY1_n <= '1'&not(JOY1(8)&JOY1(7))&"11" when (paddle_1(0) = '1' and PADDLE_DIS = '0') else not(JOY1(4)&JOY1(0)&JOY1(1)&JOY1(2)&JOY1(3));
JOY1_X <= JOY1X when (paddle_1(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_1(1) = '0' or JOY1(5) = '1') else X"70";
JOY1_Y <= JOY1Y when (paddle_1(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_1(2) = '0' or JOY1(6) = '1') else X"70";

JOY2_n <= '1'&not(JOY2(8)&JOY2(7))&"11" when (paddle_2(0) = '1' and PADDLE_DIS = '0') else not(JOY2(4)&JOY2(0)&JOY2(1)&JOY2(2)&JOY2(3));
JOY2_X <= JOY2X when (paddle_2(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_2(1) = '0' or JOY2(5) = '1') else X"70";
JOY2_Y <= JOY2Y when (paddle_2(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_2(2) = '0' or JOY2(6) = '1') else X"70";

JOY3_n <= '1'&not(JOY3(8)&JOY3(7))&"11" when (paddle_3(0) = '1' and PADDLE_DIS = '0') else not(JOY3(4)&JOY3(0)&JOY3(1)&JOY3(2)&JOY3(3));
JOY3_X <= JOY3X when (paddle_3(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_3(1) = '0' or JOY3(5) = '1') else X"70";
JOY3_Y <= JOY3Y when (paddle_3(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_3(2) = '0' or JOY3(6) = '1') else X"70";

JOY4_n <= '1'&not(JOY4(8)&JOY4(7))&"11" when (paddle_4(0) = '1' and PADDLE_DIS = '0') else not(JOY4(4)&JOY4(0)&JOY4(1)&JOY4(2)&JOY4(3));
JOY4_X <= JOY4X when (paddle_4(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_4(1) = '0' or JOY4(5) = '1') else X"70";
JOY4_Y <= JOY4Y when (paddle_4(0) = '1' and PADDLE_DIS = '0') else X"80" when (paddle_4(2) = '0' or JOY4(6) = '1') else X"70";

-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari800
generic map (ps2_enable => 0, direct_enable => 1)
PORT MAP
( 
	CLK => clk,
	RESET_N => reset_n,

	INPUT => x"000"&"000"&ps2_key(9)&"000"&ps2_key(8)&x"0"&ps2_key(7 downto 0),
	INPUT2 => JOY(13 downto 9),
	KEY_TYPE => KEY_TYPE,

	KEYBOARD_SCAN => KEYBOARD_SCAN,
	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

	CONSOL_START => CONSOL_START,
	CONSOL_SELECT => CONSOL_SELECT,
	CONSOL_OPTION => CONSOL_OPTION,

	FKEYS => FKEYS,
	FREEZER_ACTIVATE => freezer_activate,

	PS2_KEYS_NEXT_OUT => open,
	PS2_KEYS => ps2_keys
);

atarixl_simple_sdram1 : entity work.atari800core_simple_sdram
GENERIC MAP
(
	cycle_length => CYCLE_LENGTH,
	video_bits => 8,
	palette => 1,
	internal_rom => 0,
	internal_ram => 0
)
PORT MAP
(
	CLK => CLK,
	RESET_N => areset_n,

	VIDEO_VS => VGA_VS,
	VIDEO_HS => VGA_HS,
	VIDEO_CS => open,
	VIDEO_BLANK => VGA_BLANK,
	VIDEO_PIXCE => VGA_PIXCE,
	VIDEO_B => VGA_B,
	VIDEO_G => VGA_G,
	VIDEO_R => VGA_R,

	HBLANK => HBLANK,
	VBLANK => VBLANK,

	STEREO => STEREO,
	AUDIO_L => AUDIO_L,
	AUDIO_R => AUDIO_R,

	JOY1_n => JOY1_n,
	JOY2_n => JOY2_n,
	JOY3_n => JOY3_n,
	JOY4_n => JOY4_n,

	PADDLE0 => signed(JOY1_X),
	PADDLE1 => signed(JOY1_Y),
	PADDLE2 => signed(JOY2_X),
	PADDLE3 => signed(JOY2_Y),
	PADDLE4 => signed(JOY3_X),
	PADDLE5 => signed(JOY3_Y),
	PADDLE6 => signed(JOY4_X),
	PADDLE7 => signed(JOY4_Y),

	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
	KEYBOARD_SCAN => KEYBOARD_SCAN,

	SIO_COMMAND => sio_command,
	SIO_RXD => sio_rxd,
	SIO_TXD => sio_txd,
	SIO_CLOCK => sio_clk,
	SIO_CLOCK_IN => SIO_CLKIN,
	SIO_PROC => SIO_PROC,
	SIO_IRQ  => SIO_IRQ,
	SIO_MOTOR => SIO_MOTOR,

	CONSOL_OPTION => CONSOL_OPTION or option_tmp,
	CONSOL_SELECT => CONSOL_SELECT,
	CONSOL_START => CONSOL_START,

	SDRAM_REQUEST => SDRAM_REQUEST,
	SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
	SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
	SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
	SDRAM_ADDR => SDRAM_ADDR,
	SDRAM_DO => RAM_DATA,
	SDRAM_DI => SDRAM_DI,
	SDRAM_32BIT_WRITE_ENABLE => SDRAM_WIDTH_32bit_ACCESS,
	SDRAM_16BIT_WRITE_ENABLE => SDRAM_WIDTH_16bit_ACCESS,
	SDRAM_8BIT_WRITE_ENABLE => SDRAM_WIDTH_8bit_ACCESS,
	SDRAM_REFRESH => SDRAM_REFRESH,

	DMA_FETCH => dma_fetch,
	DMA_READ_ENABLE => dma_read_enable,
	DMA_32BIT_WRITE_ENABLE => dma_32bit_write_enable,
	DMA_16BIT_WRITE_ENABLE => dma_16bit_write_enable,
	DMA_8BIT_WRITE_ENABLE => dma_8bit_write_enable,
	DMA_ADDR => dma_addr_fetch,
	DMA_WRITE_DATA => dma_write_data,
	MEMORY_READY_DMA => dma_memory_ready,
	DMA_MEMORY_DATA => dma_memory_data, 

	RAM_SELECT => RAM_SIZE,
	PAL => PAL,
	EXT_ANTIC => EXT_ANTIC,
	CLIP_SIDES => CLIP_SIDES,
	RESET_RNMI => reset_rnmi_atari,
	ATARI800MODE => OS_MODE_800,
	PBI_ROM_MODE => PBI_MODE,
	RTC => RTC,
	HALT => pause_atari,
	THROTTLE_COUNT_6502 => CPU_SPEED,
	TURBO_VBLANK_ONLY => TURBO_VBLANK_ONLY,
	emulated_cartridge_select => emulated_cartridge_select,
	emulated_cartridge2_select => emulated_cartridge2_select,
	freezer_enable => freezer_enable,
	freezer_activate => freezer_activate
);

SIO_CLKOUT <= sio_clk;
SIO_OUT    <= sio_txd;
SIO_CMD    <= sio_command;

zpu_sio_rxd     <= sio_txd     when SIO_MODE = '0' else '1';
zpu_sio_command <= sio_command when SIO_MODE = '0' else '1';
zpu_sio_clk     <= sio_clk     when SIO_MODE = '0' else '1';

sio_rxd <= zpu_sio_txd when SIO_MODE = '0' else SIO_IN;

sdram_adaptor : entity work.sdram_statemachine
GENERIC MAP
(
	ADDRESS_WIDTH => 24,
	AP_BIT => 10,
	COLUMN_WIDTH => 9,
	ROW_WIDTH => 13
)
PORT MAP
(
	CLK_SYSTEM => CLK,
	CLK_SDRAM => CLK_SDRAM,
	RESET_N =>  RESET_N,
	READ_EN => SDRAM_READ_ENABLE,
	WRITE_EN => SDRAM_WRITE_ENABLE,
	REQUEST => SDRAM_REQUEST,
	BYTE_ACCESS => SDRAM_WIDTH_8BIT_ACCESS,
	WORD_ACCESS => SDRAM_WIDTH_16BIT_ACCESS,
	LONGWORD_ACCESS => SDRAM_WIDTH_32BIT_ACCESS,
	REFRESH => SDRAM_REFRESH,
	ADDRESS_IN => sdram_addr_phys,
	DATA_IN => SDRAM_DI,
	SDRAM_DQ => SDRAM_DQ,
	COMPLETE => SDRAM_REQUEST_COMPLETE,
	SDRAM_BA0 => SDRAM_BA(0),
	SDRAM_BA1 => SDRAM_BA(1),
	SDRAM_CKE => SDRAM_CKE,
	SDRAM_CS_N => SDRAM_nCS,
	SDRAM_RAS_N => SDRAM_nRAS,
	SDRAM_CAS_N => SDRAM_nCAS,
	SDRAM_WE_N => SDRAM_nWE,
	SDRAM_ldqm => SDRAM_DQML,
	SDRAM_udqm => SDRAM_DQMH,
	DATA_OUT => SDRAM_DO,
	SDRAM_ADDR => SDRAM_A,
	reset_client_n => SDRAM_RESET_N
);

joy <= joy1 or joy2 or joy3 or joy4;

rom_bank   <= std_logic_vector(to_unsigned(ROM_STORE_64K, 9));
rom_win    <= '1' when SDRAM_ADDR(24 downto 15) = "0011100000" else '0';
rom_hi_win <= '1' when SDRAM_ADDR(24 downto 20) = "00111" and rom_win = '0' else '0';
rom_basic  <= '1' when SDRAM_ADDR(14 downto 13) = "00" else '0';
rom_pbi    <= '1' when SDRAM_ADDR(14 downto 13) = "01" else '0';
rom_os     <= SDRAM_ADDR(14);

rom_os_base <= "01" when ROM_SEL(1) = '0' else
               "10" when ROM_SEL(0) = '0' else
               "11";
rom_os_off  <= unsigned(OSXL_OFF) when ROM_SEL(1) = '0' else
               unsigned(OSA_OFF)  when ROM_SEL(0) = '0' else
               unsigned(OSB_OFF);
rom_os_idx  <= unsigned(SDRAM_ADDR(13 downto 0)) - rom_os_off;
rom_os_below <= '1' when unsigned(SDRAM_ADDR(13 downto 0)) < rom_os_off else '0';

rom_ff <= rom_hi_win or
          (rom_win and rom_basic and (ROM_SEL(1) or ROM_SEL(0))) or
          (rom_win and rom_os and rom_os_below);
rom_remap <= rom_win and not(SDRAM_WRITE_ENABLE) and (rom_basic or rom_os);

sdram_addr_phys <= rom_bank & rom_os_base & std_logic_vector(rom_os_idx) when rom_remap = '1' and rom_os = '1' else
                   rom_bank & "000" & SDRAM_ADDR(12 downto 0)          when rom_remap = '1' else
                   SDRAM_ADDR;

RAM_DATA <= x"FFFFFF"&pbirom_do when rom_win = '1' and rom_pbi = '1' else
            (others=>'1')       when rom_ff = '1' else
            SDRAM_DO;

pbirom: entity work.spram
generic map(13,8,"firmware/PBIBIOS.mif")
port map
(
	clock => clk,
	address => SDRAM_ADDR(12 downto 0),
	q => pbirom_do
);

process(clk)
begin
	if rising_edge(clk) then
		LOAD_ACK <= '0';
		if RESET_N = '0' or sdram_reset_n = '0' then
			load_pending <= '0';
			load_grant <= '0';
		else
			if LOAD_REQ = '1' then
				load_pending <= '1';
			end if;
			if areset_n = '0' then
				load_grant <= '0';
			elsif load_grant = '0' then
				if (load_pending = '1' or LOAD_REQ = '1') and zpu_dma_fetch = '0' then
					load_grant <= '1';
				end if;
			elsif dma_memory_ready = '1' then
				load_grant <= '0';
				load_pending <= '0';
				LOAD_ACK <= '1';
			end if;
		end if;
	end if;
end process;
load_busy <= load_grant;

dma_addr_fetch <= '1'&LOAD_ADDR when load_grant = '1' else zpu_dma_addr_fetch;
dma_write_data <= LOAD_DATA when load_grant = '1' else zpu_dma_write_data;
dma_fetch <= load_busy when load_grant = '1' else zpu_dma_fetch;
dma_32bit_write_enable <= load_busy and LOAD_WIDTH32 when load_grant = '1' else zpu_dma_32bit_write_enable;
dma_16bit_write_enable <= '0' when load_grant = '1' else zpu_dma_16bit_write_enable;
dma_8bit_write_enable <= load_busy and not(LOAD_WIDTH32) when load_grant = '1' else zpu_dma_8bit_write_enable;
dma_read_enable <= '0' when load_grant = '1' else zpu_dma_read_enable;
zpu_dma_memory_ready <= '0' when load_grant = '1' else dma_memory_ready;

zpu: entity work.zpucore
GENERIC MAP
(
	platform => 1,
	clk_hz_ntsc => CLK_HZ_NTSC,
	clk_hz_pal => CLK_HZ_PAL
)
PORT MAP
(
	-- standard...
	CLK => CLK,
	RESET_N => RESET_N and sdram_reset_n and not CORE_RESET,
	PAL => PAL,

	-- dma bus master (with many waitstates...)
	ZPU_ADDR_FETCH => zpu_dma_addr_fetch,
	ZPU_DATA_OUT => zpu_dma_write_data,
	ZPU_FETCH => zpu_dma_fetch,
	ZPU_32BIT_WRITE_ENABLE => zpu_dma_32bit_write_enable,
	ZPU_16BIT_WRITE_ENABLE => zpu_dma_16bit_write_enable,
	ZPU_8BIT_WRITE_ENABLE => zpu_dma_8bit_write_enable,
	ZPU_READ_ENABLE => zpu_dma_read_enable,
	ZPU_MEMORY_READY => zpu_dma_memory_ready,
	ZPU_MEMORY_DATA => dma_memory_data, 

	-- rom bus master
	-- data on next cycle after addr
	ZPU_ADDR_ROM => zpu_addr_rom,
	ZPU_ROM_DATA => zpu_rom_data,

	ZPU_ROM_WREN => open,

	-- SIO
	-- Ditto for speaking to Atari, we have a built in Pokey
	ZPU_POKEY_ENABLE => zpu_pokey_enable,
	ZPU_SIO_TXD => zpu_sio_txd,
	ZPU_SIO_RXD => zpu_sio_rxd,
	ZPU_SIO_COMMAND => zpu_sio_command,
	ZPU_SIO_CLK => zpu_sio_clk,

	-- external control
	-- switches etc. sector DMA blah blah.
	-- Originally WinKey Left + Right (#11F + #127) for pausing the core
	-- Potential alternatives for MiSTer not to conflict with Win+PrintScreen:
	-- Right Ctrl #114, Home #16C, End #169, Right Alt #111, Scroll Lock #7E
	-- Right Alt seems to be the only option to account for reduced keyboards
	ZPU_IN1 => X"000"&
			--'0'&(ps2_keys(16#11F#) or ps2_keys(16#127#)) &
			'0'&ps2_keys(16#111#)&
			((ps2_keys(16#76#)&ps2_keys(16#5A#)&ps2_keys(16#174#)&ps2_keys(16#16B#)&ps2_keys(16#172#)&ps2_keys(16#175#)) or (joy(5)&joy(4)&joy(0)&joy(1)&joy(2)&joy(3)))& -- (esc)FRLDU
			(FKEYS(10) and (ps2_keys(16#11f#) or ps2_keys(16#127#)))&(FKEYS(10) and (not ps2_keys(16#11f#)) and (not ps2_keys(16#127#)))&(FKEYS(9) or cold_reset_request)&(FKEYS(8) or warm_reset_request)&FKEYS(7 downto 0),
	ZPU_IN2 => X"0" & '0' & PBI_BOOT & PBI_DRIVES_MODE & ZPU_IN2 & PBI_SPLASH & PBI_MODE & ATX_MODE & XEX_LOC & OS_MODE_800 & DRV_SPEED,
	ZPU_IN3 => ZPU_IN3,
	ZPU_IN4 => X"00000000",
	
	ZPU_RD => ZPU_RD,
	ZPU_WR => ZPU_WR,

	-- ouputs - e.g. Atari system control, halt, throttle, rom select
	ZPU_OUT1 => zpu_out1,
	ZPU_OUT2 => zpu_out2,
	ZPU_OUT3 => zpu_out3
);

pause_atari <= zpu_out1(0) or CPU_HOLD;
reset_atari <= zpu_out1(1);
emulated_cartridge2_select <= zpu_out1(16 downto 9);
process(CLK)
begin
	if rising_edge(CLK) then
		if RESET_N = '0' or CORE_RESET = '1' then
			fcart_active <= '0';
		elsif CART_FAST_SET = '1' then
			fcart_active <= '1';
			fcart_mode <= CART_FAST_MODE;
			fcart_fw_last <= zpu_out1(24 downto 17);
		elsif CART_FAST_CLEAR = '1' or (fcart_active = '1' and zpu_out1(24 downto 17) /= fcart_fw_last) then
			fcart_active <= '0';
		end if;
	end if;
end process;
emulated_cartridge_select <= fcart_mode when fcart_active = '1' else zpu_out1(24 downto 17);
freezer_enable <= zpu_out1(25);
reset_rnmi_atari <= zpu_out1(26);
DRIVE_LED <= zpu_out1(27);
option_force <= zpu_out1(28);

CPU_HALT <= pause_atari;

zpu_rom1: entity work.spram
generic map(12,32,"firmware/zpu_rom_800.mif")
port map
(
	clock => clk,
	address => zpu_addr_rom(13 downto 2),
	q => zpu_rom_data
);

enable_179_clock_div_zpu_pokey : entity work.enable_divider
	generic map (COUNT=>CYCLE_LENGTH)
	port map(clk=>clk,reset_n=>reset_n,enable_in=>'1',enable_out=>zpu_pokey_enable);

END vhdl;
