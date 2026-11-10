# Regenerates mods/patches from the commits on the current branch since mods/BASE.
# Run after merging a mod PR (or after an upstream update) so the patch series stays current.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$base = (Get-Content "$PSScriptRoot\BASE" -Raw).Trim()
Remove-Item "$PSScriptRoot\patches\*.patch" -ErrorAction SilentlyContinue
# Exclude commits that only touch mods/ itself (docs/scripts), they are not code mods.
git format-patch "$base..HEAD" -o mods/patches --no-signature -- . ':(exclude)mods' |
    ForEach-Object { Write-Host (Split-Path $_ -Leaf) }
Write-Host 'Done. Update mods/MODS.md if a mod was added or changed.'
