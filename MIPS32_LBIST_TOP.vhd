-- Copyright (c) 2025 LBIST Project
-- Author: LBIST Team
-- Module: MIPS32 with LBIST Integration
-- Description: Top-level integration of MIPS32 processor with LBIST system
-- This module combines MIPS32 multi-cycle processor with scan-based LBIST
-- Supports proper shift-capture operation for instruction testing
-- All scan chains have identical length for synchronized capture

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MIPS32_LBIST_TOP is
  generic(
    -- Scan chain configuration
    SCAN_CHAIN_LENGTH : integer := 1024;  -- Identical length for all chains
    PIPELINE_STAGES   : integer := 5;      -- Number of pipeline stages (capture cycles)
    -- Multi-cycle processor stages:
    -- 1. Instruction Fetch
    -- 2. Instruction Decode  
    -- 3. Execution
    -- 4. Memory Access (if needed)
    -- 5. Write Back
    -- Total: 5 stages maximum
    CAPTURE_CYCLES    : integer := 5      -- Capture cycles = pipeline stages
  );
  port(
    CLK           : in  std_logic;
    reset_neg     : in  std_logic;
    
    -- Test mode control
    test_mode     : in  std_logic;  -- 1 = test mode (LBIST), 0 = normal mode
    scan_enable   : in  std_logic;  -- 1 = shift mode, 0 = capture/normal mode
    
    -- LBIST control
    lfsr_seed     : in  std_logic_vector(31 downto 0);
    lfsr_enable   : in  std_logic;
    
    -- Status outputs
    test_complete : out std_logic;
    lbist_status  : out std_logic_vector(7 downto 0);
    
    -- Scan chain outputs (for verification)
    scan_out_chain_0 : out std_logic;  -- Register file scan out
    scan_out_chain_1 : out std_logic;  -- PC scan out
    scan_out_chain_2 : out std_logic;  -- Temp registers scan out
    scan_out_chain_3 : out std_logic   -- Reserved scan out
  );
end MIPS32_LBIST_TOP;

architecture Behavioral of MIPS32_LBIST_TOP is
  
  -- Component declarations for LBIST
  component LBIST_TOP is
    generic(
      LFSR_WIDTH       : integer := 32;
      NUM_SCAN_CHAINS  : integer := 4;
      SCAN_CHAIN_LENGTH: integer := 100;
      ALPHA            : integer := 38;
      BETA             : integer := 19;
      GAMMA            : integer := 38
    );
    port(
      CLK              : in  std_logic;
      reset_neg        : in  std_logic;
      scan_enable      : in  std_logic;
      test_mode        : in  std_logic;
      lfsr_seed        : in  std_logic_vector(31 downto 0);
      lfsr_enable      : in  std_logic;
      scan_out         : out std_logic_vector(3 downto 0);
      scan_feedback    : in  std_logic_vector(3 downto 0);
      lfsr_output      : out std_logic_vector(31 downto 0);
      scan_counter     : out std_logic_vector(7 downto 0)
    );
  end component;
  
  -- Component declarations for MIPS32 (serial scan with identical length)
  component scan_registers_serial is
    generic(
      SCAN_CHAIN_LENGTH : integer := 1024
    );
    port( 
      CLK          : in std_logic;
      reset_neg     : in std_logic;
      address_in_1 : in std_logic_vector(4 downto 0);
      address_in_2 : in std_logic_vector(4 downto 0);
      write_reg    : in std_logic_vector(4 downto 0);
      write_data   : in std_logic_vector(31 downto 0);
      RegWrite     : in std_logic;
      scan_enable  : in std_logic;
      scan_in      : in std_logic;
      scan_out     : out std_logic;
      register_1   : out std_logic_vector(31 downto 0);
      register_2   : out std_logic_vector(31 downto 0)
    );
  end component;
  
  component scan_program_counter_serial is
    generic(
      SCAN_CHAIN_LENGTH : integer := 1024
    );
    port( 
      CLK        : in  std_logic;
      reset_neg  : in  std_logic;
      input      : in  std_logic_vector(31 downto 0);
      PCcontrol  : in  std_logic;
      scan_enable : in  std_logic;
      scan_in     : in  std_logic;
      scan_out    : out std_logic;
      output : out std_logic_vector(31 downto 0)
    );
  end component;
  
  component scan_temp_registers_serial is
    generic(
      SCAN_CHAIN_LENGTH : integer := 1024
    );
    port( 
      CLK         : in std_logic;
      reset_neg   : in std_logic;
      in_reg_A    : in std_logic_vector(31 downto 0);
      in_reg_B    : in std_logic_vector(31 downto 0);
      in_ALU_out  : in std_logic_vector(31 downto 0);
      scan_enable : in std_logic;
      scan_in     : in std_logic;
      scan_out    : out std_logic;
      out_reg_A   : out std_logic_vector(31 downto 0);
      out_reg_B   : out std_logic_vector(31 downto 0);
      out_ALU_out : out std_logic_vector(31 downto 0)
    );
  end component;
  
  -- Internal signals
  signal lbist_scan_out : std_logic_vector(3 downto 0);
  signal lbist_scan_feedback : std_logic_vector(3 downto 0);
  signal lbist_counter : std_logic_vector(7 downto 0);
  
  -- Serial scan chain connections (one bit per chain)
  signal reg_scan_in : std_logic;
  signal reg_scan_out : std_logic;
  signal pc_scan_in : std_logic;
  signal pc_scan_out : std_logic;
  signal temp_scan_in : std_logic;
  signal temp_scan_out : std_logic;
  
  -- MIPS32 internal signals (simplified for scan integration)
  signal pc_out : std_logic_vector(31 downto 0);
  signal reg_data_1, reg_data_2 : std_logic_vector(31 downto 0);
  signal temp_reg_A, temp_reg_B, temp_ALU_out : std_logic_vector(31 downto 0);
  
  -- Capture cycle counter
  signal capture_counter : integer range 0 to PIPELINE_STAGES := 0;
  signal capture_complete : std_logic := '0';
  
begin
  
  -- Instantiate LBIST system
  LBIST_INST: LBIST_TOP
    generic map(
      LFSR_WIDTH        => 32,
      NUM_SCAN_CHAINS   => 4,
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH,  -- Use identical length
      ALPHA             => 38,
      BETA              => 19,
      GAMMA             => 38
    )
    port map(
      CLK           => CLK,
      reset_neg     => reset_neg,
      scan_enable   => scan_enable,
      test_mode     => test_mode,
      lfsr_seed     => lfsr_seed,
      lfsr_enable   => lfsr_enable,
      scan_out      => lbist_scan_out,
      scan_feedback => lbist_scan_feedback,
      scan_counter  => lbist_counter,
      lfsr_output  => open
    );
  
  -- Instantiate scan-enabled MIPS32 components (SERIAL SCAN with IDENTICAL LENGTH)
  -- Register File (Chain 0): SCAN_CHAIN_LENGTH bits
  REG_FILE: scan_registers_serial
    generic map(
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH
    )
    port map(
      CLK          => CLK,
      reset_neg    => reset_neg,
      address_in_1 => "00000",  -- Simplified for scan
      address_in_2 => "00001",
      write_reg    => "00000",
      write_data   => (others => '0'),
      RegWrite     => '0',
      scan_enable  => scan_enable,
      scan_in      => reg_scan_in,
      scan_out     => reg_scan_out,
      register_1   => reg_data_1,
      register_2   => reg_data_2
    );
  
  -- Program Counter (Chain 1): SCAN_CHAIN_LENGTH bits (padded to match)
  PC: scan_program_counter_serial
    generic map(
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH
    )
    port map(
      CLK         => CLK,
      reset_neg   => reset_neg,
      input       => (others => '0'),
      PCcontrol   => '0',
      scan_enable => scan_enable,
      scan_in     => pc_scan_in,
      scan_out    => pc_scan_out,
      output      => pc_out
    );
  
  -- Temp Registers (Chain 2): SCAN_CHAIN_LENGTH bits (padded to match)
  TEMP_REG: scan_temp_registers_serial
    generic map(
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH
    )
    port map(
      CLK         => CLK,
      reset_neg   => reset_neg,
      in_reg_A    => (others => '0'),
      in_reg_B    => (others => '0'),
      in_ALU_out  => (others => '0'),
      scan_enable => scan_enable,
      scan_in     => temp_scan_in,
      scan_out    => temp_scan_out,
      out_reg_A   => temp_reg_A,
      out_reg_B   => temp_reg_B,
      out_ALU_out => temp_ALU_out
    );
  
  -- Capture cycle counter (for pipelined processor)
  -- Counts capture cycles equal to pipeline stages
  process(CLK, reset_neg)
  begin
    if reset_neg = '0' then
      capture_counter <= 0;
      capture_complete <= '0';
    elsif rising_edge(CLK) then
      if test_mode = '1' and scan_enable = '0' then
        -- Capture mode: count cycles for pipeline stages
        if capture_counter < PIPELINE_STAGES - 1 then
          capture_counter <= capture_counter + 1;
          capture_complete <= '0';
        else
          capture_counter <= PIPELINE_STAGES - 1;
          capture_complete <= '1';  -- Capture complete after all pipeline stages
        end if;
      else
        -- Reset counter when not in capture mode
        capture_counter <= 0;
        capture_complete <= '0';
      end if;
    end if;
  end process;
  
  -- Serial scan chain connections
  -- Chain 0: Register file (SCAN_CHAIN_LENGTH bits)
  reg_scan_in <= lbist_scan_out(0) when test_mode = '1' else '0';
  lbist_scan_feedback(0) <= reg_scan_out;
  
  -- Chain 1: Program Counter (SCAN_CHAIN_LENGTH bits, padded)
  pc_scan_in <= lbist_scan_out(1) when test_mode = '1' else '0';
  lbist_scan_feedback(1) <= pc_scan_out;
  
  -- Chain 2: Temp Registers (SCAN_CHAIN_LENGTH bits, padded)
  temp_scan_in <= lbist_scan_out(2) when test_mode = '1' else '0';
  lbist_scan_feedback(2) <= temp_scan_out;
  
  -- Chain 3: Reserved/Instruction storage (SCAN_CHAIN_LENGTH bits)
  lbist_scan_feedback(3) <= lbist_scan_out(3);  -- For now, just echo back
  
  -- Status outputs
  test_complete <= '1' when (unsigned(lbist_counter) >= SCAN_CHAIN_LENGTH - 1) else '0';
  lbist_status <= lbist_counter;
  
  -- Scan chain outputs (for verification)
  scan_out_chain_0 <= reg_scan_out;
  scan_out_chain_1 <= pc_scan_out;
  scan_out_chain_2 <= temp_scan_out;
  scan_out_chain_3 <= lbist_scan_out(3);
  
end Behavioral;
