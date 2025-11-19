library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_validator_test is
end tb_validator_test;

architecture sim of tb_validator_test is

  constant CLK_PERIOD : time := 10 ns;
  constant SHIFT_MSB_FIRST : boolean := true;
  
  -- Seed for pseudo-random instruction generation (simulating LBIST)
  constant TEST_SEED : std_logic_vector(31 downto 0) := x"DEADBEEF";

  -- DUT ports
  signal clk            : std_logic := '0';
  signal reset_neg      : std_logic := '0';
  signal scan_instr_sel : std_logic := '0';
  signal se             : std_logic := '1';
  signal ce             : std_logic := '0';
  signal si             : std_logic := '0';
  signal so             : std_logic;
  signal dbg_instruction : std_logic_vector(31 downto 0);
  signal dbg_alu_result  : std_logic_vector(31 downto 0);
  signal dbg_instr_valid : std_logic;

  -- Test instruction patterns (mix of valid and invalid)
  type instruction_array is array (0 to 15) of std_logic_vector(31 downto 0);
  
  -- Test instructions: mix of valid and invalid
  constant test_instructions : instruction_array := (
    x"2001001E",  -- 0: VALID - addi $1,$0,30
    x"FFFFFFFF",  -- 1: INVALID - all 1s (invalid opcode)
    x"00000020",  -- 2: VALID - add $0,$0,$0 (R-type, function 0x20)
    x"01000000",  -- 3: INVALID - opcode=000001 (not supported)
    x"8C030000",  -- 4: VALID - lw $3,0($0) (correct format: opcode=100011, rs=0, rt=3, imm=0)
    x"00000000",  -- 5: VALID - NOP (sll $0,$0,0)
    x"03000000",  -- 6: INVALID - opcode=000011 (not supported)
    x"00100020",  -- 7: VALID - addi $0,$0,32
    x"00000042",  -- 8: INVALID - R-type with invalid function code (0x42)
    x"2002000A",  -- 9: VALID - addi $2,$0,10
    x"07000000",  -- 10: INVALID - opcode=000111 (not supported)
    x"08000000",  -- 11: VALID - j 0
    x"0F000000",  -- 12: INVALID - opcode=001111 (not supported)
    x"00221822",  -- 13: VALID - sub $3,$1,$2
    x"00000099",  -- 14: INVALID - R-type with invalid function 0x99
    x"20420001"   -- 15: VALID - addi $2,$2,1
  );

  -- Expected validity for each instruction
  type validity_array is array (0 to 15) of boolean;
  constant expected_valid : validity_array := (
    true,   -- 0: valid
    false,  -- 1: invalid
    true,   -- 2: valid
    false,  -- 3: invalid
    true,   -- 4: valid
    true,   -- 5: valid (NOP)
    false,  -- 6: invalid
    true,   -- 7: valid
    false,  -- 8: invalid
    true,   -- 9: valid
    false,  -- 10: invalid
    true,   -- 11: valid
    false,  -- 12: invalid
    true,   -- 13: valid
    false,  -- 14: invalid
    true    -- 15: valid
  );

  -- Simple LFSR for generating pseudo-random patterns (simulating LBIST)
  function simple_lfsr(seed : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable next_val : std_logic_vector(31 downto 0);
    variable feedback : std_logic;
  begin
    -- Simple LFSR: taps at bits 32, 22, 2, 1 (polynomial x^32 + x^22 + x^2 + x + 1)
    feedback := seed(31) xor seed(21) xor seed(1) xor seed(0);
    next_val := seed(30 downto 0) & feedback;
    return next_val;
  end function;

  procedure shift_in_word(
    signal  si_sig  : out std_logic;
    signal  clk_sig : in  std_logic;
    constant word   : std_logic_vector(31 downto 0);
    constant msb_first : boolean
  ) is
  begin
    if msb_first then
      for i in 31 downto 0 loop
        si_sig <= word(i);
        wait until rising_edge(clk_sig);
      end loop;
    else
      for i in 0 to 31 loop
        si_sig <= word(i);
        wait until rising_edge(clk_sig);
      end loop;
    end if;
  end procedure;

begin

  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;

  -- DUT instantiation
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

  -- Stimulus process
  stim: process
    variable lfsr_state : std_logic_vector(31 downto 0) := TEST_SEED;
    variable test_instr : std_logic_vector(31 downto 0);
    variable valid_count : integer := 0;
    variable invalid_count : integer := 0;
  begin

    report "=== Instruction Validator Test with Seed 0x" & to_hstring(TEST_SEED) & " ===" severity note;
    report "" severity note;

    -- Reset
    reset_neg <= '0';
    scan_instr_sel <= '0';
    se <= '1';
    ce <= '0';
    si <= '0';

    wait for 5*CLK_PERIOD;
    reset_neg <= '1';
    wait for 2*CLK_PERIOD;

    report "PHASE 1: Testing predefined instruction patterns (mix of valid/invalid)" severity note;
    report "----------------------------------------------------------------------------" severity note;

    -- Test predefined instructions
    for i in 0 to 15 loop
      test_instr := test_instructions(i);
      
      report "Test " & integer'image(i) & ": Injecting instruction 0x" & to_hstring(test_instr) & 
             " (Expected: " & boolean'image(expected_valid(i)) & ")" severity note;

      -- Select scan instruction mode
      scan_instr_sel <= '1';
      se <= '1';
      ce <= '1';

      -- Shift in the instruction
      shift_in_word(si, clk, test_instr, SHIFT_MSB_FIRST);

      -- Freeze scan chain
      ce <= '0';

      -- Execute (wait a few cycles for instruction to propagate)
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);  -- Extra cycle for validator to settle

      -- Check what instruction actually reached the processor
      report "  -> Received instruction: 0x" & to_hstring(dbg_instruction) & 
             ", Valid flag: " & std_logic'image(dbg_instr_valid) severity note;
      
      if dbg_instruction = test_instr then
        -- Instruction passed through (should be valid)
        if expected_valid(i) then
          report "  -> PASS: Valid instruction passed through correctly" severity note;
          valid_count := valid_count + 1;
        else
          report "  -> ERROR: Invalid instruction should have been flushed but passed through!" severity error;
        end if;
      elsif dbg_instruction = x"00000000" then
        -- Instruction was flushed (NOP)
        if expected_valid(i) then
          report "  -> ERROR: Valid instruction was incorrectly flushed!" severity error;
        else
          report "  -> PASS: Invalid instruction correctly flushed (NOP)" severity note;
          invalid_count := invalid_count + 1;
        end if;
      else
        report "  -> WARNING: Instruction changed to 0x" & to_hstring(dbg_instruction) & " (unexpected)" severity warning;
      end if;

      wait for 2*CLK_PERIOD;
    end loop;

    report "" severity note;
    report "PHASE 2: Testing LFSR-generated pseudo-random instructions (simulating LBIST)" severity note;
    report "----------------------------------------------------------------------------" severity note;

    -- Reset LFSR to seed
    lfsr_state := TEST_SEED;

    -- Generate and test 20 random instructions
    for i in 0 to 19 loop
      -- Generate next LFSR value
      lfsr_state := simple_lfsr(lfsr_state);
      test_instr := lfsr_state;

      report "Random Test " & integer'image(i) & ": LFSR generated 0x" & to_hstring(test_instr) severity note;

      -- Select scan instruction mode
      scan_instr_sel <= '1';
      se <= '1';
      ce <= '1';

      -- Shift in the instruction
      shift_in_word(si, clk, test_instr, SHIFT_MSB_FIRST);

      -- Freeze scan chain
      ce <= '0';

      -- Execute
      wait until rising_edge(clk);
      wait until rising_edge(clk);

      -- Check result
      if dbg_instruction = test_instr then
        report "  -> Instruction passed through (likely valid)" severity note;
      elsif dbg_instruction = x"00000000" then
        report "  -> Instruction flushed to NOP (invalid)" severity note;
      end if;

      wait for 2*CLK_PERIOD;
    end loop;

    report "" severity note;
    report "=== Test Summary ===" severity note;
    report "Valid instructions processed: " & integer'image(valid_count) severity note;
    report "Invalid instructions flushed: " & integer'image(invalid_count) severity note;
    report "=== Test Complete ===" severity note;

    wait for 10*CLK_PERIOD;
    wait;
  end process;

end sim;

