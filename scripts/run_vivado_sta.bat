@echo off
REM ===========================================================================
REM Native Windows CMD/PowerShell Launcher for Vivado Kintex UltraScale STA & Fmax
REM Usage: .\scripts\run_vivado_sta.bat [ROLE_MODE]
REM ===========================================================================
set ROLE_MODE=%1
if "%ROLE_MODE%"=="" set ROLE_MODE=0

echo [EDA-STA] Running Vivado Kintex UltraScale Out-of-Context Synthesis ^& True-Fmax Push (ROLE_MODE=%ROLE_MODE%)...
call vivado.bat -mode batch -nojournal -nolog -source scripts/run_vivado_synth_sta.tcl -tclargs %ROLE_MODE%
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
