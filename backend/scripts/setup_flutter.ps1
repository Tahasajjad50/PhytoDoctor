# Setup Flutter SDK
$ErrorActionPreference = 'Stop'

$flutterDest = 'C:\Users\munee\flutter'
$toolsDir = 'C:\Users\munee\tools'
if (!(Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }

if (Test-Path (Join-Path $flutterDest 'bin\flutter.bat')) {
    Write-Host "Flutter SDK already exists at $flutterDest."
    exit 0
}

$flutterZip = Join-Path $toolsDir 'flutter_windows_3.24.5-stable.zip'
if (!(Test-Path $flutterZip)) {
    Write-Host "Downloading Flutter 3.24.5 stable to $flutterZip..."
    curl.exe -L -o $flutterZip 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip'
}

Write-Host "Extracting Flutter SDK to C:\Users\munee..."
# Use tar or powershell Expand-Archive (tar.exe is fast and built into Windows 10/11)
tar.exe -xf $flutterZip -C 'C:\Users\munee'

if (Test-Path (Join-Path $flutterDest 'bin\flutter.bat')) {
    Write-Host "Flutter SDK successfully installed at $flutterDest."
    Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
} else {
    Write-Error "Failed to extract Flutter SDK to $flutterDest."
}
