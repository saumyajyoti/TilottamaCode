<#
.SYNOPSIS
  Build a TilottamaCode release: bundle all built fonts + every license into a zip.

.DESCRIPTION
  Packages the ALREADY-BUILT, Nerd Font-patched fonts found in:
    - IOSEVKA-Custom-NF\dist\TilottamaCode<N>\ (*NerdFont*.ttf - JoySevka, Riosevka)
    - MONASPACE-Custom-NF\dist\               (*NerdFont*.otf - JoySpace)
  Unpatched source faces in those folders are skipped, and each pipeline must have
  produced output or the script fails (so a partial build can't ship a half-family zip).
  These are bundled together with every license file in the repo root (upstream + this project's own
  OFL/MIT) and Install-Font.ps1, into dist\release\TilottamaCode-v<N>.zip.

  Run the build scripts (IOSEVKA-Custom-NF\nerdfont.bat and MONASPACE-Custom-NF\joyspace.bat)
  BEFORE this script - it packages existing output, it does not build.

  Version number (N) is read from FONTVERNUM in nerdfont.bat.

.EXAMPLE
  pwsh ./release.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

# --- determine version from FONTVERNUM -------------------------------------------
$fontVersion = 1
$bat = Join-Path $root 'IOSEVKA-Custom-NF\nerdfont.bat'
if (Test-Path $bat) {
    $m = Select-String -Path $bat -Pattern 'FONTVERNUM=(\d+)' | Select-Object -First 1
    if ($m) { $fontVersion = [int]$m.Matches[0].Groups[1].Value }
}
$Tag = "v$fontVersion"
Write-Host "Release version: $Tag" -ForegroundColor Cyan

# --- staging area (under gitignored dist\) -------------------------------------------
$relDir = Join-Path $root 'dist\release'
$stage  = Join-Path $relDir "TilottamaCode-$Tag"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

# --- collect built fonts -------------------------------------------------------------
# Both pipelines are validated SEPARATELY: an empty IOSEVKA-Custom-NF\dist used to slip
# through and produce a JoySpace-only release, because the old check only tripped when
# *every* dist folder was empty.
$iosevkaDist   = Join-Path $root 'IOSEVKA-Custom-NF\dist'
$monaspaceDist = Join-Path $root 'MONASPACE-Custom-NF\dist'

# nerdfont.bat stages into IOSEVKA-Custom-NF\dist\TilottamaCode<N> and copies the whole
# Iosevka ttf folder there, i.e. the UNPATCHED JoySevka-*.ttf / Riosevka-*.ttf sit next to
# the patched *NerdFont-*.ttf. Only the patched ones belong in a release (shipping both
# gives clashing font families), and only from the newest version folder.
$verDir = Get-ChildItem -Path $iosevkaDist -Directory -Filter 'TilottamaCode*' -ErrorAction SilentlyContinue |
    Sort-Object { [int]($_.Name -replace '\D', '0') } | Select-Object -Last 1
$iosevkaSearch = if ($verDir) { $verDir.FullName } else { $iosevkaDist }
$iosevkaFonts  = @(Get-ChildItem -Path $iosevkaSearch -Recurse -Filter '*NerdFont*.ttf' -ErrorAction SilentlyContinue)
$monaspaceFonts = @(Get-ChildItem -Path $monaspaceDist -Recurse -Filter '*NerdFont*.otf' -ErrorAction SilentlyContinue)

if (-not $iosevkaFonts) {
    throw "No patched *NerdFont*.ttf found under '$iosevkaSearch'. Run IOSEVKA-Custom-NF\nerdfont.bat first (JoySevka + Riosevka)."
}
if (-not $monaspaceFonts) {
    throw "No patched *NerdFont*.otf found under '$monaspaceDist'. Run MONASPACE-Custom-NF\joyspace.bat first (JoySpace)."
}
Write-Host "  JoySevka/Riosevka: $($iosevkaFonts.Count) ttf from $iosevkaSearch"
Write-Host "  JoySpace         : $($monaspaceFonts.Count) otf from $monaspaceDist"

$fonts = $iosevkaFonts + $monaspaceFonts
$dupes = $fonts | Group-Object Name | Where-Object Count -gt 1
if ($dupes) { throw "Duplicate font file name(s) across dist folders: $(($dupes.Name) -join ', ')" }
foreach ($f in $fonts) { Copy-Item $f.FullName -Destination $stage -Force }
Write-Host "Bundled $($fonts.Count) font file(s)" -ForegroundColor Green

# --- collect every license (upstream + own OFL/MIT) ----------------------------------
$licenses = Get-ChildItem -Path $root -File |
    Where-Object { $_.Name -eq 'LICENSE' -or $_.Name -match 'LICENSE' }
foreach ($l in $licenses) { Copy-Item $l.FullName -Destination $stage -Force }
Write-Host "Bundled $($licenses.Count) license file(s): $(( $licenses.Name ) -join ', ')" -ForegroundColor Green

# --- installer -----------------------------------------------------------------------
$installer = Join-Path $root 'Install-Font.ps1'
if (Test-Path $installer) { Copy-Item $installer -Destination $stage -Force }

# --- zip -----------------------------------------------------------------------------
$zip = Join-Path $relDir "TilottamaCode-$Tag.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "Created $zip" -ForegroundColor Green

Write-Host "`nRelease ready:" -ForegroundColor Cyan
Write-Host "  $zip"
