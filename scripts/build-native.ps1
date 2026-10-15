param([string]$Compiler = 'g++.exe', [string]$Make = 'mingw32-make.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source.Replace('\', '/')
$makePath = (Get-Command $Make -ErrorAction Stop).Source.Replace('\', '/')
Push-Location $projectRoot
try {
    if (-not (Test-Path 'vendor/pikafish/src/engine.cpp')) {
        throw 'Run git submodule update --init --recursive first.'
    }
    cmake -S native -B .native-build/mingw -G 'MinGW Makefiles' "-DCMAKE_CXX_COMPILER=$compilerPath" "-DCMAKE_MAKE_PROGRAM=$makePath" -DCMAKE_BUILD_TYPE=Release
    if ($LASTEXITCODE) { throw 'Native configure failed' }
    cmake --build .native-build/mingw --parallel 4
    if ($LASTEXITCODE) { throw 'Native compilation failed' }
    New-Item -ItemType Directory -Force native/bin/windows | Out-Null
    Copy-Item -LiteralPath .native-build/mingw/anxin_pikafish.dll -Destination native/bin/windows/anxin_pikafish.dll
} finally { Pop-Location }
