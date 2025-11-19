library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TopWithScan_SC is
  generic ( n : integer := 32 );
  port (
    -- core clock & reset
    clk         : in  std_logic;
    reset_neg   : in  std_logic;

    -- scan controls
    scan_instr_sel : in  std_logic;  -- 0 = system instruction, 1 = scan instruction (post-IM mux)
    se             : in  std_logic;  -- scan enable: 1 = shift path, 0 = capture DI
    ce             : in  std_logic;  -- clock enable for scan flops (freeze when 0)
    si             : in  std_logic;  -- serial scan in
    so             : out std_logic;  -- serial scan out

    -- (optional) debug out
    dbg_instruction  : out std_logic_vector(31 downto 0);
    dbg_alu_result   : out std_logic_vector(31 downto 0)
  );
end TopWithScan_SC;

architecture rtl of TopWithScan_SC is

  -- =========================
  -- Components
  -- =========================
  component InstructionMemory is
    port(
      register_addr : in  std_logic_vector(31 downto 0);
      mux_scan_mode : in  std_logic;                      -- we'll tie to '0' (always system inside IM)
      scan_data_out : in  std_logic_vector(31 downto 0);  -- unused when mux_scan_mode='0'
      instruction   : out std_logic_vector(31 downto 0)
    );
  end component;

  component ControlUnit is
    port(
      instruction : in  std_logic_vector(31 downto 0);
      ZeroCarry   : in  std_logic;
      RegDst      : out std_logic;
      Jump        : out std_logic;
      Branch      : out std_logic;
      MemRead     : out std_logic;
      MemToReg    : out std_logic;
      ALUOp       : out std_logic_vector(3 downto 0);
      MemWrite    : out std_logic;
      ALUSrc      : out std_logic;
      RegWrite    : out std_logic
    );
  end component;

  component DataPath is
    generic(n : integer := 32);
    port(
      CLK, reset_neg    : in  std_logic;
      instruction       : in  std_logic_vector(31 downto 0);
      RegDst            : in  std_logic;
      Jump              : in  std_logic;
      Branch            : in  std_logic;
      MemRead           : in  std_logic;
      MemToReg          : in  std_logic;
      ALUOp             : in  std_logic_vector(3 downto 0);
      MemWrite          : in  std_logic;
      ALUSrc            : in  std_logic;
      RegWrite          : in  std_logic;
      next_instruction  : out std_logic_vector(31 downto 0);
      ZeroCarry         : out std_logic;
      ALUZero           : out std_logic;
      ALU_Result        : out std_logic_vector(31 downto 0);
      PC_increment      : out std_logic_vector(31 downto 0)
    );
  end component;

  component Mux is
    generic(n : integer := 32);
    port(
      input_1    : in  std_logic_vector(n - 1 downto 0);
      input_2    : in  std_logic_vector(n - 1 downto 0);
      mux_select : in  std_logic;
      output     : out std_logic_vector(n - 1 downto 0)
    );
  end component;

  component alu_scan_to_im32 is
    port(
      clk           : in  std_logic;
      ce            : in  std_logic;
      se            : in  std_logic;
      si            : in  std_logic;
      scan_data_in  : in  std_logic_vector(31 downto 0);  -- what we capture (ALU result)
      scan_data_out : out std_logic_vector(31 downto 0);  -- parallel word (to the post-IM mux)
      so            : out std_logic
    );
  end component;

  -- =========================
  -- Wires
  -- =========================
  signal instr_from_im     : std_logic_vector(31 downto 0);
  signal instr_muxed       : std_logic_vector(31 downto 0);  -- goes to CU+DP
  signal scan_word_to_mux  : std_logic_vector(31 downto 0);  -- from scan chain (parallel)
  signal pc_addr           : std_logic_vector(31 downto 0);

  -- control signals
  signal RegDst_s, Jump_s, Branch_s, MemRead_s, MemToReg_s, MemWrite_s, ALUSrc_s, RegWrite_s : std_logic;
  signal ALUOp_s : std_logic_vector(3 downto 0);

  -- datapath status/results
  signal ZeroCarry_s  : std_logic;
  signal ALUZero_s    : std_logic;
  signal ALU_Result_s : std_logic_vector(31 downto 0);
  signal PC_inc_s     : std_logic_vector(31 downto 0);

begin
  -- 1) Instruction Memory: keep its internal mux OFF (always system output)
  U_IM: InstructionMemory
    port map(
      register_addr => pc_addr,
      mux_scan_mode => '0',           -- IMPORTANT: disable the internal mux; we mux *after* IM
      scan_data_out => (others => '0'),
      instruction   => instr_from_im
    );

  -- 2) Our required mux *after IM*:
  --    select between system instruction (input_1) and scan-chain word (input_2)
  U_IM_SEL: Mux
    generic map(n => 32)
    port map(
      input_1    => instr_from_im,
      input_2    => scan_word_to_mux,
      mux_select => scan_instr_sel,   -- 0 = system, 1 = scan
      output     => instr_muxed
    );

  -- 3) Control Unit sees the muxed instruction
  U_CU: ControlUnit
    port map(
      instruction => instr_muxed,
      ZeroCarry   => ZeroCarry_s,
      RegDst      => RegDst_s,
      Jump        => Jump_s,
      Branch      => Branch_s,
      MemRead     => MemRead_s,
      MemToReg    => MemToReg_s,
      ALUOp       => ALUOp_s,
      MemWrite    => MemWrite_s,
      ALUSrc      => ALUSrc_s,
      RegWrite    => RegWrite_s
    );

  -- 4) Datapath sees the same muxed instruction; exposes ALU_Result to us
  U_DP: DataPath
    generic map(n => 32)
    port map(
      CLK            => clk,
      reset_neg      => reset_neg,
      instruction    => instr_muxed,
      RegDst         => RegDst_s,
      Jump           => Jump_s,
      Branch         => Branch_s,
      MemRead        => MemRead_s,
      MemToReg       => MemToReg_s,
      ALUOp          => ALUOp_s,
      MemWrite       => MemWrite_s,
      ALUSrc         => ALUSrc_s,
      RegWrite       => RegWrite_s,
      next_instruction => pc_addr,
      ZeroCarry      => ZeroCarry_s,
      ALUZero        => ALUZero_s,
      ALU_Result     => ALU_Result_s,    -- <-- we will capture this into scan chain
      PC_increment   => PC_inc_s
    );

  -- 5) Scan chain sits *beside* the core:
  --    - Its parallel input (DI) is ALU_Result_s, captured when se='0' and ce='1'
  --    - Its parallel output feeds the post-IM mux as the "scan instruction"
  U_SC: alu_scan_to_im32
    port map(
      clk           => clk,
      ce            => ce,
      se            => se,
      si            => si,
      scan_data_in  => ALU_Result_s,    -- dump ALU result to scan chain on capture clock
      scan_data_out => scan_word_to_mux,
      so            => so
    );

  -- optional debug
  dbg_instruction <= instr_muxed;
  dbg_alu_result  <= ALU_Result_s;

end rtl;
