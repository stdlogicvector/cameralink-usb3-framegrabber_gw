library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;

entity cl_mux is
Generic (
	WIDTH		: integer := 8;
	CHANNELS	: integer := 3
);
Port (
	CLK_INT_I	: in	std_logic;
	DATA_INT_I	: in	std_logic_vector(WIDTH*CHANNELS-1 downto 0);
	
	CLK_EXT_I	: in	std_logic;
	DATA_EXT_I	: in	std_logic_vector(WIDTH*CHANNELS-1 downto 0);
		
	SELECT_I	: in	std_logic;
		
	CLK_O		: out	std_logic;
	DATA_O		: out 	std_logic_vector(WIDTH*CHANNELS-1 downto 0)
);
end cl_mux;

architecture Behavioral of cl_mux is

signal sel			: std_logic := '0';

signal in_frame_ext : std_logic := '0';
signal in_frame_int : std_logic := '0';

begin

ext : process(CLK_EXT_I)
begin
	if rising_edge(CLK_EXT_I) then
		in_frame_ext <= DATA_EXT_I(15);
	end if;
end process;

int : process(CLK_INT_I)
begin
	if rising_edge(CLK_INT_I) then
		in_frame_int <= DATA_INT_I(15);
	end if;
end process;

clk_mux : BUFGMUX
generic map (
	CLK_SEL_TYPE	=> "ASYNC"
)
port map (
	S	=> sel,
	I0	=> CLK_INT_I,
	I1	=> CLK_EXT_I,
	O	=> CLK_O
);

data_mux : process(CLK_O)
begin
	if rising_edge(CLK_O) then

		if (in_frame_ext = '0' AND SELECT_I = '1')
		OR (in_frame_int = '0' AND SELECT_I = '0') then
			sel <= SELECT_I;
		end if;
			
		if sel = '1' then
			DATA_O <= DATA_EXT_I;
		else
			DATA_O <= DATA_INT_I;
		end if;
	end if;
end process;

end Behavioral;

