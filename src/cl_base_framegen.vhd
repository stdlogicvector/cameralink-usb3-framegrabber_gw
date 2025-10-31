library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.util.all;

entity cl_base_framegen is
	generic (
		F			: integer := 7;	-- SERDES Factor
		C			: integer := 4;	-- Channels;
		TAPS		: integer := 2;	-- CL Taps
		WIDTH		: integer := 8	-- CL Tap Width
	);
	port (
	-- Internal
		RESET_I		: IN	STD_LOGIC;

	-- Data
		PCLK_I		: IN	STD_LOGIC;
		DATA_O		: OUT	STD_LOGIC_VECTOR((F*C)-1 downto 0) := (others => '0');
		
	-- Control
		MODE_I		: IN	STD_LOGIC_VECTOR(1 downto 0);	-- TODO: Mode
		FREERUN_I	: IN	STD_LOGIC := '0';
		CC_I		: IN	STD_LOGIC_VECTOR( 3 downto 0);	-- Camera Control 1-4
		
		PPL_I		: IN	STD_LOGIC_VECTOR(15 downto 0);	-- Pixel Per Line
		LPF_I		: IN	STD_LOGIC_VECTOR(15 downto 0);	-- Lines Per Frame
		
		LPAUSE_I	: IN	STD_LOGIC_VECTOR(15 downto 0);
		FPAUSE_I	: IN	STD_LOGIC_VECTOR(15 downto 0)
	);
end cl_base_framegen;

architecture RTL of cl_base_framegen is

type state_t is (
	S_IDLE,
	S_DATA,
	S_EOL,
	S_LPAUSE,
	S_FPAUSE
);

signal state	: state_t := S_IDLE;

signal mode		: std_logic_vector( 1 downto 0) := (others => '0');

signal pixel_nr	: std_logic_vector(15 downto 0) := (others => '0');
signal line_nr	: std_logic_vector(15 downto 0) := (others => '0');

signal pixel	: std_logic_vector((F*C-4)-1 downto 0) := (others => '0');

signal dval		: std_logic := '0';
signal lval		: std_logic := '0';
signal fval		: std_logic := '0';
signal spare	: std_logic := '0';

begin

DATA_O <= (
	0 => pixel(8),
	1 => pixel(5),
	2 => pixel(4),
	3 => pixel(3),
	4 => pixel(2),
	5 => pixel(1),
	6 => pixel(0),
	7 => pixel(13),
	8 => pixel(12),
	9 => pixel(21),
	10 => pixel(20),
	11 => pixel(11),
	12 => pixel(10),
	13 => pixel(9),
	14 => dval,
	15 => fval,
	16 => lval,
	17 => pixel(17),
	18 => pixel(16),
	19 => pixel(15),
	20 => pixel(14),
	21 => spare,
	22 => pixel(19),
	23 => pixel(18),
	24 => pixel(23),
	25 => pixel(22),
	26 => pixel(7),
	27 => pixel(6)
);

process(PCLK_I)
begin
	if rising_edge(PCLK_I) then
		fval <= '0';
		lval <= '0';
		dval <= '0';
		spare <= '0';
		
		case (state) is
		when S_IDLE =>
			if CC_I(0) = '1' or FREERUN_I = '1' then
				state <= S_LPAUSE;
				
				mode <= MODE_I;
				
				fval <= '1';
				pixel_nr <= (others => '0');
				line_nr  <= (others => '0');
			end if;
			
		when S_DATA =>
			fval <= '1';
			lval <= '1';
			dval <= '1';

			pixel_nr <= inc(pixel_nr);
			
			case (mode) is
			when "00" =>
				pixel( 4 downto  0) <= pixel_nr(5 downto 1);
				pixel(10 downto  5) <= pixel_nr(5 downto 0);
				pixel(15 downto 11) <= pixel_nr(5 downto 1);
				
			when "01" =>
				pixel( 4 downto  0) <= line_nr(5 downto 1);
				pixel(10 downto  5) <= line_nr(5 downto 0);
				pixel(15 downto 11) <= line_nr(5 downto 1);
				
			when "10" =>
				pixel( 4 downto  0) <= (others => '0');
				pixel(10 downto  5) <= (others => pixel_nr(4));
				pixel(15 downto 11) <= (others => line_nr(4));		
				
			when "11" =>
				pixel( 4 downto  0) <= (others => pixel_nr(7));
				pixel(10 downto  5) <= (others => line_nr(7));
				pixel(15 downto 11) <= (others => '0');
				
			when others => 
				pixel(15 downto 0) <= (others => '0');
			end case;
			
			
			if pixel_nr = PPL_I then
				pixel_nr <= (others => '0');
				line_nr <= inc(line_nr);
				dval <= '0';
				state <= S_EOL;
			end if;
			
		when S_EOL =>
			fval <= '1';
			lval <= '1';
			
			if line_nr < LPF_I then
				lval <= '0';
				state <= S_LPAUSE;
			else
				lval <= '0';
				line_nr <= (others => '0');
				state <= S_FPAUSE;
			end if;
					
		when S_LPAUSE =>
			fval <= '1';
			
			if pixel_nr < LPAUSE_I then
				pixel_nr <= inc(pixel_nr);
			else
				pixel_nr <= (others => '0');
				lval <= '1';
				state <= S_DATA;
			end if;
		
		when S_FPAUSE =>
			if pixel_nr < FPAUSE_I then
				pixel_nr <= inc(pixel_nr);
			else
				pixel_nr <= (others => '0');
				state <= S_IDLE;
			end if;

		end case;
	
	end if;
end process;

end architecture;