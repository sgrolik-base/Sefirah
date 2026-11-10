# Re-applies this fork's mods on top of a new upstream Sefirah.
# The mods are the commits on master since mods/BASE; they are replayed (git rebase) onto the
# new upstream on a new branch update/upstream-<sha>. master is never changed.
# Stops on the first conflict and says which mod it is.
# Usage: .\mods\update-from-upstream.ps1 [-UpstreamRef upstream/master] [-ModsRef master]
param(
    [string]$UpstreamRef = 'upstream/master',
    [string]$ModsRef = 'master'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

if (git status --porcelain) { throw 'Working tree has uncommitted changes. Commit or stash them first.' }

if (-not (git remote | Select-String -SimpleMatch 'upstream')) {
    git remote add upstream https://github.com/shrimqy/Sefirah
}
git fetch upstream --tags

$base = (git show "${ModsRef}:mods/BASE").Trim()
$target = (git rev-parse $UpstreamRef).Trim()
Write-Host "Mods base:      $base"
Write-Host "New upstream:   $target ($UpstreamRef)"
Write-Host ''
Write-Host 'Mods to re-apply:'
git log --reverse --oneline "$base..$ModsRef"
Write-Host ''
Write-Host 'Upstream changes since the mods base:'
git log --oneline "$base..$target"
Write-Host ''
Write-Host 'Files changed both by upstream and by the mods (likely conflicts):'
$modFiles = git diff --name-only $base $ModsRef -- src
$upstreamFiles = git diff --name-only $base $target
$overlap = $modFiles | Where-Object { $upstreamFiles -contains $_ }
if ($overlap) { $overlap | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow } } else { Write-Host '  (none)' }
Write-Host ''

if ($base -eq $target) {
    Write-Host 'Upstream has nothing new since the mods base. Nothing to do.' -ForegroundColor Green
    exit 0
}

$branch = "update/upstream-$($target.Substring(0, 7))"
git branch -f $branch $ModsRef
git -c user.name=sgrolik-base -c user.email=s.grolik@baselinker.com rebase --onto $target $base $branch
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'CONFLICT while re-applying a mod (see the commit title above; mods/MODS.md explains each mod).' -ForegroundColor Red
    Write-Host 'Fix the files, then: git add <files>; git rebase --continue   (or git rebase --abort to give up)'
    exit 1
}

# Record the new base on the update branch.
Set-Content "$repo\mods\BASE" $target -NoNewline -Encoding ascii
git add mods/BASE
git -c user.name=sgrolik-base -c user.email=s.grolik@baselinker.com commit -q -m "chore(mods): rebase mods onto upstream $($target.Substring(0, 7))"

Write-Host ''
Write-Host "All mods re-applied on branch $branch (master untouched)." -ForegroundColor Green
Write-Host 'Next: mods\Build-Install.cmd, test each mod (mods/MODS.md), push the branch, open a PR to master.'
Write-Host 'After merging, run mods\export-mods.ps1 to refresh the backup patches.'
