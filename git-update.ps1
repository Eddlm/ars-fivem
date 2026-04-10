# Updates existing ars-fivem modules using git pull.
# Run from your resources folder. Requires git to be installed.
# Can be run directly from GitHub:
#   irm https://raw.githubusercontent.com/Eddlm/ars-fivem/main/git-update.ps1 | iex

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
    exit 1
}

foreach ($module in $modules) {
    $targetDir = Join-Path $baseDir $module

    if (Test-Path $targetDir) {
        Write-Host "[$module] Updating..."
        git -C $targetDir pull origin main
        Write-Host ""
    } else {
        Write-Host "[$module] Not found, skipping. Run git-clone-update.ps1 to clone it."
        Write-Host ""
    }
}
