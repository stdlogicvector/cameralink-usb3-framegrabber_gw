library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity uart_arbiter is
	generic (
		CLK_MHZ			: real		:= 100.0;
		ADDRESS			: character := '1';
		STARTCHAR		: character	:= '{';
		STOPCHAR		: character	:= '}';
		ACKCHAR			: character := '!';
		NACKCHAR		: character := '?';
		DATA_BITS		: integer	:= 8;
		LAST			: boolean	:= false
	);
	port (
		RESET_I			: in	STD_LOGIC;
		CLK_I			: in	STD_LOGIC;	
		
		ACK_O			: out	STD_LOGIC := '0';
		NACK_O			: out	STD_LOGIC := '0';
		
		EOC_O			: out	STD_LOGIC := '0';	-- End Of Command
		EOR_O			: out	STD_LOGIC := '0';	-- End Of Reply
		
		-- Downstream FiFo
		D_PUT_CHAR_O	: out	STD_LOGIC := '0';
		D_PUT_ACK_I		: in 	STD_LOGIC;
		D_TX_CHAR_O		: out 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		D_TX_FULL_I		: in	STD_LOGIC;
		
		D_GET_CHAR_O	: out	STD_LOGIC := '0';
		D_GET_ACK_I		: in	STD_LOGIC;
		D_RX_CHAR_I		: in	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		D_RX_EMPTY_I	: in	STD_LOGIC;
		
		-- Upstream FiFo
		U_PUT_CHAR_O	: out	STD_LOGIC := '0';
		U_PUT_ACK_I		: in 	STD_LOGIC;
		U_TX_CHAR_O		: out 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		U_TX_FULL_I		: in	STD_LOGIC;
		
		U_GET_CHAR_O	: out	STD_LOGIC := '0';
		U_GET_ACK_I		: in	STD_LOGIC;
		U_RX_CHAR_I		: in	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		U_RX_EMPTY_I	: in	STD_LOGIC;
		
		-- CMD Decoder
		C_PUT_CHAR_I	: in	STD_LOGIC;
		C_PUT_ACK_O		: out 	STD_LOGIC := '0';
		C_TX_CHAR_I		: in 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		C_TX_FULL_O		: out	STD_LOGIC := '0';
		
		C_GET_CHAR_I	: in	STD_LOGIC;
		C_GET_ACK_O		: out	STD_LOGIC := '0';
		C_RX_CHAR_O		: out	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		C_RX_EMPTY_O	: out	STD_LOGIC := '1'
	);
end uart_arbiter;

-- Up		:
-- IDLE 	: if rx_not_empty > get char > CHECK
-- CHECK	: if char = address > PASS else > TAKE
-- PASS		: mux signals, if char = stopchar > IDLE
-- TAKE		: feed chars from downstream RX to upstream TX until stopchar

-- Down		:
-- IDLE		: if put > ADDR, if rx_not_empty > PASS
-- ADDR		: send addr-char > PUT
-- PUT		: mux signals, if char = stopchar > IDLE
-- PASS		: mux signals, if char = stopchar > IDLE

architecture Behavioral of uart_arbiter is

type state_t is
(
	S_IDLE,
	S_CHECK,
	S_FWD,
	S_WAIT,
	S_PASS,
	S_TAKE,
	S_PUT,
	S_ACK
);

signal up_state		: state_t := S_IDLE;
signal get_char		: std_logic := '0';
signal last_addr	: std_logic := '0';
signal empty		: std_logic := '1';
signal fwd			: std_logic := '0';
signal ack			: std_logic := '0';
signal nack			: std_logic := '0';

signal dn_state		: state_t := S_IDLE;
signal put_char		: std_logic := '0';
signal char			: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');

constant NULL_CHAR	: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');

signal put_flag		: std_logic := '0';

signal out_count	: integer range 0 to 63 := 0;
signal in_count		: integer range 0 to 63 := 0;

constant MAX_TIME	: integer := integer(80.0 * CLK_MHZ)-1;
signal timeout		: integer range 0 to MAX_TIME := 0;
signal cmd_rx		: std_logic := '0';

begin

D_GET_CHAR_O	<= C_GET_CHAR_I	when up_state = S_PASS else get_char;
C_GET_ACK_O		<= D_GET_ACK_I	when up_state = S_PASS else ack;
C_RX_EMPTY_O	<= D_RX_EMPTY_I	when up_state = S_PASS else empty;
C_RX_CHAR_O		<= D_RX_CHAR_I;

UP : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RESET_I = '1' then
			up_state 	<= S_IDLE;
			out_count	<= 0;
			timeout 	<= 0;
		else
			get_char	<= '0';
			ack			<= '0';
			empty		<= '1';
			NACK_O		<= '0';
			EOC_O	 	<= '0';
			U_PUT_CHAR_O <= '0';
			
			case (up_state) is
			when S_IDLE	=>
			
				if (D_RX_EMPTY_I = '0') then											-- New Char available
					get_char	<= '1';
					up_state	<= S_CHECK;
				end if;
				
			when S_CHECK=>
				if (D_GET_ACK_I = '1') then
					if (D_RX_CHAR_I = char2vec(ADDRESS)) then
						last_addr	<= '1';
						fwd			<= '0';
						up_state	<= S_WAIT;
					else
						if (D_RX_CHAR_I = char2vec(STARTCHAR)) AND (last_addr = '1') then
							last_addr	<= '1';
							-- Pass on Start Char to CMD Decoder
							fwd			<= '1';
							up_state	<= S_WAIT;
						else
							last_addr	<= '0';	
							
							if (LAST = true) then
								nack <= '1';
							else
								nack <= '0';
								-- Pass on Address char
								U_TX_CHAR_O		<= D_RX_CHAR_I;	
								U_PUT_CHAR_O	<= '1';
								
								out_count <= out_count + 1;		-- Count CMDs for other FPGAs
							end if;

							up_state 		<= S_ACK;
						end if;
					end if;
				end if;

			when S_WAIT =>
				if (in_count = out_count) then		-- Wait until every CMD for another FPGA has been replied to
					if (fwd = '1') then
						up_state <= S_FWD;
					else
						up_state <= S_PASS;
					end if;
					timeout <= 0;
				else
					if (timeout = MAX_TIME) then
						out_count <= in_count;
						timeout <= 0;
					else
						if (cmd_rx = '1') then
							timeout <= 0;
						else	
							timeout <= timeout + 1;
						end if;
					end if;
				end if;
			
			when S_FWD =>
				-- Fake Interaction with FIFO
				empty <= '0';
				ack <= '1';

				if (C_GET_CHAR_I = '1') then
					up_state <= S_PASS;
				end if;
			
			when S_PASS	=>
				if (D_RX_CHAR_I = char2vec(STOPCHAR)) AND (D_GET_ACK_I = '1') then		-- Stopchar has been received from FIFO
					EOC_O	 <= '1';
					up_state <= S_IDLE;
				end if;
				
			when S_TAKE =>
				if (D_RX_EMPTY_I = '0') then											-- New Char available
					get_char	<= '1';
					up_state	<= S_PUT;
				end if;
			
			when S_PUT =>
				if (D_GET_ACK_I = '1') then
					U_TX_CHAR_O		<= D_RX_CHAR_I;
					U_PUT_CHAR_O	<= NOT nack;
					up_state		<= S_ACK;
				end if;
			
			when S_ACK =>
				if (U_PUT_ACK_I = '1') OR (nack = '1') then
					if (D_RX_CHAR_I = char2vec(STOPCHAR)) then							-- Stopchar has been put to TX FiFo -> return to IDLE
						EOC_O	 	<= '1';
						NACK_O		<= nack;
						up_state	<= S_IDLE;
					else
						up_state	<= S_TAKE;
					end if;
				end if;
				
				
			end case;
		end if;
	end if;
end process;

D_PUT_CHAR_O	<= C_PUT_CHAR_I	OR put_flag when dn_state = S_PASS OR dn_state = S_IDLE else put_char;
C_PUT_ACK_O		<= D_PUT_ACK_I				when dn_state = S_PASS OR dn_state = S_IDLE else '0';
C_TX_FULL_O		<= D_TX_FULL_I				when dn_state = S_PASS OR dn_state = S_IDLE else '0';
D_TX_CHAR_O		<= C_TX_CHAR_I				when dn_state = S_PASS OR dn_state = S_IDLE else char;

DOWN : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RESET_I = '1' then
			dn_state	<= S_IDLE;
			put_flag	<= '0';
			char		<= (others => '0');
			in_count	<= 0;
		else
			cmd_rx			<= '0';
			put_char 		<= '0';
			U_GET_CHAR_O	<= '0';
			EOR_O			<= '0';
			
			if (C_PUT_CHAR_I = '1') then
				put_flag <= '1';
			end if;
			
			case (dn_state) is
			when S_IDLE =>
				
				if (U_RX_EMPTY_I = '0') then
					dn_state <= S_TAKE;
				elsif (C_PUT_CHAR_I = '1' OR put_flag = '1') then
					dn_state <= S_PASS;
					put_flag <= '0';
				end if;
				
			when S_PASS =>
				put_flag <= '0';
				
				if ((C_TX_CHAR_I = char2vec(ACKCHAR))	OR
					(C_TX_CHAR_I = char2vec(NACKCHAR)))	AND
					(D_PUT_ACK_I = '1')
				then																	-- Stopchar has been put into FIFO
					EOR_O	 <= '1';
					dn_state <= S_IDLE;
				end if;	
			
			when S_TAKE =>
				if (U_RX_EMPTY_I = '0') then											-- New Char available
					U_GET_CHAR_O	<= '1';
					dn_state		<= S_PUT;
				end if;
			
			when S_PUT =>
				if (U_GET_ACK_I = '1') then
					if (U_RX_CHAR_I /= NULL_CHAR) then
						char			<= U_RX_CHAR_I;
						put_char		<= '1';
						dn_state 		<= S_ACK;
					else
						dn_state		<= S_IDLE;
					end if;
				end if;
			
			when S_ACK =>
				if (D_PUT_ACK_I = '1') then
					if	(U_RX_CHAR_I = char2vec(ACKCHAR)) OR
						(U_RX_CHAR_I = char2vec(NACKCHAR))
					then																-- Ack/Nack-char has been put to TX FiFo -> return to IDLE
						EOR_O	 	<= '1';
						
						if (out_count /= in_count) then									-- When waiting for CMDs
							in_count	<= in_count + 1;								-- Count Replies from other FPGAs
							cmd_rx		<= '1';
						end if;
						
						dn_state	<= S_IDLE;
					else
						dn_state	<= S_TAKE;
					end if;
				end if;
			
			when others =>
				dn_state <= S_IDLE;	
			
			end case;
		end if;
	end if;
end process;

end architecture;
