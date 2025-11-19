library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LFSR is
  generic(
    WIDTH : integer := 32
  );
  port(
    CLK       : in  std_logic;
    reset_neg : in  std_logic;
    seed      : in  std_logic_vector(WIDTH-1 downto 0);
    enable    : in  std_logic;
    output    : out std_logic_vector(WIDTH-1 downto 0);
    bit_out   : out std_logic
  );
end LFSR;

architecture Behavioral of LFSR is
  signal lfsr_reg : std_logic_vector(WIDTH-1 downto 0);
  constant TAP_32 : integer := 31;
  constant TAP_22 : integer := 21;
  constant TAP_2  : integer := 1;
  constant TAP_1  : integer := 0;
  signal feedback : std_logic;
begin
  feedback <= lfsr_reg(TAP_1) xor lfsr_reg(TAP_2) xor
              lfsr_reg(TAP_22) xor lfsr_reg(TAP_32);
  
  process(CLK, reset_neg)
  begin
    if reset_neg = '0' then
      lfsr_reg <= seed;
    elsif rising_edge(CLK) then
      if enable = '1' then
        lfsr_reg <= feedback & lfsr_reg(WIDTH-1 downto 1);
      end if;
    end if;
  end process;
  
  output  <= lfsr_reg;
  bit_out <= lfsr_reg(0);
end Behavioral;