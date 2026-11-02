# Setup script for JDK 17, Android SDK Command-line Tools, and Flutter
$ErrorActionPreference = 'Stop'

$toolsDir = 'C:\Users\munee\tools'
if (!(Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}

# 1. OpenJDK 17
$jdkDest = 'C:\Users\munee\jdk-17'
if (!(Test-Path $jdkDest)) {
    $jdkZip = Join-Path $toolsDir 'jdk17.zip'
    Write-Host "Downloading OpenJDK 17 to $jdkZip..."
    curl.exe -L -o $jdkZip 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip'
    
    Write-Host "Extracting OpenJDK 17..."
    Expand-Archive -Path $jdkZip -DestinationPath $toolsDir -Force
    $extractedFolder = Get-ChildItem -Path $toolsDir -Directory -Filter 'jdk-17*' | Select-Object -First 1
    if ($extractedFolder) {
        Move-Item -Path $extractedFolder.FullName -Destination $jdkDest -Force
    }
    Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
    Write-Host "OpenJDK 17 installed at $jdkDest."
} else {
    Write-Host "OpenJDK 17 already exists at $jdkDest."
}

# 2. Android Command-line Tools
$androidSdkRoot = 'C:\Users\munee\AppData\Local\Android\Sdk'
$cmdlineToolsDir = Join-Path $androidSdkRoot 'cmdline-tools\latest'
if (!(Test-Path (Join-Path $cmdlineToolsDir 'bin\sdkmanager.bat'))) {
    $cmdlineZip = Join-Path $toolsDir 'commandlinetools.zip'
    Write-Host "Downloading Android Command-Line Tools to $cmdlineZip..."
    curl.exe -L -o $cmdlineZip 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'
    
    Write-Host "Extracting Android Command-Line Tools..."
    $tempExtract = Join-Path $toolsDir 'cmdline_temp'
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $cmdlineZip -DestinationPath $tempExtract -Force
    
    if (!(Test-Path (Split-Path $cmdlineToolsDir -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $cmdlineToolsDir -Parent) -Force | Out-Null
    }
    Move-Item -Path (Join-Path $tempExtract 'cmdline-tools') -Destination $cmdlineToolsDir -Force
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $cmdlineZip -Force -ErrorAction SilentlyContinue
    Write-Host "Android Command-Line Tools installed at $cmdlineToolsDir."
} else {
    Write-Host "Android Command-Line Tools already exist at $cmdlineToolsDir."
}

Write-Host "=== Base environment setup complete ==="
