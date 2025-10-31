library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.types.all;
use work.util.all;

entity USB3_FG is
	Generic (
		VERSION			: integer := 16#0100#;	-- Set by TCL
		BUILD			: integer := 0;			-- Set by TCL
		TIMESTAMP		: integer := 0;			-- Set by TCL
		
		CL_INPUT_WIDTH		: integer := 8;
		CL_INPUT_CHANNELS	: integer := 3;
		CL_INVERT			: std_logic_vector(4 downto 0) := "11100";
			
		INVERT_CLK		: boolean := true;
			
		UART_BAUDRATE	: integer := 921600;
		UART_FLOW_CTRL	: boolean := FALSE;
		SIMULATION		: boolean := FALSE
	);
	Port (
		CLK_I			: in	STD_LOGIC;
		
		-- GPIF
		DQ_O			: out	STD_LOGIC_VECTOR (31 downto  0) := (others => '0');
		CTL_IO			: inout	STD_LOGIC_VECTOR (29 downto 17) := (others => 'Z');
		PCLK_O			: out	STD_LOGIC := '0';
		INT_O			: out	STD_LOGIC := '0';
		
		-- LPP
		SCL_IO			: inout	STD_LOGIC := 'Z';
		SDA_IO			: inout	STD_LOGIC := 'Z';
		MOSI_RX_I		: in	STD_LOGIC;
		MISO_TX_O		: out	STD_LOGIC := '0';
		CS_I			: in	STD_LOGIC;
		SCK_I			: in	STD_LOGIC;
		
		-- Misc
		LED_O			: out	STD_LOGIC_VECTOR (1 downto 0)  := "00";
		POCL_O			: out	STD_LOGIC := '0';
		
		-- FLASH
		FLASH_CS_O		: out	STD_LOGIC := '1';
		FLASH_SCK_O		: out	STD_LOGIC := '0';
		FLASH_MOSI_O	: out	STD_LOGIC := '0';
		FLASH_MISO_I	: in	STD_LOGIC := '0';
		
		-- CameraLink
		CL_CLK_Ip		: in	STD_LOGIC;
		CL_CLK_In		: in	STD_LOGIC;

		CL_DATA_Ip		: in	STD_LOGIC_VECTOR (3 downto 0);
		CL_DATA_In		: in	STD_LOGIC_VECTOR (3 downto 0);

		CL_CC_Op		: out	STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
		CL_CC_On		: out	STD_LOGIC_VECTOR (3 downto 0) := (others => '1');
		
		CL_TFG_Ip		: in	STD_LOGIC;
		CL_TFG_In		: in	STD_LOGIC;
		
		CL_TC_Op		: out	STD_LOGIC := '1';	-- Idle High
		CL_TC_On		: out	STD_LOGIC := '0'
	);
end USB3_FG;

architecture Behavioral of USB3_FG is

-- Clocks
constant CL_CLK_FREQ		: real :=  80.0;	--MHz
constant SYS_CLK_FREQ		: real := 100.0;	--MHz

signal clk100				: std_logic;
signal rst100				: std_logic := '1';
signal clk_ready			: std_logic;

signal clk_cl				: std_logic;
signal clk_cl_ext			: std_logic;
signal clk_cl_int			: std_logic;

signal blink_led			: std_logic := '0';
signal blink_cnt			: std_logic_vector(25 downto 0) := (others => '0');

-- Registers
constant NR_OF_REGS			: integer := 32;

signal reg_dv				: std_logic_vector(NR_OF_REGS-1 downto 0);
signal reg					: array16_t(0 to NR_OF_REGS-1);

signal reg_ack				: std_logic;
signal reg_addr				: std_logic_vector( 7 downto 0);
signal reg_data_r			: std_logic_vector(15 downto 0);
signal reg_data_w			: std_logic_vector(15 downto 0);
signal reg_write			: std_logic;
signal reg_read				: std_logic;

-- Timestamp
signal ts_set				: std_logic := '0';
signal ts_data_set			: std_logic_vector(31 downto 0) := (others => '0');
signal ps_set				: std_logic := '0';
signal ps_data_set			: std_logic_vector( 7 downto 0) := (others => '0');
signal ts_data				: std_logic_vector(31 downto 0) := (others => '0');
signal pulse_1hz			: std_logic := '0';
signal pulse_1khz			: std_logic := '0';
signal pulse_1mhz			: std_logic := '0';

-- SPI Flash
signal flash_new_cmd		: std_logic := '0';
signal flash_cmd			: std_logic_vector( 7 downto 0);
signal flash_new_data_w		: std_logic := '0';
signal flash_data_w			: std_logic_vector(31 downto 0);

signal flash_rtr			: std_logic := '0';
signal flash_rts			: std_logic := '0';
signal flash_busy			: std_logic := '0';

signal flash_new_data_r		: std_logic := '0';
signal flash_data_r			: std_logic_vector(31 downto 0);

signal reconfig				: std_logic := '0';

-- UART		
constant UART_CMD_BITS		: integer := 8;
constant UART_CMD_MAX_ARGS	: integer := 4;

signal UART_RX_I			: std_logic := '1';
signal UART_TX_O			: std_logic := '1';
signal UART_CTS_O			: std_logic;
signal UART_RTS_O			: std_logic;

signal uart_arb_nack		: std_logic;
signal uart_arb_ack			: std_logic;

-- CMD UART Decoder
signal cmd_uart_rx_busy		: std_logic;
signal cmd_uart_tx_busy		: std_logic;

signal cmd_decoder_rx_busy	: std_logic;
signal cmd_decoder_tx_busy	: std_logic;

signal cmd_uart_put			: std_logic;
signal cmd_uart_put_ack		: std_logic;
signal cmd_uart_put_char	: std_logic_vector(7 downto 0) := (others => '0');
signal cmd_uart_put_full	: std_logic;

signal cmd_uart_get			: std_logic;
signal cmd_uart_get_ack		: std_logic;
signal cmd_uart_get_char	: std_logic_vector(7 downto 0) := (others => '0');
signal cmd_uart_get_empty	: std_logic;

-- UART CMD Handler
signal cmd_uart_new_cmd		: std_logic;
signal cmd_uart_cmd_ack		: std_logic;
signal cmd_uart_cmd_id		: std_logic_vector(UART_CMD_BITS-1 downto 0) := (others => '0');
signal cmd_uart_cmd_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0) := (others => '0');
signal cmd_uart_cmd_argn	: std_logic_vector(clogb2(UART_CMD_MAX_ARGS+1)-1 downto 0);

signal cmd_uart_new_ack		: std_logic;
signal cmd_uart_new_nack	: std_logic;

signal cmd_uart_new_reply	: std_logic;
signal cmd_uart_reply_ack	: std_logic;
signal cmd_uart_reply_id	: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal cmd_uart_reply_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);
signal cmd_uart_reply_argn	: std_logic_vector(clogb2(UART_CMD_MAX_ARGS+1)-1 downto 0);

signal zero					: std_logic := '0';
signal cl_reg_1				: std_logic_vector(5 downto 0) := (others => '0');
signal cl_reg_1_sync		: std_logic_vector(5 downto 0) := (others => '0');

-- Cameralink UART		
signal cl_uart_tx			: std_logic := '1';
signal cl_uart_rx			: std_logic := '1';

signal cl_uart_rx_busy		: std_logic;
signal cl_uart_tx_busy		: std_logic;

signal cl_uart_put			: std_logic;
signal cl_uart_put_ack		: std_logic;
signal cl_uart_put_char		: std_logic_vector(7 downto 0) := (others => '0');
signal cl_uart_put_full		: std_logic;
signal cl_uart_get			: std_logic;
signal cl_uart_get_ack		: std_logic;
signal cl_uart_get_char		: std_logic_vector(7 downto 0) := (others => '0');
signal cl_uart_get_empty	: std_logic;

-- Cameralink
constant CL_TAPS			: integer := 2;
constant CL_TAPWIDTH		: integer := 8;
constant CL_BITDEPTH		: integer := 16;

signal cl_cc				: std_logic_vector(3 downto 0) := "0000";
signal cl_dval				: std_logic;
signal cl_lval				: std_logic;
signal cl_fval				: std_logic;
signal cl_spare				: std_logic;
signal cl_data_int			: std_logic_vector((CL_INPUT_WIDTH*CL_INPUT_CHANNELS + 4)-1 downto 0) := (others => '0');
signal cl_data_ext			: std_logic_vector((CL_INPUT_WIDTH*CL_INPUT_CHANNELS + 4)-1 downto 0) := (others => '0');
signal cl_data				: std_logic_vector((CL_INPUT_WIDTH*CL_INPUT_CHANNELS + 4)-1 downto 0) := (others => '0');

signal cl_data_mapped		: std_logic_vector((CL_INPUT_WIDTH*CL_INPUT_CHANNELS + 0)-1 downto 0) := (others => '0');
signal cl_data_unused		: std_logic_vector(79 downto cl_data_mapped'high+1);

signal cl_clk				: std_logic_vector(2 downto 0);
signal cl_x, cl_y, cl_z		: std_logic_vector(3 downto 0);

signal cl_in_frame_int		: std_logic := '0';
signal cl_in_frame_ext		: std_logic := '0';
signal cl_mux				: std_logic := '0';

signal rec_read				: std_logic := '0';
signal rec_lval				: std_logic := '0';
signal rec_fval				: std_logic := '0';
signal rec_data				: std_logic_vector(CL_BITDEPTH-1 downto 0);
signal rec_valid			: std_logic := '0';
signal rec_empty			: std_logic := '0';
signal rec_avail			: std_logic := '0';
signal rec_threshold		: std_logic_vector(11 downto 0);

-- Video
signal tx_fval				: std_logic := '0';
signal tx_lval				: std_logic := '0';
signal tx_data				: std_logic_vector(15 downto 0):= (others => '0');

signal roi_fval				: std_logic := '0';
signal roi_lval				: std_logic := '0';
signal roi_data				: std_logic_vector(15 downto 0):= (others => '0');

signal col_fval				: std_logic := '0';
signal col_lval				: std_logic := '0';
signal col_data				: std_logic_vector(15 downto 0):= (others => '0');

constant USB_BITDEPTH		: integer := 16;

signal VID_RST_I			: std_logic := '1';
signal VID_PCLK_O			: std_logic := '0';
signal VID_LVAL_O			: std_logic := '0';
signal VID_FVAL_O			: std_logic := '0';
signal VID_DATA_O			: std_logic_vector(15 downto 0) := (others => '0');

signal CTL_I				: std_logic_vector(29 downto 17);
signal CTL_O				: std_logic_vector(29 downto 17) := (others => '0');
signal CTL_T				: std_logic_vector(29 downto 17);

signal DEBUG_O				: std_logic_vector(7 downto 0) := (others => '0');

begin

-- Assertions -----------------------------------------------------------------

assert (CL_BITDEPTH <= CL_TAPS*CL_TAPWIDTH) report "CL Bitdepth doesn't fit in Taps" severity error;
assert (24 >= CL_TAPS * CL_TAPWIDTH) report "CL Taps don't fit in Base-Config" severity error;

-- Pin Mapping ----------------------------------------------------------------

UART_RX_I <= MOSI_RX_I;
MISO_TX_O <= UART_TX_O;

-- GPIO[15: 0]	= DQ[15:0]
-- GPIO[16]		= PCLK
-- GPIO[29:17]	= CTL[12:0]
-- GPIO[32:30]	= PMODE[2:0]
-- GPIO[44:33]	= DQ[27:16]
-- GPIO[45]		= GPIO[45]
-- GPIO[49:46]	= DQ[31:28]

-- GPIO[52:50]	= I2S_WS, I2S_SD, I2S_CLK
-- GPIO[57]		= I2S_MCLK

-- GPIO[56:53]	= UART_RX, UART_TX, UART_CTS, UART_RTS
-- GPIO[56:53]	= SPIO_MOSI, SPI_MISO, SPI_CS, SPI_SCK

CTL_O(28)			<= VID_LVAL_O;
CTL_O(29)			<= VID_FVAL_O;
	
VID_RST_I			<= CTL_I(27);

CTL_T				<= (29 => '0', 28 => '0', others => '1');	-- high=input, low=output 

CTL : for i in 17 to 29 generate

n : IOBUF
generic map (
	DRIVE		=> 12,
	IOSTANDARD	=> "LVCMOS33",
	SLEW		=> "FAST"
)
port map (
	IO => CTL_IO(i),
	O => CTL_I(i),
	I => CTL_O(i),
	T => CTL_T(i)
);
end generate;

PCLK_O				<= VID_PCLK_O;
DQ_O(15 downto  0)	<= VID_DATA_O;
DQ_O(31 downto 24)	<= DEBUG_O;

-- DEBUG ----------------------------------------------------------------------

DEBUG_O <= (
	0		=> cl_lval,
	1		=> rec_avail,
	2		=> rec_empty,
	3		=> cl_reg_1(1),
	4		=> rec_lval,
	
	
	5		=> cl_mux,
	6		=> cl_in_frame_int,
	7		=> cl_in_frame_ext,
	others	=> '0'
);

-- LEDs	-----------------------------------------------------------------------

LED_O(0) <= blink_led;
LED_O(1) <= VID_FVAL_O;
		
blink : process(clk100)
begin
	if rising_edge(clk100) then
		if pulse_1Hz = '1' then
			blink_led <= not blink_led;
		end if;
	end if;
end process;

-- Clocks ---------------------------------------------------------------------

clk_gen : entity work.clk_gen
generic map (
	CLK_IN_PERIOD	=> 20.0,	-- 50MHz
	DIFF_CLK_IN		=> false,
	CLKFB_MULT		=> 20,
	DIVCLK_DIVIDE	=> 1,
	CLK_OUT_DIVIDE	=> ( 0 => 10,   1 => 12,  others => 1 )
)
port map (
	CLK_Ip			=> CLK_I,
	
	CLK0_O			=> clk100,		-- 50MHz * 20 / 10 = 100MHz
	CLK1_O			=> clk_cl_int,	-- 50MHz * 20 / 12 = 83.3MHz
	
	LOCKED_O		=> clk_ready
);

rst100 <= (NOT clk_ready);

-- Cameralink -----------------------------------------------------------------

cl_sync : entity work.sync_clk_domain(Handshake)
generic map (
	SLOTS		=> 6,
	STAGES		=> 2
)
port map (
	CLK_SRC_I	=> clk100,
	RST_SRC_I	=> rst100,
	
	SRC_I(5 downto 0)	=> reg(1)(5 downto 0),
		
	CLK_DST_I	=> clk_cl,
	
	DST_O(5 downto 0)	=> cl_reg_1_sync
);

process(clk_cl)
begin
	if rising_edge(clk_cl) then
		if cl_fval = '0' then
			cl_reg_1 <= cl_reg_1_sync;
		end if;
	end if;
end process;

cl_rx : entity work.cl_base_rx
generic map (
	CLOCK_MHZ		=> CL_CLK_FREQ,
	INVERT			=> CL_INVERT
)
port map (
	RESET_I			=> '0',
	
	PCLK_O			=> clk_cl_ext,
	DATA_O			=> cl_data_ext,
	
	CC_I			=> cl_cc,
	TX_I			=> cl_uart_tx,
	RX_O			=> cl_uart_rx,
	
	Xp_I			=> CL_DATA_Ip,
	Xn_I			=> CL_DATA_In,
	XCLKp_I			=> CL_CLK_Ip,
	XCLKn_I			=> CL_CLK_In,
	
	CCp_O			=> CL_CC_Op,
	CCn_O			=> CL_CC_On,
	
	SERTFGp_I		=> CL_TFG_Ip,
	SERTFGn_I		=> CL_TFG_In,
	
	SERTCp_O		=> CL_TC_Op,
	SERTCn_O		=> CL_TC_On
);

cl_framegen : entity work.cl_base_framegen
generic map (
	TAPS			=> CL_TAPS,
	WIDTH			=> CL_TAPWIDTH
)
port map (
	RESET_I			=> '0',
	
	PCLK_I			=> clk_cl_int,
	DATA_O			=> cl_data_int,
	
	FREERUN_I		=> not cl_reg_1(0) and cl_reg_1(2),
	MODE_I			=> cl_reg_1(5 downto 4),
	
	CC_I			=> cl_cc OR reg(0)(3 downto 0),
	
	PPL_I			=> reg(12),
	LPF_I			=> reg(13),
	
	LPAUSE_I		=> reg(14),
	FPAUSE_I		=> reg(15)
);

cl_ext : process(clk_cl_ext)
begin
	if rising_edge(clk_cl_ext) then
		cl_in_frame_ext <= cl_data_ext(15);
	end if;
end process;

cl_int : process(clk_cl_int)
begin
	if rising_edge(clk_cl_int) then
		cl_in_frame_int <= cl_data_int(15);
	end if;
end process;

cl_clk_mux : BUFGMUX
generic map (
	CLK_SEL_TYPE	=> "ASYNC"
)
port map (
	S	=> cl_mux,
	I0	=> clk_cl_int,
	I1	=> clk_cl_ext,
	O	=> clk_cl
);

cl_data_mux : process(clk_cl)
begin
	if rising_edge(clk_cl) then

		if (cl_in_frame_ext = '0' AND cl_reg_1(0) = '1')
		OR (cl_in_frame_int = '0' AND cl_reg_1(0) = '0') then
			cl_mux <= cl_reg_1(0);
		end if;
			
		if cl_mux = '1' then
			cl_data <= cl_data_ext;
		else
			cl_data <= cl_data_int;
		end if;
	end if;
end process;

cl_bitmap : entity work.bitmap_cl_rx
port map (
	CLK_I			=> clk_cl,
	
	FVAL_O			=> cl_fval,
	LVAL_O			=> cl_lval,
	DVAL_O			=> cl_dval,
	SPARE_O			=> cl_spare,
	
	DATA_I(cl_data'high downto 0) 		 	=> cl_data,
	DATA_I(83 downto cl_data'high+1)	 	=> (others => '0'),
	
	DATA_O(cl_data_mapped'high downto 0) 	=> cl_data_mapped,
	DATA_O(79 downto cl_data_mapped'high+1)	=> cl_data_unused
);

cl_data_rec : entity work.data_recorder
generic map (
	WIDTH		=> CL_BITDEPTH
)
port map (
	WR_CLK_I	=> clk_cl,
	
	EN_I		=> cl_reg_1(1),
	
	LV_MASK_I	=> reg(2)( 3 downto  0),
	FV_MASK_I	=> reg(2)( 7 downto  4),
	INV_MASK_I	=> reg(2)(11 downto  8),
	
	FVAL_I		=> cl_fval,
	LVAL_I		=> cl_lval,
	DVAL_I		=> cl_dval,
	SPARE_I		=> cl_spare,
	DATA_I		=> cl_data_mapped(CL_BITDEPTH-1 downto 0),
	FULL_O		=> open,
	
	RD_CLK_I	=> clk100,
	
	FVAL_O		=> rec_fval,
	LVAL_O		=> rec_lval,
	DATA_O		=> rec_data,
	
	READ_I		=> rec_read,
	VALID_O		=> rec_valid,
	EMPTY_O		=> rec_empty,
	AVAIL_O		=> rec_avail,
	THRESHOLD_I	=> rec_threshold
);

video_tx : entity work.video_tx
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	FVAL_I		=> rec_fval,
	LVAL_I		=> rec_lval,
	DATA_I		=> rec_data,
	
	READ_O		=> rec_read,
	VALID_I		=> rec_valid,
	EMPTY_I		=> rec_empty,
	AVAIL_I		=> rec_avail,
	THRESHOLD_O	=> rec_threshold,

	PPL_I		=> reg(12),

	FVAL_O		=> tx_fval,
	LVAL_O		=> tx_lval,
	DATA_O		=> tx_data
);

video_roi : entity work.video_roi
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	TOP_I		=> reg(4),
	LEFT_I		=> reg(5),
	HEIGHT_I	=> reg(6),
	WIDTH_I		=> reg(7),

	FVAL_I		=> tx_fval,
	LVAL_I		=> tx_lval,
	DATA_I		=> tx_data,
	
	FVAL_O		=> roi_fval,
	LVAL_O		=> roi_lval,
	DATA_O		=> roi_data
);

video_color : entity work.video_color
generic map (
	DEPTH		=> CL_BITDEPTH
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	MODE_I		=> reg(1)(9 downto 8),
	SHIFT_I		=> reg(8)(2 downto 0),

	FVAL_I		=> roi_fval,
	LVAL_I		=> roi_lval,
	DATA_I		=> roi_data,
	
	FVAL_O		=> col_fval,
	LVAL_O		=> col_lval,
	DATA_O		=> col_data
);

video_rate : entity work.video_rate
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	INTERVAL_I	=> reg(3),
	
	FVAL_I		=> col_fval,
	LVAL_I		=> col_lval,
	DATA_I		=> col_data,
	
	FVAL_O		=> VID_FVAL_O,
	LVAL_O		=> VID_LVAL_O,
	DATA_O		=> VID_DATA_O
);

video_clk : ODDR2
generic map(
	DDR_ALIGNMENT	=> "C1",	-- Sets output alignment to "NONE", "C0", "C1" 
	INIT			=> '0',		-- Sets initial state of the Q output to '0' or '1'
	SRTYPE			=> "ASYNC"	-- Specifies "SYNC" or "ASYNC" set/reset
)
port map (
	Q		=> VID_PCLK_O,
	C0		=> clk100,
	C1		=> not clk100,
	CE		=> '1',
	D0		=> switch(INVERT_CLK, '0', '1'),
	D1		=> switch(INVERT_CLK, '1', '0'),
	R		=> '0',
	S		=> '0'
);

-- Registers ------------------------------------------------------------------

registers : entity work.registers
generic map (
	NR_OF_REGS 		=> NR_OF_REGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	ACK_O			=> reg_ack,
	WRITE_I			=> reg_write,
	READ_I			=> reg_read,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_r,
	DATA_I			=> reg_data_w,
	
	-- Read/Write Registers
	REG_DV_O		=> reg_dv,
	REGISTERS_O		=> reg,
	
	-- Read Only Registers
	REG_DV_I		=> (
					 
				others => '0'
	),
	REGISTERS_I		=> (
					 
					25	=> int2vec(TIMESTAMP, 32)(15 downto   0),
					26	=> int2vec(TIMESTAMP, 32)(31 downto  16),
					 
					29	=> int2vec(integer(SYS_CLK_FREQ), 16),	-- Sys Clk (MHz)
					30	=> int2vec(VERSION, 16),				-- FPGA VERSION
					31	=> int2vec(BUILD, 16),					-- FPGA BUILD
				others	=> x"0000"
	)
);

-- Timestamp ------------------------------------------------------------------

time_stamp : entity work.timestamp
generic map (
	CLOCK_MHZ		=> SYS_CLK_FREQ
)
port map (
	CLK_I			=> clk100,
	RESET_I			=> rst100,
	
	TIMESTAMP_O		=> ts_data,
	
	SET_TS_I		=> ts_set,
	TIMESTAMP_I		=> ts_data_set,
	
	SET_PS_I		=> ps_set,
	PRESCALER_I		=> ps_data_set,
	
	PULSE_1HZ_O		=> pulse_1hz,
	PULSE_1KHZ_O	=> pulse_1khz,
	PULSE_1MHZ_O	=> pulse_1mhz
);

-- Flash ----------------------------------------------------------------------

flash : entity work.flash_wrapper
generic map (
 	CLK_MHZ			=> SYS_CLK_FREQ
)
port map (
	CLK_I			=> clk100,
	RESET_I			=> rst100,
 	
 	RECONFIG_I		=> reconfig,
 	
 	nCS_O			=> FLASH_CS_O,
 	SCK_O			=> FLASH_SCK_O,
	MOSI_O			=> FLASH_MOSI_O,
	MISO_I			=> FLASH_MISO_I,
 		
 	NEW_CMD_I		=> flash_new_cmd,
 	CMD_I			=> flash_cmd,
 	NEW_DATA_I		=> flash_new_data_w,
 	DATA_I			=> flash_data_w,
 	
 	RTR_I			=> flash_rtr,
 	RTS_O			=> flash_rts,
 	BUSY_O			=> flash_busy,
 	
 	NEW_DATA_O		=> flash_new_data_r,
 	DATA_O			=> flash_data_r
);

-- UART -----------------------------------------------------------------------

uart : entity work.uart
generic map (
	CLK_MHZ			=> SYS_CLK_FREQ,
	BAUDRATE		=> UART_BAUDRATE,
	FLOW_CTRL		=> UART_FLOW_CTRL
)
port map (
	CLK_I			=> clk100,
	RST_I 			=> rst100,
	
	RX_I	 		=> UART_RX_I,
	TX_O 			=> UART_TX_O,
	
	TX_DONE_O		=> open,
	
	PUT_CHAR_I		=> cmd_uart_put,
	PUT_ACK_O		=> cmd_uart_put_ack,
	TX_CHAR_I		=> cmd_uart_put_char,
	TX_FULL_O		=> cmd_uart_put_full,
	
	GET_CHAR_I		=> cmd_uart_get,
	GET_ACK_O		=> cmd_uart_get_ack,
	RX_CHAR_O		=> cmd_uart_get_char,
	RX_EMPTY_O		=> cmd_uart_get_empty
);

uart_cmd_decoder : entity work.uart_cmd_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	RX_BUSY_O		=> cmd_decoder_rx_busy,
	TX_BUSY_O		=> cmd_decoder_tx_busy,
	
	PUT_CHAR_O		=> cmd_uart_put,
	PUT_ACK_I		=> cmd_uart_put_ack,
	TX_CHAR_O		=> cmd_uart_put_char,
	TX_FULL_I		=> cmd_uart_put_full,
	
	GET_CHAR_O		=> cmd_uart_get,
	GET_ACK_I		=> cmd_uart_get_ack,
	RX_CHAR_I		=> cmd_uart_get_char,
	RX_EMPTY_I		=> cmd_uart_get_empty,
	
	NEW_CMD_O		=> cmd_uart_new_cmd,
	CMD_ACK_I		=> cmd_uart_cmd_ack,
	CMD_ID_O		=> cmd_uart_cmd_id,
	CMD_ARGS_O		=> cmd_uart_cmd_args,
	CMD_ARGN_O		=> cmd_uart_cmd_argn,
	
	NEW_ACK_I		=> cmd_uart_new_ack,
	NEW_NACK_I		=> cmd_uart_new_nack,
	
	NEW_REPLY_I		=> cmd_uart_new_reply,
	REPLY_ACK_O		=> cmd_uart_reply_ack,
	REPLY_ID_I		=> cmd_uart_reply_id,
	REPLY_ARGS_I	=> cmd_uart_reply_args,
	REPLY_ARGN_I	=> cmd_uart_reply_argn
);

uart_cmd_handler : entity work.uart_cmd_handler
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	BUSY_O			=> open,
	
	NEW_CMD_I		=> cmd_uart_new_cmd,
	CMD_ACK_O		=> cmd_uart_cmd_ack,
	CMD_ID_I		=> cmd_uart_cmd_id,
	CMD_ARGS_I		=> cmd_uart_cmd_args,
	CMD_ARGN_I		=> cmd_uart_cmd_argn,
	
	NEW_ACK_O		=> cmd_uart_new_ack,
	NEW_NACK_O		=> cmd_uart_new_nack,
	
	NEW_REPLY_O		=> cmd_uart_new_reply,
	REPLY_ACK_I		=> cmd_uart_reply_ack,
	REPLY_ID_O		=> cmd_uart_reply_id,
	REPLY_ARGS_O	=> cmd_uart_reply_args,
	REPLY_ARGN_O	=> cmd_uart_reply_argn,
	
	UART_BUSY_I		=> cmd_decoder_tx_busy,	
		
	SOFT_RST_O		=> zero,
	
	TST_DATA_I		=> ts_data,
	TST_DV_O		=> ts_set,
	TST_DATA_O		=> ts_data_set,
	TST_PS_DV_O		=> ps_set,
	TST_PS_O		=> ps_data_set,
	
	REG_WRITE_O		=> reg_write,
	REG_READ_O		=> reg_read,
	REG_ADDR_O		=> reg_addr,
	REG_DATA_I		=> reg_data_r,
	REG_DATA_O		=> reg_data_w,
	REG_ACK_I		=> reg_ack,
	
	FL_NEW_CMD_O	=> flash_new_cmd,
	FL_CMD_O		=> flash_cmd,
	FL_NEW_DATA_O	=> flash_new_data_w,
	FL_DATA_O		=> flash_data_w,
	
	FL_RTR_O		=> flash_rtr,
	FL_RTS_I		=> flash_rts,
	FL_BUSY_I		=> flash_busy,
	
	FL_NEW_DATA_I	=> flash_new_data_r,
	FL_DATA_I		=> flash_data_r,
	
	RECONFIG_O		=> reconfig,
	
	CC_O			=> cl_cc
);

end Behavioral;

