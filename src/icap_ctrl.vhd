library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity icap_ctrl is
	Port (
		CLK_I 			: in  STD_LOGIC;
		RESET_I 		: in  STD_LOGIC;
	
		BUSY_O 			: out STD_LOGIC := '0';
		
		READ_I 			: in  STD_LOGIC;
		ADDR_I 			: in  STD_LOGIC_VECTOR ( 7 downto 0);
		DATA_O 			: out STD_LOGIC_VECTOR (15 downto 0);
		
		ICAP_CE_O 		: out STD_LOGIC;
		ICAP_WRITE_O	: out STD_LOGIC;
		ICAP_BUSY_I		: in  STD_LOGIC;
		ICAP_DATA_O 	: out STD_LOGIC_VECTOR (15 downto 0);
		ICAP_DATA_I 	: in  STD_LOGIC_VECTOR (15 downto 0)
	);
end icap_ctrl;

architecture Behavioral of icap_ctrl is

type vector_array_t is array(natural range <>) of std_logic_vector(15 downto 0); 
type state_t is (IDLE, WRITING, TO_READ, WAIT_FOR_READ, READING, TO_WRITE);

signal state 		: state_t := IDLE;
signal i 	 		: integer range 0 to 31 := 0;

constant R 	 : std_logic := '1';
constant W 	 : std_logic := '0';

signal timeout	: integer range 0 to 63 := 0;

signal cmd 	 : vector_array_t(0 to 15) := (
x"FFFF",	-- 0
x"FFFF",	-- 1
x"AA99",	-- 2
x"5566",	-- 3
x"2000",	-- 4
x"2901",	-- 5
x"2000",	-- 6
x"2000",	-- 7
x"2000",	-- 8
x"2000",	-- 9
x"0000",	-- 10 Read
x"30A1",	-- 11
x"000D",	-- 12
x"2000",	-- 13
x"2000",	-- 14
x"2000"	-- 15
);


begin

process(CLK_I)
begin
	if rising_edge(CLK_I)
	then
		if (RESET_I = '1')
		then
			state 	<= IDLE;
			timeout	<= 0;
		else

			case (state) is
			when IDLE =>
				ICAP_CE_O 		<= '1';
				BUSY_O 	 		<= '0';
				ICAP_WRITE_O	<= W;
				
				if (READ_I = '1') then
					BUSY_O 		<= '1';
					i 				<= 0;
					cmd(5)(10 downto 5) <= ADDR_I(5 downto 0);
					state <= WRITING;
				end if;
				
			when WRITING =>
				ICAP_CE_O		<= '0';
				ICAP_WRITE_O	<= W;
				
				if (cmd(i) = x"0000") then
					state <= TO_READ;
				else
					ICAP_DATA_O <= cmd(i);
					
					ICAP_DATA_O( 7 downto 0) <= cmd(i)(0) & cmd(i)(1) & cmd(i)(2)  & cmd(i)(3)  & cmd(i)(4)  & cmd(i)(5)  & cmd(i)(6)  & cmd(i)(7);
					ICAP_DATA_O(15 downto 8) <= cmd(i)(8) & cmd(i)(9) & cmd(i)(10) & cmd(i)(11) & cmd(i)(12) & cmd(i)(13) & cmd(i)(14) & cmd(i)(15);
					
					if (i >= 15) then
						state <= IDLE;
					else
						i <= i + 1;
					end if;
				end if;
					
			when TO_READ =>
				ICAP_CE_O		<= '1';
				ICAP_WRITE_O	<= R;
				state				<= WAIT_FOR_READ;
					
			when WAIT_FOR_READ =>
				ICAP_CE_O		<= '0';
				ICAP_WRITE_O	<= R;
				
				if (ICAP_BUSY_I = '1') OR (timeout = 63) then
					state 		<= READING;
					timeout		<= 0;
				else
					timeout 		<= timeout + 1;
				end if;
				
			when READING =>
				ICAP_CE_O		<= '0';
				ICAP_WRITE_O	<= R;
				
				if (ICAP_BUSY_I = '0') OR (timeout = 63) then
					timeout		<= 0;
					DATA_O		<= ICAP_DATA_I;
					
					DATA_O( 7 downto 0) <= ICAP_DATA_I(0) & ICAP_DATA_I(1) & ICAP_DATA_I(2)  & ICAP_DATA_I(3)  & ICAP_DATA_I(4)  & ICAP_DATA_I(5)  & ICAP_DATA_I(6)  & ICAP_DATA_I(7);
					DATA_O(15 downto 8) <= ICAP_DATA_I(8) & ICAP_DATA_I(9) & ICAP_DATA_I(10) & ICAP_DATA_I(11) & ICAP_DATA_I(12) & ICAP_DATA_I(13) & ICAP_DATA_I(14) & ICAP_DATA_I(15);
					
					i		<= i + 1;
					state <= TO_WRITE;
				else
					timeout <= timeout + 1;
				end if;
			
			when TO_WRITE =>
				ICAP_CE_O		<= '1';
				ICAP_WRITE_O	<= W;
				state				<= WRITING;
				
			when others =>
				state <= IDLE;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;

