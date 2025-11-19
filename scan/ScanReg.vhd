library ieee;
use ieee.std_logic_1164.all;

-- N-bit scan register.
-- se='1' -> shift (LSB-first in this design), so = MSB
-- se='0' -> capture/hold 'cap_d'
entity ScanReg is
  generic ( N : integer := 32 );
  port (
    clk     : in  std_logic;
    reset_n : in  std_logic;
    se      : in  std_logic;  -- 1=shift, 0=capture/hold
    si      : in  std_logic;  -- serial in
    cap_d   : in  std_logic_vector(N-1 downto 0);
    q       : out std_logic_vector(N-1 downto 0);
    so      : out std_logic
  );
end entity;

architecture rtl of ScanReg is
  signal r : std_logic_vector(N-1 downto 0) := (others => '0');
begin
  process(clk, reset_n)
  begin
    if reset_n = '0' then
      r <= (others => '0');
    elsif rising_edge(clk) then
      if se = '1' then
        r <= r(N-2 downto 0) & si;  -- shift right, LSB-first loading
      else
        r <= cap_d;                 -- capture/hold
      end if;
    end if;
  end process;

  q  <= r;
  so <= r(N-1);                      -- MSB out
end architecture;
