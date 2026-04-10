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
        git -C $targetDir pull origin main
    } else {
        Write-Host "[$module] Cloning..."
        git init $targetDir
        git -C $targetDir remote add origin $repoUrl
        git -C $targetDir sparse-checkout init --cone
        git -C $targetDir sparse-checkout set $module
        git -C $targetDir pull origin main
    }

    Write-Host ""
}
