# Codemagic 免費建置流程

1. 把 `DC_Location_Flutter` 放到 GitHub repository。
2. 到 Codemagic 匯入該 repository。
3. 選 `android-debug` workflow 可以先產生容易安裝測試的 APK。
4. Android 沒問題後再跑 `android-release`。
5. iOS 可跑 `ios-unsigned`，它會輸出 `DC_Location_unsigned.ipa`。

注意：`ios-unsigned` 只是包成 IPA，沒有正式簽名。你仍然需要 AltStore / SideStore / Sideloadly 這類工具用自己的 Apple ID 安裝到 iPhone。

Bot 端 `.env` 需要加：

```env
LOCATION_API_TOKEN=你自己產生的一串長密碼
```

App 端設定：

- API 位址：`https://你的網域/api/location/update`
- Token：同 `.env` 的 `LOCATION_API_TOKEN`
- Guild ID：要改暱稱的伺服器 ID
- User ID：使用者自己的 Discord ID

Bot 必須在該伺服器有「管理暱稱」權限，而且 Bot 的最高身分組要高於目標使用者。
