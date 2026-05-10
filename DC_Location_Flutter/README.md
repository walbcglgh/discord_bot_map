# DC Location Flutter

把所在地區同步到 Discord 暱稱的小工具。

## 第一次建立完整 Flutter 專案

因為這台目前沒有 Flutter，所以這裡先放核心源碼。你安裝 Flutter 後在此資料夾執行：

```bash
flutter create --platforms=android,ios .
flutter pub get
```

如果 `flutter create` 覆蓋 `lib/main.dart`，把本資料夾目前的 `lib/main.dart` 保留下來或再貼回去。

平台權限設定請看：

- `docs/ANDROID.md`
- `docs/IOS.md`
- `docs/CODEMAGIC.md`

## Bot 端設定

`.env`：

```env
LOCATION_API_TOKEN=請換成很長的隨機字串
```

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

App 會送出：

```json
{
  "token": "LOCATION_API_TOKEN",
  "guild_id": "Discord 伺服器 ID",
  "user_id": "Discord 使用者 ID",
  "lat": 25.033,
  "lon": 121.565
}
```

Bot 收到後會依照內建鄉鎮市區資料把暱稱改成：

```text
原本暱稱｜臺北市信義區
```

若使用者移動到別的區，舊的尾巴會被替換，不會一直疊上去。
