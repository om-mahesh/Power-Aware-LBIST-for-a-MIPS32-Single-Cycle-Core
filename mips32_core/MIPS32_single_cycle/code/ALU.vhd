-- Copyright (c) 2019 David Palma licensed under the MIT license
-- Author: David Palma
-- Project: MIPS32 single cycle
-- Module: ALU

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU is
  GENERIC(n : integer := 32);
  port( -- input
        operand_1     : in std_logic_vector(n - 1 downto 0);
        operand_2     : in std_logic_vector(n - 1 downto 0);
        ALU_control   : in std_logic_vector(3 downto 0);  -- 9 operations
        mux_scan_mode : in std_logic;

        -- output
        result        : out std_logic_vector(n - 1 downto 0);
        scan_data_in : out std_logic_vector(n - 1 downto 0);
        zero          : out std_logic );
end ALU;

architecture Behavioral of ALU is
  signal temp : std_logic_vector(n - 1 downto 0);
begin
  temp <=
    std_logic_vector(unsigned(operand_1) + unsigned(operand_2)) when ALU_control = "0000" else
    std_logic_vector(unsigned(operand_1) - unsigned(operand_2)) when ALU_control = "0001" else
    (operand_1 and  operand_2)                                   when ALU_control = "0010" else
    (operand_1 or   operand_2)                                   when ALU_control = "0011" else
    (not (operand_1 or  operand_2))                              when ALU_control = "0100" else
    (not (operand_1 and operand_2))                              when ALU_control = "0101" else
    (operand_1 xor  operand_2)                                   when ALU_control = "0110" else
    std_logic_vector(shift_left (unsigned(operand_1), to_integer(unsigned(operand_2(10 downto 6))))) when ALU_control = "0111" else
    std_logic_vector(shift_right(unsigned(operand_1), to_integer(unsigned(operand_2(10 downto 6))))) when ALU_control = "1000" else
    (others => '0');

  -- Assert only if exactly zero
  zero <= '1' when unsigned(temp) = 0 else '0';

  process(temp, mux_scan_mode)
  begin
    if mux_scan_mode = '1' then
      scan_data_in <= temp;            -- feed scan DI
      result       <= (others => '0'); -- float normal output in scan mode
    else
      result       <= temp;
      scan_data_in <= (others => '0');
    end if;
  end process;
end Behavioral;
