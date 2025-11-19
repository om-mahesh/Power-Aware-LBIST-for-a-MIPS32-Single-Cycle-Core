-- Copyright (c) 2025 LBIST Project
-- Author: LBIST Team
-- Module: PLPF (Pseudo Low-Pass Filter) for n=3
-- Description: Optimized PLPF with n=3 inputs (toggle rate = 7.14%)
-- Based on reference paper Fig. 3(b): Optimized PLPF(n=3)
-- Structure: OR gate, AND gate, and multiplexer controlled by past bit Sj-1

library ieee;
use ieee.std_logic_1164.all;

entity PLPF_n3 is
  port(
    -- Inputs from PSF
    current_bit  : in  std_logic;  -- Tj (current bit)
    future_bit_1 : in  std_logic;  -- Tj+1 (future bit)
    future_bit_2 : in  std_logic;  -- Tj+2 (future bit)
    
    -- Feedback from scan chain
    past_bit     : in  std_logic;  -- Sj-1 (past bit from first FF of scan chain)
    
    -- Output to scan chain
    scan_out     : out std_logic   -- Sj
  );
end PLPF_n3;

architecture Behavioral of PLPF_n3 is
  signal or_output : std_logic;
  signal and_output : std_logic;
  signal mux_output : std_logic;
  
begin
  -- OR gate: OR of current bit, future_bit_1, and future_bit_2
  or_output <= current_bit OR future_bit_1 OR future_bit_2;
  
  -- AND gate: AND of current bit, future_bit_1, and future_bit_2
  and_output <= current_bit AND future_bit_1 AND future_bit_2;
  
  -- Multiplexer: Select OR or AND based on past bit Sj-1
  -- When Sj-1 = 0: select OR output
  -- When Sj-1 = 1: select AND output
  mux_output <= or_output when past_bit = '0' else and_output;
  
  -- Output: Sj only toggles when past_bit differs from (current_bit, future_bit_1, future_bit_2)
  -- This reduces toggle rate to approximately 7.14%
  scan_out <= mux_output;
  
end Behavioral;

