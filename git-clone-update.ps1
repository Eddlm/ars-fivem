# Downloads or updates ars-fivem modules using git sparse checkout.
# Run from your resources folder. Requires git to be installed.
# Can be run directly from GitHub:
#   irm https://raw.githubusercontent.com/Eddlm/ars-fivem/main/git-clone-update.ps1 | iex

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

$existingItems = Get-ChildItem -Path $baseDir
$isEmpty = $existingItems.Count -eq 0
$hasKnownModule = $modules | Where-Object { Test-Path (Join-Path $baseDir $_) }

if (-not $isEmpty -and -not $hasKnownModule) {
    Write-Error "No known ars-fivem module folders found in '$baseDir' and the folder is not empty. Run this from your resources folder."
    Read-Host "Press Enter to exit"
    exit 1
}

$succeeded = @()
$failed = @()

function Install-Module($module) {
    $targetDir = Join-Path $baseDir $module
    $tmpDir = Join-Path $baseDir "_ars_tmp_$module"

    # Remove old folder if updating
    if (Test-Path $targetDir) {
        Write-Host "[$module] Removing old files..."
        Remove-Item -Recurse -Force $targetDir -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        if (Test-Path $targetDir) {
            Write-Warning "[$module] Could not remove '$targetDir'. Files may be locked (is FiveM running?). Skipping."
            return $false
        }
    }

    # Clean up any leftover tmp dir
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
        return $false
    }

    Write-Host "[$module] Installing..."
    Move-Item -Path $moduleSrc -Destination $targetDir
    Start-Sleep -Milliseconds 300

    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return $true
}

Write-Host ""
Write-Host "=== ars-fivem installer ==="
Write-Host "Target folder: $baseDir"
Write-Host ""

foreach ($module in $modules) {
    $targetDir = Join-Path $baseDir $module
    $action = if (Test-Path $targetDir) { "Updating" } else { "Cloning" }
    Write-Host "[$module] $action..."

    $ok = Install-Module $module
    if ($ok) {
        $succeeded += $module
        Write-Host "[$module] Done."
    } else {
        $failed += $module
    }
    Write-Host ""
}

Write-Host "==========================="
if ($succeeded.Count -gt 0) {
    Write-Host "Successfully installed/updated: $($succeeded -join ', ')"
}
if ($failed.Count -gt 0) {
    Write-Warning "Failed (check messages above): $($failed -join ', ')"
}
Write-Host ""
Read-Host "Press Enter to exit"
