# PowerShell script to set up GitHub repository
# Run this script to initialize and push to GitHub

Write-Host "=== Setting up GitHub Repository ===" -ForegroundColor Green
Write-Host ""

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "Step 1: Initializing git repository..." -ForegroundColor Yellow
git init
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to initialize git repository" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Adding all files..." -ForegroundColor Yellow
git add .
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to add files" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Creating initial commit..." -ForegroundColor Yellow
git commit -m "Initial commit: Power-Aware LBIST for MIPS32 Single-Cycle Core

- Complete LBIST system with LFSR and PLPF control
- Instruction validator for system reliability
- Scan chain integration with MIPS32 processor
- Comprehensive testbench with toggle rate validation
- 44.64% power reduction achieved
- Full documentation and architecture diagrams"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create commit" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 4: Setting main branch..." -ForegroundColor Yellow
git branch -M main
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to rename branch" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Adding remote repository..." -ForegroundColor Yellow
git remote add origin https://github.com/om-mahesh/Power-Aware-LBIST-for-a-MIPS32-Single-Cycle-Core.git
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Remote may already exist. Continuing..." -ForegroundColor Yellow
    git remote set-url origin https://github.com/om-mahesh/Power-Aware-LBIST-for-a-MIPS32-Single-Cycle-Core.git
}

Write-Host ""
Write-Host "Step 6: Pushing to GitHub..." -ForegroundColor Yellow
Write-Host "Note: You may need to authenticate with GitHub" -ForegroundColor Cyan
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to push to GitHub" -ForegroundColor Red
    Write-Host "You may need to:" -ForegroundColor Yellow
    Write-Host "  1. Set up GitHub authentication" -ForegroundColor White
    Write-Host "  2. Create the repository on GitHub first" -ForegroundColor White
    Write-Host "  3. Check your internet connection" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "=== Repository Successfully Pushed to GitHub! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Repository URL: https://github.com/om-mahesh/Power-Aware-LBIST-for-a-MIPS32-Single-Cycle-Core" -ForegroundColor Cyan

