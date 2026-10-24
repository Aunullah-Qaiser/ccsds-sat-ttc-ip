@echo off
REM ============================================================================
REM File Name   : sync_from_gdrive.bat
REM Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
REM Description : One-command Windows launcher to sync the local repository
REM               from the Google Drive for Desktop folder CCSDS_SAT_TTC_IP_Sync
REM ============================================================================
python "%~dp0sync_from_gdrive.py" %*
