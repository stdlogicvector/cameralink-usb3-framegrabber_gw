library IEEE;
use IEEE.STD_LOGIC_1164.all;

package types is

	---------------------------------------------------------------------------------------------
	-- attributes
	---------------------------------------------------------------------------------------------

	attribute line_buffer_type	: string;	-- "{bufgdll | ibufg | bufgp | ibuf | bufr | none}";
	attribute clock_signal		: string;	-- "{yes | no}";
	attribute ram_style			: string;	-- "{block | distributed | registers}";
	attribute rom_style			: string;	-- "{block | distributed | registers}";
	attribute U_SET				: string;	-- Group Design Elements
	attribute HU_SET			: string;	-- Group Design Elements Hierachically
	attribute ASYNC_REG 		: string;	-- "{TRUE  | FALSE}";

	---------------------------------------------------------------------------------------------
	-- constants
	---------------------------------------------------------------------------------------------

	constant RISING					: std_logic_vector(1 downto 0) := "01";
	constant FALLING				: std_logic_vector(1 downto 0) := "10";

	---------------------------------------------------------------------------------------------
	-- types
	---------------------------------------------------------------------------------------------

	type integer_vector is array(natural range <>) of integer;
	type boolean_vector is array(natural range <>) of boolean;
	type real_vector 	is array(natural range <>) of real;

	type stringarray_t is array(natural range <>) of string(1 to 80);
	
	type array32_t	is array(natural range <>) of std_logic_vector(31 downto 0);
	type array20_t	is array(natural range <>) of std_logic_vector(19 downto 0);
	type array16_t	is array(natural range <>) of std_logic_vector(15 downto 0);
	type array12_t	is array(natural range <>) of std_logic_vector(11 downto 0);
	type array11_t	is array(natural range <>) of std_logic_vector(10 downto 0);
	type array10_t	is array(natural range <>) of std_logic_vector(9 downto 0);
	type array9_t	is array(natural range <>) of std_logic_vector(8 downto 0);
	type array8_t	is array(natural range <>) of std_logic_vector(7 downto 0);
	type array4_t	is array(natural range <>) of std_logic_vector(3 downto 0);

	type bit_array	is array(natural range <>) of std_logic;
	
	--type std_logic_array is array(natural range <>) of std_logic_vector;

end types;

package body types is
 
end types;
