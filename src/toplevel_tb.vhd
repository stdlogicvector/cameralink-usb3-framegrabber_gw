LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.types.all;
USE work.util.ALL;

entity tb_toplevel is
end tb_toplevel;

architecture behavior of tb_toplevel is 

constant UART_BAUDRATE	: integer := 921600;

signal clk50		: std_logic := '0';

signal uart_rx		: std_logic := '1';
signal uart_tx		: std_logic := '1';

-- CL
signal cl_XCLKp		: std_logic := '0';
signal cl_XCLKn		: std_logic := '0';

signal cl_TFG		: STD_LOGIC := '1';
signal cl_TFGp		: STD_LOGIC := '1';
signal cl_TFGn		: STD_LOGIC := '0';

signal cl_TC		: STD_LOGIC := '1';	
signal cl_TCp		: STD_LOGIC := '1';
signal cl_TCn		: STD_LOGIC := '0';

-- GPIF
signal gpif_clock	: STD_LOGIC := '0';
signal gpif_ctl		: STD_LOGIC_VECTOR(29 downto 17);
signal gpif_data	: STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

procedure cmd_send(c : string; signal uart : out std_logic) is
begin
	log("CMD : {" & c & "}");
	uart_puts("{" & c & "}", uart, UART_BAUDRATE);
end procedure;

begin

sim : process
begin
	gpif_ctl(22) <= '0';
	wait for 3us;
	
	gpif_ctl(22) <= '1';
		
--	cmd_send("R09", uart_tx);
--	wait for 1us;
	
--	cmd_send("R9E", uart_tx);
--	wait for 1us;
	
--	cmd_send("C01", uart_tx);
--	cmd_send("C00", uart_tx);
--	wait for 10us;
	
	cmd_send("W080300", uart_tx);	-- 768 pixel per line
	wait for 1us;
	
	cmd_send("W090008", uart_tx);	-- 768 lines per frame
	wait for 1us;
	
--	cmd_send("W0A0008", uart_tx);
--	wait for 1us;
	
	cmd_send("W0B0150", uart_tx);	-- Pause between frames
	wait for 1us;
	
	cmd_send("W010116", uart_tx);
	
--	uart_puts("ok", cl_TFG, 115200);
	
--	cmd_send("C01", uart_tx);
--	cmd_send("C00", uart_tx);

--	wait for 50us;
	
--	cmd_send("W010006", uart_tx);
--	wait for 1us;
	
--	wait for 50us;
		
--	cmd_send("C01", uart_tx);
--	cmd_send("C00", uart_tx);

	wait;
end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

clk_80 : process
begin
	clock_diff(80.0, cl_XCLKp, cl_XCLKn);
end process;

ser_tx : process(cl_TFG)
begin
	cl_TFGp <= cl_TFG;
	cl_TFGn <= not cl_TFG;
end process;

uut : entity work.USB3_FG
generic map (
	UART_BAUDRATE	=> UART_BAUDRATE,
	SIMULATION		=> TRUE
)
port map (
	CLK_I			=> clk50,
	
	-- GPIF
	DQ_O			=> gpif_data,
	CTL_IO			=> gpif_ctl,
	PCLK_O			=> gpif_clock,
	INT_O			=> open,
	
	-- LPP
	SCL_IO			=> 'H',
	SDA_IO			=> 'H',
	MOSI_RX_I		=> uart_tx,
	MISO_TX_O		=> uart_rx,
	CS_I			=> '0',
	SCK_I			=> '0',
	
	-- Misc
	LED_O			=> open,
	POCL_O			=> open,
	
	-- FLASH
	FLASH_CS_O		=> open,
	FLASH_SCK_O		=> open,
	FLASH_MOSI_O	=> open,
	FLASH_MISO_I	=> '0',
	
	-- CameraLink
	CL_CLK_Ip		=> cl_XCLKp,
	CL_CLK_In		=> cl_XCLKn,
	
	CL_DATA_Ip		=> (others => '0'),
	CL_DATA_In		=> (others => '1'),

	CL_CC_Op		=> open,
	CL_CC_On		=> open,
	
	CL_TFG_Ip		=> cl_TFGp,
	CL_TFG_In		=> cl_TFGn,
	
	CL_TC_Op		=> cl_TCp,
	CL_TC_On		=> cl_TCn	
);

END;
