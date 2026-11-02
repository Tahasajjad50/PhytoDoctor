import os
import shutil

res_dir = r'c:\Users\munee\Downloads\PhytoDoctor\mobile\android\app\src\main\res'
os.makedirs(os.path.join(res_dir, 'drawable'), exist_ok=True)
os.makedirs(os.path.join(res_dir, 'values'), exist_ok=True)

# 1. launch_background.xml
with open(os.path.join(res_dir, 'drawable', 'launch_background.xml'), 'w', encoding='utf-8') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
</layer-list>
''')

# 2. styles.xml
with open(os.path.join(res_dir, 'values', 'styles.xml'), 'w', encoding='utf-8') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''')

# 3. mipmaps with ic_launcher.png
icon_src = r'c:\Users\munee\Downloads\PhytoDoctor\mobile\assets\images\phytodoctor_icon.png'
for mip in ['mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi']:
    mip_dir = os.path.join(res_dir, mip)
    os.makedirs(mip_dir, exist_ok=True)
    shutil.copy(icon_src, os.path.join(mip_dir, 'ic_launcher.png'))

print("All Android resources created successfully!")
