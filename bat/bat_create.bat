REM ============================================================
REM Create new version package
REM ============================================================
call bat_rsvars.bat

@SET kam_version=Beta 7k.1

REM Clean before build to avoid any side-effects from old DCUs
call bat_get_kam_folder.bat

REM Clean target, so if anything fails we have a clear indication (dont pack old files by mistake)
rmdir /S /Q "%kam_folder%"

REM Clean before build to avoid any side-effects from old DCUs
call bat_clean_src.bat

REM Pack rx data
call bat_rx_pack.bat

REM Build exe
call bat_build_exe.bat

REM Patch exe
REM call bat_patch_exe.bat

REM Copy
call bat_copy_pack.bat

REM Future: Archive into 7z
call bat_7zip.bat

REM Create Installer instructions
call bat_prepare_installer.bat

REM Build Installer
call bat_build_installer.bat