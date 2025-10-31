library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity video_rate is
	Port (
		CLK_I		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		INTERVAL_I	: in	STD_LOGIC_VECTOR (15 downto 0);
		
		FVAL_I 		: in	STD_LOGIC;
		LVAL_I 		: in	STD_LOGIC;
		DATA_I 		: in	STD_LOGIC_VECTOR (15 downto 0);
		
		FVAL_O 		: out	STD_LOGIC;
		LVAL_O 		: out	STD_LOGIC;
		DATA_O 		: out	STD_LOGIC_VECTOR (15 downto 0)
	);
end video_rate;

architecture Behavioral of video_rate is

constant PRESCALE		: integer := 100000;
signal prescaler		: integer range 0 to PRESCALE-1 := 0;

signal timer			: std_logic_vector(15 downto 0) := (others => '0');

type state_t is (S_IDLE, S_FRAME, S_WAIT, S_EOF);
signal state			: state_t := S_IDLE;

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then

		if prescaler = PRESCALE-1 then
			prescaler <= 0;
			
			timer <= inc(timer);
		else
			prescaler <= prescaler + 1;
		end if;
		
		case state is
		when S_IDLE =>
			if FVAL_I = '1' then
				state <= S_FRAME;
				timer <= (others => '0');
			end if;
			
		when S_FRAME =>
			if FVAL_I = '0' then
				state <= S_WAIT;
			end if;
			
		when S_WAIT =>
			if timer > INTERVAL_I then
				state <= S_EOF;
			end if;
			
		when S_EOF =>
			if FVAL_I = '0' then
				state <= S_IDLE;
			end if;
		
		end case;
		
		if state = S_IDLE or state = S_FRAME then
			FVAL_O <= FVAL_I;
			LVAL_O <= LVAL_I;
		else
			FVAL_O <= '0';
			LVAL_O <= '0';
		end if;
		
		DATA_O <= DATA_I;
	
	end if;
end process;

end Behavioral;

