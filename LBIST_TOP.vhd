library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LBIST_TOP is
  generic(
    LFSR_WIDTH        : integer := 32;
    NUM_SCAN_CHAINS   : integer := 1;
    SCAN_CHAIN_LENGTH : integer := 83;
    ALPHA             : integer := 29;
    BETA              : integer := 25;
    GAMMA             : integer := 29
  );
  port(
    CLK           : in  std_logic;
    reset_neg     : in  std_logic;
    scan_enable   : in  std_logic;
    test_mode     : in  std_logic;
    
    lfsr_seed     : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
    lfsr_enable   : in  std_logic;
    
    -- CHANGE #14: Added control_mode input
    control_mode  : in  std_logic_vector(1 downto 0) := "00";
    
    scan_out      : out std_logic_vector(NUM_SCAN_CHAINS-1 downto 0);
    scan_feedback : in  std_logic_vector(NUM_SCAN_CHAINS-1 downto 0);
    
    lfsr_output   : out std_logic_vector(LFSR_WIDTH-1 downto 0);
    scan_counter  : out std_logic_vector(7 downto 0);
    -- CHANGE #14: Added debug output
    current_control : out std_logic_vector(1 downto 0)
  );
end LBIST_TOP;

architecture Behavioral of LBIST_TOP is

  component LFSR is
    generic(WIDTH : integer := 32);
    port(
      CLK       : in  std_logic;
      reset_neg : in  std_logic;
      seed      : in  std_logic_vector(WIDTH-1 downto 0);
      enable    : in  std_logic;
      output    : out std_logic_vector(WIDTH-1 downto 0);
      bit_out   : out std_logic
    );
  end component;

  component PSF is
    generic(
      LFSR_WIDTH : integer := 32;
      NUM_CHAINS : integer := 1
    );
    port(
      -- CHANGE #10: Removed CLK from port list
      lfsr_output  : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
      current_bit  : out std_logic_vector(NUM_CHAINS-1 downto 0);
      future_bit_1 : out std_logic_vector(NUM_CHAINS-1 downto 0);
      future_bit_2 : out std_logic_vector(NUM_CHAINS-1 downto 0)
    );
  end component;

  component Dynamic_PLPF is
    port(
      current_bit  : in  std_logic;
      future_bit_1 : in  std_logic;
      future_bit_2 : in  std_logic;
      past_bit     : in  std_logic;
      plpf_control : in  std_logic_vector(1 downto 0);
      scan_out     : out std_logic
    );
  end component;

  component PLPF_Control is
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
      control_mode  : in  std_logic_vector(1 downto 0);
      chain_index   : in  std_logic_vector(7 downto 0);
      pattern_index : in  std_logic_vector(15 downto 0);
      plpf_control  : out std_logic_vector(1 downto 0)
    );
  end component;

  -- CHANGE #10: Removed clk_div2 signal
  signal lfsr_out       : std_logic_vector(LFSR_WIDTH-1 downto 0);
  signal lfsr_bit       : std_logic;
  signal current_bits   : std_logic_vector(NUM_SCAN_CHAINS-1 downto 0);
  signal future_bits_1  : std_logic_vector(NUM_SCAN_CHAINS-1 downto 0);
  signal future_bits_2  : std_logic_vector(NUM_SCAN_CHAINS-1 downto 0);
  signal plpf_ctrl      : std_logic_vector(1 downto 0);
  signal scan_cnt       : std_logic_vector(7 downto 0);
  signal scan_cnt_int   : integer range 0 to 255 := 0;
  
  signal pattern_cnt    : unsigned(15 downto 0) := (others => '0');
  signal pattern_index  : std_logic_vector(15 downto 0);
  signal chain_index    : std_logic_vector(7 downto 0) := (others => '0');
  
  -- CHANGE #12: Removed plpf_ctrl_d1 and plpf_ctrl_eff signals

begin
  
  -- CHANGE #10: Removed clock divider process

  -------------------------------------------------------------------
  -- LFSR
  -------------------------------------------------------------------
  LFSR_INST: LFSR
    generic map(WIDTH => LFSR_WIDTH)
    port map(
      CLK       => CLK,  -- CHANGE #10: Direct CLK connection
      reset_neg => reset_neg,
      seed      => lfsr_seed,
      enable    => lfsr_enable,
      output    => lfsr_out,
      bit_out   => lfsr_bit
    );

  -------------------------------------------------------------------
  -- PSF (Now combinational)
  -------------------------------------------------------------------
  PSF_INST: PSF
    generic map(
      LFSR_WIDTH => LFSR_WIDTH,
      NUM_CHAINS => NUM_SCAN_CHAINS
    )
    port map(
      -- CHANGE #11: Removed CLK from port map
      lfsr_output  => lfsr_out,
      current_bit  => current_bits,
      future_bit_1 => future_bits_1,
      future_bit_2 => future_bits_2
    );

  -------------------------------------------------------------------
  -- Scan Counter
  -------------------------------------------------------------------
  process(CLK, reset_neg)
  begin
    if reset_neg = '0' then
      scan_cnt_int <= 0;
    elsif rising_edge(CLK) then
      -- CHANGE #10: Use CLK directly instead of clk_div2
      if scan_enable = '1' and test_mode = '1' then
        if scan_cnt_int < SCAN_CHAIN_LENGTH - 1 then
          scan_cnt_int <= scan_cnt_int + 1;
        else
          scan_cnt_int <= 0;
        end if;
      else
        scan_cnt_int <= 0;
      end if;
    end if;
  end process;
  
  scan_cnt <= std_logic_vector(to_unsigned(scan_cnt_int, 8));

  -------------------------------------------------------------------
  -- Pattern Counter
  -------------------------------------------------------------------
  process(CLK, reset_neg)
  begin
    if reset_neg = '0' then
      pattern_cnt <= (others => '0');
    elsif rising_edge(CLK) then
      -- CHANGE #13: Simplified logic
      if scan_enable = '1' and test_mode = '1' then
        if scan_cnt_int = SCAN_CHAIN_LENGTH - 1 then
          pattern_cnt <= pattern_cnt + 1;
        end if;
      end if;
    end if;
  end process;
  
  pattern_index <= std_logic_vector(pattern_cnt);

  -------------------------------------------------------------------
  -- PLPF Control
  -------------------------------------------------------------------
  PLPF_CTRL_INST: PLPF_Control
    generic map(
      SCAN_CHAIN_LENGTH => SCAN_CHAIN_LENGTH,
      ALPHA => ALPHA,
      BETA  => BETA,
      GAMMA => GAMMA
    )
    port map(
      CLK           => CLK,  -- CHANGE #10: Direct CLK connection
      reset_neg     => reset_neg,
      scan_enable   => scan_enable,
      scan_counter  => scan_cnt,
      control_mode  => control_mode,  -- CHANGE #14: Connected input
      chain_index   => chain_index,
      pattern_index => pattern_index,
      plpf_control  => plpf_ctrl
    );

  -- CHANGE #12: Removed pipeline process for plpf_ctrl_d1
  -- CHANGE #12: Removed remapping logic for plpf_ctrl_eff

  -------------------------------------------------------------------
  -- Dynamic PLPF
  -------------------------------------------------------------------
  gen_plpf: for i in 0 to NUM_SCAN_CHAINS-1 generate
    PLPF_INST: Dynamic_PLPF
      port map(
        current_bit  => current_bits(i),
        future_bit_1 => future_bits_1(i),
        future_bit_2 => future_bits_2(i),
        past_bit     => scan_feedback(i),
        plpf_control => plpf_ctrl,  -- CHANGE #12: Direct connection
        scan_out     => scan_out(i)
      );
  end generate;

  -------------------------------------------------------------------
  -- Output assignments
  -------------------------------------------------------------------
  lfsr_output     <= lfsr_out;
  scan_counter    <= scan_cnt;
  current_control <= plpf_ctrl;  -- CHANGE #14: Added debug output

end Behavioral;