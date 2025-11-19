library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_scan_ayan_lbist_integration is
end entity tb_scan_ayan_lbist_integration;

architecture testbench of tb_scan_ayan_lbist_integration is
  constant CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic := '0';
  signal reset_n : std_logic := '0';
  
  -- LBIST signals
  signal test_mode : std_logic := '0';
  signal scan_enable : std_logic := '0';
  signal lfsr_seed : std_logic_vector(31 downto 0);
  signal lfsr_enable : std_logic := '0';
  signal control_mode : std_logic_vector(1 downto 0) := "00";
  
  -- LBIST outputs
  signal lbist_scan_out : std_logic_vector(0 downto 0);
  signal lbist_scan_feedback : std_logic_vector(0 downto 0);
  signal lbist_lfsr_output : std_logic_vector(31 downto 0);
  signal lbist_scan_counter : std_logic_vector(7 downto 0);
  signal lbist_current_control : std_logic_vector(1 downto 0);
  
  -- ALU scan signals
  signal alu_result : std_logic_vector(31 downto 0);
  signal alu_scan_out : std_logic_vector(31 downto 0);
  signal alu_scan_serial_out : std_logic;
  
begin
  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;
  
  -- LBIST instance
  lbist_inst: entity work.LBIST_TOP
    generic map(
      LFSR_WIDTH        => 32,
      NUM_SCAN_CHAINS   => 1,
      SCAN_CHAIN_LENGTH => 32,
      ALPHA             => 29,
      BETA              => 25,
      GAMMA             => 29
    )
    port map(
      CLK            => clk,
      reset_neg      => reset_n,
      scan_enable    => scan_enable,
      test_mode      => test_mode,
      lfsr_seed      => lfsr_seed,
      lfsr_enable    => lfsr_enable,
      control_mode   => control_mode,
      scan_out       => lbist_scan_out,
      scan_feedback  => lbist_scan_feedback,
      lfsr_output    => lbist_lfsr_output,
      scan_counter   => lbist_scan_counter,
      current_control => lbist_current_control
    );
  
  -- ALU scan chain instance
  alu_scan_inst: entity work.alu_scan_to_im32
    port map(
      clk           => clk,
      se            => scan_enable,
      si            => lbist_scan_out(0),
      scan_data_in  => alu_result,
      scan_data_out => alu_scan_out,
      so            => alu_scan_serial_out
    );
  
  -- Feedback connection
  lbist_scan_feedback(0) <= alu_scan_serial_out;
  
  -- Test process
  process
    variable pattern_count : integer := 0;
    variable error_count : integer := 0;
  begin
    report "=== Starting scan_ayan LBIST Integration Test ===" severity note;
    
    -- Reset
    reset_n <= '0';
    test_mode <= '0';
    scan_enable <= '0';
    lfsr_seed <= x"12345678";
    lfsr_enable <= '0';
    control_mode <= "00";
    alu_result <= (others => '0');
    
    wait for 5 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;
    
    -- ============================================
    -- Test 1: Initialize LBIST
    -- ============================================
    report "Test 1: Initialize LBIST" severity note;
    test_mode <= '1';
    lfsr_enable <= '1';
    wait for 2 * CLK_PERIOD;
    
    assert lbist_lfsr_output /= x"00000000" or lbist_lfsr_output = lfsr_seed
      report "ERROR: LFSR not initialized properly"
      severity error;
    
    -- ============================================
    -- Test 2: Shift Mode - Load pattern from LBIST
    -- ============================================
    report "Test 2: Shift mode - Load pattern from LBIST" severity note;
    scan_enable <= '1';  -- Enter shift mode
    
    -- Shift for 32 cycles
    for i in 0 to 31 loop
      wait for CLK_PERIOD;
      report "Cycle " & integer'image(i) & ": LBIST scan_out=" & std_logic'image(lbist_scan_out(0)) &
             ", ALU scan_out=" & std_logic'image(alu_scan_serial_out) &
             ", Counter=" & integer'image(to_integer(unsigned(lbist_scan_counter)));
    end loop;
    
    -- Check that counter incremented
    assert to_integer(unsigned(lbist_scan_counter)) >= 31
      report "ERROR: Scan counter not incrementing properly"
      severity error;
    
    -- ============================================
    -- Test 3: Capture Mode - Capture ALU result
    -- ============================================
    report "Test 3: Capture mode - Capture ALU result" severity note;
    scan_enable <= '0';  -- Enter capture mode
    alu_result <= x"ABCDEF01";  -- Simulate ALU computation
    wait for CLK_PERIOD;
    
    -- Check that ALU data was captured
    assert alu_scan_out = x"ABCDEF01"
      report "ERROR: ALU data not captured. Expected 0xABCDEF01, got 0x" & to_hstring(alu_scan_out)
      severity error;
    if alu_scan_out /= x"ABCDEF01" then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 4: Shift out captured data
    -- ============================================
    report "Test 4: Shift out captured data" severity note;
    scan_enable <= '1';  -- Back to shift mode
    
    -- Shift out the captured data
    for i in 0 to 31 loop
      wait for CLK_PERIOD;
      if i = 0 then
        report "First bit shifted out: " & std_logic'image(alu_scan_serial_out);
      end if;
    end loop;
    
    -- ============================================
    -- Test 5: Multiple patterns
    -- ============================================
    report "Test 5: Multiple test patterns" severity note;
    pattern_count := 0;
    
    for pattern in 0 to 2 loop
      -- Shift in pattern
      scan_enable <= '1';
      for i in 0 to 31 loop
        wait for CLK_PERIOD;
      end loop;
      
      -- Capture
      scan_enable <= '0';
      alu_result <= std_logic_vector(to_unsigned(pattern * 16#11111111#, 32));
      wait for CLK_PERIOD;
      
      -- Verify capture
      assert alu_scan_out = alu_result
        report "ERROR: Pattern " & integer'image(pattern) & " capture failed"
        severity error;
      if alu_scan_out /= alu_result then error_count := error_count + 1; end if;
      
      pattern_count := pattern_count + 1;
    end loop;
    
    -- ============================================
    -- Test 6: Control mode switching
    -- ============================================
    report "Test 6: Control mode switching" severity note;
    for mode in 0 to 3 loop
      control_mode <= std_logic_vector(to_unsigned(mode, 2));
      wait for CLK_PERIOD;
      assert lbist_current_control = control_mode
        report "ERROR: Control mode not set correctly"
        severity error;
      if lbist_current_control /= control_mode then error_count := error_count + 1; end if;
    end loop;
    
    -- ============================================
    -- Test Summary
    -- ============================================
    wait for 2 * CLK_PERIOD;
    if error_count = 0 then
      report "=== ALL INTEGRATION TESTS PASSED ===" severity note;
      report "Patterns tested: " & integer'image(pattern_count) severity note;
    else
      report "=== INTEGRATION TEST FAILED: " & integer'image(error_count) & " error(s) found ===" severity error;
    end if;
    
    report "=== Integration Test Complete ===" severity note;
    wait;
  end process;
  
end architecture testbench;

