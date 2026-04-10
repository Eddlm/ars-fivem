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
    exit 1
}

foreach ($module in $modules) {
    $targetDir = Join-Path $baseDir $module

    if (Test-Path $targetDir) {
        Write-Host "[$module] Updating..."
        Remove-Item -Recurse -Force $targetDir
    } else {
        Write-Host "[$module] Cloning..."
    }

    $tmpDir = Join-Path $baseDir "_ars_tmp_$module"
    git init $tmpDir
    git -C $tmpDir remote add origin $repoUrl
    git -C $tmpDir sparse-checkout init --cone
    git -C $tmpDir sparse-checkout set $module
    git -C $tmpDir pull origin main
    Move-Item -Path (Join-Path $tmpDir $module) -Destination $targetDir
    Remove-Item -Recurse -Force $tmpDir

    Write-Host ""
}
