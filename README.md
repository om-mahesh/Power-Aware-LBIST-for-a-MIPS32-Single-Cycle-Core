# Power-Aware LBIST for MIPS32 Single-Cycle Core

A comprehensive Design-for-Test (DFT) implementation integrating Logic Built-In Self-Test (LBIST) with a MIPS32 single-cycle processor, featuring Programmable Low Power Filter (PLPF) for power-aware testing and an instruction validator for system reliability.

## 🎯 Project Overview

This project demonstrates a complete LBIST integration with a MIPS32 single-cycle processor, achieving **44.64% power reduction** through PLPF-controlled toggle rate management while maintaining high fault coverage. The system includes an innovative instruction validator that filters invalid LBIST-generated patterns before they reach the processor core.

## ✨ Key Features

- **LBIST System**: 32-bit LFSR with configurable seed for pseudo-random pattern generation
- **PLPF Control**: Three-region toggle rate control (α, β, γ) achieving 27.68% overall toggle rate
- **Instruction Validator**: Real-time validation filtering 68% of invalid instructions
- **Scan Chain Integration**: 32-bit serial scan chain for instruction injection and result capture
- **Power Reduction**: 44.64% reduction compared to uncontrolled 50% toggle rate
- **System Safety**: Automatic NOP replacement for invalid instructions, preventing crashes

## 📊 Architecture

### System Architecture Flow

```
┌─────────────────┐
│   LBIST System  │
│  (LFSR + PSF)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PLPF Control   │  ← Toggle Rate Management
│  (α/β/γ regions)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Scan Chain    │  ← 32-bit Serial Shift
│  (32 bits)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Instruction   │  ← Real-time Validation
│    Validator    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  Valid    Invalid
    │         │
    │         ▼
    │      NOP (0x00000000)
    │         │
    └────┬────┘
         │
         ▼
┌─────────────────┐
│  MIPS32 Single- │
│  Cycle Processor │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   ALU Result    │
│   (Capture)     │
└─────────────────┘
```

### Component Breakdown

1. **LBIST System**
   - LFSR: 32-bit Linear Feedback Shift Register
   - Polynomial: x³² + x²² + x² + x + 1
   - PSF: Pattern Selection Filter
   - Seed: Configurable (default: 0xDEADBEEF)

2. **PLPF (Programmable Low Power Filter)**
   - **Alpha Region** (10 cycles): 15.07% toggle rate (PLPF n=3)
   - **Beta Region** (12 cycles): 47.67% toggle rate (PLPF n=1) - High fault coverage
   - **Gamma Region** (10 cycles): 22.6% toggle rate (PLPF n=3)
   - **Overall**: 27.68% toggle rate

3. **Scan Chain**
   - Length: 32 bits (one instruction)
   - Modes: Shift (serial) and Capture (parallel)
   - Operation: 32 cycles to shift in one instruction

4. **Instruction Validator**
   - Validates opcode, function code, and register numbers
   - Flushes invalid instructions to NOP (0x00000000)
   - Real-time combinational validation

5. **MIPS32 Single-Cycle Core**
   - Standard MIPS32 instruction set
   - Single-cycle execution
   - Integrated with scan chain and validator

## 📈 Performance Metrics

### Toggle Rate Measurements (Validated)

| Region | Theoretical | Measured | Power Reduction |
|--------|-------------|----------|-----------------|
| Alpha (Head) | 7.14% | 15.07% | 69.9% |
| Beta (Middle) | 50.0% | 47.67% | 4.7% |
| Gamma (Tail) | 7.14% | 22.6% | 54.8% |
| **Overall** | **23.2%** | **27.68%** | **44.64%** |

### Instruction Validation Results

- **Total Instructions Tested**: 50 (LBIST-generated)
- **Valid Instructions**: 16 (32%)
- **Invalid Instructions Flushed**: 34 (68%)
- **Validation Success Rate**: 100% (all invalid instructions correctly filtered)

## 🏗️ Project Structure

```
DFT3/
├── mips32_core/
│   └── MIPS32_single_cycle/
│       └── code/
│           ├── InstructionValidator.vhd      # Instruction validation module
│           ├── InstructionMemory.vhd         # Instruction memory with bounds checking
│           ├── TopWithScan_SC.vhd            # Top-level with scan chain
│           ├── ControlUnit.vhd
│           ├── DataPath.vhd
│           └── ... (other core components)
├── lbist/
│   ├── lfsr/
│   │   └── LFSR.vhd                          # Linear Feedback Shift Register
│   ├── psf/
│   │   └── PSF.vhd                           # Pattern Selection Filter
│   ├── plpf/
│   │   ├── PLPF_n1.vhd                       # High toggle rate (n=1)
│   │   ├── PLPF_n2.vhd                       # Medium toggle rate (n=2)
│   │   └── PLPF_n3.vhd                       # Low toggle rate (n=3)
│   └── control/
│       ├── PLPF_Control.vhd                  # PLPF control logic
│       └── Dynamic_PLPF.vhd                  # Dynamic PLPF implementation
├── scan/
│   ├── scan_ayan.vhd                         # Scan flip-flop with clock enable
│   └── ... (scan chain components)
├── integration/
│   ├── LBIST_TOP.vhd                         # Top-level LBIST system
│   ├── TopWithScan_SC.vhdl                    # Processor with scan integration
│   ├── tb_lbist_validator_test.vhd            # Comprehensive testbench
│   └── MIPS32_LBIST_TOP.vhd                  # Full system integration
├── ghdl/                                      # GHDL simulator
├── lbist_validator_test.vcd                   # VCD waveform file (15.52 MB)
└── README.md                                  # This file
```

## 🚀 Getting Started

### Prerequisites

- **GHDL**: VHDL simulator (included in `ghdl/` directory)
- **PowerShell**: For running test scripts (Windows)
- **VCD Viewer**: GTKWave or similar (optional, for waveform viewing)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/om-mahesh/Power-Aware-LBIST-for-a-MIPS32-Single-Cycle-Core.git
cd Power-Aware-LBIST-for-a-MIPS32-Single-Cycle-Core
```

2. Verify GHDL is available:
```bash
.\ghdl\bin\ghdl.exe --version
```

### Running the Testbench

The project includes a comprehensive testbench that validates:
- LBIST pattern generation
- PLPF toggle rate control
- Instruction validation
- Processor execution

**Run the LBIST Validator Test:**
```powershell
# Windows PowerShell
.\run_lbist_validator_test.ps1
```

This will:
1. Compile all components
2. Run simulation with 50 LBIST-generated patterns
3. Generate VCD waveform file
4. Display validation statistics and toggle rate measurements

### Viewing Waveforms

Open the generated VCD file with GTKWave:
```bash
gtkwave lbist_validator_test.vcd
```

**Key Signals to Observe:**
- `dbg_instruction`: Instruction that reached processor (after validation)
- `dbg_instr_valid`: Validation flag ('1' = valid, '0' = flushed)
- `dbg_alu_result`: ALU computation result
- `lbist_scan_out`: LBIST-generated patterns
- `si/so`: Scan chain serial in/out

## 📝 Technical Details

### PLPF Toggle Rate Formulas

- **PLPF(n=1)**: T = 50% (direct pass-through)
- **PLPF(n=2)**: T = 25% (two future bits)
- **PLPF(n=3)**: T = 1/14 ≈ 7.14% (three future bits)

### Overall Toggle Rate Calculation

```
T_overall = (α × T_n=3 + β × T_n=1 + γ × T_n=3) / (α + β + γ)
T_overall = (10 × 0.0714 + 12 × 0.50 + 10 × 0.0714) / 32
T_overall ≈ 23.2% (theoretical)
T_overall = 27.68% (measured)
```

### Instruction Validator

The validator checks:
- **Opcode**: Must be in supported set (R-type: 0x00, I-type: 0x08, 0x23, 0x2B, etc., J-type: 0x02)
- **Function Code**: For R-type instructions (add, sub, and, or, etc.)
- **Register Numbers**: Must be 0-31 (5-bit fields)

Invalid instructions are automatically replaced with NOP (0x00000000).

## 📊 Experimental Results

### Test Configuration
- **LFSR Seed**: 0xDEADBEEF
- **Test Patterns**: 50 instructions
- **Scan Chain Length**: 32 bits
- **PLPF Configuration**: α=10, β=12, γ=10 cycles
- **Total Bits Measured**: 1,850 bits

### Results Summary
- ✅ **Power Reduction**: 44.64% compared to uncontrolled testing
- ✅ **Validation Rate**: 100% (all invalid instructions correctly filtered)
- ✅ **Toggle Rate Control**: Effective control in all three regions
- ✅ **System Reliability**: Zero crashes, all invalid instructions safely handled

## 🔬 Supported Instructions

### R-type (opcode 0x00)
- add, sub, and, or, nor, xor, sll, srl, slt

### I-type
- addi (0x08), lw (0x23), sw (0x2B), andi (0x0C), ori (0x0D)
- beq (0x04), bne (0x05), slti (0x0A)

### J-type
- j (0x02)

## 📚 Documentation

- **Main Report**: `integration/LBIST_Validator_Integration_Report.pdf` (242 KB, 5 pages)
- **Summary**: See `integration/REPORT_SUMMARY.md` for quick reference
- **VCD Waveform**: `lbist_validator_test.vcd` (15.52 MB) - Complete simulation data

## 🛠️ Development

### Adding New Instructions

To add support for new instructions, modify:
1. `InstructionValidator.vhd`: Add opcode/function code to validation logic
2. `ControlUnit.vhd`: Add control signal generation for new instruction

### Modifying PLPF Configuration

Edit the generic parameters in `LBIST_TOP.vhd`:
```vhdl
generic(
    ALPHA : integer := 10;  -- Head region cycles
    BETA  : integer := 12;  -- Middle region cycles
    GAMMA : integer := 10   -- Tail region cycles
);
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is part of a Design-for-Test (DFT) course project.

## 👥 Authors

- Design Team - Digital Design and Testing Laboratory

## 🙏 Acknowledgments

- Digital Design and Testing Laboratory for resources and infrastructure
- Based on established LBIST and PLPF methodologies
- MIPS32 processor core from open-source implementations

## 📧 Contact

For questions or issues, please open an issue on GitHub.

---

**Note**: This project demonstrates advanced DFT techniques including LBIST, PLPF power-aware testing, and instruction-level validation for processor testing applications.

