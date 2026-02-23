:: Copyright
:: Saumyajyoti Mukherjee
:: 2024
::
:: Build JoySpace: a Monaspace derivative (TilottamaCode family).
::   Upright (Regular/Bold)      = Monaspace Argon
::   Italic  (Italic/BoldItalic) = Monaspace Radon (cursive voice)
::
:: Pipeline:
::   Step 1  resources\build_joyspace.py  -> rename the 4 base OTFs into one
::           style-linked "JoySpace" family (RIBBI).
::   Step 2  Nerd Fonts patcher           -> patch those JoySpace faces, yielding
::           the "JoySpace Nerd Font" family, all in a single output dir.
::
:: Prerequisites (same as ..\IOSEVKA-Custom-NF\nerdfont.bat):
::   - FontForge with ffpython (Nerd Fonts patcher), Python 3 with fontTools.
::   - The 4 base Monaspace OTFs are vendored in resources\ (no external source needed).

@echo off
setlocal

SET "RES=%~dp0resources"

SET "FFPYTHON_EXE=%USERPROFILE%\scoop\apps\fontforge\current\bin\ffpython.exe"
SET "PATCHER=%~dp0..\bin\nerdfont\font-patcher"
SET "PATH=%~dp0..\bin;%PATH%"

SET "WORK=%~dp0dist\_joyspace"
SET "OUT=%~dp0dist"

if not exist "%RES%\MonaspaceArgon-Regular.otf" (
  echo ERROR: vendored Monaspace OTFs not found in "%RES%"
  exit /b 1
)

rmdir /S /Q "%WORK%" >nul 2>&1
mkdir "%WORK%"
if not exist "%OUT%" mkdir "%OUT%"

echo =======================================================
echo Step 1: Rename base faces to JoySpace family
python "%~dp0resources\build_joyspace.py" "%WORK%"
if errorlevel 1 (
  echo ERROR: build_joyspace.py failed.
  exit /b 1
)

echo =======================================================
echo Step 2: Nerd-patch JoySpace faces -^> JoySpace Nerd Font
for %%S in (Regular Bold Italic BoldItalic) do (
  echo   Patching JoySpace-%%S.otf
  start /B "" "%FFPYTHON_EXE%" "%PATCHER%" -c "%WORK%\JoySpace-%%S.otf" -out "%OUT%"
)

echo Waiting for patching jobs to complete...
:waitpatch
tasklist /FI "IMAGENAME eq ffpython.exe" 2>NUL | find /I "ffpython.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 3 /nobreak >NUL
    goto :waitpatch
)
echo All patching complete.

echo =======================================================
echo Copy license
:: Bundle the upstream licenses for JoySpace's sources (Monaspace OFL + Nerd Fonts).
copy /Y "%~dp0..\MONASPACE-LICENSE.txt" "%OUT%" >nul 2>&1
copy /Y "%~dp0..\NERDFONT-LICENSE.txt"  "%OUT%" >nul 2>&1

echo =======================================================
echo Clean up scratch (leave only final JoySpace Nerd Font OTFs in the output dir)
rmdir /S /Q "%WORK%" >nul 2>&1

echo =======================================================
echo Done. JoySpace Nerd Font OTFs in "%OUT%"
explorer "%OUT%"
exit /b 0
