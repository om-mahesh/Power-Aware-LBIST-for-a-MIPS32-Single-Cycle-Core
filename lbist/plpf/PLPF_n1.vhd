-- Copyright (c) 2025 LBIST Project
-- Author: LBIST Team
-- Module: PLPF (Pseudo Low-Pass Filter) for n=1
-- Description: Direct pass-through (toggle rate = 50%)
-- This is equivalent to no filtering - just pass the current bit

library ieee;
use ieee.std_logic_1164.all;

entity PLPF_n1 is
  port(
    -- Input from PSF
    current_bit  : in  std_logic;  -- Tj
    
    -- Output to scan chain
    scan_out     : out std_logic   -- Sj = Tj (direct pass)
  );
end PLPF_n1;

architecture Behavioral of PLPF_n1 is
begin
  -- Direct pass-through: Sj = Tj
  -- Toggle rate = 50% (same as LFSR output)
  scan_out <= current_bit;
end Behavioral;

