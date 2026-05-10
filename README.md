# DC Location Flutter

把所在地區同步到 Discord 暱稱的小工具。

## 第一次建立完整 Flutter 專案

因為這台目前沒有完整 Android SDK，所以這裡主要交給 Codemagic build。若本機有 Flutter，可在此資料夾執行：

```bash
flutter create --platforms=android,ios .
flutter pub get
```

如果 `flutter create` 覆蓋 `lib/main.dart`，把本資料夾目前的 `lib/main.dart` 保留下來或再貼回去。

平台權限設定請看：

- `docs/ANDROID.md`
- `docs/IOS.md`
- `docs/CODEMAGIC.md`

## 使用流程

1. App 會自動產生一組通知碼。
2. 複製通知碼。
3. 到 Discord 伺服器使用：

```text
/location_code action:綁定 code:你的通知碼
```

4. 回到 App 填 API Endpoint，按「手動同步一次」或「儲存並啟動背景同步」。

App endpoint：

```text
https://你的網域/api/location/update
```

## Android 打包

```bash
flutter build apk --release
```

APK 位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## iOS / Codemagic

把這個資料夾推到 GitHub，Codemagic 讀 `codemagic.yaml`。

免費 Apple ID / 7 天重簽通常會用 AltStore 或 SideStore 處理安裝；Codemagic 主要負責雲端 macOS build。

## API 行為

App 只會送出通知碼與定位，不會送 Discord 使用者 ID 或伺服器 ID：

```json
{
  "code": "DCL-ABCD-2345-EFGH-6789",
  "lat": 25.033,
  "lon": 121.565
}
```

Bot 收到後會依照通知碼查出綁定的 Discord 使用者，再把暱稱改成：

```text
原本暱稱｜臺北市信義區
```

若使用者移動到別的區，舊的尾巴會被替換，不會一直疊上去。
