<#
.SYNOPSIS
  Build a TilottamaCode release candidate: bundle all built fonts + every license into a
  versioned zip and create a git tag.

.DESCRIPTION
  Packages the ALREADY-BUILT fonts found in:
    - IOSEVKA-Custom-NF\dist\   (*.ttf  - JoySevka, Riosevka)
    - MONASPACE-Custom-NF\dist\ (*.otf  - JoySpace)
  together with every license file in the repo root (upstream + this project's own
  OFL/MIT) and Install-Font.ps1, into dist\release\TilottamaCode-v<N>.zip, then creates
  an annotated git tag v<N>.

  Run the build scripts (IOSEVKA-Custom-NF\nerdfont.bat and MONASPACE-Custom-NF\joyspace.bat)
  BEFORE this script - it packages existing output, it does not build.

  Versioning is an incrementing integer tag (v<N>). The next version is max(existing v* tags)+1,
  or, if there are no tags yet, the FONTVERNUM value from nerdfont.bat (so the first release
  lines up with the build's version number).

.PARAMETER Tag
  Override the auto-computed tag (must look like v<N>, e.g. v20).

.PARAMETER Push
  Also push the created tag to origin. Off by default (tag is created locally only).

.EXAMPLE
  pwsh ./release.ps1
.EXAMPLE
  pwsh ./release.ps1 -Tag v20 -Push
#>
[CmdletBinding()]
param(
    [string]$Tag,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

# --- determine next version (integer v<N>) -------------------------------------------
if (-not $Tag) {
    $nums = @()
    foreach ($t in (git tag --list "v*")) {
        if ($t -match '^v(\d+)$') { $nums += [int]$Matches[1] }
    }
    if ($nums.Count) {
        $next = ($nums | Measure-Object -Maximum).Maximum + 1
    }
    else {
        # No tags yet: start at FONTVERNUM from nerdfont.bat (fallback 1).
        $next = 1
        $bat = Join-Path $root 'IOSEVKA-Custom-NF\nerdfont.bat'
        if (Test-Path $bat) {
            $m = Select-String -Path $bat -Pattern 'FONTVERNUM=(\d+)' | Select-Object -First 1
            if ($m) { $next = [int]$m.Matches[0].Groups[1].Value }
        }
    }
    $Tag = "v$next"
}
if ($Tag -notmatch '^v\d+$') { throw "Tag must look like v<N> (e.g. v17); got '$Tag'." }
if (git tag --list $Tag)     { throw "Tag $Tag already exists." }
Write-Host "Release tag: $Tag" -ForegroundColor Cyan

# --- staging area (under gitignored dist\) -------------------------------------------
$relDir = Join-Path $root 'dist\release'
$stage  = Join-Path $relDir "TilottamaCode-$Tag"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

# --- collect built fonts -------------------------------------------------------------
$fonts = @()
$fonts += Get-ChildItem -Path (Join-Path $root 'IOSEVKA-Custom-NF\dist')  -Recurse -Filter *.ttf -ErrorAction SilentlyContinue
$fonts += Get-ChildItem -Path (Join-Path $root 'MONASPACE-Custom-NF\dist') -Recurse -Filter *.otf -ErrorAction SilentlyContinue
if (-not $fonts) {
    throw "No fonts found in dist folders. Run nerdfont.bat and joyspace.bat first."
}
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

# --- tag -----------------------------------------------------------------------------
git tag -a $Tag -m "TilottamaCode $Tag"
Write-Host "Created git tag $Tag (local)" -ForegroundColor Green
if ($Push) {
    git push origin $Tag
    Write-Host "Pushed tag $Tag to origin" -ForegroundColor Green
}
else {
    Write-Host "To publish the tag: git push origin $Tag" -ForegroundColor Yellow
}

Write-Host "`nRelease candidate ready:" -ForegroundColor Cyan
Write-Host "  $zip"
