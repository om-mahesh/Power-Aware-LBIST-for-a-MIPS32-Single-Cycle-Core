library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_with_scan_sc is
end tb_top_with_scan_sc;

architecture sim of tb_top_with_scan_sc is

  constant CLK_PERIOD : time := 10 ns;

  constant SHIFT_MSB_FIRST : boolean := true;

  -- DUT ports

  signal clk            : std_logic := '0';

  signal reset_neg      : std_logic := '0';

  signal scan_instr_sel : std_logic := '0';  -- 0=system IM, 1=scan word

  signal se             : std_logic := '1';  -- 1=shift path, 0=capture DI

  signal ce             : std_logic := '0';  -- clock enable for scan flops

  signal si             : std_logic := '0';

  signal so             : std_logic;

  signal dbg_instruction : std_logic_vector(31 downto 0);

  signal dbg_alu_result  : std_logic_vector(31 downto 0);

  -- Test patterns

  constant INSTR_ADDI_R1_R0_30 : std_logic_vector(31 downto 0) := x"2001001E"; -- addi $1,$0,30

  constant EXP_ALU_RESULT_30   : std_logic_vector(31 downto 0) := x"0000001E";

  -- helpers

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

  procedure shift_out_word(

    signal  clk_sig : in  std_logic;

    signal  so_sig  : in  std_logic;

    constant msb_first : boolean;

    variable result : out std_logic_vector(31 downto 0)

  ) is

  begin

    if msb_first then

      for i in 31 downto 0 loop

        wait until rising_edge(clk_sig);

        result(i) := so_sig;         -- first bit out is MSB (bit 31)

      end loop;

    else

      for i in 0 to 31 loop

        wait until rising_edge(clk_sig);

        result(i) := so_sig;         -- first bit out is LSB (bit 0)

      end loop;

    end if;

  end procedure;

begin

  -- Clock

  clk <= not clk after CLK_PERIOD/2;

  -- DUT

  DUT: entity work.TopWithScan_SC

    generic map ( n => 32 )

    port map (

      clk             => clk,

      reset_neg       => reset_neg,

      -- scan controls

      scan_instr_sel  => scan_instr_sel,

      se              => se,

      ce              => ce,

      si              => si,

      so              => so,

      -- debug

      dbg_instruction => dbg_instruction,

      dbg_alu_result  => dbg_alu_result

    );

  -- Stimulus

  stim: process

    variable shifted_out : std_logic_vector(31 downto 0);

  begin

    ----------------------------------------------------------------

    -- Reset

    ----------------------------------------------------------------

    reset_neg <= '0';

    scan_instr_sel <= '0';  -- start in normal/system mode

    se <= '1'; ce <= '0';   -- scan chain idle & frozen

    si <= '0';

    wait for 5*CLK_PERIOD;

    reset_neg <= '1';

    wait for 2*CLK_PERIOD;

    ----------------------------------------------------------------

    -- PHASE A: Functional run (normal IM)

    -- Let the core fetch/execute a few IM instructions

    ----------------------------------------------------------------

    report "PHASE A: Normal mode run from InstructionMemory" severity note;

    for k in 0 to 9 loop

      wait until rising_edge(clk);

      -- optional trace

      report "A) instr=0x" & to_hstring(dbg_instruction) &

             " alu=0x" & to_hstring(dbg_alu_result);

    end loop;

    ----------------------------------------------------------------

    -- PHASE B: Scan test: inject one instruction, execute, capture ALU, shift it out

    ----------------------------------------------------------------

    report "PHASE B: Scan test with ADDI $r1,$r0,30" severity note;

    -- 1) Select scan instruction on the post-IM mux

    scan_instr_sel <= '1';

    -- 2) SHIFT-IN the 32-bit instruction (MSB-first)

    se <= '1'; ce <= '1';

    shift_in_word(si, clk, INSTR_ADDI_R1_R0_30, SHIFT_MSB_FIRST);

    -- Freeze the scan flops so instruction stays stable while CPU runs

    ce <= '0';

    -- 3) EXECUTE the scanned instruction

    -- Give the single-cycle core one full cycle to compute ALU result

    wait until rising_edge(clk);

    -- (Optional extra cycle margin)

    wait until rising_edge(clk);

    -- 4) CAPTURE ALU result into scan chain (one capture edge)

    se <= '0'; ce <= '1';

    wait until rising_edge(clk);

    -- 5) SHIFT-OUT the captured result

    se <= '1'; ce <= '1';

    shift_out_word(clk, so, SHIFT_MSB_FIRST, shifted_out);

    -- Check the value

    report "Shifted-out ALU result = 0x" &

           to_hstring(shifted_out) severity note;

    assert shifted_out = EXP_ALU_RESULT_30

      report "ERROR: Expected ALU result 0x" & to_hstring(EXP_ALU_RESULT_30) &

             ", got 0x" & to_hstring(shifted_out)

      severity error;

    report "PASS: Scan chain correctly captured & shifted ALU result 0x" &

           to_hstring(shifted_out) severity note;

    ----------------------------------------------------------------

    -- Done

    ----------------------------------------------------------------

    wait for 10*CLK_PERIOD;

    report "Simulation finished." severity note;

    wait;

  end process;

end sim;

