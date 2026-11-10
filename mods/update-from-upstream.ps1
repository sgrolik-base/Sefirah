# Re-applies this fork's mods (mods/patches/*.patch) on top of a new upstream Sefirah.
# Creates branch update/upstream-<sha>; never touches master. Stops on the first conflict
# and says which mod it is. Usage: .\mods\update-from-upstream.ps1 [-UpstreamRef upstream/master]
param([string]$UpstreamRef = 'upstream/master')

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

if (git status --porcelain) { throw 'Working tree has uncommitted changes. Commit or stash them first.' }
$source = (git branch --show-current).Trim()

if (-not (git remote | Select-String -SimpleMatch 'upstream')) {
    git remote add upstream https://github.com/shrimqy/Sefirah
}
git fetch upstream --tags

$base = (Get-Content "$PSScriptRoot\BASE" -Raw).Trim()
$target = (git rev-parse $UpstreamRef).Trim()
Write-Host "Mods base:      $base"
Write-Host "New upstream:   $target ($UpstreamRef)"
Write-Host ''
Write-Host 'Upstream changes since the mods base:'
git log --oneline "$base..$target"
Write-Host ''
Write-Host 'Upstream changes that touch files our mods also change:'
$modFiles = Get-ChildItem "$PSScriptRoot\patches\*.patch" |
    ForEach-Object { Select-String -Path $_.FullName -Pattern '^diff --git a/(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } } |
    Sort-Object -Unique
$upstreamFiles = git diff --name-only "$base" "$target"
$overlap = $modFiles | Where-Object { $upstreamFiles -contains $_ }
if ($overlap) { $overlap | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow } } else { Write-Host '  (none)' }
Write-Host ''

# mods/ does not exist in the upstream tree, so keep a copy of the patches before switching.
$work = Join-Path ([IO.Path]::GetTempPath()) "sefirah-mods-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory $work | Out-Null
Copy-Item "$PSScriptRoot\patches\*.patch" $work

$branch = "update/upstream-$($target.Substring(0, 7))"
git checkout -b $branch $target

$patches = Get-ChildItem "$work\*.patch" | Sort-Object Name
foreach ($p in $patches) {
    Write-Host "Applying $($p.Name) ..."
    git am -3 --keep-cr $p.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host "CONFLICT in mod $($p.Name). See mods/MODS.md for what this mod does." -ForegroundColor Red
        Write-Host 'Fix the files, then: git add <files>; git am --continue   (or git am --abort to give up)'
        Write-Host 'Then apply the remaining mods with:'
        Write-Host "  git am -3 --keep-cr $((($patches | Where-Object Name -gt $p.Name).FullName) -join ' ')"
        exit 1
    }
}

# Bring the mods folder (docs, scripts, patches) onto the new branch too.
git checkout $source -- mods
git -c user.name=sgrolik-base -c user.email=s.grolik@baselinker.com commit -q -m "chore: carry mods folder onto upstream update"

Write-Host ''
Write-Host "All $($patches.Count) mods applied on branch $branch." -ForegroundColor Green
Write-Host 'Next: build + install with mods\build-install.ps1, test (mods/MODS.md checklist), then push the branch and open a PR to master.'
Write-Host "After merging, set mods/BASE to $target and regenerate patches with mods\export-mods.ps1."
