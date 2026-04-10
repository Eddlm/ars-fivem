# Updates existing ars-fivem modules using git sparse checkout.
# Run from your resources folder. Requires git to be installed.
# Can be run directly from GitHub:
#   irm https://raw.githubusercontent.com/Eddlm/ars-fivem/main/git-update.ps1 | iex

$repoUrl = "https://github.com/Eddlm/ars-fivem"
$modules = @(
    "customcam",
    "customphysics",
    "performancetuning",
    "racingsystem",
    "traffic_control",
    "vehiclemanager"
)

$baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }

$hasKnownModule = $modules | Where-Object { Test-Path (Join-Path $baseDir $_) }

if (-not $hasKnownModule) {
    Write-Error "No known ars-fivem module folders found in '$baseDir'. Run this from your resources folder, or use git-clone-update.ps1 to clone them first."
    Read-Host "Press Enter to exit"
    exit 1
}

$succeeded = @()
$skipped = @()
$failed = @()

Write-Host ""
Write-Host "=== ars-fivem updater ==="
Write-Host "Target folder: $baseDir"
Write-Host ""

foreach ($module in $modules) {
    $targetDir = Join-Path $baseDir $module
    $tmpDir = Join-Path $baseDir "_ars_tmp_$module"

    if (-not (Test-Path $targetDir)) {
        Write-Host "[$module] Not found, skipping. Run git-clone-update.ps1 to install it first."
        $skipped += $module
        Write-Host ""
        continue
    }

    # Clean up any leftover tmp dir from a previous failed run
    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }

    Write-Host "[$module] Initializing sparse clone..."
    git init $tmpDir
    Start-Sleep -Milliseconds 300

    Write-Host "[$module] Configuring remote..."
    git -C $tmpDir remote add origin $repoUrl
    git -C $tmpDir sparse-checkout init --cone
    git -C $tmpDir sparse-checkout set $module
    Start-Sleep -Milliseconds 300

    Write-Host "[$module] Downloading..."
    git -C $tmpDir pull origin main

    $moduleSrc = Join-Path $tmpDir $module
    if (-not (Test-Path $moduleSrc)) {
        Write-Warning "[$module] Expected folder '$moduleSrc' not found after clone. Something went wrong."
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
        $failed += $module
        Write-Host ""
        continue
    }

    # Overwrite only tracked files, leaving user files (custom races, etc.) untouched
    Write-Host "[$module] Installing..."
    robocopy $moduleSrc $targetDir /E /IS /IT /IM /NFL /NDL /NJH /NJS | Out-Null
    Start-Sleep -Milliseconds 300

    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue

    $succeeded += $module
    Write-Host "[$module] Done."
    Write-Host ""
}

Write-Host "========================="
if ($succeeded.Count -gt 0) {
    Write-Host "Successfully updated: $($succeeded -join ', ')"
}
if ($skipped.Count -gt 0) {
    Write-Host "Skipped (not installed): $($skipped -join ', ')"
}
if ($failed.Count -gt 0) {
    Write-Warning "Failed (check messages above): $($failed -join ', ')"
}
Write-Host ""
Read-Host "Press Enter to exit"
