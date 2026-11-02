# Configure Environment and Install Android Components
$ErrorActionPreference = 'Stop'

# 1. Set environment variables permanently in User scope
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Users\munee\jdk-17', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Users\munee\AppData\Local\Android\Sdk', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', 'C:\Users\munee\AppData\Local\Android\Sdk', 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$addPaths = @(
    'C:\Users\munee\jdk-17\bin',
    'C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools\latest\bin',
    'C:\Users\munee\AppData\Local\Android\Sdk\platform-tools',
    'C:\Users\munee\AppData\Local\Android\Sdk\emulator',
    'C:\Users\munee\flutter\bin'
)

foreach ($p in $addPaths) {
    if ($userPath -notlike "*$p*") {
        $userPath = "$p;$userPath"
    }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')

# Also set in current process
$env:JAVA_HOME = 'C:\Users\munee\jdk-17'
$env:ANDROID_HOME = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:PATH = "C:\Users\munee\jdk-17\bin;C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools\latest\bin;C:\Users\munee\AppData\Local\Android\Sdk\platform-tools;C:\Users\munee\AppData\Local\Android\Sdk\emulator;$env:PATH"

Write-Host "Verifying Java..."
& "$env:JAVA_HOME\bin\java.exe" -version

Write-Host "Verifying sdkmanager..."
$sdkmanager = 'C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat'

# 2. Accept licenses
Write-Host "Accepting Android SDK licenses..."
cmd.exe /c "set JAVA_HOME=C:\Users\munee\jdk-17&& echo y| `"$sdkmanager`" --licenses"

# 3. Install platform-tools, emulator, platforms;android-34, build-tools;34.0.0, system image
Write-Host "Installing Android SDK packages (platform-tools, emulator, platforms;android-34, build-tools;34.0.0, system-images;android-33;google_apis;x86_64)..."
cmd.exe /c "set JAVA_HOME=C:\Users\munee\jdk-17&& `"$sdkmanager`" `"platform-tools`" `"emulator`" `"platforms;android-34`" `"build-tools;34.0.0`" `"system-images;android-33;google_apis;x86_64`""

Write-Host "Android packages installed successfully."
