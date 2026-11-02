$licDir = 'C:\Users\munee\AppData\Local\Android\Sdk\licenses'
if (!(Test-Path $licDir)) {
    New-Item -ItemType Directory -Path $licDir -Force | Out-Null
}

@'
24333f8a63b6825ea9c5514f83c2829b004d1fee
d56f5187479451eabf01fb78af6dfcb131a6481e
893777c830ddb3133440c3584d96b79f0d153476
'@ | Set-Content (Join-Path $licDir 'android-sdk-license')

@'
84831b9409646a53fe4447a616996614e03bc07e
'@ | Set-Content (Join-Path $licDir 'android-sdk-preview-license')

@'
d975f751698a77b662f1254ddbeed3901e1a16db
'@ | Set-Content (Join-Path $licDir 'intel-android-extra-license')

@'
601085b94cd77f0b54ff86406955499418714e67
'@ | Set-Content (Join-Path $licDir 'android-googletv-license')

@'
33b6a2b64900ae02302b413cce0eadba123f2b86
'@ | Set-Content (Join-Path $licDir 'google-gdk-license')

@'
e9acab587f1749c670a831157c91fa4d323f96f
'@ | Set-Content (Join-Path $licDir 'mips-android-sysimage-license')

Write-Host "All Android SDK license hashes successfully written."
