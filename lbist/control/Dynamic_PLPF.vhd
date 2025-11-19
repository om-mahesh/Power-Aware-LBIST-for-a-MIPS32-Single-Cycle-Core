library ieee;
use ieee.std_logic_1164.all;

entity Dynamic_PLPF is
  port(
    current_bit  : in  std_logic;
    future_bit_1 : in  std_logic;
    future_bit_2 : in  std_logic;
    past_bit     : in  std_logic;
    plpf_control : in  std_logic_vector(1 downto 0);
    scan_out     : out std_logic
  );
end Dynamic_PLPF;

architecture Behavioral of Dynamic_PLPF is
  signal and_path : std_logic;
  signal or_path  : std_logic;
begin
  -- Low-toggle path: requires correlated 1's to switch
  and_path <= current_bit and future_bit_1 and future_bit_2;

  -- High-toggle path: flips easily when future bits are 0
  or_path  <= current_bit or (not future_bit_1) or (not future_bit_2);

  -- Control mapping:
  --  "00" -> use AND  (α/γ)
  --  "01" -> PASS     (β)
  --  "10" -> use OR   (optional high-toggle mode)
  --  "11" -> PASS     (default)
  with plpf_control select
    scan_out <= and_path   when "00",
                current_bit when "01",
                or_path     when "10",
                current_bit when others;
end Behavioral;
