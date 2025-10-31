library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bitmap_cl_rx is
	Port (
		CLK_I	: in  STD_LOGIC;
		
		LVAL_O	: out STD_LOGIC := '0';
		FVAL_O 	: out STD_LOGIC := '0';
		DVAL_O 	: out STD_LOGIC := '0';
		SPARE_O	: out STD_LOGIC := '0';
		
		DATA_O 	: out STD_LOGIC_VECTOR (79 downto 0) := (others => '0');
		DATA_I 	: in  STD_LOGIC_VECTOR (83 downto 0) := (others => '0')
	);
end bitmap_cl_rx;

architecture RTL of bitmap_cl_rx is

begin

-- Per Channel

process (CLK_I)
begin
	if rising_edge(CLK_I)
	then
		FVAL_O <= DATA_I(15);
		LVAL_O <= DATA_I(16);
		DVAL_O <= DATA_I(14);
		SPARE_O<= DATA_I(21);
		
		DATA_O <= (
		
		-- BASE
		
			8	=> DATA_I(0),	
			5	=> DATA_I(1),	
			4	=> DATA_I(2),	
			3	=> DATA_I(3),	
			2	=> DATA_I(4),	
			1	=> DATA_I(5),	
			0	=> DATA_I(6),	
			
			13	=> DATA_I(7),
			12	=> DATA_I(8),
			21	=> DATA_I(9),
			20	=> DATA_I(10),
			11	=> DATA_I(11),
			10	=> DATA_I(12),
			 9  => DATA_I(13),
			
			-- DVAL
			-- FVAL
			-- LVAL
			
			17	=> DATA_I(17),	
			16	=> DATA_I(18),	
			15	=> DATA_I(19),	
			14	=> DATA_I(20),	
			
			-- SPARE
			
			19	=> DATA_I(22),	
			18	=> DATA_I(23),	
			23	=> DATA_I(24),	
			22	=> DATA_I(25),	
			 7	=> DATA_I(26),
			 6	=> DATA_I(27),
			 
		-- MEDIUM
		
			32	=> DATA_I(28),
			29	=> DATA_I(29),
			28	=> DATA_I(30),
			27	=> DATA_I(31),
			26	=> DATA_I(32),
			25	=> DATA_I(33),
			24	=> DATA_I(34),
			
			41	=> DATA_I(35),
			40	=> DATA_I(36),
			37	=> DATA_I(37),
			36	=> DATA_I(38),
			35	=> DATA_I(39),
			34	=> DATA_I(40),
			33	=> DATA_I(41),	
			
			50	=> DATA_I(42),	--
			49	=> DATA_I(43),	--
			48	=> DATA_I(44),	--
			45	=> DATA_I(45),	
			44	=> DATA_I(46),	
			43	=> DATA_I(47),	
			42	=> DATA_I(48),	
			
			51	=> DATA_I(49),	--
			47	=> DATA_I(50),		
			46	=> DATA_I(51),	
			39	=> DATA_I(52),	
			38	=> DATA_I(53),	
			31	=> DATA_I(54),	
			30	=> DATA_I(55),	
			
		-- FULL
		
			60	=> DATA_I(56),
			57	=> DATA_I(57),
			56	=> DATA_I(58),
			55	=> DATA_I(59),
			54	=> DATA_I(60),
			53	=> DATA_I(61),
			52	=> DATA_I(62),
		
			69	=> DATA_I(63),
			68	=> DATA_I(64),
			65	=> DATA_I(65),
			64	=> DATA_I(66),
			63	=> DATA_I(67),
			62	=> DATA_I(68),
			61	=> DATA_I(69),
			
			78	=> DATA_I(70),	--
			77	=> DATA_I(71),	--
			76	=> DATA_I(72),	--
			73	=> DATA_I(73),
			72	=> DATA_I(74),
			71	=> DATA_I(75),
			70	=> DATA_I(76),
			
			79	=> DATA_I(77),	--
			75	=> DATA_I(78),
			74	=> DATA_I(79),
			67	=> DATA_I(80),
			66	=> DATA_I(81),
			59	=> DATA_I(82),
			58	=> DATA_I(83)
		);
		
	end if;
end process;
	
end RTL;

