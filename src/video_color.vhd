library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity video_color is
	Generic (
		DEPTH		: integer := 12
	);
	Port (
		CLK_I		: in	STD_LOGIC;
		RST_I		: in	STD_LOGIC;
		
		MODE_I		: in	STD_LOGIC_VECTOR(1 downto 0);
		SHIFT_I		: in	STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
		
		FVAL_I		: in	STD_LOGIC;
		LVAL_I		: in	STD_LOGIC;
		DATA_I		: in	STD_LOGIC_VECTOR(15 downto 0);
		
		FVAL_O		: out	STD_LOGIC := '0';
		LVAL_O		: out	STD_LOGIC := '0';
		DATA_O		: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end video_color;

architecture Behavioral of video_color is

constant MODE_RAW		: std_logic_vector(1 downto 0) := "00";
constant MODE_RGB565	: std_logic_vector(1 downto 0) := "01";
constant MODE_YUV422	: std_logic_vector(1 downto 0) := "10";

signal fval				: std_logic := '0';
signal lval				: std_logic := '0';
signal data				: std_logic_vector(15 downto 0);

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		
		fval <= FVAL_I;
		lval <= LVAL_I;
		data <= std_logic_vector(shift_left(unsigned(DATA_I), vec2int(SHIFT_I)));
		
		FVAL_O <= fval;
		LVAL_O <= lval;
		
		case MODE_I is
		when MODE_RGB565 =>
			DATA_O(15 downto 11) <= data(DEPTH-1 downto DEPTH-5);
			DATA_O(10 downto  5) <= data(DEPTH-1 downto DEPTH-6);
			DATA_O( 4 downto  0) <= data(DEPTH-1 downto DEPTH-5);
			
		when MODE_YUV422 =>
			DATA_O(15 downto 8)  <= data(DEPTH-1 downto DEPTH-8);
			DATA_O( 7 downto 0)  <= x"80";

		--when MODE_RAW =>		
		when others =>
			DATA_O <= data;
		end case;
	end if;
end process;

end Behavioral;

