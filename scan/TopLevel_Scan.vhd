library ieee;
use ieee.std_logic_1164.all;

entity TopLevel_Scan is
  generic ( n : integer := 32 );
  port (
    CLK, reset_neg : in  std_logic;

    -- scan interface
    scan_mode      : in  std_logic;  -- 1 = use scan instruction; 0 = normal IMem
    scan_en        : in  std_logic;  -- 1 = shift, 0 = capture
    scan_in        : in  std_logic;  -- serial in (LSB-first)
    scan_out       : out std_logic   -- serial out (MSB-first of tail)
  );
end TopLevel_Scan;

architecture Behavioral of TopLevel_Scan is
  ---------------------------------------------------------------------------
  -- Existing components (signatures from your files)
  ---------------------------------------------------------------------------
  component InstructionMemory is
    port (
      register_addr : in  std_logic_vector(31 downto 0);
      instruction   : out std_logic_vector(31 downto 0)
    );
  end component;

  component ControlUnit is
    port (
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
    generic ( n : integer := 32 );
    port (
      -- inputs
      CLK, reset_neg    : in  std_logic;
      instruction       : in  std_logic_vector(31 downto 0);
      -- control signals
      RegDst            : in  std_logic;
      Jump              : in  std_logic;
      Branch            : in  std_logic;
      MemRead           : in  std_logic;
      MemToReg          : in  std_logic;
      ALUOp             : in  std_logic_vector(3 downto 0);
      MemWrite          : in  std_logic;
      ALUSrc            : in  std_logic;
      RegWrite          : in  std_logic;
      -- outputs
      ALUZero           : out std_logic;
      ALU_Result        : out std_logic_vector(31 downto 0);
      next_instruction  : out std_logic_vector(31 downto 0);
      PC_increment      : out std_logic_vector(31 downto 0)
    );
  end component;

  ---------------------------------------------------------------------------
  -- Scan registers (from ScanReg.vhd)
  ---------------------------------------------------------------------------
  component ScanReg is
    generic ( N : integer := 32 );
    port (
      clk     : in  std_logic;
      reset_n : in  std_logic;
      se      : in  std_logic;
      si      : in  std_logic;
      cap_d   : in  std_logic_vector(N-1 downto 0);
      q       : out std_logic_vector(N-1 downto 0);
      so      : out std_logic
    );
  end component;

  ---------------------------------------------------------------------------
  -- Internal signals
  ---------------------------------------------------------------------------
  signal instr_mem     : std_logic_vector(31 downto 0);
  signal instr_scan_q  : std_logic_vector(31 downto 0);
  signal instr_sel     : std_logic_vector(31 downto 0);
  signal chain_mid     : std_logic;

  -- control from ControlUnit (pre-gating)
  signal RegDst_TL, Jump_TL, Branch_TL, MemRead_TL, MemToReg_TL,
         MemWrite_TL, ALUSrc_TL, RegWrite_TL : std_logic;
  signal ALUOp_TL : std_logic_vector(3 downto 0);

  -- gated control into DataPath (stall side-effects in scan mode)
  signal RegDst_G, Jump_G, Branch_G, MemRead_G, MemToReg_G,
         MemWrite_G, ALUSrc_G, RegWrite_G : std_logic;
  signal ALUOp_G : std_logic_vector(3 downto 0);

  -- datapath
  signal ZeroCarry_TL   : std_logic;
  signal ALU_Result_TL  : std_logic_vector(31 downto 0);
  signal NextInstruction: std_logic_vector(31 downto 0);
  signal PC_inc_dummy   : std_logic_vector(31 downto 0);

  -- scan tail payload {zero,result}
  signal cap_payload    : std_logic_vector(32 downto 0);
  signal tail_q         : std_logic_vector(32 downto 0);
  signal chain_out      : std_logic;

begin
  ---------------------------------------------------------------------------
  -- Head of scan chain: 32b instruction register
  --  - In shift, we load LSB-first via scan_in
  --  - In capture/hold, we keep its value (cap_d=its own q)
  ---------------------------------------------------------------------------
  SR_INSTR : ScanReg
    generic map ( N => 32 )
    port map (
      clk     => CLK,
      reset_n => reset_neg,
      se      => scan_en,
      si      => scan_in,
      cap_d   => instr_scan_q,  -- self-hold in capture
      q       => instr_scan_q,
      so      => chain_mid
    );

  -- Select instruction source
  instr_sel <= instr_scan_q when scan_mode = '1' else instr_mem;

  ---------------------------------------------------------------------------
  -- Existing blocks, unmodified
  ---------------------------------------------------------------------------
  CU : ControlUnit
    port map (
      instruction => instr_sel,
      ZeroCarry   => ZeroCarry_TL,
      RegDst      => RegDst_TL,
      Jump        => Jump_TL,
      Branch      => Branch_TL,
      MemRead     => MemRead_TL,
      MemToReg    => MemToReg_TL,
      ALUOp       => ALUOp_TL,
      MemWrite    => MemWrite_TL,
      ALUSrc      => ALUSrc_TL,
      RegWrite    => RegWrite_TL
    );

  -- Gate off “dangerous” effects while in scan mode (stall)
  RegDst_G   <= RegDst_TL;                        -- harmless
  MemToReg_G <= MemToReg_TL;                      -- harmless
  ALUSrc_G   <= ALUSrc_TL;
  ALUOp_G    <= ALUOp_TL;

  Jump_G     <= Jump_TL     when scan_mode='0' else '0';
  Branch_G   <= Branch_TL   when scan_mode='0' else '0';
  MemRead_G  <= MemRead_TL  when scan_mode='0' else '0';
  MemWrite_G <= MemWrite_TL when scan_mode='0' else '0';
  RegWrite_G <= RegWrite_TL when scan_mode='0' else '0';

  DP : DataPath
    generic map ( n => 32 )
    port map (
      CLK              => CLK,
      reset_neg        => reset_neg,
      instruction      => instr_sel,
      RegDst           => RegDst_G,
      Jump             => Jump_G,
      Branch           => Branch_G,
      MemRead          => MemRead_G,
      MemToReg         => MemToReg_G,
      ALUOp            => ALUOp_G,
      MemWrite         => MemWrite_G,
      ALUSrc           => ALUSrc_G,
      RegWrite         => RegWrite_G,
      ALUZero          => ZeroCarry_TL,
      ALU_Result       => ALU_Result_TL,
      next_instruction => NextInstruction,
      PC_increment     => PC_inc_dummy
    );

  IMEM : InstructionMemory
    port map (
      register_addr => NextInstruction,
      instruction   => instr_mem
    );

  ---------------------------------------------------------------------------
  -- Tail of scan chain: capture {Zero, Result}
  ---------------------------------------------------------------------------
  cap_payload <= ZeroCarry_TL & ALU_Result_TL;

  SR_TAIL : ScanReg
    generic map ( N => 33 )
    port map (
      clk     => CLK,
      reset_n => reset_neg,
      se      => scan_en,
      si      => chain_mid,      -- chained after SR_INSTR
      cap_d   => cap_payload,    -- captured when se='0'
      q       => tail_q,
      so      => chain_out
    );

  scan_out <= chain_out;
end Behavioral;
