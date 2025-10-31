library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity video_roi is
	Port (
		CLK_I		: in	STD_LOGIC;
		RST_I		: in	STD_LOGIC;
		
		FVAL_I		: in	STD_LOGIC;
		LVAL_I		: in	STD_LOGIC;
		DATA_I		: in	STD_LOGIC_VECTOR(15 downto 0);
		
		FVAL_O		: out	STD_LOGIC := '0';
		LVAL_O		: out	STD_LOGIC := '0';
		DATA_O		: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
		
		WIDTH_I		: in	STD_LOGIC_VECTOR(15 downto 0);
		HEIGHT_I	: in	STD_LOGIC_VECTOR(15 downto 0);
		TOP_I		: in	STD_LOGIC_VECTOR(15 downto 0);
		LEFT_I		: in	STD_LOGIC_VECTOR(15 downto 0)
	);
end video_roi;

architecture Behavioral of video_roi is

signal pixel_nr		: std_logic_vector(15 downto 0) := (others => '0');
signal line_nr		: std_logic_vector(15 downto 0) := (others => '0');

signal pixel_nr_a	: std_logic_vector(15 downto 0) := (others => '0');
signal line_nr_a	: std_logic_vector(15 downto 0) := (others => '0');

signal left, top	: std_logic_vector(15 downto 0) := (others => '0');
signal width, height: std_logic_vector(15 downto 0) := (others => '1');

signal x, y			: std_logic_vector(1 downto 0) := "00";

type state_t		is (S_IDLE, S_FRAME, S_LINE);
signal state		: state_t := S_IDLE;

signal fval			: std_logic := '0';
signal data			: std_logic_vector(15 downto 0) := (others => '0');

signal gate			: std_logic := '1';

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		case state is
		when S_IDLE =>
			line_nr		<= (others => '0');
			line_nr_a	<= (others => '0');
			
			x	<= "00";
			y	<= "00";
			
			left	<= LEFT_I;
			top		<= TOP_I;
			height	<= HEIGHT_I;
			width	<= WIDTH_I;
			
			gate	<= '1';
			
			if FVAL_I = '1' then
				state <= S_FRAME;
			end if;
			
		when S_FRAME =>
			pixel_nr 	<= (others => '0');
			pixel_nr_a	<= (others => '0');
			
			x	<= "00";
			
			if LVAL_I = '1' then
				state <= S_LINE;
			end if;
			
			if FVAL_I = '0' then
				state <= S_IDLE;
			end if;
			
		when S_LINE =>
			pixel_nr <= inc(pixel_nr);
			
			if pixel_nr >= left then
				pixel_nr_a <= inc(pixel_nr_a);
				x(0) <= '1';
			end if;
			
			if pixel_nr_a < width then
				x(1) <= '1';
			else
				x(1) <= '0';
			end if;
			
			if line_nr >= top then
				y(0) <= '1';
			end if;
			
			if line_nr_a < height then
				y(1) <= '1';
			else
				y(1) <= '0';
				gate <= '0';
			end if;		
			
			if LVAL_I = '0' then
				line_nr	<= inc(line_nr);
				
				if line_nr >= top then
					line_nr_a <= inc(line_nr_a);
				end if;
				
				state <= S_FRAME;
			end if;
		
		end case;
		
		fval	<= FVAL_I AND gate;
		data	<= DATA_I;
		
		FVAL_O	<= fval;
		DATA_O	<= data;
	end if;
end process;

LVAL_O <= x(0) AND x(1) AND y(0) AND y(1);

end Behavioral;

