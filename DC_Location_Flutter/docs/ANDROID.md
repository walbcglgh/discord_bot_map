# Android 設定

先在 `DC_Location_Flutter` 內建立 Flutter 平台檔案：

```bash
flutter create --platforms=android,ios .
flutter pub get
```

接著確認 `android/app/src/main/AndroidManifest.xml` 有這些權限。`INTERNET` 通常 Flutter 會自動放，但建議確認一次。

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

Android 10 之後背景定位需要使用者到系統設定裡允許「一律允許」。App 會先要求前景定位；若手機沒有給背景定位，背景同步可能只會在 App 開著或系統願意喚醒時成功。

打包 APK：

```bash
flutter build apk --release
```

輸出位置通常是：

```text
build/app/outputs/flutter-apk/app-release.apk
```
