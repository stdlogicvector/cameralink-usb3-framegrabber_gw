library IEEE, UNISIM;
use UNISIM.VComponents.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity flash_wrapper is
	Generic (
		CLK_MHZ			: real := 200.0;
		START_ADDR		: std_logic_vector(23 downto 0) := x"000000";
		FALLBACK_ADDR	: std_logic_vector(23 downto 0) := x"000000"
	);
	Port (
		CLK_I		: in	STD_LOGIC;
		RESET_I		: in	STD_LOGIC;
		
		RECONFIG_I	: in	STD_LOGIC := '0';
		
		nCS_O		: out	STD_LOGIC := '1';
		SCK_O		: out	STD_LOGIC := '0';
		MOSI_O		: out	STD_LOGIC := '0';
		MISO_I		: in	STD_LOGIC;
		
		NEW_CMD_I	: in	STD_LOGIC;
		CMD_I		: in	STD_LOGIC_VECTOR ( 7 downto 0);
		NEW_DATA_I	: in  	STD_LOGIC;
		DATA_I		: in	STD_LOGIC_VECTOR (31 downto 0);
		
		RTR_I		: in	STD_LOGIC := '0';		-- Control is Ready to Receive
		RTS_O		: out	STD_LOGIC := '0';		-- Flash is Ready to Send
		BUSY_O		: out	STD_LOGIC := '0';
		
		NEW_DATA_O	: out	STD_LOGIC := '0';
		DATA_O		: out	STD_LOGIC_VECTOR (31 downto 0) := (others => '0')
	);
end flash_wrapper;

architecture RTL of flash_wrapper is

begin

flash : entity work.flash_controller
generic map (
	CLK_MHZ			=> CLK_MHZ
)
port map (
	CLK_I			=> CLK_I,
	RESET_I			=> RESET_I,
	
	nCS_O			=> nCS_O,
	SCK_O			=> SCK_O,
	MOSI_O			=> MOSI_O,
	MISO_I			=> MISO_I,
	
	NEW_CMD_I		=> NEW_CMD_I,
	CMD_I			=> CMD_I,
	NEW_DATA_I		=> NEW_DATA_I,
	DATA_I			=> DATA_I,
	
	RTR_I			=> RTR_I,
	RTS_O			=> RTS_O,
	BUSY_O			=> BUSY_O,
	
	NEW_DATA_O		=> NEW_DATA_O,
	DATA_O			=> DATA_O
);

icap : entity work.icap_wrapper
generic map (
	START_ADDR		=> START_ADDR,
	FALLBACK_ADDR	=> FALLBACK_ADDR
)
port map (
	CLK_I			=> CLK_I,
	RESET_I			=> RESET_I,
	RECONFIG_I		=> RECONFIG_I
);

end architecture;