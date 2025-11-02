library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.types.all;
use work.util.all;

entity video_tx is

	Port (
		CLK_I		: in  STD_LOGIC;
		RST_I		: in  STD_LOGIC;

		FVAL_I		: in  STD_LOGIC;
		LVAL_I		: in  STD_LOGIC;
		DATA_I		: in  STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
		
		READ_O		: out STD_LOGIC := '0';
		EMPTY_I		: in  STD_LOGIC;
		VALID_I		: in  STD_LOGIC;
		AVAIL_I		: in  STD_LOGIC;
		THRESHOLD_O	: out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
		
		PPL_I		: in  STD_LOGIC_VECTOR(15 downto 0);
		
		FVAL_O		: out STD_LOGIC := '0';
		LVAL_O		: out STD_LOGIC := '0';
		DATA_O		: out STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end video_tx;

architecture Behavioral of video_tx is

type state_t is (S_IDLE, S_SOF, S_SOL, S_EOL, S_EOF);

signal state		: state_t := S_IDLE;
signal delay		: std_logic := '0';

begin

THRESHOLD_O <= PPL_I(11 downto 0); -- A line 

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			state <= S_IDLE;
		else
	
			DATA_O <= DATA_I;
			LVAL_O <= LVAL_I;

			READ_O <= '0';

			case (state) is
			when S_IDLE =>
				FVAL_O <= '0';
				
				if AVAIL_I = '1' then
					state	<= S_SOF;
				end if;
		
			when S_SOF =>
				if FVAL_I = '1' then
					state  <= S_SOL;
					FVAL_O <= '1';
				else
					FVAL_O <= '0';
					READ_O <= '1';
				end if;			
			
			when S_SOL =>
				FVAL_O <= '1';
				
				if LVAL_I = '1' then
					state <= S_EOL;
				end if;
				
				READ_O <= '1';
			
			when S_EOL =>
				FVAL_O <= '1';
			
				if LVAL_I = '0' then
					state <= S_EOF;
				else
					READ_O <= '1';
				end if;
			
			when S_EOF =>
				FVAL_O <= '1';
				
				if FVAL_I = '0' then
					state <= S_IDLE;
				elsif AVAIL_I = '1' then
					state	<= S_SOL;
				end if;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;
