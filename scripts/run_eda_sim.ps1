param(
    [string]$Sim = "xsim",
    [int]$Stage = 8
)
$ErrorActionPreference = "Stop"
& cmd.exe /c "scripts\run_eda_sim.bat $Sim $Stage"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
