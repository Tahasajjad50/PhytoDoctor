# Script to create lightweight AVD and boot it
$ErrorActionPreference = 'Stop'

$env:JAVA_HOME = 'C:\Users\munee\jdk-17'
$env:ANDROID_HOME = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:PATH = "C:\Users\munee\jdk-17\bin;C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools\latest\bin;C:\Users\munee\AppData\Local\Android\Sdk\platform-tools;C:\Users\munee\AppData\Local\Android\Sdk\emulator;$env:PATH"

$avdName = 'PhytoDoctor_Pixel'
$sysImage = 'system-images;android-33;google_apis;x86_64'

Write-Host "Checking if AVD $avdName exists..."
$avdList = & avdmanager.bat list avd
if ($avdList -notmatch $avdName) {
    Write-Host "Creating AVD $avdName with $sysImage..."
    cmd.exe /c "echo no | `"$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\avdmanager.bat`" create avd -n $avdName -k `"$sysImage`" -d pixel_5 --force"
} else {
    Write-Host "AVD $avdName already exists."
}

# Tune config.ini for 8 GB RAM host PC
$avdDir = Join-Path $env:USERPROFILE ".android\avd\$avdName.avd"
$configFile = Join-Path $avdDir "config.ini"

if (Test-Path $configFile) {
    Write-Host "Tuning config.ini for lightweight 8GB RAM host..."
    $content = Get-Content $configFile
    $tuned = @()
    $hasRam = $false
    $hasHeap = $false
    $hasGpu = $false

    foreach ($line in $content) {
        if ($line -match '^hw\.ramSize') {
            $tuned += 'hw.ramSize = 1536'
            $hasRam = $true
        } elseif ($line -match '^vm\.heapSize') {
            $tuned += 'vm.heapSize = 256'
            $hasHeap = $true
        } elseif ($line -match '^hw\.gpu\.mode') {
            $tuned += 'hw.gpu.mode = auto'
            $hasGpu = $true
        } else {
            $tuned += $line
        }
    }
    if (!$hasRam) { $tuned += 'hw.ramSize = 1536' }
    if (!$hasHeap) { $tuned += 'vm.heapSize = 256' }
    if (!$hasGpu) { $tuned += 'hw.gpu.mode = auto' }
    $tuned | Set-Content $configFile
    Write-Host "AVD config tuned (1536 MB RAM, 256 MB Heap)."
}

Write-Host "Starting Emulator in background..."
Start-Process -FilePath "$env:ANDROID_SDK_ROOT\emulator\emulator.exe" -ArgumentList "-avd $avdName -memory 1536 -no-boot-anim -netdelay none -netspeed full"

Write-Host "Waiting for device to connect to adb..."
& adb.exe wait-for-device

Write-Host "Waiting for device boot completion..."
$booted = $false
for ($i = 0; $i -lt 60; $i++) {
    $prop = (& adb.exe shell getprop sys.boot_completed) -replace '\r|\n', ''
    if ($prop -eq '1') {
        $booted = $true
        break
    }
    Start-Sleep -Seconds 2
}

if ($booted) {
    Write-Host "=== Android Virtual Device successfully booted and ready! ==="
    & adb.exe devices
} else {
    Write-Warning "Emulator is still starting up. Please check adb devices in a moment."
}
