library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.util.all;

entity flash_controller is
	Generic (
		CLK_MHZ	: real := 100.0 --MHz
	);
	Port (
		CLK_I		: in  STD_LOGIC;
		RESET_I		: in  STD_LOGIC;
		
		nCS_O		: out STD_LOGIC := '1';
		SCK_O		: out STD_LOGIC := '0';
		MISO_I		: in  STD_LOGIC;
		MOSI_O		: out STD_LOGIC := '0';
		
		NEW_CMD_I	: in  STD_LOGIC;
		CMD_I		: in  STD_LOGIC_VECTOR (7 downto 0);
		NEW_DATA_I	: in  STD_LOGIC;
		DATA_I		: in  STD_LOGIC_VECTOR (31 downto 0);
		
		RTR_I		: in  STD_LOGIC := '0';		-- Control is Ready to Receive
		RTS_O		: out STD_LOGIC := '0';		-- Flash is Read to Send
		BUSY_O		: out STD_LOGIC := '0';
		
		NEW_DATA_O	: out STD_LOGIC := '0';
		DATA_O		: out STD_LOGIC_VECTOR (31 downto 0) := (others => '0')
	);
end flash_controller;

architecture RTL of flash_controller is

-- FLASH OpCodes
constant NOP  : std_logic_vector (7 downto 0) := x"FF";  -- no command to execute

constant ID   : std_logic_vector (7 downto 0) := x"9F";  -- Read ID

constant WREN : std_logic_vector (7 downto 0) := x"06";  -- write enable
constant WRDI : std_logic_vector (7 downto 0) := x"04";  -- write disable

constant RDSR : std_logic_vector (7 downto 0) := x"05";  -- read status reg
constant WRSR : std_logic_vector (7 downto 0) := x"01";  -- write stat. reg

constant RDCMD: std_logic_vector (7 downto 0) := x"03";  -- read data
--constant F_RD : std_logic_vector (7 downto 0) := x"0B";  -- fast read data
constant PP	  : std_logic_vector (7 downto 0) := x"02";  -- page program
constant SE	  : std_logic_vector (7 downto 0) := x"D8";  -- sector erase
constant BE	  : std_logic_vector (7 downto 0) := x"C7";  -- bulk erase

constant DP	  : std_logic_vector (7 downto 0) := x"B9";  -- deep power down
constant RES  : std_logic_vector (7 downto 0) := x"AB";  -- resume

constant ADDR : std_logic_vector (7 downto 0) := x"AD";
constant PKTS : std_logic_vector (7 downto 0) := x"DC";

-- SPI
constant SPI_FREQ	: integer := 6250000;  -- 6.25MHz
constant CLK_FREQ	: integer := integer(CLK_MHZ * 1000000.0);
signal clk_cnt		: integer range 0 to (CLK_FREQ / SPI_FREQ);
signal clk_falling	: std_logic := '0';
signal clk_rising 	: std_logic := '0';
 
signal tx_reg		: std_logic_vector(31 downto 0) := (others => '1');
signal rx_reg		: std_logic_vector(31 downto 0) := (others => '1');
signal tx_cnt		: std_logic_vector( 5 downto 0) := (others => '0');
signal rx_cnt		: std_logic_vector( 5 downto 0) := (others => '0');

signal tx_start   	: std_logic := '0';
signal rx_start		: std_logic := '0';

signal tx_sreg		: std_logic_vector(31 downto 0) := (others => '1');
signal rx_sreg		: std_logic_vector(31 downto 0) := (others => '1');
signal tx_scnt		: std_logic_vector( 5 downto 0) := (others => '0');
signal rx_scnt		: std_logic_vector( 5 downto 0) := (others => '0');

signal tx_finish  	: std_logic := '0';
signal rx_finish  	: std_logic := '0';

type state_t is
(
	IDLE, FINISH,
	TX_CMD, TX_CMD_WAIT,
	TX_ADDR,	TX_ADDR_WAIT,
	TX_DATA, TX_WAIT, WAIT_FOR_TX_DATA,
--	TX_DUMMY, TX_DUMMY_WAIT,
	RX_DATA, RX_WAIT, WAIT_FOR_RX_DATA
);

signal state : state_t := IDLE;

type tstate_t is
(
	IDLE,
	TRANSFER,
	WAIT1
);

signal tx_state, rx_state : tstate_t := IDLE;

signal command	: std_logic_vector( 7 downto 0) := (others => '0');
signal address 	: std_logic_vector(23 downto 0) := (others => '0');
signal pkt_cnt	: std_logic_vector(23 downto 0) := (others => '0');
signal pkt_scnt	: std_logic_vector(23 downto 0) := (others => '0');

signal busy 	: std_logic := '0';

begin

BUSY_O 	<= busy;
MOSI_O	<= tx_sreg(31);
--nCS_O		<= '0' when (tx_state /= IDLE OR rx_state /= IDLE) else '1';

fsm : process (CLK_I, RESET_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state <= IDLE;
			nCS_O	<= '1';
		else
			NEW_DATA_O	<= '0';
			RTS_O			<= '0';
			tx_start		<= '0';
			rx_start		<= '0';
			
			case (state) is
			when IDLE =>
				busy  <= '0';
				
				if (NEW_CMD_I = '1') then
					busy <= '1';
					
					case (CMD_I) is
					when ADDR =>
						address <= DATA_I(23 downto 0);
						state <= FINISH;
					when PKTS =>
						pkt_cnt <= DATA_I(23 downto 0);
						state <= FINISH;
					when others =>
						command	<= CMD_I;
						state		<= TX_CMD;
						nCS_O		<= '0';
					end case;
				end if;
				
			when TX_CMD =>
				pkt_scnt <= pkt_cnt;	
				tx_reg <= command & x"FFFFFF";										-- 8bit Command + 3 Dummybytes
				tx_cnt <= int2vec(8-1, 6);
				tx_start <= '1';
				state <= TX_CMD_WAIT;
								
			when TX_CMD_WAIT =>
				if (tx_finish = '1') then
					case (command) is
					when WREN | WRDI | BE | DP => state <= FINISH;					-- One Byte Commands
					when ID | RDSR => state <= RX_DATA;								-- Read Data after Command
					when WRSR => state <= TX_DATA;									-- Write Data after Command
					when SE | PP | RES | --F_RD |
						  RDCMD => state <= TX_ADDR;								-- Write Address after Command
					when others => state <= FINISH;
					end case;
				end if;
				
			when TX_ADDR =>
				tx_reg <= address & x"FF";											-- 24bit Address + Dummybyte
				tx_start <= '1';
				tx_cnt	<= int2vec(24-1, 6);
				state <= TX_ADDR_WAIT;
								
			when TX_ADDR_WAIT =>
				if (tx_finish = '1') then
					case (command) is
					when RES | RDCMD => state <= RX_DATA;
					when PP => RTS_O <= '1'; state <= WAIT_FOR_TX_DATA;
--					when F_RD => state <= TX_DUMMY;
					when others => state <= FINISH;
					end case;
				end if;
			
--			when TX_DUMMY =>
--				tx_reg <= x"FFFFFFFF";
--				tx_cnt <= int2vec(8-1, 6);
--				tx_start <= '1';
--				state <= TX_DUMMY_WAIT;
--				
--			when TX_DUMMY_WAIT =>	
--				if (tx_finish = '1') then
--					state <= RX_DATA;
--				end if;
--			
			when RX_DATA =>
				if (RTR_I = '1') then
					rx_cnt <= int2vec(32-1, 6);
					rx_start <= '1';

					state <= RX_WAIT;
				end if;
				
			when RX_WAIT =>
				if (rx_finish = '1') then
					NEW_DATA_O <= '1';
					DATA_O <= rx_reg;
					pkt_scnt <= pkt_scnt - '1';
					state <= WAIT_FOR_RX_DATA;
				end if;
				
			when WAIT_FOR_RX_DATA =>
				if (command /= RDCMD OR pkt_scnt = 0) then
					state <= FINISH;	
				else										-- Continue Reading
					state <= RX_DATA;
				end if;
			
			when WAIT_FOR_TX_DATA =>
				if (command /= PP OR pkt_scnt = 0) then
					state <= FINISH;	
				elsif (NEW_DATA_I = '1') then
					tx_reg <= DATA_I;
					state <= TX_DATA;						-- Continue Writing			
				end if;
		
			when TX_DATA =>
				tx_start <= '1';
				tx_cnt	<= int2vec(32-1, 6);
				state <= TX_WAIT;
				
			when TX_WAIT =>
				if (tx_finish = '1') then
					RTS_O <= '1';
					pkt_scnt <= pkt_scnt - '1';
					state <= WAIT_FOR_TX_DATA;
				end if;
				
			when FINISH =>
				nCS_O <= '1';
				state <= IDLE;
	
			end case;
		end if;
	end if;
end process fsm;

spi_tx : process (RESET_I, CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			tx_state <= IDLE;
			tx_sreg	<= x"FFFFFFFF";
			tx_scnt	<= "000000";
		else
			tx_finish <= '0';
			
			case (tx_state) is			
			when IDLE =>
				if (tx_start = '1') then
					tx_sreg <= tx_reg;
					tx_scnt <= tx_cnt;
					tx_state <= TRANSFER;
				end if;
				
			when TRANSFER =>
				if (clk_falling = '1') then
					if (tx_scnt > "000000") then
						tx_scnt  <= tx_scnt - '1';
						tx_sreg <= tx_sreg(30 downto 0) & '1';
					else
						tx_state <= WAIT1;
					end if;
				end if;
				
			when WAIT1 =>
				tx_finish <= '1';
				tx_state <= IDLE;
				
			end case;
		end if;
	end if;
end process spi_tx;

spi_rx : process (RESET_I, CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			rx_state <= IDLE;
			rx_sreg	<= x"FFFFFFFF";
			rx_scnt	<= "000000";
		else
			rx_finish <= '0';
			
			case (rx_state) is
			when IDLE =>
				if (rx_start = '1') then
					rx_sreg <= x"00000000";
					rx_scnt <= rx_cnt;
					rx_state <= TRANSFER;
				end if;
			
			when TRANSFER =>
				if (clk_rising = '1') then
					rx_sreg <= rx_sreg(30 downto 0) & MISO_I;
					
					if (rx_scnt > "000000") then
						rx_scnt  <= rx_scnt - '1';
					else
						rx_state <= WAIT1;
					end if;
				end if;
			
			when WAIT1 =>
				rx_reg <= rx_sreg;
				rx_finish <= '1';
				rx_state <= IDLE;
				
			end case;
		end if;
	end if;
end process spi_rx;

-- SPI Clock Generator
spi_divider : process (RESET_I, CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			clk_cnt	<= 0;
			clk_falling	<= '0';
			clk_rising <= '0';
			SCK_O		<= '0';
		else
			clk_falling	<= '0';
			clk_rising	<= '0';
			
			if (rx_state = TRANSFER OR tx_state = TRANSFER) then
				if (clk_cnt = (CLK_FREQ / (SPI_FREQ * 2))) then
					clk_cnt <= clk_cnt + 1;
					clk_rising <= '1';
					SCK_O <= '1';
				
				elsif (clk_cnt = (CLK_FREQ / SPI_FREQ)) then
					clk_cnt	<= 0;
					clk_falling	<= '1';
					SCK_O		<= '0';
				else
					clk_cnt <= clk_cnt + 1;
				end if;
			else
				SCK_O <= '0';
				clk_cnt <= 0;
			end if;

		end if;
	end if;
end process spi_divider;

end RTL;

