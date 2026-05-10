# iOS 設定

iOS 可以 sideload，但背景定位比 Android 嚴格很多。這個 Flutter 版本用背景工作定期同步，系統不保證每 15 分鐘一定喚醒；如果要更接近即時定位，之後需要加原生 iOS 的 Significant Location Change 或背景定位服務。

先建立平台檔案：

```bash
flutter create --platforms=android,ios .
flutter pub get
```

在 `ios/Runner/Info.plist` 加入定位說明與背景模式：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>用於更新 Discord 暱稱後方的所在地區。</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>用於背景更新 Discord 暱稱後方的所在地區。</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
  <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>dc_location_sync_task</string>
</array>
```

若有 Xcode，還要在 Runner target 的 Signing & Capabilities 啟用 Background Modes，勾選：

- Location updates
- Background fetch
- Background processing

無 Mac 的情況下，可以用 Codemagic 產出未簽名 IPA，再用 AltStore / SideStore 類工具以自己的 Apple ID 重簽。免費 Apple ID 通常 7 天要重簽一次。
