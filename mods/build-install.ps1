# Builds Sefirah (Windows, x64, Release) and installs it as a sideloaded app over the current one.
# Keeps the app identity (shrimqy.Seki-PhoneLink), so pairing and data survive. Needs Developer Mode.
# Usage: .\mods\build-install.ps1            (closes the running Sefirah, bumps the install version)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$installDir = 'C:\Users\s.grolik\Apps\Sefirah'

$env:DOTNET_ROOT = "$env:LOCALAPPDATA\Microsoft\dotnet"
$env:PATH = "$env:DOTNET_ROOT;$env:PATH"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
if (-not (Test-Path "$env:DOTNET_ROOT\dotnet.exe")) {
    throw '.NET 10 SDK missing. Install per-user: dotnet-install.ps1 -Channel 10.0 -InstallDir $env:LOCALAPPDATA\Microsoft\dotnet -NoPath'
}

# mrmsupport.dll comes from the restored NuGet package; the full Windows SDK is not needed.
$mrm = Get-ChildItem "$env:USERPROFILE\.nuget\packages\microsoft.windows.sdk.buildtools" -Recurse -Filter mrmsupport.dll -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -eq 'x64' } | Sort-Object FullName -Descending | Select-Object -First 1

Set-Location "$repo\src"
$buildArgs = @('build', 'Sefirah\Sefirah.csproj', '-f', 'net10.0-windows10.0.26100', '-p:Platform=x64', '-c', 'Release')
if ($mrm) { $buildArgs += "-p:SefirahMrmSupportDll=$($mrm.FullName)" }
dotnet @buildArgs
if ($LASTEXITCODE -ne 0) {
    if (-not $mrm) { Write-Host 'Tip: if the error is about mrmsupport.dll, run the build once more (first run restores the NuGet package).' }
    throw "Build failed ($LASTEXITCODE)."
}

$out = "$repo\src\Sefirah\bin\x64\Release\net10.0-windows10.0.26100\win-x64"

Get-Process | Where-Object { $_.Path -like "$installDir\*" } | ForEach-Object { Stop-Process -Id $_.Id -Confirm:$false }
Start-Sleep -Seconds 2
robocopy $out $installDir /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy $LASTEXITCODE)." }

# Windows refuses to re-register the same version: bump the last number above the installed one.
$installed = (Get-AppxPackage shrimqy.Seki-PhoneLink).Version
$next = if ($installed) { $v = [version]$installed; "$($v.Major).$($v.Minor).$($v.Build).$($v.Revision + 1)" } else { $null }
$manifest = "$installDir\AppxManifest.xml"
if ($next) {
    $xml = Get-Content $manifest -Raw
    $xml = $xml -replace '(<Identity Version=")[\d\.]+(")', "`${1}$next`$2"
    Set-Content $manifest $xml -NoNewline -Encoding utf8
}

Add-AppxPackage -Register $manifest -ForceApplicationShutdown
Write-Host "Installed Sefirah $((Get-AppxPackage shrimqy.Seki-PhoneLink).Version) from $installDir" -ForegroundColor Green
Start-Process 'shell:AppsFolder\shrimqy.Seki-PhoneLink_9yhjgvpvzzxz2!App'
