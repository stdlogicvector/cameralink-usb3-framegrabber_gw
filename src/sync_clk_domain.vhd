library IEEE, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.types.all;
use work.util.all;

entity sync_clk_domain is
	generic (
		SLOTS		: natural range 1 to 64 := 1;
		STAGES		: natural range 2 to 10 := 3;
		REG_OUTPUT	: integer := 0;
		SIMULATION	: boolean := false
	);
	port (
		CLK_SRC_I	: in	std_logic := '0';
		CLK_DST_I	: in	std_logic := '0';
		RST_SRC_I	: in	std_logic := '0';
		RST_DST_I	: in	std_logic := '0';
		RST_DST_O	: out	std_logic := '0';
	
		SRC_I		: in	std_logic_vector(SLOTS-1 downto 0) := (others => '0');
		DST_O		: out	std_logic_vector(SLOTS-1 downto 0) := (others => '0')
	);
end sync_clk_domain;

architecture HandShake of sync_clk_domain is

constant LEN		: integer := SLOTS;	--SRC_I'length;

signal input		: std_logic_vector(LEN-1 downto 0) := (others => '0');
signal output		: std_logic_vector(LEN-1 downto 0) := (others => '0');
signal flag			: std_logic_vector(LEN-1 downto 0) := (others => '0');

type sync_array_t	is array(STAGES-1 downto 0) of std_logic_vector(LEN-1 downto 0);

signal flag_sync	: sync_array_t := (others => (others => '0'));
signal input_sync	: sync_array_t := (others => (others => '0'));
signal output_sync	: sync_array_t := (others => (others => '0'));

attribute ASYNC_REG of flag_sync : signal is "TRUE";
attribute ASYNC_REG of input_sync : signal is "TRUE";
attribute ASYNC_REG of output_sync : signal is "TRUE";

constant TOP		: integer := STAGES-2;
constant MSB		: integer := STAGES-1;

begin

process (CLK_SRC_I)
begin
	if rising_edge(CLK_SRC_I) then
		if (RST_SRC_I = '1') then	
			output_sync <= (others => (others => '0'));
			flag 		<= (others => '0');
			input		<= (others => '0');
		else
			output_sync <= output_sync(TOP downto 0) & output;
			
			for I in 0 to LEN-1 loop
			
				if (flag(I) = '0') AND ((input(I) XOR SRC_I(I)) = '1')
				then
					flag(I)		<= '1';
					input(I)	<= SRC_I(I);
				end if;
			
				if (flag(I) = '1') AND (output_sync(MSB)(I) = input(I))
				then
					flag(I)	<= '0';
				end if;
				
			end loop;
		end if;
	end if;
end process;

process (CLK_DST_I)
begin
	if rising_edge(CLK_DST_I) then
		if (RST_DST_I = '1') then	
			flag_sync 	<= (others => (others => '0'));
			input_sync	<= (others => (others => '0'));
			output		<= (others => '0');
		else
			flag_sync	<= flag_sync(TOP downto 0)	& flag;
			input_sync	<= input_sync(TOP downto 0)	& input;
		
			for I in 0 to LEN-1 loop
				if (flag_sync(MSB)(I) = '1') then
					output(I)	<= input_sync(MSB)(I);
				end if;
			end loop;

			DST_O(LEN-1 downto 0)	<= output;
			
		end if;
	end if;
end process;

--DST_O	<= output;

end architecture;