library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use Work.util.all;

entity timestamp is
	generic (
		CLOCK_MHZ	: real := 125.0
	);
	port (
		-- system signals
		CLK_I		: in	std_logic;
		RESET_I		: in	std_logic;

		-- Interface
		TIMESTAMP_O	: out	std_logic_vector(31 downto 0) := (others => '0');
		
		SET_TS_I	: in	std_logic := '0';
		TIMESTAMP_I	: in	std_logic_vector(31 downto 0) := (others => '0');
		
		SET_PS_I	: in	std_logic := '0';
		PRESCALER_I	: in	std_logic_vector(7 downto 0) := (others => '0');
		
		PULSE_1HZ_O	: out	std_logic := '0';
		PULSE_1KHZ_O: out	std_logic := '0';
		PULSE_1MHZ_O: out	std_logic := '0'
	);
end timestamp;

architecture Behavioral of timestamp is

signal prescaler : integer range 0 to 2**8-1 := integer(round(CLOCK_MHZ)) - 1;

signal p : integer range 0 to 2**8-1 := 0;
signal t : std_logic_vector(31 downto 0) := (others => '0');

signal count_hz		: integer range 0 to 1e3-1 := 0;
signal count_khz	: integer range 0 to 1e3-1 := 0;

begin

TIMESTAMP_O <= t;

count : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		
		if (RESET_I = '1') OR (SET_TS_I = '1') then
			count_hz	<= 0;
			count_khz	<= 0;
			t <= TIMESTAMP_I;
			p <= 0;
		end if;
		
		if (SET_PS_I = '1') then
			prescaler <= vec2int(PRESCALER_I);
		end if;
		
		if (RESET_I = '1') then
			prescaler <= integer(round(CLOCK_MHZ)) - 1;
		else
			PULSE_1HZ_O		<= '0';
			PULSE_1KHZ_O	<= '0';
			PULSE_1MHZ_O	<= '0';
			
			if (p >= prescaler) then
				if (count_khz = 999) then
					PULSE_1KHZ_O	<= '1';
					count_khz <= 0;
					
					if (count_hz = 999) then
						PULSE_1HZ_O	<= '1';
						count_hz <= 0;
					else
						count_hz <= count_hz + 1;
					end if;
				else
					count_khz <= count_khz + 1;
				end if;
				
				PULSE_1MHZ_O	<= '1';
				
				t <= inc(t);
				p <= 0;
			else
				p <= p + 1;
			end if;
		end if;
	end if;
end process count;

end architecture;