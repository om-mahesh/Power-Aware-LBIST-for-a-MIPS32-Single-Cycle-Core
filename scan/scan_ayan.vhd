library ieee;
use ieee.std_logic_1164.all;

entity scan_dff is
  port(
    clk : in  std_logic;
    ce  : in  std_logic;  -- new: clock enable
    se  : in  std_logic;  -- scan enable: 1 = SI, 0 = DI
    di  : in  std_logic;  -- functional data
    si  : in  std_logic;  -- scan data (serial)
    q   : out std_logic   -- normal / scan out (same)
  );
end scan_dff;

architecture rtl of scan_dff is
  signal d_sel : std_logic;
begin
  d_sel <= si when se = '1' else di;

  process(clk)
  begin
    if rising_edge(clk) then
      if ce = '1' then
        q <= d_sel;
      end if;
    end if;
  end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity scan_chain32 is
  port(
    clk : in  std_logic;
    ce  : in  std_logic;                         -- clock enable for all 32
    se  : in  std_logic;                         -- scan enable for all 32

    -- serial scan ports
    si  : in  std_logic;                         -- scan in (to bit 0)
    so  : out std_logic;                         -- scan out (from bit 31)

    -- parallel functional ports
    di  : in  std_logic_vector(31 downto 0);     -- normal data to flops
    q   : out std_logic_vector(31 downto 0)      -- normal outputs
  );
end scan_chain32;

architecture structural of scan_chain32 is
  signal q_int : std_logic_vector(31 downto 0);
begin
  -- bit 0: SI comes from external si, DI comes from di(0)
  bit0: entity work.scan_dff
    port map (
      clk => clk,
      ce  => ce,
      se  => se,
      di  => di(0),
      si  => si,
      q   => q_int(0)
    );

  -- bits 1..30: SI from previous Q, DI from corresponding di bit
  gen_bits: for i in 1 to 30 generate
    scan_i: entity work.scan_dff
      port map (
        clk => clk,
        ce  => ce,
        se  => se,
        di  => di(i),
        si  => q_int(i-1),
        q   => q_int(i)
      );
  end generate;

  -- bit 31: last one
  bit31: entity work.scan_dff
    port map (
      clk => clk,
      ce  => ce,
      se  => se,
      di  => di(31),
      si  => q_int(30),
      q   => q_int(31)
    );

  -- parallel output
  q <= q_int;

  -- serial out
  so <= q_int(31);

end structural;

library ieee;
use ieee.std_logic_1164.all;

entity alu_scan_to_im32 is
  port(
    clk            : in  std_logic;
    ce             : in  std_logic;                      -- new: clock enable
    se             : in  std_logic;                      -- scan enable
    si             : in  std_logic;                      -- serial scan in
    scan_data_in   : in  std_logic_vector(31 downto 0);  -- ALU result (to capture)
    scan_data_out  : out std_logic_vector(31 downto 0);  -- to IM.scan_data_out
    so             : out std_logic                       -- serial scan out
  );
end alu_scan_to_im32;

architecture structural of alu_scan_to_im32 is
  signal q_int : std_logic_vector(31 downto 0);
begin
  bit0: entity work.scan_dff
    port map ( clk => clk, ce => ce, se => se,
               di  => scan_data_in(0),  si => si,         q => q_int(0));

  gen_bits: for i in 1 to 30 generate
    scan_i: entity work.scan_dff
      port map ( clk => clk, ce => ce, se => se,
                 di  => scan_data_in(i), si => q_int(i-1), q => q_int(i));
  end generate;

  bit31: entity work.scan_dff
    port map ( clk => clk, ce => ce, se => se,
               di  => scan_data_in(31), si => q_int(30),   q => q_int(31));

  scan_data_out <= q_int;
  so            <= q_int(31);
end structural;
