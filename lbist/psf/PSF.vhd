library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PSF is
  generic(
    LFSR_WIDTH : integer := 32;
    NUM_CHAINS : integer := 4
  );
  port(
    -- REMOVED: CLK port (was causing timing issues)
    lfsr_output  : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
    current_bit  : out std_logic_vector(NUM_CHAINS-1 downto 0);
    future_bit_1 : out std_logic_vector(NUM_CHAINS-1 downto 0);
    future_bit_2 : out std_logic_vector(NUM_CHAINS-1 downto 0)
  );
end PSF;

architecture Behavioral of PSF is
  -- CHANGE: Added helper functions for direct bit extraction
  -- For polynomial X^32 + X^22 + X^2 + 1 (taps at 0,1,21,31)
  
  function compute_future_1(lfsr : std_logic_vector; idx : integer) return std_logic is
  begin
    -- Tj+1: one shift ahead
    if idx < LFSR_WIDTH-1 then
      return lfsr(idx+1);  -- Direct extraction
    else
      -- Wraparound: compute feedback
      return lfsr(0) xor lfsr(1) xor lfsr(21) xor lfsr(31);
    end if;
  end function;
  
  function compute_future_2(lfsr : std_logic_vector; idx : integer) return std_logic is
    variable fb1 : std_logic;
  begin
    -- Tj+2: two shifts ahead
    if idx < LFSR_WIDTH-2 then
      return lfsr(idx+2);  -- Direct extraction
    elsif idx = LFSR_WIDTH-2 then
      fb1 := lfsr(0) xor lfsr(1) xor lfsr(21) xor lfsr(31);
      return fb1;
    else -- idx = LFSR_WIDTH-1
      fb1 := lfsr(0) xor lfsr(1) xor lfsr(21) xor lfsr(31);
      return lfsr(1) xor lfsr(2) xor lfsr(22) xor fb1;
    end if;
  end function;

begin
  -- CHANGE: Pure combinational logic (no process/clocking)
  gen_chains: for i in 0 to NUM_CHAINS-1 generate
    current_bit(i)  <= lfsr_output(i);
    future_bit_1(i) <= compute_future_1(lfsr_output, i);
    future_bit_2(i) <= compute_future_2(lfsr_output, i);
  end generate;

end Behavioral;