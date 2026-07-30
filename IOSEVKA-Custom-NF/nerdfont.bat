:: Copyright
:: Saumyajyoti Mukherjee
:: 2024


@echo off
setlocal
SET FONTVERNUM=17

:: Minutes to wait for the parallel Nerd Font patching jobs before giving up.
SET PATCH_WAIT_MIN=30

::  prerequisites in comments
:: 		ref https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md#building
:: 		tested in Windows11 setup

:: install nodejs, fontforge python 3. Used below versions:
:: 		node version: v26.4.0
:: 		Fontforge: https://github.com/fontforge/fontforge/releases/download/20251009/FontForge-2025-10-09-Windows-x64.exe
:: 		python 3 with fontTools:  python -m pip install --user fonttools

:: Pipeline (each stage is verified before the next one starts):
:: 		STEP 0  prerequisites
:: 		STEP 1  build Iosevka variants (JoySevka, Riosevka)
:: 		STEP 2  merge Victor Mono italic glyphs into JoySevka-Italic
:: 		STEP 3  patch every built TTF with Nerd Fonts symbols
:: 		STEP 4  collect licenses + fonts into dist and zip

SET "IOSEVKA_PATH=%temp%\Iosevka"
SET "ROOT=%~dp0.."
SET "PATH=%ROOT%\bin;%PATH%"
SET "FFPYTHON_EXE=%USERPROFILE%\scoop\apps\fontforge\current\bin\ffpython.exe"
SET "OUTPATH=%~dp0dist\TilottamaCode%FONTVERNUM%"
SET "NERDFONT_PATCHER_PATH=%ROOT%\bin\nerdfont\font-patcher"
SET "FONTVER=TilottamaCode%FONTVERNUM%"

echo =======================================================
echo STEP 0/4: Check prerequisites

where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] git not found on PATH.
  goto :fail
)

where npm >nul 2>&1
if errorlevel 1 (
  echo [ERROR] npm / Node.js not found on PATH.
  goto :fail
)

:: Pick a Python interpreter that actually has fontTools (needed by the merge step).
SET "PYTHON_EXE="
python -c "from fontTools.ttLib import TTFont" >nul 2>&1
if not errorlevel 1 SET "PYTHON_EXE=python"
if not defined PYTHON_EXE (
  py -3 -c "from fontTools.ttLib import TTFont" >nul 2>&1
  if not errorlevel 1 SET "PYTHON_EXE=py -3"
)
if not defined PYTHON_EXE (
  echo [ERROR] No Python 3 with fontTools found ^(tried "python" and "py -3"^).
  echo         Install it with:  python -m pip install --user fonttools
  goto :fail
)
echo   python with fontTools: %PYTHON_EXE%

if not exist "%FFPYTHON_EXE%" (
  echo [ERROR] ffpython not found at "%FFPYTHON_EXE%".
  echo         Install FontForge ^(scoop install fontforge^) or edit FFPYTHON_EXE above.
  goto :fail
)
if not exist "%NERDFONT_PATCHER_PATH%" (
  echo [ERROR] Nerd Fonts patcher not found at "%NERDFONT_PATCHER_PATH%".
  goto :fail
)
if not exist "%~dp0resources\merge_vm_glyphs.py" (
  echo [ERROR] merge_vm_glyphs.py not found in "%~dp0resources".
  goto :fail
)
if not exist "%~dp0resources\VictorMono-MediumItalic.ttf" (
  echo [ERROR] VictorMono-MediumItalic.ttf not found in "%~dp0resources".
  goto :fail
)
echo   all prerequisites OK

rmdir /S /Q "%OUTPATH%" >nul 2>&1
mkdir "%OUTPATH%"

echo =======================================================
echo STEP 1/4: Build Iosevka variants

if exist "%IOSEVKA_PATH%\" (
  echo Sync Iosevka
  cd /d "%IOSEVKA_PATH%" || goto :fail
  rmdir /S /Q "%IOSEVKA_PATH%\dist" >nul 2>&1
  git pull --depth=1
) else (
  echo Clone Iosevka
  git clone https://github.com/be5invis/Iosevka.git "%IOSEVKA_PATH%" --depth=1
  if errorlevel 1 (
    echo [ERROR] git clone of Iosevka failed.
    goto :fail
  )
  cd /d "%IOSEVKA_PATH%" || goto :fail
)

call npm install
if errorlevel 1 (
  echo [ERROR] npm install failed in "%IOSEVKA_PATH%".
  goto :fail
)

call :BUILD JoySevka joysevka || goto :fail
call :BUILD Riosevka riosevka || goto :fail

echo =======================================================
echo STEP 2/4: Merge Victor Mono glyphs into JoySevka Italic only ^(BoldItalic left untouched^)

cd /d "%IOSEVKA_PATH%\dist\joysevka\ttf" || goto :fail
%PYTHON_EXE% "%~dp0resources\merge_vm_glyphs.py" JoySevka-Italic.ttf "%~dp0resources\VictorMono-MediumItalic.ttf" JoySevka-Italic.ttf
if errorlevel 1 (
  echo [ERROR] Victor Mono glyph merge failed - not patching with a broken italic.
  goto :fail
)
if not exist "JoySevka-Italic.ttf" (
  echo [ERROR] JoySevka-Italic.ttf missing after the merge step.
  goto :fail
)
echo   merge OK
cd /d "%IOSEVKA_PATH%" || goto :fail

echo =======================================================
echo STEP 3/4: Patch fonts with Nerd Fonts symbols

call :PATCH joysevka
call :PATCH riosevka

echo Waiting up to %PATCH_WAIT_MIN% minutes for patching jobs to complete...
set /a _waitleft=%PATCH_WAIT_MIN%*20
:waitpatch
tasklist /FI "IMAGENAME eq ffpython.exe" 2>NUL | find /I "ffpython.exe" >NUL
if errorlevel 1 goto :patchdone
if %_waitleft% LEQ 0 goto :patchtimeout
set /a _waitleft-=1
REM timeout.exe fails when stdin is redirected (piped/CI runs); fall back to ping.
timeout /t 3 /nobreak >NUL 2>&1 || ping -n 4 127.0.0.1 >NUL 2>&1
goto :waitpatch

:patchtimeout
echo [ERROR] Nerd Font patching still running after %PATCH_WAIT_MIN% minutes - giving up.
echo         Raise PATCH_WAIT_MIN at the top of this script if the machine is just slow.
goto :fail

:patchdone
echo All patching jobs exited.

call :VERIFYPATCH joysevka || goto :fail
call :VERIFYPATCH riosevka || goto :fail

echo =======================================================
echo STEP 4/4: Copy Files
copy /Y "%ROOT%\*license.*" "%OUTPATH%"
copy /Y "%ROOT%\Install-Font.ps1" "%OUTPATH%"
copy /Y "%IOSEVKA_PATH%\dist\joysevka\ttf\*.ttf" "%OUTPATH%"
copy /Y "%IOSEVKA_PATH%\dist\riosevka\ttf\*.ttf" "%OUTPATH%"

cd /d "%OUTPATH%\.." || goto :fail

echo create %FONTVER%.zip
tar.exe -a -c -f "%FONTVER%.zip" "%OUTPATH%"
if errorlevel 1 (
  echo [ERROR] failed to create %FONTVER%.zip
  goto :fail
)

echo =======================================================
echo Build complete: "%OUTPATH%"
explorer .
exit /b 0

::================ FAILURE EXIT ======================
:fail
echo =======================================================
echo BUILD FAILED - see the [ERROR] line above. Nothing was packaged.
exit /b 1
::====================================================

::================ ROUTINE BUILD =====================
:: %1 = Iosevka build-plan family name (e.g. JoySevka)
:: %2 = lowercase dist folder name / build-plan filename prefix (e.g. joysevka)
:BUILD

echo -------------------------------------------------------
echo Build %1
copy /Y "%~dp0%2-build-plans.toml" "%IOSEVKA_PATH%\private-build-plans.toml" >nul
if errorlevel 1 (
  echo [ERROR] could not copy "%~dp0%2-build-plans.toml".
  exit /b 1
)
call npm run build -- ttf::%1
if errorlevel 1 (
  echo [ERROR] Iosevka build of %1 failed.
  exit /b 1
)
if not exist "%IOSEVKA_PATH%\dist\%2\ttf\%1-Regular.ttf" (
  echo [ERROR] %1 build produced no TTFs in "%IOSEVKA_PATH%\dist\%2\ttf".
  exit /b 1
)
exit /b 0
::====================================================

::================ ROUTINE PATCH =====================
:PATCH

echo -------------------------------------------------------
echo patch fonts in "%IOSEVKA_PATH%\dist\%1\ttf"
cd /d "%IOSEVKA_PATH%\dist\%1\ttf" || exit /b 1
REM --name filename : Iosevka omits "Regular" from the internal font names, so the
REM Regular face is just "Riosevka"/"JoySevka" and the Nerd Font name parser cannot
REM split it into family+style ("WARNING: Parsing the font names failed"). Parsing the
REM filename ("Riosevka-Regular") instead avoids that; output names are unchanged.
REM NOTE: keep comments OUT of the for-loop body - "::" inside a parenthesized block
REM is a batch parse error ("instead was unexpected at this time") and kills patching.
for /r %%f in (%1-*.ttf) do (
 echo "Patching: %%f"
 start /B "" "%FFPYTHON_EXE%" "%NERDFONT_PATCHER_PATH%" -c --name filename "%%f"
)
exit /b 0
::====================================================

::=============== ROUTINE VERIFYPATCH ================
:: Patching runs as detached background jobs, so failures are invisible.
:: Compare the number of source faces with the number of NerdFont outputs.
:VERIFYPATCH

set _in=0
set _out=0
for /f "delims=" %%f in ('dir /b "%IOSEVKA_PATH%\dist\%1\ttf\%1-*.ttf" 2^>nul') do set /a _in+=1
for /f "delims=" %%f in ('dir /b "%IOSEVKA_PATH%\dist\%1\ttf\*NerdFont*.ttf" 2^>nul') do set /a _out+=1
echo   %1: %_in% source face^(s^), %_out% Nerd Font output^(s^)
if %_out% LSS %_in% (
  echo [ERROR] Nerd Font patching incomplete for %1 - expected %_in% output file^(s^), got %_out%.
  echo         Re-run one patch in the foreground to see the error, e.g.:
  echo         "%FFPYTHON_EXE%" "%NERDFONT_PATCHER_PATH%" -c --name filename "%IOSEVKA_PATH%\dist\%1\ttf\%1-Regular.ttf"
  exit /b 1
)
exit /b 0
::====================================================
