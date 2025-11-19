library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PLPF_Control is
  generic(
    SCAN_CHAIN_LENGTH : integer := 83;
    ALPHA : integer := 29;
    BETA  : integer := 25;
    GAMMA : integer := 29
  );
  port(
    CLK           : in  std_logic;
    reset_neg     : in  std_logic;
    scan_enable   : in  std_logic;
    scan_counter  : in  std_logic_vector(7 downto 0);
    control_mode  : in  std_logic_vector(1 downto 0) := "00";
    chain_index   : in  std_logic_vector(7 downto 0) := (others => '0');
    pattern_index : in  std_logic_vector(15 downto 0) := (others => '0');
    plpf_control  : out std_logic_vector(1 downto 0)
  );
end PLPF_Control;

architecture Behavioral of PLPF_Control is
  signal counter_value : integer range 0 to 255;
  signal chain_idx_i   : integer range 0 to 255;
  signal patt_idx_i    : integer range 0 to 65535;
  constant L_C : integer := SCAN_CHAIN_LENGTH;
begin
  counter_value <= to_integer(unsigned(scan_counter));
  chain_idx_i   <= to_integer(unsigned(chain_index));
  patt_idx_i    <= to_integer(unsigned(pattern_index));

  process(CLK, reset_neg)
    variable alpha_v     : integer;
    variable beta_v      : integer;
    variable gamma_v     : integer;
    variable start_mid_v : integer;
    variable in_middle_v : boolean;
  begin
    if reset_neg = '0' then
      plpf_control <= "00";
    elsif rising_edge(CLK) then
      if scan_enable = '1' then

        -- BASIC CONTROL
        if control_mode = "00" then
          alpha_v := ALPHA;
          beta_v  := BETA;
          gamma_v := GAMMA;

          if (counter_value < alpha_v) then
            plpf_control <= "00";  -- α region: low toggle (n=3)
          elsif (counter_value < (alpha_v + beta_v)) then
            plpf_control <= "11";  -- β region: high toggle (n=1)
          else
            plpf_control <= "00";  -- γ region: low toggle (n=3)
          end if;

        -- SWAP CONTROL
        elsif control_mode = "01" then
          beta_v := BETA;

          if ((patt_idx_i + chain_idx_i) mod 2) = 0 then
            alpha_v := ALPHA;
            gamma_v := GAMMA;
          else
            alpha_v := GAMMA;
            gamma_v := ALPHA;
          end if;

          if (counter_value < alpha_v) then
            plpf_control <= "00";
          elsif (counter_value < (alpha_v + beta_v)) then
            plpf_control <= "11";
          else
            plpf_control <= "00";
          end if;

        -- MOVING CONTROL
        else
          beta_v := BETA;
          start_mid_v := (ALPHA + (patt_idx_i mod L_C)) mod L_C;

          if (start_mid_v + beta_v) <= L_C then
            in_middle_v := (counter_value >= start_mid_v) and
                           (counter_value <  start_mid_v + beta_v);
          else
            in_middle_v := (counter_value >= start_mid_v) or
                           (counter_value < ((start_mid_v + beta_v) mod L_C));
          end if;

          -- after you compute `in_middle_v` for the β region:
    if in_middle_v then
      plpf_control <= "01";  -- PASS (β -> ~50%)
    else
      plpf_control <= "00";  -- AND  (α/γ -> low toggle)
    end if;

        end if;

      else
        plpf_control <= "00";
      end if;
    end if;
  end process;

end Behavioral;