$emuZip = Get-ChildItem -Path 'C:\Users\munee\AppData\Local\Android\Sdk\.temp' -Recurse -Filter '*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
$flutterZip = Get-Item 'C:\Users\munee\tools\flutter_windows_3.24.5-stable.zip' -ErrorAction SilentlyContinue

$emuSize = if ($emuZip) { [math]::Round($emuZip.Length / 1MB, 1) } else { 0 }
$flutterSize = if ($flutterZip) { [math]::Round($flutterZip.Length / 1MB, 1) } else { 0 }

Write-Host "Emulator Package: $emuSize MB"
Write-Host "Flutter SDK:      $flutterSize MB / 985.8 MB"
