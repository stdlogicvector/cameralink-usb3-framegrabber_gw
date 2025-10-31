library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.util.all;

entity uart_cmd_handler is
	generic (
		DATA_BITS			: integer	:= 8;
		MAX_ARGS			: integer	:= 10
	);
	port (
		CLK_I			: in	std_logic;
		RST_I			: in	std_logic;
	
		-- Control Connections
		BUSY_O			: out	std_logic := '0';
		
		NEW_CMD_I		: in	std_logic := '0';
		CMD_ACK_O 		: out	std_logic := '0';
		CMD_ID_I		: in	std_logic_vector(DATA_BITS-1 downto 0);
		CMD_ARGS_I		: in	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0);
		CMD_ARGN_I		: in	std_logic_vector(clogb2(MAX_ARGS+1) - 1 downto 0) := (others => '0');
		
		NEW_ACK_O		: out	std_logic := '0';
		NEW_NACK_O		: out	std_logic := '0';
		
		NEW_REPLY_O		: out	std_logic := '0';
		REPLY_ACK_I		: in	std_logic := '0';
		REPLY_ID_O		: out	std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		REPLY_ARGS_O	: out	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0) := (others => '0');
		REPLY_ARGN_O	: out	std_logic_vector(clogb2(MAX_ARGS+1) - 1 downto 0) := (others => '0');
		
		UART_BUSY_I		: in	std_logic := '0';
		
		-- Soft Reset
		SOFT_RST_O		: out	std_logic := '0';
		
		-- Timestamp
		TST_DV_O		: out	std_logic := '0';
		TST_PS_DV_O		: out	std_logic := '0';
		TST_PS_O		: out	std_logic_vector(7 downto 0) := (others => '0');
		TST_DATA_O		: out	std_logic_vector(31 downto 0) := (others => '0');
		TST_DATA_I		: in	std_logic_vector(31 downto 0);
		
		-- Internal Registers
		REG_WRITE_O		: out	std_logic := '0';
		REG_READ_O		: out	std_logic := '0';
		REG_ADDR_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		REG_DATA_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		REG_DATA_I		: in	std_logic_vector(15 downto 0) := (others => '0');
		REG_ACK_I		: in	std_logic := '1';
		
		-- Control
		CC_O			: out	std_logic_vector(3 downto 0) := (others => '0');

		-- Flash Controller Interface
		FL_NEW_CMD_O	: out	std_logic := '0';
		FL_CMD_O		: out	std_logic_vector (7 downto 0) := (others => '0');
		FL_NEW_DATA_O	: out	std_logic := '0';
		FL_DATA_O		: out	std_logic_vector (31 downto 0) := (others => '0');
		
		FL_RTR_O		: out	std_logic := '0';
		FL_RTS_I		: in	std_logic := '0';
		FL_BUSY_I		: in	std_logic := '0';
		
		FL_NEW_DATA_I	: in	std_logic := '0';
		FL_DATA_I		: in	std_logic_vector (31 downto 0) := (others => '0');
		
		-- Reconfiguration
		RECONFIG_O		: out	std_logic := '0'
	);
end uart_cmd_handler;

architecture RTL of uart_cmd_handler is

constant ARG_NR_WIDTH	: integer := clogb2(MAX_ARGS+1);

-- Command IDs

constant READ_REG		: character := 'R';
constant WRITE_REG		: character := 'W';

constant READ_TIME		: character := 'T';
constant SET_TIME		: character := 'U';
constant SET_PRESCALER	: character := 'p';

constant FLASH_CMD		: character := 'M';
constant FLASH_DATA		: character := 'm';
constant RECONFIGURE	: character := '*';

constant CONTROL		: character := 'C';

constant SOFT_RESET		: character	:= 'Z';

--constant ICAP_READ		: character := 'h';
--constant ICAP_WRITE		: character := 'g';

--constant READ_DEBUG		: character := 'D';

--------------------------------------------------------------------------------

constant id_reg_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(READ_REG);
constant id_reg_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(WRITE_REG);

constant id_time_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(READ_TIME);
constant id_time_set	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SET_TIME);
constant id_prescale_set: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SET_PRESCALER);
constant id_soft_reset	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SOFT_RESET);

constant id_flash_cmd	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(FLASH_CMD);
constant id_flash_data	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(FLASH_DATA);
constant id_reconfigure : std_logic_vector(DATA_BITS-1 downto 0) := char2vec(RECONFIGURE);

constant id_control		: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(CONTROL);

--constant id_icap_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(ICAP_READ);
--constant id_icap_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(ICAP_WRITE);

--constant id_dbg_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(READ_DEBUG);

-- Control Signals

type std_logic_bus is array(natural range <>) of std_logic_vector(DATA_BITS-1 downto 0);

type state_t is (
S_IDLE,
S_CMD,
S_WAIT_FOR_START,
S_WAIT_FOR_END,
S_REPLY,
S_WAIT_FOR_REPLY
);

constant ARGN_LEN	: integer := clogb2(MAX_ARGS+1) - 1;

signal state : state_t := S_IDLE;

signal cmd_id		: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal cmd_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));
signal cmd_argn		: std_logic_vector(ARGN_LEN downto 0);
signal rpl_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));

signal flash_ack	: std_logic := '0';

constant ZERO_LENGTH: integer := 8;
signal zero_count	: integer range 0 to ZERO_LENGTH-1 := 0;

begin

args : for i in 0 to MAX_ARGS-1 generate
	REPLY_ARGS_O((8*(i+1)-1) downto (8*i)) <= rpl_args(i);
end generate;

fsm : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state 		 <= S_IDLE;
			cmd_id		 <= (others => '0');

			zero_count 	 <= 0;
			rpl_args	 <= (others => (others => '0'));
			REPLY_ID_O	 <= (others => '0');
		else
			CMD_ACK_O	 	<= '0';
			NEW_ACK_O	 	<= '0';
			NEW_NACK_O	 	<= '0';
			NEW_REPLY_O	 	<= '0';
		
			SOFT_RST_O		<= '0';
			TST_DV_O		<= '0';
			TST_PS_DV_O		<= '0';
			FL_NEW_CMD_O	<= '0';
			FL_NEW_DATA_O	<= '0';
			REG_WRITE_O 	<= '0';
			REG_READ_O		<= '0';
			RECONFIG_O		<= '0';
	
			case (state) is
			when S_IDLE =>
				BUSY_O 		<= '0';
				FL_RTR_O 	<= '0';
	
				flash_ack	<= '0';

				if (NEW_CMD_I = '1') then
					BUSY_O 		<= '1';
					CMD_ACK_O	<= '1';
					cmd_id		<= CMD_ID_I;
					cmd_argn	<= CMD_ARGN_I;
					
					args : for i in 0 to MAX_ARGS-1 loop
						cmd_args(i) <= 	CMD_ARGS_I((8*(i+1)-1) downto (8*i));
					end loop;
						
					state <= S_CMD;
				end if;
				
			when S_CMD =>
				REPLY_ID_O <= cmd_id;
				
				state <= S_WAIT_FOR_START;
				
				case cmd_id is
				
				when id_reg_read =>
					REG_ADDR_O <= cmd_args(0);
					
					REG_WRITE_O <= '0';
					REG_READ_O	<= '1';
				
				when id_reg_write =>
					REG_ADDR_O  <= cmd_args(0);
					REG_DATA_O  <= cmd_args(1) & cmd_args(2);
					
					REG_WRITE_O <= '1';
					REG_READ_O	<= '0';
					
				when id_soft_reset =>
					SOFT_RST_O	<= '1';
					
				when id_time_set =>
					TST_DATA_O <= cmd_args(0) & cmd_args(1) & cmd_args(2) & cmd_args(3);
					
				when id_prescale_set =>
					TST_PS_O	<= cmd_args(1);
					
				when id_control =>
					CC_O <= cmd_args(0)(3 downto 0);
									
				when id_flash_cmd =>							-- Flash CMD : Opcode in first Arg, Params (Addr, ByteCount) in 2-4 Arg
					if (FL_BUSY_I = '0') then
						FL_CMD_O <= cmd_args(0);
						FL_DATA_O( 7 downto  0)	<= cmd_args(3);
						FL_DATA_O(15 downto  8)	<= cmd_args(2);
						FL_DATA_O(23 downto 16)	<= cmd_args(1);
						FL_NEW_CMD_O <= '1';
						flash_ack 	<= '0';
					else
						state <= S_CMD;
					end if;
					
				when id_flash_data =>							-- Flash Data
					FL_NEW_DATA_O <= '1';
					FL_DATA_O( 7 downto  0) <= cmd_args(3);
					FL_DATA_O(15 downto  8) <= cmd_args(2);
					FL_DATA_O(23 downto 16) <= cmd_args(1);
					FL_DATA_O(31 downto 24) <= cmd_args(0);
					
				when id_reconfigure =>
					RECONFIG_O <= '1';
					
				when others =>
					NULL;
				end case;
				
			when S_WAIT_FOR_START =>
				case cmd_id is

				when id_time_set =>
					TST_DV_O <= '1';
					
					if zero_count = ZERO_LENGTH-1 then
						zero_count <= 0;
						state <= S_WAIT_FOR_END;
					else
						zero_count <= zero_count + 1;
					end if;						
					
				when id_prescale_set =>
					TST_PS_DV_O <= '1';	
					state <= S_WAIT_FOR_END;
									
				when id_flash_cmd =>	
					if ((flash_ack = '0') AND (FL_BUSY_I = '1')) OR
					   ((flash_ack = '1') AND (REPLY_ACK_I = '1'))
					then
						state 		<= S_WAIT_FOR_END;
					end if;
							
				when id_reconfigure =>
					RECONFIG_O <= '1';
					state <= S_WAIT_FOR_END;
				
				when others =>
					state <= S_WAIT_FOR_END;
				end case;
				
			when S_WAIT_FOR_END =>
				case cmd_id is
				when id_flash_cmd	|
					 id_flash_data	=>
					FL_RTR_O <= '1';
					 				
					if (FL_NEW_DATA_I = '1') then	-- New bytes received, repeated for previously set bytecount 
						NEW_REPLY_O <= '1';
						--NEW_ACK_O	<= '1';			-- ACK every 4byte Transfer
						rpl_args(0) <= FL_DATA_I(31 downto 24);
						rpl_args(1) <= FL_DATA_I(23 downto 16);
						rpl_args(2) <= FL_DATA_I(15 downto  8);
						rpl_args(3) <= FL_DATA_I( 7 downto  0);
						REPLY_ARGN_O<= int2vec(4, ARG_NR_WIDTH);
						FL_RTR_O	<= '0';
						flash_ack	<= '1';
						state 		<= S_WAIT_FOR_START;
					end if;
					
					if (FL_RTS_I = '1') OR (FL_BUSY_I = '0') then
						state <= S_REPLY;
					end if;
				
				when others =>
					state <= S_REPLY;
				end case;
			
			when S_REPLY =>
				case cmd_id is
					
				when id_reg_read =>
					NEW_ACK_O		<= REG_ACK_I;
					NEW_NACK_O		<= NOT REG_ACK_I;
					NEW_REPLY_O		<= REG_ACK_I;
					rpl_args(0) 	<= REG_DATA_I(15 downto 8);
					rpl_args(1) 	<= REG_DATA_I( 7 downto 0);
					REPLY_ARGN_O	<= int2vec(2, ARG_NR_WIDTH);
					
				when id_reg_write =>
					NEW_ACK_O		<= REG_ACK_I;
					NEW_NACK_O		<= NOT REG_ACK_I;
			
				when id_time_read =>
					NEW_REPLY_O 	<= '1';
					NEW_ACK_O		<= '1';
					rpl_args(0) 	<= TST_DATA_I(31 downto 24);
					rpl_args(1) 	<= TST_DATA_I(23 downto 16);
					rpl_args(2) 	<= TST_DATA_I(15 downto  8);
					rpl_args(3) 	<= TST_DATA_I( 7 downto  0);
					REPLY_ARGN_O	<= int2vec(4, ARG_NR_WIDTH);
 
				when id_soft_reset	|
					 id_time_set	|
					 id_prescale_set|
					 id_flash_cmd	|
					 id_flash_data	|
					 id_reconfigure |
					 id_control		=>
					NEW_ACK_O	<= '1';				
					
				when others =>
					NEW_NACK_O	<= '1';
				end case;
				
				if (UART_BUSY_I = '0') then		-- Wait until UART is done putting reply into FIFO before trying to transmit ACK/NACK
					state <= S_WAIT_FOR_REPLY;
				else
					state <= S_REPLY;
				end if;
				
			when S_WAIT_FOR_REPLY =>
				if (REPLY_ACK_I = '1') then
					state <= S_IDLE;
				end if;
		
			end case;
		end if;
	end if;
end process;

end architecture;