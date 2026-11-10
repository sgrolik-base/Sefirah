# Refreshes mods/patches: a backup copy of every mod commit since mods/BASE (code changes only).
# The update script replays commits from master; these patches are for reading and for
# re-applying by hand (git am --keep-cr) if the git history is ever lost.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$base = (Get-Content "$PSScriptRoot\BASE" -Raw).Trim()
Remove-Item "$PSScriptRoot\patches\*.patch" -ErrorAction SilentlyContinue
git format-patch "$base..HEAD" -o mods/patches --no-signature -- src |
    ForEach-Object { Write-Host (Split-Path $_ -Leaf) }
Write-Host 'Done. Update mods/MODS.md if a mod was added or changed.'
