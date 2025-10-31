library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity serdes_1_to_n_data_s8_diff is
	generic (
		S				: integer := 8;				-- Parameter to set the serdes factor 1..8
		D 				: integer := 16;			-- Set the number of inputs and outputs
		DIFF_TERM		: boolean := TRUE;			-- Enable or disable internal differential termination
		DATA_STRIPING 	: string := "PER_CLOCK";	-- Used to determine method for mapping input parallel word to output serial words
		PHASE_DETECTOR	: boolean := TRUE
	);
	port (
		DATAp_I			: in	std_logic_vector(D-1 downto 0);			-- Input from LVDS receiver pin
		DATAn_I			: in	std_logic_vector(D-1 downto 0);			-- Input from LVDS receiver pin
		
		RESET_I			: in	std_logic;								-- Reset line
		
		GCLK_I			: in	std_logic;								-- Global clock
		IOCLK_I			: in	std_logic;								-- IO Clock network
		STROBE_I		: in	std_logic;								-- Parallel data capture strobe
		
		BITSLIP_I		: in	std_logic;								-- Bitslip control line
		DATA_O			: out	std_logic_vector((D*S)-1 downto 0);  	-- Output data
		
		DEBUG_I  		: in	std_logic_vector(1 downto 0);			-- input DEBUG_O data, set to "00" if not required
		DEBUG_O			: out	std_logic_vector((3*D)+5 downto 0);  	-- Debug bus, 5D+5 = 3 lines per input (from inc, mux and ce) + 6, leave nc if DEBUG_O not required
		
		INVERT_I		: in	std_logic_vector(D-1 downto 0)			-- pinswap mask for input bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.
	);
end serdes_1_to_n_data_s8_diff;

architecture arch_serdes_1_to_n_data_s8_diff of serdes_1_to_n_data_s8_diff is

signal data_raw 		: std_logic_vector(D-1 downto 0);
signal data_i			: std_logic_vector(D-1 downto 0);

signal data_delay_m		: std_logic_vector(D-1 downto 0);
signal data_delay_s		: std_logic_vector(D-1 downto 0);
signal shiftout_m 		: std_logic_vector(D-1 downto 0);
signal shiftout_s		: std_logic_vector(D-1 downto 0);

signal mdataout 		: std_logic_vector((8*D)-1 downto 0);

signal data_valid		: std_logic_vector(D-1 downto 0);
signal cal_busy			: std_logic_vector(D-1 downto 0);
signal cal_slave		: std_logic;
signal cal_master		: std_logic;
signal cal_rst			: std_logic;
signal cal_inc			: std_logic_vector(D-1 downto 0);
signal cal_ce			: std_logic_vector(D-1 downto 0);
signal cal_incdec		: std_logic_vector(D-1 downto 0);

begin

phasedetector : entity work.phase_detector
	generic map (
		D		      	=> D,
		S				=> S,
		ENABLED			=> PHASE_DETECTOR,
		BITSLIP			=> FALSE
	)
	port map (
		GCLK_I 			=> GCLK_I,		
		RESET_I 		=> RESET_I,	
	
		BUSY_I			=> cal_busy,
		VALID_I 		=> data_valid,	
		
		CAL_MASTER_O	=> cal_master,
		CAL_SLAVE_O 	=> cal_slave,	
		CAL_RST_O 		=> cal_rst,
		CAL_CE_O		=> cal_ce,
		CAL_INC_O		=> cal_inc,
		CAL_INCDEC_I 	=> cal_incdec,	
		
		DATA_I			=> (others => '0'),
		BITSLIP_O		=> open,
		PATTERN1_I		=> (others => '0'),
		PATTERN2_I		=> (others => '0'),
		
		DEBUG_I			=> DEBUG_I,
		DEBUG_O			=> DEBUG_O
	);

loop0 : for i in 0 to (D - 1) generate
	
iob_clk_in : IBUFDS
	generic map(
		DIFF_TERM		=> DIFF_TERM
	)
	port map (
		I    			=> DATAp_I(i),
		IB       		=> DATAn_I(i),
		O         		=> data_raw(i)
	);
	
data_i(i) <= data_raw(i) xor INVERT_I(i);	-- Invert signals as required

iodelay_m : IODELAY2
	generic map(
		DATA_RATE      		=> "SDR", 					-- <SDR>, DDR
		IDELAY_VALUE  		=> 0, 						-- {0 ... 255}
		IDELAY2_VALUE 		=> 0, 						-- {0 ... 255}
		IDELAY_MODE  		=> "NORMAL" , 				-- NORMAL, PCI
		ODELAY_VALUE  		=> 0, 						-- {0 ... 255}
		IDELAY_TYPE   		=> "DIFF_PHASE_DETECTOR",-- "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
		COUNTER_WRAPAROUND 	=> "WRAPAROUND", 			-- <STAY_AT_LIMIT>, WRAPAROUND
		DELAY_SRC     		=> "IDATAIN", 				-- "IO", "IDATAIN", "ODATAIN"
		SERDES_MODE   		=> "MASTER", 				-- <NONE>, MASTER, SLAVE
		SIM_TAPDELAY_VALUE  => 49
	)
	port map (
		IDATAIN  			=> data_i(i), 				-- data from primary IOB
		TOUT     			=> open, 					-- tri-state signal to IOB
		DOUT     			=> open, 					-- output data to IOB
		T        			=> '1', 						-- tri-state control from OLOGIC/OSERDES2 		
		ODATAIN  			=> '0', 						-- data from OLOGIC/OSERDES2
		DATAOUT  			=> data_delay_m(i), 		-- Output data 1 to ILOGIC/ISERDES2
		DATAOUT2 			=> open, 					-- Output data 2 to ILOGIC/ISERDES2
		IOCLK0   			=> IOCLK_I, 				-- High speed clock for calibration
		IOCLK1   			=> '0', 						-- High speed clock for calibration
		CLK      			=> GCLK_I, 					-- Fabric clock (GCLK) for control signals
		CAL      			=> cal_master,				-- Calibrate control signal
		INC      			=> cal_inc(i),				-- Increment counter
		CE       			=> cal_ce(i),				-- Clock Enable
		RST      			=> cal_rst,					-- Reset delay line
		BUSY      			=> open 						-- output signal indicating sync circuit has finished / calibration has finished 
	);

iodelay_s : IODELAY2
	generic map(
		DATA_RATE      		=> "SDR", 					-- <SDR>, DDR
		IDELAY_VALUE  		=> 0, 						-- {0 ... 255}
		IDELAY2_VALUE 		=> 0, 						-- {0 ... 255}
		IDELAY_MODE  		=> "NORMAL", 				-- NORMAL, PCI
		ODELAY_VALUE  		=> 0, 						-- {0 ... 255}
		IDELAY_TYPE   		=> "DIFF_PHASE_DETECTOR",-- "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
		COUNTER_WRAPAROUND	=> "WRAPAROUND" , 		-- <STAY_AT_LIMIT>, WRAPAROUND
		DELAY_SRC     		=> "IDATAIN" , 			-- "IO", "IDATAIN", "ODATAIN"
		SERDES_MODE   		=> "SLAVE", 				-- <NONE>, MASTER, SLAVE
		SIM_TAPDELAY_VALUE	=> 49
	)
	port map (
		IDATAIN 			=> data_i(i), 				-- data from primary IOB
		TOUT     			=> open, 					-- tri-state signal to IOB
		DOUT     			=> open, 					-- output data to IOB
		T        			=> '1', 						-- tri-state control from OLOGIC/OSERDES2
		ODATAIN  			=> '0', 						-- data from OLOGIC/OSERDES2
		DATAOUT  			=> data_delay_s(i), 		-- Output data 1 to ILOGIC/ISERDES2
		DATAOUT2 			=> open, 					-- Output data 2 to ILOGIC/ISERDES2
		IOCLK0   			=> IOCLK_I, 				-- High speed clock for calibration
		IOCLK1   			=> '0', 						-- High speed clock for calibration
		CLK      			=> GCLK_I, 					-- Fabric clock (GCLK) for control signals
		CAL      			=> cal_slave,				-- Calibrate control signal
		INC      			=> cal_inc(i), 			-- Increment counter
		CE       			=> cal_ce(i) ,				-- Clock Enable
		RST      			=> cal_rst,					-- Reset delay line
		BUSY      			=> cal_busy(i) 			-- output signal indicating sync circuit has finished / calibration has finished
	);

iserdes_m : ISERDES2
	generic map (
		DATA_WIDTH     		=> S, 					-- SERDES word width.  This should match the setting is BUFPLL
		DATA_RATE      		=> "SDR", 				-- <SDR>, DDR
		BITSLIP_ENABLE 		=> TRUE, 				-- <FALSE>, TRUE
		SERDES_MODE    		=> "MASTER", 			-- <DEFAULT>, MASTER, SLAVE
		INTERFACE_TYPE 		=> "RETIMED" 			-- NETWORKING, NETWORKING_PIPELINED, <RETIMED>
	)
	port map (
		D       			=> data_delay_m(i),
		CE0     			=> '1',
		CLK0    			=> IOCLK_I,
		CLK1    			=> '0',
		IOCE    			=> STROBE_I,
		RST     			=> RESET_I,
		CLKDIV  			=> GCLK_I,
		SHIFTIN 			=> shiftout_s(i),
		BITSLIP 			=> BITSLIP_I,
		FABRICOUT 			=> open,
		Q4  				=> mdataout((8*i)+7),
		Q3  				=> mdataout((8*i)+6),
		Q2  				=> mdataout((8*i)+5),
		Q1  				=> mdataout((8*i)+4),
		DFB  				=> open,		
		CFB0 				=> open,
		CFB1 				=> open,
		VALID    			=> data_valid(i),
		INCDEC   			=> cal_incdec(i),
		SHIFTOUT 			=> shiftout_m(i)
	);

iserdes_s : ISERDES2
	generic map(
		DATA_WIDTH     		=> S, 				-- SERDES word width.  This should match the setting is BUFPLL
		DATA_RATE      		=> "SDR", 			-- <SDR>, DDR
		BITSLIP_ENABLE 		=> TRUE, 			-- <FALSE>, TRUE
		SERDES_MODE    		=> "SLAVE", 		-- <DEFAULT>, MASTER, SLAVE
		INTERFACE_TYPE 		=> "RETIMED" 		-- NETWORKING, NETWORKING_PIPELINED, <RETIMED>
	)	
	port map (
		D       			=> data_delay_s(i),
		CE0     			=> '1',
		CLK0    			=> IOCLK_I,
		CLK1    			=> '0',
		IOCE    			=> STROBE_I,
		RST     			=> RESET_I,
		CLKDIV  			=> GCLK_I,
		SHIFTIN 			=> shiftout_m(i),
		BITSLIP 			=> BITSLIP_I,
		FABRICOUT 			=> open,
		Q4  				=> mdataout((8*i)+3),
		Q3  				=> mdataout((8*i)+2),
		Q2  				=> mdataout((8*i)+1),
		Q1  				=> mdataout((8*i)+0),
		DFB  				=> open,		
		CFB0 				=> open,
		CFB1 				=> open,
		VALID 				=> open,
		INCDEC 				=> open,
		SHIFTOUT 			=> shiftout_s(i)
	);

loop2 : for j in 7 downto (8-S)
generate
	loop2a : if DATA_STRIPING = "PER_CLOCK"
	generate
		DATA_O(((D*(j+S-8))+i)) <= mdataout((8*i)+j);
	end generate;
	
	loop2b : if DATA_STRIPING = "PER_CHANL"
	generate 	
		DATA_O(S*i+j+S-8) <= mdataout((8*i)+j);
	end generate;
end generate;

end generate;

end arch_serdes_1_to_n_data_s8_diff;
