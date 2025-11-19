library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_InstructionMemory is
end tb_InstructionMemory;

architecture sim of tb_InstructionMemory is

  -- DUT signals
  signal register_addr : std_logic_vector(31 downto 0);
  signal mux_scan_mode : std_logic;
  signal scan_data_out : std_logic_vector(31 downto 0);
  signal instruction   : std_logic_vector(31 downto 0);

begin

  -- DUT instantiation
  dut: entity work.InstructionMemory
    port map (
      register_addr => register_addr,
      mux_scan_mode => mux_scan_mode,
      scan_data_out => scan_data_out,
      instruction   => instruction
    );

  -- stimulus process
  stim: process
  begin
    -- init
    register_addr <= (others => '0');               -- address 0
    mux_scan_mode <= '1';                           -- normal mode
    scan_data_out <= (others => '0');
    wait for 10 ns;

    -- at this point instruction should be the 4 bytes at addr 0..3
    -- now force scan mode
    scan_data_out <= x"DEADBEEF";
    mux_scan_mode <= '0';                           -- pick scan data
    wait for 10 ns;

    -- back to normal, but change address to 4 to read next instruction (sw ...)
    mux_scan_mode <= '1';
    register_addr <= x"00000004";
    wait for 10 ns;

    -- try another scan pattern
    mux_scan_mode <= '0';
    scan_data_out <= x"12345678";
    wait for 10 ns;

    -- stop sim
    wait;
  end process;

end sim;
