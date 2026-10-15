param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$metadataPath = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $metadataPath)) {
    throw 'Run flutter pub get first to resolve the dependency paths.'
}
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$linkRoot = Join-Path $projectRoot 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Path $linkRoot -Force | Out-Null
foreach ($plugin in $metadata.plugins.windows) {
    if ($plugin.name -notmatch '^[a-z0-9_]+$') { throw 'Unexpected plugin name.' }
    $target = (Resolve-Path -LiteralPath $plugin.path).Path
    $link = Join-Path $linkRoot $plugin.name
    if (Test-Path -LiteralPath $link) {
        $existing = Get-Item -LiteralPath $link -Force
        if ($existing.LinkType -notin @('Junction', 'SymbolicLink') -or
            [IO.Path]::GetFullPath($existing.Target[0]).TrimEnd('\') -ne $target.TrimEnd('\')) {
            throw "Existing plugin entry has a different target: $link"
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
    Write-Output "Ready: $($plugin.name)"
}
