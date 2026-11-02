Write-Host "=== 1. CHECKING SYSTEM INFO & VIRTUALIZATION ==="
$sysInfo = systeminfo.exe
$virtEnabled = $sysInfo | Select-String -Pattern "Virtualization Enabled In Firmware|A hypervisor has been detected"
$totalRam = $sysInfo | Select-String -Pattern "Total Physical Memory"
Write-Host "Virtualization:" ($virtEnabled -join " ; ")
Write-Host "RAM:" ($totalRam -join " ; ")

Write-Host "`n=== 2. CHECKING COMMON SDK PATHS ==="
$checkDirs = @(
    "C:\Program Files\Android",
    "C:\Program Files\Android\Android Studio",
    "C:\Program Files\Android\Android Studio\bin",
    "C:\Program Files\Java",
    "C:\Program Files\Eclipse Adoptium",
    "C:\Program Files\Microsoft\jdk",
    "C:\Program Files (x86)\Android",
    "C:\Users\munee\AppData\Local\Android",
    "C:\Users\munee\AppData\Local\Android\Sdk",
    "C:\Users\munee\AppData\Local\Android\Sdk\platform-tools",
    "C:\Users\munee\AppData\Local\Android\Sdk\emulator",
    "C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools",
    "C:\flutter",
    "C:\src\flutter",
    "C:\Users\munee\flutter",
    "C:\Users\munee\Downloads\flutter",
    "C:\Users\munee\AppData\Local\Programs"
)

foreach ($dir in $checkDirs) {
    if (Test-Path $dir) {
        Write-Host "[FOUND]" $dir
    } else {
        Write-Host "[MISSING]" $dir
    }
}

Write-Host "`n=== 3. SEARCHING FOR EXECUTABLES ==="
$executables = @("flutter.bat", "dart.exe", "java.exe", "javac.exe", "adb.exe", "emulator.exe", "studio64.exe", "avdmanager.bat", "sdkmanager.bat")
foreach ($exe in $executables) {
    $found = Get-Command $exe -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "[PATH-OK] $exe -> $($found.Source)"
    } else {
        # Check if exists anywhere in local AppData or Program Files
        $deep = Get-ChildItem "C:\Program Files", "C:\Users\munee\AppData\Local" -Filter $exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($deep) {
            Write-Host "[FOUND ON DISK] $exe -> $($deep.FullName)"
        } else {
            Write-Host "[NOT FOUND] $exe"
        }
    }
}

Write-Host "`n=== 4. CHECKING WINGET / PACKAGE MANAGERS ==="
$wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetCheck) {
    Write-Host "[OK] winget is available at $($wingetCheck.Source)"
} else {
    Write-Host "[NOT FOUND] winget"
}
