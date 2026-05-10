from pathlib import Path

ANDROID_PERMISSIONS = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />',
]


def patch_android_manifest():
    path = Path('android/app/src/main/AndroidManifest.xml')
    if not path.exists():
        print('[patch] AndroidManifest.xml not found, skip')
        return
    text = path.read_text(encoding='utf-8')
    insert = '\n'.join(f'    {line}' for line in ANDROID_PERMISSIONS if line not in text)
    if insert:
        text = text.replace('<application', insert + '\n    <application', 1)
        path.write_text(text, encoding='utf-8')
        print('[patch] Android permissions added')
    else:
        print('[patch] Android permissions already exist')


def plist_entry(key, value):
    return f'\n\t<key>{key}</key>\n\t<string>{value}</string>'


def patch_ios_plist():
    path = Path('ios/Runner/Info.plist')
    if not path.exists():
        print('[patch] Info.plist not found, skip')
        return
    text = path.read_text(encoding='utf-8')
    changed = False
    entries = {
        'NSLocationWhenInUseUsageDescription': '用於更新 Discord 暱稱後方的所在地區。',
        'NSLocationAlwaysAndWhenInUseUsageDescription': '用於背景更新 Discord 暱稱後方的所在地區。',
    }
    for key, value in entries.items():
        if f'<key>{key}</key>' not in text:
            text = text.replace('\n</dict>', plist_entry(key, value) + '\n</dict>', 1)
            changed = True
    if '<key>UIBackgroundModes</key>' not in text:
        bg = '''
	<key>UIBackgroundModes</key>
	<array>
		<string>location</string>
		<string>fetch</string>
		<string>processing</string>
	</array>'''
        text = text.replace('\n</dict>', bg + '\n</dict>', 1)
        changed = True
    if '<key>BGTaskSchedulerPermittedIdentifiers</key>' not in text:
        task = '''
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>dc_location_sync_task</string>
	</array>'''
        text = text.replace('\n</dict>', task + '\n</dict>', 1)
        changed = True
    if changed:
        path.write_text(text, encoding='utf-8')
        print('[patch] iOS location permissions added')
    else:
        print('[patch] iOS permissions already exist')


if __name__ == '__main__':
    patch_android_manifest()
    patch_ios_plist()
