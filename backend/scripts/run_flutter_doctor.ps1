# Run Flutter Doctor
$env:JAVA_HOME = 'C:\Users\munee\jdk-17'
$env:ANDROID_HOME = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = 'C:\Users\munee\AppData\Local\Android\Sdk'
$env:PATH = "C:\Users\munee\flutter\bin;C:\Users\munee\jdk-17\bin;C:\Users\munee\AppData\Local\Android\Sdk\cmdline-tools\latest\bin;C:\Users\munee\AppData\Local\Android\Sdk\platform-tools;C:\Users\munee\AppData\Local\Android\Sdk\emulator;$env:PATH"

cmd.exe /c "set JAVA_HOME=C:\Users\munee\jdk-17&& set ANDROID_HOME=C:\Users\munee\AppData\Local\Android\Sdk&& flutter doctor -v"
