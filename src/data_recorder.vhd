library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.vcomponents.all;
use work.types.all;
use work.util.all;

entity data_recorder is
	Generic (
		WIDTH	: integer range 1 to 16 := 12
	);
	Port (
		WR_CLK_I	: in  STD_LOGIC;
		
		EN_I		: in  STD_LOGIC := '1';
		
		FV_MASK_I	: in  STD_LOGIC_VECTOR(3 downto 0);	-- Select Frame Valid Bit(s)
		LV_MASK_I	: in  STD_LOGIC_VECTOR(3 downto 0);	-- Select Line Valid Bit(s)
		INV_MASK_I	: in  STD_LOGIC_VECTOR(3 downto 0); -- Invert Valid Bits
		
		DVAL_I		: in  STD_LOGIC;
		LVAL_I		: in  STD_LOGIC;
		FVAL_I		: in  STD_LOGIC;
		SPARE_I		: in  STD_LOGIC;
		DATA_I		: in  STD_LOGIC_VECTOR(WIDTH-1 downto 0);
		FULL_O		: out STD_LOGIC := '0';
			
		RD_CLK_I	: in  STD_LOGIC;
		READ_I		: in  STD_LOGIC;
		FVAL_O		: out STD_LOGIC := '0';
		LVAL_O		: out STD_LOGIC := '0';
		DATA_O		: out STD_LOGIC_VECTOR(WIDTH-1 downto 0) := (others => '0');
		VALID_O		: out STD_LOGIC := '0';
		EMPTY_O		: out STD_LOGIC := '1';
		AVAIL_O		: out STD_LOGIC := '0';
		THRESHOLD_I	: in  STD_LOGIC_VECTOR(11 downto 0) := int2vec(512, 12)
	);
end data_recorder;

architecture Behavioral of data_recorder is

signal ctrl_in		: std_logic_vector(3 downto 0) := (others => '0');

signal fval			: std_logic_vector(1 downto 0) := (others => '0');
signal lval			: std_logic_vector(1 downto 0) := (others => '0');

signal fval_edge	: std_logic := '0';
signal lval_edge	: std_logic := '0';

signal write		: std_logic := '0';
signal enable		: std_logic := '0';

signal data_dly		: array16_t(0 to 1) := (others => (others => '0'));

signal data_in		: std_logic_vector(17 downto 0) := (others => '0');
signal data_out		: std_logic_vector(17 downto 0) := (others => '0');

signal valid_out	: std_logic := '0';
signal empty_out	: std_logic := '0';

begin

ctrl_in <= (FVAL_I & LVAL_I & DVAL_I & SPARE_I) XOR INV_MASK_I;

rx : process(WR_CLK_I)
begin
	if rising_edge(WR_CLK_I) then
		fval(0)		<= or_reduce(ctrl_in and FV_MASK_I);
		lval(0)		<= or_reduce(ctrl_in and LV_MASK_I);	
		
		fval(1)		<= fval(0);
		lval(1)		<= lval(0);
	
		fval_edge	<= fval(1) XOR fval(0);
		lval_edge	<= lval(1) XOR lval(0);
	
		if fval = "00" then
			enable <= EN_I;
		end if;
		
		data_dly(0)(WIDTH-1 downto 0)	<= DATA_I;
		data_dly(1)						<= data_dly(0);

		write						<= (fval_edge or lval_edge or or_reduce(lval)) and enable;
		data_in(17)					<= fval(1);
		data_in(16) 				<= lval(1);
		data_in(WIDTH-1 downto 0)	<= data_dly(1)(WIDTH-1 downto 0);
	end if;
end process;

fifo : entity work.data_fifo -- 4096x18
PORT MAP (
	rst 						=> '0',
	wr_clk						=> WR_CLK_I,
	wr_en						=> write,
	din							=> data_in,
	full						=> FULL_O,
	
	rd_clk						=> RD_CLK_I,
	rd_en						=> READ_I,
	dout						=> data_out,
	empty						=> empty_out,
	valid						=> valid_out,
	rd_data_count				=> open,
	wr_data_count				=> open,
	prog_full					=> AVAIL_O,
	prog_full_thresh 			=> THRESHOLD_I
);

FVAL_O	<= data_out(17);
LVAL_O	<= data_out(16);
DATA_O	<= data_out(WIDTH-1 downto 0);

EMPTY_O <= empty_out;
VALID_O <= valid_out;

end Behavioral;

