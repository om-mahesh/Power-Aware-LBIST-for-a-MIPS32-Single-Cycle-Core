library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_scan_ayan is
end entity tb_scan_ayan;

architecture testbench of tb_scan_ayan is
  constant CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic := '0';
  signal reset_n : std_logic := '0';
  
  -- Test signals for scan_dff
  signal se_dff, di_dff, si_dff, q_dff : std_logic;
  
  -- Test signals for scan_chain32
  signal se_chain : std_logic;
  signal si_chain, so_chain : std_logic;
  signal di_chain : std_logic_vector(31 downto 0);
  signal q_chain : std_logic_vector(31 downto 0);
  
  -- Test signals for alu_scan_to_im32
  signal se_alu : std_logic;
  signal si_alu, so_alu : std_logic;
  signal scan_data_in_alu : std_logic_vector(31 downto 0);
  signal scan_data_out_alu : std_logic_vector(31 downto 0);
  
begin
  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;
  
  -- DUT: scan_dff
  dut_dff: entity work.scan_dff
    port map(
      clk => clk,
      se  => se_dff,
      di  => di_dff,
      si  => si_dff,
      q   => q_dff
    );
  
  -- DUT: scan_chain32
  dut_chain: entity work.scan_chain32
    port map(
      clk => clk,
      se  => se_chain,
      si  => si_chain,
      so  => so_chain,
      di  => di_chain,
      q   => q_chain
    );
  
  -- DUT: alu_scan_to_im32
  dut_alu: entity work.alu_scan_to_im32
    port map(
      clk           => clk,
      se            => se_alu,
      si            => si_alu,
      scan_data_in  => scan_data_in_alu,
      scan_data_out => scan_data_out_alu,
      so            => so_alu
    );
  
  -- Test process
  process
    variable test_vector : std_logic_vector(31 downto 0);
    variable shifted_out : std_logic_vector(31 downto 0);
    variable error_count : integer := 0;
  begin
    report "=== Starting scan_ayan.vhd Test Suite ===" severity note;
    
    -- Reset
    reset_n <= '0';
    se_dff <= '0';
    di_dff <= '0';
    si_dff <= '0';
    se_chain <= '0';
    si_chain <= '0';
    di_chain <= (others => '0');
    se_alu <= '0';
    si_alu <= '0';
    scan_data_in_alu <= (others => '0');
    
    wait for 5 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;
    
    -- ============================================
    -- Test 1: scan_dff - Functional Mode (se=0)
    -- ============================================
    report "Test 1: scan_dff functional mode" severity note;
    se_dff <= '0';
    di_dff <= '1';
    si_dff <= '0';  -- Should be ignored
    wait for CLK_PERIOD;
    assert q_dff = '1' 
      report "ERROR: scan_dff functional mode failed. Expected q=1, got q=" & std_logic'image(q_dff)
      severity error;
    if q_dff /= '1' then error_count := error_count + 1; end if;
    
    di_dff <= '0';
    wait for CLK_PERIOD;
    assert q_dff = '0'
      report "ERROR: scan_dff functional mode failed. Expected q=0, got q=" & std_logic'image(q_dff)
      severity error;
    if q_dff /= '0' then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 2: scan_dff - Scan Mode (se=1)
    -- ============================================
    report "Test 2: scan_dff scan mode" severity note;
    se_dff <= '1';
    di_dff <= '1';  -- Should be ignored
    si_dff <= '0';
    wait for CLK_PERIOD;
    assert q_dff = '0'
      report "ERROR: scan_dff scan mode failed. Expected q=0, got q=" & std_logic'image(q_dff)
      severity error;
    if q_dff /= '0' then error_count := error_count + 1; end if;
    
    si_dff <= '1';
    wait for CLK_PERIOD;
    assert q_dff = '1'
      report "ERROR: scan_dff scan mode failed. Expected q=1, got q=" & std_logic'image(q_dff)
      severity error;
    if q_dff /= '1' then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 3: scan_chain32 - Functional Mode
    -- ============================================
    report "Test 3: scan_chain32 functional mode" severity note;
    se_chain <= '0';
    test_vector := x"12345678";
    di_chain <= test_vector;
    si_chain <= '0';  -- Should be ignored
    wait for CLK_PERIOD;
    assert q_chain = test_vector
      report "ERROR: scan_chain32 functional mode failed. Expected 0x" & to_hstring(test_vector) & 
             ", got 0x" & to_hstring(q_chain)
      severity error;
    if q_chain /= test_vector then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 4: scan_chain32 - Serial Shift (LSB first)
    -- ============================================
    report "Test 4: scan_chain32 serial shift (LSB first)" severity note;
    se_chain <= '1';
    test_vector := x"ABCDEF01";
    
    -- Shift in LSB first (bit 0, then 1, ..., then 31)
    -- After 32 shifts, bit0 will have the last bit shifted in (bit 31)
    -- and bit31 will have the first bit shifted in (bit 0)
    -- So we need to shift in reversed to get correct output
    for i in 0 to 31 loop
      si_chain <= test_vector(i);  -- Shift in LSB first
      wait for CLK_PERIOD;
    end loop;
    
    -- Now read out and reverse the bits to match input
    -- Shift out MSB first (still in shift mode)
    for i in 31 downto 0 loop
      shifted_out(31-i) := so_chain;  -- Reverse the output bits
      wait for CLK_PERIOD;
    end loop;
    
    assert shifted_out = test_vector
      report "ERROR: scan_chain32 shift failed. Expected 0x" & to_hstring(test_vector) &
             ", got 0x" & to_hstring(shifted_out)
      severity error;
    if shifted_out /= test_vector then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 5: scan_chain32 - Capture Functional Data
    -- ============================================
    report "Test 5: scan_chain32 capture functional data" severity note;
    se_chain <= '1';
    test_vector := x"FEDCBA98";
    
    -- Shift in some data first
    for i in 0 to 31 loop
      si_chain <= test_vector(i);
      wait for CLK_PERIOD;
    end loop;
    
    -- Capture functional data (switch to functional mode)
    se_chain <= '0';
    test_vector := x"12345678";  -- New functional data to capture
    di_chain <= test_vector;
    wait for CLK_PERIOD;
    
    -- Should have captured the functional data, not the shifted data
    assert q_chain = test_vector
      report "ERROR: scan_chain32 capture failed. Expected 0x" & to_hstring(test_vector) &
             ", got 0x" & to_hstring(q_chain)
      severity error;
    if q_chain /= test_vector then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 6: alu_scan_to_im32 - Functional Mode
    -- ============================================
    report "Test 6: alu_scan_to_im32 functional mode" severity note;
    se_alu <= '0';
    test_vector := x"87654321";
    scan_data_in_alu <= test_vector;
    si_alu <= '0';  -- Should be ignored
    wait for CLK_PERIOD;
    assert scan_data_out_alu = test_vector
      report "ERROR: alu_scan_to_im32 functional mode failed. Expected 0x" & to_hstring(test_vector) &
             ", got 0x" & to_hstring(scan_data_out_alu)
      severity error;
    if scan_data_out_alu /= test_vector then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 7: alu_scan_to_im32 - Serial Shift
    -- ============================================
    report "Test 7: alu_scan_to_im32 serial shift" severity note;
    se_alu <= '1';
    test_vector := x"11223344";
    
    -- Shift in LSB first (bit 0, then 1, ..., then 31)
    for i in 0 to 31 loop
      si_alu <= test_vector(i);  -- Shift in LSB first
      wait for CLK_PERIOD;
    end loop;
    
    -- Now read out and reverse the bits to match input
    -- Shift out MSB first (still in shift mode)
    for i in 31 downto 0 loop
      shifted_out(31-i) := so_alu;  -- Reverse the output bits
      wait for CLK_PERIOD;
    end loop;
    
    assert shifted_out = test_vector
      report "ERROR: alu_scan_to_im32 serial out failed. Expected 0x" & to_hstring(test_vector) &
             ", got 0x" & to_hstring(shifted_out)
      severity error;
    if shifted_out /= test_vector then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test 8: alu_scan_to_im32 - Mixed Mode
    -- ============================================
    report "Test 8: alu_scan_to_im32 mixed mode (shift then capture)" severity note;
    -- Shift in data
    se_alu <= '1';
    test_vector := x"AA55AA55";
    for i in 0 to 31 loop
      si_alu <= test_vector(i);
      wait for CLK_PERIOD;
    end loop;
    
    -- Switch to functional mode with new ALU data
    se_alu <= '0';
    scan_data_in_alu <= x"55AA55AA";
    wait for CLK_PERIOD;
    
    -- Should have captured the new functional data
    assert scan_data_out_alu = x"55AA55AA"
      report "ERROR: alu_scan_to_im32 mixed mode failed. Expected 0x55AA55AA" &
             ", got 0x" & to_hstring(scan_data_out_alu)
      severity error;
    if scan_data_out_alu /= x"55AA55AA" then error_count := error_count + 1; end if;
    
    -- ============================================
    -- Test Summary
    -- ============================================
    wait for 2 * CLK_PERIOD;
    if error_count = 0 then
      report "=== ALL TESTS PASSED ===" severity note;
    else
      report "=== TEST FAILED: " & integer'image(error_count) & " error(s) found ===" severity error;
    end if;
    
    report "=== Test Suite Complete ===" severity note;
    wait;
  end process;
  
end architecture testbench;

