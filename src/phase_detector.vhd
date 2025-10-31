LIBRARY IEEE, UNISIM;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE UNISIM.VCOMPONENTS.ALL;

entity phase_detector is
	generic (
		D 			: integer := 16;			-- Set the number of inputs
		S			: integer := 7;
		ENABLED		: boolean := TRUE;
		BITSLIP		: boolean := FALSE
	);
	port (
		GCLK_I			: in	std_logic;								-- Global clock
		RESET_I			: in	std_logic;								-- Reset line
		
		BUSY_I			: in	std_logic_vector(D-1 downto 0);			-- BUSY inputs from IODELAY2s
		VALID_I			: in	std_logic_vector(D-1 downto 0);			-- VALID inputs from IODELAY2s
		
		CAL_MASTER_O	: out	std_logic;								-- Output to cal pins on master IODELAY2s
		CAL_SLAVE_O		: out	std_logic;								-- Output to cal pins on slave IODELAY2s
		CAL_RST_O		: out	std_logic;								-- Output to rst pins on master & slave IODELAY2s
		CAL_CE_O		: out	std_logic_vector(D-1 downto 0);  		-- Outputs to CAL_CE_O pins on IODELAY2s
		CAL_INC_O		: out	std_logic_vector(D-1 downto 0);  		-- Outputs to CAL_INC_O pins on IODELAY2s
		CAL_INCDEC_I	: in	std_logic_vector(D-1 downto 0);			-- INC_DEC inputs from ISERDES2s
		
		DATA_I			: in	std_logic_vector(S-1 downto 0);
		BITSLIP_O		: out	std_logic;
		PATTERN1_I		: in	STD_LOGIC_VECTOR(S-1 downto 0);
		PATTERN2_I		: in	STD_LOGIC_VECTOR(S-1 downto 0);
		
		DEBUG_I  		: in	std_logic_vector(1 downto 0);			-- input DEBUG_O data
		DEBUG_O			: out	std_logic_vector((3*D)+5 downto 0)  	-- Debug bus, 3D+5 = 3 lines per input (from CAL_INC_O, mux and CAL_CE_O) + 6, leave nc if DEBUG_O not required
	);
end phase_detector;

architecture arch_phase_detector of phase_detector is
  
signal state 			: integer range 0 to 15;

signal busy_d 			: std_logic_vector(D-1 downto 0);
signal cal_data_sint	: std_logic;
signal ce_data_inta		: std_logic;
signal busy_data_d		: std_logic;
signal counter			: std_logic_vector(11 downto 0);
signal enable			: std_logic;
signal cal_data_master	: std_logic;
signal valid_data_d		: std_logic;
signal rst_data			: std_logic;
signal pdcounter 		: std_logic_vector(4 downto 0);
signal inc_data			: std_logic;
signal ce_data			: std_logic_vector(D-1 downto 0);
signal inc_data_int		: std_logic;
signal incdec_data_d	: std_logic;
signal inc_data_int_d	: std_logic_vector(D-1 downto 0);
signal mux				: std_logic_vector(D-1 downto 0);
signal incdec_data_or	: std_logic_vector(D downto 0);
signal valid_data_or	: std_logic_vector(D downto 0);
signal busy_data_or		: std_logic_vector(D downto 0);
signal incdec_data_im	: std_logic_vector(D-1 downto 0);
signal valid_data_im	: std_logic_vector(D-1 downto 0);
signal all_ce			: std_logic_vector(D-1 downto 0);
signal all_inc			: std_logic_vector(D-1 downto 0);
signal flag1 			: std_logic := '0';
signal flag2 			: std_logic := '0';

begin

DEBUG_O			<= mux & cal_data_master & rst_data & cal_data_sint & busy_data_d & inc_data_int_d & ce_data & valid_data_d & incdec_data_d;
CAL_SLAVE_O		<= cal_data_sint;
CAL_MASTER_O	<= cal_data_master;
CAL_RST_O		<= rst_data;
CAL_CE_O		<= ce_data;
CAL_INC_O		<= inc_data_int_d;

process (GCLK_I, RESET_I)
begin
	if RESET_I = '1' then
		state			<= 0;
		cal_data_master <= '0';
		cal_data_sint	<= '0';
		counter			<= (others => '0');
		enable			<= '0';
		counter			<= (others => '0');
		mux				<= (0 => '1', others => '0');
	elsif rising_edge(GCLK_I)
	then
		BITSLIP_O <= '0';
   	
		if counter(11) = '1' then
			enable <= '1';
			counter <= (others => '0');
    	else if BITSLIP = TRUE then
			if DATA_I /= PATTERN1_I then flag1 <= '1'; else flag1 <= '0'; end if;
			if DATA_I /= PATTERN2_I then flag2 <= '1'; else flag2 <= '0'; end if;
		end if;
			
   		counter <= counter + 1;
--synthesis translate_off
			counter(10 downto 8) <= "111";	-- speed up simulation
--synthesis translate_on
   	end if;

		case (state) is
		when 0 =>	
			if enable = '1' then			-- Wait for all IODELAYs to be available
				cal_data_master <= '0';
				cal_data_sint <= '0';
				rst_data <= '0';
				
				if busy_data_d = '0' then
					state <= 1;
				end if;
			end if;
		
		when 1 => 											-- Issue calibrate command to both master and slave, needed for simulation, not for the silicon    
			cal_data_master <= '1';                -- When in phase_detector mode the slave controls the master completely in silicon, but due to the 
			cal_data_sint <= '1';                  -- way the simulation models work, the master does require these signals for correct simulation    
			if busy_data_d = '1' then					-- and wait for command to be accepted                                                             
				state <= 2;
			end if;
			
		when 2 => 											-- Now RST master and slave IODELAYs needed for simulation, not for the silicon                
			cal_data_master <= '0';                -- When in phase_detector mode the slave controls the master completely in silicon, but due to 
			cal_data_sint <= '0';                  -- way the simulation models work, the master does require these signals for correct simulation
			
			if busy_data_d = '0' then               
				rst_data <= '1';
				state <= 3;
			end if;
			
		when 3 =>					-- Dummy state. delay may or may not go BUSY depending on timing
			rst_data <= '0';
			state <= 4;
			
		when 4 => 					-- Wait for all IODELAYs to be available
			if busy_data_d = '0' then
				state <= 6;
			end if;
			
		when 5 => 					-- Wait for occasional enable
			if counter(11) = '1' then
				state <= 6;
			end if;
			
		when 6 =>					-- Calibrate slave only                
		
			if busy_data_d = '0' then              
				cal_data_sint <= '1';         
				state <= 7;
				
				if D /= 1 then
					mux <= mux(D-2 downto 0) & mux(D-1);
				end if;
			end if;
			
		when 7 =>					-- Wait for command to be accepted
			if busy_data_d = '1' then
			
				if flag1 = '1' and flag2 = '1'
				then
     		   		BITSLIP_O <= '1';						-- bitslip needed
				end if;
			
				cal_data_sint <= '0';
				state <= 8;
			end if;
			
		when 8 =>					-- Wait for all IODELAYs to be available, ie CAL command finished
			cal_data_sint <= '0';
			if busy_data_d = '0' then
				state <= 5;
			end if;
			
		when others => 
			state <= 0;
		end case;
	end if;
end process;

process (GCLK_I, RESET_I)
begin
	if RESET_I = '1'
	then
		pdcounter	 <= "10000";
		ce_data_inta <= '0';
		inc_data_int <= '0';
	elsif rising_edge(GCLK_I)
	then
		busy_data_d		<= busy_data_or(D);
		incdec_data_d	<= incdec_data_or(D);
		valid_data_d	<= valid_data_or(D);
		
		if ENABLED = TRUE
		then
			if ce_data_inta = '1'
			then
				ce_data <= mux;
			
				if inc_data_int = '1' then
					inc_data_int_d <= mux;
				end if;
			else 
				ce_data <= (others => '0');
				inc_data_int_d <= (others => '0');
			end if;
		
	   		if state /= 5 or busy_data_d = '1' then		-- Reset filter if state machine issues a cal command or unit is busy
				pdcounter <= "10000";
	   			ce_data_inta <= '0';
	   			inc_data_int <= '0';
	   		elsif pdcounter = "11111" then					-- Filter has reached positive max - increment the tap count
				ce_data_inta <= '1';
				inc_data_int <= '1';
				pdcounter <= "10000";
			elsif pdcounter = "00000" then					-- Filter has reached negative max - decrement the tap count
				ce_data_inta <= '1';
				inc_data_int <= '0';
				pdcounter <= "10000";
			elsif valid_data_d = '1' then						-- increment filter
				ce_data_inta <= '0';
				inc_data_int <= '0';
				
				if incdec_data_d = '1' then
						pdcounter <= pdcounter + 1;
				elsif incdec_data_d = '0' then 				-- decrement filter
					pdcounter <= pdcounter - 1;
				end if;
	   		else 
	   			ce_data_inta <= '0';
				inc_data_int <= '0';
			end if;
   		else
   			ce_data <= all_ce;
			inc_data_int_d <= all_inc;
		end if;
	end if;
end process;

incdec_data_or(0) <= '0';							-- Input Mux - Initialise generate loop OR gates
valid_data_or(0) <= '0';
busy_data_or(0) <= '0';

loop0 : for i in 0 to (D - 1) generate

	incdec_data_im(i) 	<= CAL_INCDEC_I(i) and mux(i);							-- Input muxes
	incdec_data_or(i+1)	<= incdec_data_im(i) or incdec_data_or(i);			-- AND gates to allow just one signal through at a tome
	valid_data_im(i)	<= VALID_I(i) and mux(i);									-- followed by an OR
	valid_data_or(i+1)	<= valid_data_im(i) or valid_data_or(i);				-- for the three inputs from each PD
	busy_data_or(i+1)	<= BUSY_I(i) or busy_data_or(i);							-- The busy signals just need an OR gate

	all_ce(i)			<= DEBUG_I(0);
	all_inc(i)			<= DEBUG_I(1) and DEBUG_I(0);

end generate;

end arch_phase_detector;
