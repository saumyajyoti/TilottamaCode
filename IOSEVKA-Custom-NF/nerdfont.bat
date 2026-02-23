:: Copyright
:: Saumyajyoti Mukherjee
:: 2024


@echo off
setlocal
SET FONTVERNUM=16

::  prerequisites in comments
:: 		ref https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md#building
:: 		tested in Windows11 setup

:: install nodejs, fontforge python 3. Used below versions:
:: 		node version: v22.21.1
:: 		Fontforge: https://github.com/fontforge/fontforge/releases/download/20251009/FontForge-2025-10-09-Windows-x64.exe

SET IOSEVKA_PATH="%temp%\Iosevka"
SET "PATH=%~dp0\..\bin;%PATH%"
SET "FFPYTHON_EXE=%USERPROFILE%\scoop\apps\fontforge\current\bin\ffpython.exe"
SET OUTPATH="%~dp0dist\TilottamaCode%FONTVERNUM%"
SET NERDFONT_PATCHER_PATH="%~dp0\..\bin\nerdfont\font-patcher"
SET FONTVER=TilottamaCode%FONTVERNUM%

rmdir /S /Q %OUTPATH% >nul 2>&1
mkdir %OUTPATH%

echo =======================================================

if exist %IOSEVKA_PATH%\ (
  echo Sync Iosevka 
  cd /d %IOSEVKA_PATH%
  rmdir /S /Q "%IOSEVKA_PATH%\dist" >nul 2>&1
  git pull --depth=1
) else (
  echo Clone Iosevka
  git clone https://github.com/be5invis/Iosevka.git %IOSEVKA_PATH% --depth=1
  cd /d %IOSEVKA_PATH%
)

call npm install
echo =======================================================
echo Build JoySevka
copy /Y %~dp0\joysevka-build-plans.toml  %IOSEVKA_PATH%\private-build-plans.toml
call npm run build -- ttf::JoySevka
echo =======================================================
echo Build Riosevka
copy /Y %~dp0\riosevka-build-plans.toml  %IOSEVKA_PATH%\private-build-plans.toml
call npm run build -- ttf::Riosevka

echo =======================================================
echo Merge Victor Mono glyphs into JoySevka Italic only (BoldItalic left untouched)
set mi_ttf_dir="%IOSEVKA_PATH%\dist\joysevka\ttf"
cd /d %mi_ttf_dir%
python "%~dp0resources\merge_vm_glyphs.py" JoySevka-Italic.ttf "%~dp0resources\VictorMono-MediumItalic.ttf" JoySevka-Italic.ttf
cd /d %IOSEVKA_PATH%

echo =======================================================
call :PATCH joysevka
call :PATCH riosevka

echo Waiting for patching jobs to complete...
:waitpatch
tasklist /FI "IMAGENAME eq ffpython.exe" 2>NUL | find /I "ffpython.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 3 /nobreak >NUL
    goto :waitpatch
)
echo All patching complete.

echo =======================================================
echo Copy Files
copy /Y %~dp0\..\*license.* %OUTPATH%
copy /Y %~dp0\..\Install-Font.ps1 %OUTPATH%
copy /Y "%IOSEVKA_PATH%\dist\joysevka\ttf\*.ttf" %OUTPATH%
copy /Y "%IOSEVKA_PATH%\dist\riosevka\ttf\*.ttf" %OUTPATH%

cd /d %OUTPATH%\..\

echo create %FONTVER%.zip 
tar.exe -a -c -f "%FONTVER%.zip" %OUTPATH%

explorer .
exit /b 0

::================ ROUTINE PATCH ====================
:PATCH

echo =======================================================

set fontdir="%IOSEVKA_PATH%\dist\%1\ttf"
echo patch fonts in %fontdir%
cd /d %fontdir%
:: setlocal enabledelayedexpansion
for /r %%f in (%1-*.ttf) do (
 echo "Patching: %%f"
 start /B "" "%FFPYTHON_EXE%" %NERDFONT_PATCHER_PATH% -c "%%f"
)
exit /b 0
::====================================================
