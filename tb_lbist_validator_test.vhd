library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lbist_validator_test is
end tb_lbist_validator_test;

architecture sim of tb_lbist_validator_test is

  constant CLK_PERIOD : time := 10 ns;
  
  -- LBIST Configuration
  constant SCAN_CHAIN_LENGTH : integer := 32;  -- 32-bit instruction scan chain
  constant LFSR_SEED : std_logic_vector(31 downto 0) := x"DEADBEEF";

  -- Clock and reset
  signal clk            : std_logic := '0';
  signal reset_neg      : std_logic := '0';

  -- LBIST control signals
  signal test_mode      : std_logic := '0';
  signal scan_enable    : std_logic := '0';
  signal lfsr_seed_sig  : std_logic_vector(31 downto 0) := LFSR_SEED;
  signal lfsr_enable    : std_logic := '0';
  signal test_complete  : std_logic;
  signal lbist_status   : std_logic_vector(7 downto 0);

  -- TopWithScan_SC signals
  signal scan_instr_sel : std_logic := '0';
  signal se             : std_logic := '1';
  signal ce             : std_logic := '0';
  signal si             : std_logic := '0';
  signal so             : std_logic;
  signal dbg_instruction : std_logic_vector(31 downto 0);
  signal dbg_alu_result : std_logic_vector(31 downto 0);
  signal dbg_instr_valid : std_logic;

  -- LBIST scan output (we'll use chain 3 for instruction injection)
  signal lbist_scan_out : std_logic_vector(3 downto 0);
  signal lbist_scan_feedback : std_logic_vector(3 downto 0);
  signal lbist_current_control : std_logic_vector(1 downto 0);
  
  -- Toggle rate measurement signals
  signal prev_scan_bit : std_logic := '0';
  signal scan_bit_toggle_count : integer := 0;
  signal alpha_toggle_count : integer := 0;
  signal beta_toggle_count : integer := 0;
  signal gamma_toggle_count : integer := 0;
  signal alpha_bit_count : integer := 0;
  signal beta_bit_count : integer := 0;
  signal gamma_bit_count : integer := 0;
  
  -- Constants for PLPF regions (must match LBIST generic values)
  -- Note: For 32-bit scan chain, we use: ALPHA=10, BETA=12, GAMMA=10 (total 32)
  constant ALPHA_VAL : integer := 10;
  constant BETA_VAL : integer := 12;
  constant GAMMA_VAL : integer := 10;

  -- Component declaration for LBIST
  component LBIST_TOP is
    generic(
      LFSR_WIDTH        : integer := 32;
      NUM_SCAN_CHAINS   : integer := 4;
      SCAN_CHAIN_LENGTH : integer := 32;
      ALPHA             : integer := 29;
      BETA              : integer := 25;
      GAMMA             : integer := 29
    );
    port(
      CLK           : in  std_logic;
      reset_neg     : in  std_logic;
      scan_enable   : in  std_logic;
      test_mode     : in  std_logic;
      lfsr_seed     : in  std_logic_vector(31 downto 0);
      lfsr_enable   : in  std_logic;
      control_mode  : in  std_logic_vector(1 downto 0);
      scan_out      : out std_logic_vector(3 downto 0);
      scan_feedback : in  std_logic_vector(3 downto 0);
      lfsr_output   : out std_logic_vector(31 downto 0);
      scan_counter  : out std_logic_vector(7 downto 0);
      current_control : out std_logic_vector(1 downto 0)
    );
  end component;

begin

  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;

  -- LBIST instance
  LBIST_INST: LBIST_TOP
    generic map(
      LFSR_WIDTH        => 32,
      NUM_SCAN_CHAINS   => 4,
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH,
      ALPHA             => ALPHA_VAL,  -- 10 cycles
      BETA              => BETA_VAL,   -- 12 cycles
      GAMMA             => GAMMA_VAL   -- 10 cycles (total = 32)
    )
    port map(
      CLK            => clk,
      reset_neg      => reset_neg,
      scan_enable    => scan_enable,
      test_mode      => test_mode,
      lfsr_seed      => lfsr_seed_sig,
      lfsr_enable    => lfsr_enable,
      control_mode   => "00",
      scan_out       => lbist_scan_out,
      scan_feedback  => lbist_scan_feedback,
      lfsr_output    => open,
      scan_counter   => lbist_status,
      current_control => lbist_current_control
    );

  -- TopWithScan_SC instance (processor with validator)
  DUT: entity work.TopWithScan_SC
    generic map ( n => 32 )
    port map (
      clk             => clk,
      reset_neg       => reset_neg,
      scan_instr_sel  => scan_instr_sel,
      se              => se,
      ce              => ce,
      si              => si,
      so              => so,
      dbg_instruction => dbg_instruction,
      dbg_alu_result  => dbg_alu_result,
      dbg_instr_valid => dbg_instr_valid
    );

  -- Connect LBIST chain 3 to instruction scan chain
  si <= lbist_scan_out(3) when test_mode = '1' else '0';
  lbist_scan_feedback(3) <= so;
  lbist_scan_feedback(0) <= '0';  -- Other chains not used
  lbist_scan_feedback(1) <= '0';
  lbist_scan_feedback(2) <= '0';

  -- Toggle rate measurement process
  toggle_measure: process(clk, reset_neg)
    variable scan_counter_val : integer;
    variable current_scan_bit : std_logic;
  begin
    if reset_neg = '0' then
      scan_bit_toggle_count <= 0;
      alpha_toggle_count <= 0;
      beta_toggle_count <= 0;
      gamma_toggle_count <= 0;
      alpha_bit_count <= 0;
      beta_bit_count <= 0;
      gamma_bit_count <= 0;
      prev_scan_bit <= '0';
    elsif rising_edge(clk) and scan_enable = '1' and test_mode = '1' then
      scan_counter_val := to_integer(unsigned(lbist_status));
      current_scan_bit := lbist_scan_out(3);  -- Monitor chain 3
      
      -- Count toggles in each region
      if scan_counter_val < ALPHA_VAL then  -- Alpha region (0 to ALPHA-1)
        alpha_bit_count <= alpha_bit_count + 1;
        if current_scan_bit /= prev_scan_bit then
          alpha_toggle_count <= alpha_toggle_count + 1;
          scan_bit_toggle_count <= scan_bit_toggle_count + 1;
        end if;
      elsif scan_counter_val < (ALPHA_VAL + BETA_VAL) then  -- Beta region (ALPHA to ALPHA+BETA-1)
        beta_bit_count <= beta_bit_count + 1;
        if current_scan_bit /= prev_scan_bit then
          beta_toggle_count <= beta_toggle_count + 1;
          scan_bit_toggle_count <= scan_bit_toggle_count + 1;
        end if;
      else  -- Gamma region (ALPHA+BETA to end)
        gamma_bit_count <= gamma_bit_count + 1;
        if current_scan_bit /= prev_scan_bit then
          gamma_toggle_count <= gamma_toggle_count + 1;
          scan_bit_toggle_count <= scan_bit_toggle_count + 1;
        end if;
      end if;
      
      prev_scan_bit <= current_scan_bit;
    end if;
  end process;

  -- Test process
  stim: process
    variable instruction_count : integer := 0;
    variable valid_count : integer := 0;
    variable invalid_count : integer := 0;
    variable captured_instr : std_logic_vector(31 downto 0);
    variable total_toggles : integer := 0;
    variable total_bits : integer := 0;
    variable alpha_rate, beta_rate, gamma_rate, overall_rate : real;
  begin

    report "=== LBIST Instruction Validator Test with Seed 0x" & to_hstring(LFSR_SEED) & " ===" severity note;
    report "" severity note;

    -- Reset
    reset_neg <= '0';
    test_mode <= '0';
    scan_enable <= '0';
    scan_instr_sel <= '0';
    se <= '1';
    ce <= '0';
    lfsr_enable <= '0';

    wait for 5*CLK_PERIOD;
    reset_neg <= '1';
    wait for 2*CLK_PERIOD;

    report "PHASE 1: Initialize LBIST" severity note;
    test_mode <= '1';
    lfsr_enable <= '1';
    wait for 2*CLK_PERIOD;

    report "PHASE 2: Generate and test 50 LBIST-generated instructions" severity note;
    report "----------------------------------------------------------------------------" severity note;

    -- Generate 50 instructions from LBIST
    for pattern_num in 0 to 49 loop
      
      -- Shift mode: load instruction from LBIST
      scan_enable <= '1';  -- Shift mode
      scan_instr_sel <= '1';  -- Select scan instruction
      se <= '1';  -- Shift path
      ce <= '1';  -- Enable scan chain

      -- Shift in 32 bits (one instruction)
      for bit_num in 0 to 31 loop
        wait until rising_edge(clk);
      end loop;

      -- Freeze scan chain
      ce <= '0';

      -- Wait for instruction to propagate through validator
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);

      -- Capture the instruction that reached the processor
      captured_instr := dbg_instruction;
      instruction_count := instruction_count + 1;

      -- Report results
      if dbg_instr_valid = '1' then
        report "Pattern " & integer'image(pattern_num) & ": 0x" & to_hstring(captured_instr) & 
               " -> VALID (passed through)" severity note;
        valid_count := valid_count + 1;
      else
        report "Pattern " & integer'image(pattern_num) & ": 0x" & to_hstring(captured_instr) & 
               " -> INVALID (flushed to NOP)" severity note;
        invalid_count := invalid_count + 1;
      end if;

      -- Execute the instruction (if valid) or NOP (if invalid)
      wait until rising_edge(clk);
      wait until rising_edge(clk);

      -- Capture mode: capture ALU result (optional)
      scan_enable <= '0';  -- Capture mode
      se <= '0';  -- Capture path
      ce <= '1';  -- Enable capture
      wait until rising_edge(clk);
      ce <= '0';

      wait for 2*CLK_PERIOD;
    end loop;

    report "" severity note;
    report "=== Test Summary ===" severity note;
    report "Total instructions tested: " & integer'image(instruction_count) severity note;
    report "Valid instructions: " & integer'image(valid_count) severity note;
    report "Invalid instructions flushed: " & integer'image(invalid_count) severity note;
    report "Validation rate: " & integer'image((valid_count * 100) / instruction_count) & "%" severity note;
    report "" severity note;
    report "=== Toggle Rate Analysis ===" severity note;
    report "Alpha region:" severity note;
    report "  Bits measured: " & integer'image(alpha_bit_count) severity note;
    report "  Toggles counted: " & integer'image(alpha_toggle_count) severity note;
    if alpha_bit_count > 0 then
      alpha_rate := (real(alpha_toggle_count) / real(alpha_bit_count)) * 100.0;
      report "  Toggle rate: " & real'image(alpha_rate) & "%" severity note;
    end if;
    report "Beta region:" severity note;
    report "  Bits measured: " & integer'image(beta_bit_count) severity note;
    report "  Toggles counted: " & integer'image(beta_toggle_count) severity note;
    if beta_bit_count > 0 then
      beta_rate := (real(beta_toggle_count) / real(beta_bit_count)) * 100.0;
      report "  Toggle rate: " & real'image(beta_rate) & "%" severity note;
    end if;
    report "Gamma region:" severity note;
    report "  Bits measured: " & integer'image(gamma_bit_count) severity note;
    report "  Toggles counted: " & integer'image(gamma_toggle_count) severity note;
    if gamma_bit_count > 0 then
      gamma_rate := (real(gamma_toggle_count) / real(gamma_bit_count)) * 100.0;
      report "  Toggle rate: " & real'image(gamma_rate) & "%" severity note;
    end if;
    total_bits := alpha_bit_count + beta_bit_count + gamma_bit_count;
    total_toggles := alpha_toggle_count + beta_toggle_count + gamma_toggle_count;
    if total_bits > 0 then
      overall_rate := (real(total_toggles) / real(total_bits)) * 100.0;
      report "Overall:" severity note;
      report "  Total bits: " & integer'image(total_bits) severity note;
      report "  Total toggles: " & integer'image(total_toggles) severity note;
      report "  Overall toggle rate: " & real'image(overall_rate) & "%" severity note;
    end if;
    report "=== Test Complete ===" severity note;

    wait for 10*CLK_PERIOD;
    wait;
  end process;

end sim;

