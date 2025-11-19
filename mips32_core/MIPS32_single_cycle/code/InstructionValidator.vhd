-- Copyright (c) 2025 DFT3 Project
-- Author: Instruction Validator
-- Module: InstructionValidator
-- Description: Validates instructions from scan chain (LBIST) before passing to processor
--              Invalid instructions are flushed (replaced with NOP)
--              Validates: opcode, register numbers (0-31), and function codes for R-type

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity InstructionValidator is
  port(
    -- input
    scan_instruction : in  std_logic_vector(31 downto 0);
    
    -- output
    valid_instruction : out std_logic_vector(31 downto 0);
    is_valid          : out std_logic  -- '1' if valid, '0' if flushed
  );
end InstructionValidator;

architecture Behavioral of InstructionValidator is

  -- MIPS32 NOP instruction: sll $0, $0, 0 (0x00000000)
  constant NOP_INSTRUCTION : std_logic_vector(31 downto 0) := x"00000000";
  
  -- Extract instruction fields
  signal opcode      : std_logic_vector(5 downto 0);
  signal rs          : std_logic_vector(4 downto 0);
  signal rt          : std_logic_vector(4 downto 0);
  signal rd          : std_logic_vector(4 downto 0);
  signal shamt       : std_logic_vector(4 downto 0);
  signal funct       : std_logic_vector(5 downto 0);
  signal immediate   : std_logic_vector(15 downto 0);
  signal jump_addr   : std_logic_vector(25 downto 0);
  
  -- Validation flags
  signal opcode_valid    : std_logic;
  signal rs_valid        : std_logic;
  signal rt_valid        : std_logic;
  signal rd_valid        : std_logic;
  signal funct_valid     : std_logic;
  signal instruction_valid : std_logic;

begin

  -- Extract instruction fields
  opcode    <= scan_instruction(31 downto 26);
  rs        <= scan_instruction(25 downto 21);
  rt        <= scan_instruction(20 downto 16);
  rd        <= scan_instruction(15 downto 11);
  shamt     <= scan_instruction(10 downto 6);
  funct     <= scan_instruction(5 downto 0);
  immediate <= scan_instruction(15 downto 0);
  jump_addr <= scan_instruction(25 downto 0);

  -- Validate register numbers (must be 0-31)
  -- Note: Since rs, rt, rd are 5-bit vectors, they can only represent 0-31
  -- The unsigned comparison handles metavalues gracefully (returns false, which is safe)
  rs_valid <= '1';  -- 5-bit vectors are always in range 0-31
  rt_valid <= '1';  -- 5-bit vectors are always in range 0-31
  rd_valid <= '1';  -- 5-bit vectors are always in range 0-31

  -- Validate opcode and function code
  process(opcode, funct, rs, rt, rd)
  begin
    opcode_valid <= '0';
    funct_valid <= '0';
    
    case opcode is
      -- R-type instructions (opcode = 000000)
      when "000000" =>
        opcode_valid <= '1';
        -- Validate function code for supported R-type instructions
        case funct is
          when "100000" => funct_valid <= '1';  -- add
          when "100010" => funct_valid <= '1';  -- sub
          when "100100" => funct_valid <= '1';  -- and
          when "100101" => funct_valid <= '1';  -- or
          when "100111" => funct_valid <= '1';  -- nor
          when "100110" => funct_valid <= '1';  -- xor
          when "000000" => funct_valid <= '1';  -- sll
          when "000010" => funct_valid <= '1';  -- srl
          when "101010" => funct_valid <= '1';  -- slt
          when others   => funct_valid <= '0';  -- unsupported function
        end case;
      
      -- I-type instructions
      when "001000" => opcode_valid <= '1';  -- addi
      when "100011" => opcode_valid <= '1';  -- lw
      when "101011" => opcode_valid <= '1';  -- sw
      when "001100" => opcode_valid <= '1';  -- andi
      when "001101" => opcode_valid <= '1';  -- ori
      when "000100" => opcode_valid <= '1';  -- beq
      when "000101" => opcode_valid <= '1';  -- bne
      when "001010" => opcode_valid <= '1';  -- slti
      
      -- J-type instructions
      when "000010" => opcode_valid <= '1';  -- j
      
      -- Unsupported opcodes
      when others => opcode_valid <= '0';
    end case;
  end process;

  -- Overall instruction validity check
  process(opcode_valid, funct_valid, rs_valid, rt_valid, rd_valid, opcode)
  begin
    -- First check: opcode must be valid
    if opcode_valid = '0' then
      instruction_valid <= '0';
    elsif opcode = "000000" then
      -- R-type: check function code and all register fields
      if funct_valid = '1' and rs_valid = '1' and rt_valid = '1' and rd_valid = '1' then
        instruction_valid <= '1';
      else
        instruction_valid <= '0';
      end if;
    elsif opcode = "000010" then
      -- J-type: only opcode matters (already validated above), no register validation needed
      instruction_valid <= '1';
    elsif opcode = "000100" or opcode = "000101" then
      -- Branch instructions: check rs and rt
      if rs_valid = '1' and rt_valid = '1' then
        instruction_valid <= '1';
      else
        instruction_valid <= '0';
      end if;
    else
      -- Other I-type: check rs and rt (rt is destination for some, source for others)
      -- opcode_valid is already checked above, so if we're here, opcode is valid
      if rs_valid = '1' and rt_valid = '1' then
        instruction_valid <= '1';
      else
        instruction_valid <= '0';
      end if;
    end if;
  end process;

  -- Output: valid instruction or NOP
  valid_instruction <= scan_instruction when instruction_valid = '1' else NOP_INSTRUCTION;
  is_valid <= instruction_valid;

end Behavioral;

