@echo off
REM ============================================================================
REM File Name   : run_stage11_matrix_parallel.bat
REM Project     : CCSDS-SAT-TTC-IP v2.37.0
REM Description : Launches 12-Thread Parallel Vivado xsim Runner for all 5,760
REM               Valid CCSDS RF Link Configurations in Stage 11 with
REM               Configurable Monte Carlo Trials & OAT/Combined Impairments.
REM Usage       : .\scripts\run_stage11_matrix_parallel.bat [THREADS] [MC_ITERS] [IMPAIRMENT_MODE]
REM Examples    : .\scripts\run_stage11_matrix_parallel.bat 12 1 auto
REM               .\scripts\run_stage11_matrix_parallel.bat 12 6 progressive
REM ============================================================================
setlocal

set THREADS=%1
if "%THREADS%"=="" set THREADS=12

set MC_ITERS=%2
if "%MC_ITERS%"=="" set MC_ITERS=1

set IMP_MODE=%3
if "%IMP_MODE%"=="" set IMP_MODE=auto

echo [CCSDS-STAGE11-MATRIX] Running 5,760-Configuration RF Link Matrix across %THREADS% parallel xsim threads (MC_ITERS=%MC_ITERS%, IMPAIRMENT_MODE=%IMP_MODE%)...
python scripts/run_stage11_matrix_parallel.py --threads %THREADS% --total-configs 5760 --mc-iters %MC_ITERS% --impairment-mode %IMP_MODE%
if errorlevel 1 exit /b 1
