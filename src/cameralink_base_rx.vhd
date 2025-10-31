library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.types.all;
use work.util.all;

entity cl_base_rx is
	generic (
		CLOCK_MHZ	: real := 80.0; --MHz
		CL_FACTOR	: integer := 1;
		F			: integer := 7;	-- SERDES Factor
		C			: integer := 4;	-- Channels
		INVERT		: std_logic_vector(4 downto 0) := "00000"
	);
	port (
	-- Internal
		RESET_I		: IN	STD_LOGIC;

	-- Data
		PCLK_O		: OUT	STD_LOGIC := '0';
		DATA_O		: OUT	STD_LOGIC_VECTOR((F*C)-1 downto 0) := (others => '0');
		
	-- Control
		CC_I		: IN	STD_LOGIC_VECTOR( 3 downto 0);	-- Camera Control 1-4
	
	-- Serial
		TX_I		: IN	STD_LOGIC;						-- To Camera
		RX_O		: OUT	STD_LOGIC := '0';				-- To FrameGrabber
	
	-- Bitslip
		DBG_O		: OUT	STD_LOGIC_VECTOR(7 downto 0);
	
-- External
	-- Pixel Lines
		Xp_I		: IN	STD_LOGIC_VECTOR((C-1) downto 0);
		Xn_I		: IN	STD_LOGIC_VECTOR((C-1) downto 0);
		
		XCLKp_I		: IN	STD_LOGIC;
		XCLKn_I		: IN	STD_LOGIC;
		
	-- Control Lines
		CCp_O		: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
		CCn_O		: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '1');
		
	-- Serial Lines
		SERTFGp_I	: IN	STD_LOGIC;
		SERTFGn_I	: IN	STD_LOGIC;
		SERTCp_O	: OUT	STD_LOGIC := '0';
		SERTCn_O	: OUT	STD_LOGIC := '1'
	);
end cl_base_rx;

architecture RTL of cl_base_rx is

constant CLOCK_PERIOD_CL 		: real 		:= 1000.0 / CLOCK_MHZ;	-- ns

signal rxd						: std_logic_vector((F*C)-1 downto 0);

signal rx_clk					: std_logic;
signal rx_strobe				: std_logic;
signal rx_io_clk				: std_logic;
signal rx_bufpll_lckd			: std_logic;

signal bitslip					: std_logic_vector(2 downto 0);

attribute clock_signal of PCLK_O : signal is "yes";

begin

clkin_X : entity work.serdes_1_to_n_clk_pll_s8_diff
	generic map(
     	CLKIN_PERIOD		=> CLOCK_PERIOD_CL,
		PLLD 				=> 1 * CL_FACTOR,
		DIV_FACTOR			=> 1 * CL_FACTOR,
		FB_DIV_FACTOR		=> 1 * CL_FACTOR,
		PLLX				=> F * CL_FACTOR,
		S					=> F,
		BS 					=> TRUE
	)
	port map (
		CLKp_I    			=> XCLKp_I,
		CLKn_I    			=> XCLKn_I,
		RESET_I    			=> RESET_I,
		
		PATTERN1_I			=> "1100011",
		PATTERN2_I			=> "1100001",
		
		GCLK_O				=> rx_clk,	
		IOCLK_O    			=> rx_io_clk,
		STROBE_O		 	=> rx_strobe,

		PLLLOCK_O			=> open,
		PLLCLK_O 			=> open,
		BUFPLLLOCK_O		=> rx_bufpll_lckd,
		
		DATA_O  			=> open,
		BITSLIP_O   		=> bitslip(0),
		
		INVERT_I			=> INVERT(4)
	);
	
datain_X : entity work.serdes_1_to_n_data_s8_diff
	generic map(
     	S				=> F,
     	D				=> C,
		DIFF_TERM		=> TRUE,
		DATA_STRIPING	=> "PER_CHANL",
		PHASE_DETECTOR	=> TRUE
	)
	port map (
		DATAp_I    		=> Xp_I,
		DATAn_I    		=> Xn_I,
		RESET_I   		=> RESET_I,
		GCLK_I    		=> rx_clk,
		IOCLK_I    		=> rx_io_clk,
		STROBE_I 		=> rx_strobe,
		BITSLIP_I 		=> bitslip(0),
		DATA_O			=> rxd(27 downto 0),
		DEBUG_I			=> "00",
		DEBUG_O	  		=> open,
		INVERT_I		=> INVERT(3 downto 0)
	);
	
PCLK_O <= rx_clk;

--process (rx_clk)
--begin
--	if rising_edge(rx_clk)
--	then
		DATA_O <= rxd;
--	end if ;	
--end process;


control_lines : for i in 0 to 3 generate 
	c_lines : OBUFDS
	generic map (
		IOSTANDARD	=> "LVDS_33"
	)
	port map (
		I	=> CC_I(i),
		O	=> CCp_O(i),
		OB	=> CCn_O(i)
	);
end generate;

ser_tx : OBUFDS
	generic map (
		IOSTANDARD => "LVDS_33"
	)
	port map (
		I	=> TX_I,
		O	=> SERTCp_O,
		OB	=> SERTCn_O
	);
	
ser_rx : IBUFDS
	generic map (
		IOSTANDARD	=> "LVDS_33",
		DIFF_TERM	=> TRUE
	)
	port map (
		O	=> RX_O,
		I	=> SERTFGp_I,
		IB	=> SERTFGn_I
	);

end RTL;

