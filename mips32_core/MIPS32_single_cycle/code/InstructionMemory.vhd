-- Copyright (c) 2019 David Palma licensed under the MIT license
-- Author: David Palma
-- Project: MIPS32 single cycle
-- Module: InstructionMemory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity InstructionMemory is
  port( -- input
        register_addr : in  std_logic_vector(31 downto 0);
        mux_scan_mode : in  std_logic;
        scan_data_out : in  std_logic_vector(31 downto 0);

        -- output
        instruction   : out std_logic_vector(31 downto 0) );
end InstructionMemory;

architecture Behavioral of InstructionMemory is

type reg is array (0 to 1500) of std_logic_vector(7 downto 0);
signal instr_memory: reg := (
-- auto generated
-- addi $R1,$R0,30
0 => "00100000",
1 => "00000001",
2 => "00000000",
3 => "00011110",

-- sw $R1,0($R0)
4 => "10101100",
5 => "00000001",
6 => "00000000",
7 => "00000000",

-- lw $R3,0($R0)
8 => "10001100",
9 => "00000011",
10 => "00000000",
11 => "00000000",

-- srl $R7,$R3,1
12 => "00000000",
13 => "01100000",
14 => "00111000",
15 => "01000010",

-- sll $R8,$R7,1
16 => "00000000",
17 => "11100000",
18 => "01000000",
19 => "01000000",

-- addi $R2,$R0,27
20 => "00100000",
21 => "00000010",
22 => "00000000",
23 => "00011011",

-- addi $R2,$R2,1
24 => "00100000",
25 => "01000010",
26 => "00000000",
27 => "00000001",

-- sw $R2,1($R0)
28 => "10101100",
29 => "00000010",
30 => "00000000",
31 => "00000001",

-- sub $R3,$R1,$R2
32 => "00000000",
33 => "00100010",
34 => "00011000",
35 => "00100010",

-- beq $R1,$R2,1
36 => "00010000",
37 => "00100010",
38 => "00000000",
39 => "00000001",

-- j 6
40 => "00001000",
41 => "00000000",
42 => "00000000",
43 => "00000110",

-- sw $R2,3($R0)
44 => "10101100",
45 => "00000010",
46 => "00000000",
47 => "00000011",

-- lw $R10,3($R0)
48 => "10001100",
49 => "00001010",
50 => "00000000",
51 => "00000011",

    others => "00000000" );

  signal im_data : std_logic_vector(31 downto 0);

begin
  process(register_addr, instr_memory)
    variable addr : integer;
    variable addr0, addr1, addr2, addr3 : integer;
    variable addr_unsigned : unsigned(31 downto 0);
  begin
    -- Clamp address to prevent overflow in to_integer
    addr_unsigned := unsigned(register_addr);
    if addr_unsigned > 1500 then
      addr := 1500;
    else
      addr := to_integer(addr_unsigned);
    end if;
    
    -- Bounds checking: ensure all addresses are within valid range (0 to 1500)
    if addr > 1500 then
      addr0 := 1500;
      addr1 := 1500;
      addr2 := 1500;
      addr3 := 1500;
    elsif addr + 3 > 1500 then
      addr0 := addr;
      if (addr + 1) <= 1500 then
        addr1 := addr + 1;
      else
        addr1 := 1500;
      end if;
      if (addr + 2) <= 1500 then
        addr2 := addr + 2;
      else
        addr2 := 1500;
      end if;
      addr3 := 1500;
    else
      addr0 := addr;
      addr1 := addr + 1;
      addr2 := addr + 2;
      addr3 := addr + 3;
    end if;
    
    im_data <= instr_memory(addr0) &
               instr_memory(addr1) &
               instr_memory(addr2) &
               instr_memory(addr3);
  end process;

  instruction <= im_data    when mux_scan_mode = '0' else
                 scan_data_out;               
end Behavioral;


