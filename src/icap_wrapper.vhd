library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.all;
use work.types.all;
use Work.util.all;

entity icap_wrapper is
	Generic (
		START_ADDR		: std_logic_vector(23 downto 0) := x"000000";
		FALLBACK_ADDR	: std_logic_vector(23 downto 0) := x"000000";
		CLOCK_DIV		: integer := 2
	);
	Port (
		CLK_I			: in STD_LOGIC;
		RESET_I			: in STD_LOGIC := '0';
		RECONFIG_I		: in STD_LOGIC := '0'
	);
end icap_wrapper;

architecture Behavioral of icap_wrapper is

-- UG380, Page 136, Table 7-1
constant cmd	: array16_t(0 to 13) := (
	x"FFFF",
	x"AA99",
	x"5566",
	x"3261",
	START_ADDR(15 downto 0),
	x"3281",
	x"0B" & START_ADDR(23 downto 16),
	x"32A1",
	FALLBACK_ADDR(15 downto 0),
	x"32C1",
	x"0B" & FALLBACK_ADDR(23 downto 16),
	x"30A1",
	x"000E",
	x"2000"
); 

signal c 		: integer range 0 to cmd'high;

signal flag		: std_logic := '0';

signal clk		: std_logic := '0';
signal div		: integer range 0 to CLOCK_DIV-1 := 0;

signal csib		: std_logic := '1';
signal rdwrb	: std_logic := '0';
signal data		: std_logic_vector(15 downto 0) := x"FFFF";
signal data_i	: std_logic_vector(15 downto 0) := x"FFFF";

type state_t 	is (S_IDLE, S_IPROG);
signal state	: state_t := S_IDLE;

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RESET_I = '1' then
			state	<= S_IDLE;
			flag	<= '0';
			clk		<= '0';
			div		<= 0;
		else
			data	<= cmd(c);
			
			if (RECONFIG_I = '1') then
				flag <= '1';
			end if;
			
			if div = CLOCK_DIV-1 then
				div <= 0;
				clk <= NOT clk;

				if clk = '1' then				-- On the Falling Edge					
					case (state) is
					when S_IDLE =>
						c		<= 0;
						csib	<= '1';
						rdwrb	<= '1';			-- Read
						
						if (flag = '1') then
							state	<= S_IPROG;
							flag	<= '0';
							csib	<= '0';		-- Active LOW enable
							rdwrb	<= '0';		-- Write
						end if;
						
					when S_IPROG =>
						csib <= '0';
						
						if (c < cmd'high) then
							c <= c + 1;
						else
							state <= S_IDLE;
						end if;
										
					end case;
				end if;
			else 
				div <= div + 1;
			end if;
		end if;
	end if;
end process;

swap : for b in 0 to 1 generate
	data_i((b+1)*8-1 downto b*8) <= bit_reverse(data((b+1)*8-1 downto b*8));
end generate;

icap : ICAP_SPARTAN6
generic map (
	DEVICE_ID 			=> X"04000093",	-- Specifies the pre-programmed Device ID value
	SIM_CFG_FILE_NAME	=> "NONE" 		-- Specifies the Raw Bitstream (RBT) file to be parsed by the simulation model
)
port map (
	CLK		=> clk,			-- 1-bit input: Clock input
	CE		=> csib,		-- 1-bit input: Active-Low ICAP Enable input
	WRITE	=> rdwrb,		-- 1-bit input: Read/Write control input
	I		=> data_i,		-- 16-bit input: Configuration data input bus
	O		=> open,		-- 16-bit output: Configuartion data output bus
	BUSY	=> open			-- 1-bit output: Busy/Ready output
);

end Behavioral;
