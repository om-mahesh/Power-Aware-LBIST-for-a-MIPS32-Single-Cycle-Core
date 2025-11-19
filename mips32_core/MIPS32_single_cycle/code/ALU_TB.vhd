library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ALU is
end tb_ALU;

architecture sim of tb_ALU is

  -- DUT signals
  constant N : integer := 32;

  signal operand_1     : std_logic_vector(N-1 downto 0);
  signal operand_2     : std_logic_vector(N-1 downto 0);
  signal ALU_control   : std_logic_vector(3 downto 0);
  signal mux_scan_mode : std_logic;
  signal result        : std_logic_vector(N-1 downto 0);
  signal scan_data_out : std_logic_vector(N-1 downto 0);
  signal zero          : std_logic;

begin

  -- DUT instantiation
  dut: entity work.ALU
    generic map (
      n => N
    )
    port map (
      operand_1     => operand_1,
      operand_2     => operand_2,
      ALU_control   => ALU_control,
      mux_scan_mode => mux_scan_mode,
      result        => result,
      scan_data_out => scan_data_out,
      zero          => zero
    );

  -- stimulus
  stim_proc: process
  begin
    -- init
    operand_1     <= (others => '0');
    operand_2     <= (others => '0');
    ALU_control   <= (others => '0');
    mux_scan_mode <= '0';
    wait for 20 ns;

    -- 1) ADD: 10 + 5 = 15, normal mode
    operand_1   <= std_logic_vector(to_unsigned(10, N));
    operand_2   <= std_logic_vector(to_unsigned(5, N));
    ALU_control <= "0000";  -- add
    mux_scan_mode <= '0';   -- normal
    wait for 20 ns;
    -- expect: result = 15, scan_data_out = 0

    -- 2) Same operation but send to scan instead of normal
    mux_scan_mode <= '1';
    wait for 20 ns;
    -- expect: result = 0, scan_data_out = 15

    -- 3) AND: 0xF0F0_0000 AND 0x0F0F_0000
    operand_1   <= x"F0F00000";
    operand_2   <= x"0F0F0000";
    ALU_control <= "0010";    -- AND
    mux_scan_mode <= '0';     -- back to normal
    wait for 20 ns;
    -- expect result = x"00000000" → zero = '1'

    -- 4) Check zero flag but in scan mode
    mux_scan_mode <= '1';
    wait for 20 ns;
    -- now scan_data_out should have x"00000000"

    -- 5) shift left logical
    -- operand_1 = 1, operand_2 carries shift amount in bits 10..6 → let's set that
    operand_1   <= std_logic_vector(to_unsigned(1, N));
    -- put shift amount = 3 in bits 10..6: 3 = "00011"
    operand_2   <= (others => '0');
    operand_2(10 downto 6) <= "00011";  -- shift by 3
    ALU_control <= "0111";   -- SLL
    mux_scan_mode <= '0';
    wait for 20 ns;
    -- expect result = 0x00000008

    -- 6) And in scan mode again
    mux_scan_mode <= '1';
    wait for 20 ns;

    -- finish
    wait;
  end process;

end sim;
