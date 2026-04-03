# Android App

This Android app reuses the existing mobile web layout through a native WebView shell so the UI stays aligned with the current phone browser experience.

## What is included

- Full-screen WebView shell for the current frontend
- Pull-to-refresh
- Back-key navigation
- File chooser support
- System download handoff
- Basic launcher icon and splash theme

## Current web entry

The app currently opens:

- `https://llcms.iepose.cn/`

If you need to change it later, edit `app/build.gradle.kts` and update `MOBILE_WEB_URL`.

## Build

Use either Android Studio or the command line from the `android-app` directory:

```powershell
.\gradlew.bat assembleDebug
```

Debug APK output:

- `app\build\outputs\apk\debug\app-debug.apk`

## Release signing

1. Create `keystore.properties` based on `keystore.properties.example`.
2. Put your keystore file path in `storeFile` (relative to `android-app`).
3. Build release:

```powershell
.\gradlew.bat assembleRelease
```

Release APK output:

- `app\build\outputs\apk\release\app-release.apk`
