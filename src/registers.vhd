library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use Work.util.all;

entity registers is
	generic (
		NR_OF_REGS	: integer	:= 32
	);
	port (
		-- system signals
		CLK_I		: in	std_logic;
		RST_I		: in	std_logic;

		-- Interface
		ACK_O		: out	std_logic := '0';
		WRITE_I		: in	std_logic := '0';
		READ_I		: in	std_logic := '0';
		ADDR_I		: in	std_logic_vector( 7 downto 0);
		DATA_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		DATA_I		: in	std_logic_vector(15 downto 0);
		
		-- Registers
		REG_DV_O	: out	std_logic_vector(NR_OF_REGS-1 downto 0) := (others => '0');
		REGISTERS_O	: out 	array16_t(0 to NR_OF_REGS-1);
		
		REG_DV_I	: in	std_logic_vector(NR_OF_REGS-1 downto 0);
		REGISTERS_I	: in 	array16_t(0 to NR_OF_REGS-1)
	);
end registers;

architecture Behavioral of registers is

constant ADDR_WIDTH : integer := clogb2(NR_OF_REGS) - 1;

signal reg_ro	: array16_t(0 to NR_OF_REGS-1) := (others => (others => '0'));

signal reg_rw	: array16_t(0 to NR_OF_REGS-1) :=
(
	0	=> ( 								-- Autoreset CMD register
			0 		=> '0',					-- CC Line 0
			1 		=> '0',					-- CC Line 1
			2 		=> '0',					-- CC Line 2
			3 		=> '0',					-- CC Line 3
			others 	=> '0'
	),
	1	=> (								-- 
			0		=> '0',					-- Cameralink Clock selector	(0 = internal, 1 = external)
			1		=> '0',					-- Enable Stream
			2		=> '0',					-- FrameGen Freerun
			
			4		=> '0',					-- FrameGen Mode 0
			5		=> '0',					-- FrameGen Mode 1
			
			8 		=> '0',					-- Color Mode (0 = Raw, 1 = RGB565, 2 = YUV422)
			9		=> '0',
			
			others	=> '0'
	),
	2	=> x"0_0_8_2",						-- 0000 & INV & FVAL & LVAL Mask
	3	=> int2vec(66, 16),					-- Min. Frame Intervall (in 1ms steps)

	4	=> x"0000",							-- ROI Top offset
	5	=> x"0000",							-- ROI Left offset
	6	=> int2vec(774, 16),				-- ROI Width
	7	=> int2vec(774, 16),				-- ROI Height
	
	8	=> x"0000",							-- Color Shift

	12	=> int2vec(774, 16),				-- FrameGen Pixel per Line
	13	=> int2vec(774, 16),				-- FrameGen Lines per Frame
	14	=> int2vec(6500, 16),				-- FrameGen Pause between Lines 	78us	(in 12ns steps)
	15	=> int2vec(25833,16),				-- FrameGen Pause between Frames	310us	(in 12 ns steps)
		 
	others => x"0000"
);

-- 774 x 774 px @ 15Hz
-- 1/((7.74us+78us)*774+310us)
-- {W080306}
-- {W090306}
-- {W0A1964}	-- 78 us
-- {W0B64E9}	-- 310 us

begin

rw : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			reg_ro	<= REGISTERS_I;		-- Get initial values from unchanging registers
		else
			for i in 0 to NR_OF_REGS-1 loop
				if REG_DV_I(i) = '1' then
					reg_ro(i) <= REGISTERS_I(i);
				end if;
			end loop;		
		
			REG_DV_O	<= (others => '0');
			
			if (WRITE_I OR READ_I) = '1' then
				ACK_O		<= WRITE_I OR READ_I;
			end if;
						
			if (WRITE_I = '0') then
				reg_rw(0) <= x"0000";	-- Automatically reset to zero
			end if;
			
			if (ADDR_I(ADDR_I'high) = '0') then
				if (WRITE_I = '1') then
					REG_DV_O(vec2int(ADDR_I(ADDR_WIDTH downto 0)))	<= '1';
					reg_rw(vec2int(ADDR_I(ADDR_WIDTH downto 0)))	<= DATA_I;
				end if;
			end if;
		end if;
	end if;
end process rw;

mux : process(ADDR_I, reg_rw, reg_ro)
begin
	if (ADDR_I(ADDR_I'high) = '0') then
		DATA_O  	<= reg_rw(vec2int(ADDR_I(ADDR_WIDTH downto 0)));
	else
		DATA_O  	<= reg_ro(vec2int(ADDR_I(ADDR_WIDTH downto 0)));
	end if;
end process;

REGISTERS_O <= reg_rw;

end architecture;