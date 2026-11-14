# 把蘿讀裝到 iPhone：你要做的六步

這六步只做一次。之後每次要新版，我推一個標籤，雲端的 Mac 就會自己編好送上 TestFlight。

金鑰檔和三組代號都只貼進 GitHub 的設定頁，不要貼給我，也不要放進 repo。這個 repo 是公開的。

Apple 和 GitHub 的選單名稱偶爾會改，下面寫的位置如果找不到，照字面意思找相近的。

## 1. 決定 app 的識別碼

想一個全世界不會重複的代號，格式像倒過來的網址，例如 `com.你的英文名.luodu`。只能用英文字母、數字、點、連字號。決定之後不能改，記下來。

## 2. 在 Apple 開發者網站登記這個識別碼

1. 登入 developer.apple.com，進 Account。
2. 進「Certificates, Identifiers & Profiles」→「Identifiers」→ 按加號。
3. 選「App IDs」→「App」。
4. Description 填「Luodu」，Bundle ID 選 Explicit，填第 1 步的代號。
5. 下面的功能都不用勾，按 Continue、Register。

同一個帳號頁面裡找「Membership details」，把 **Team ID**（十碼英數字）記下來。

## 3. 在 App Store Connect 建立 app

1. 登入 appstoreconnect.apple.com →「App」→ 加號 →「新增 App」。
2. 平台選 iOS。
3. 名稱填「蘿讀」。如果說名稱已被使用，改成「蘿讀 繪本」之類的，這只是後台名稱。
4. 主要語言選繁體中文。
5. 套件識別碼選第 2 步登記的那個。
6. SKU 隨便填，例如 `luodu-001`。
7. 建立。

## 4. 產生一把 API 金鑰

這把金鑰讓雲端的 Mac 可以幫你簽章和上傳。

1. App Store Connect →「使用者與存取權限」→「整合」→「App Store Connect API」。
2. 在「團隊金鑰」按加號。
3. 名稱填「GitHub Actions」，存取權限選「管理」（Admin）。
4. 產生之後，記下這一列的 **金鑰 ID**，和頁面上方的 **Issuer ID**。
5. 按「下載」，會拿到一個 `AuthKey_XXXXXXXX.p8`。這個檔只能下載一次，收好。

## 5. 把五個值填進 GitHub

打開 repo 的 Settings →「Secrets and variables」→「Actions」。

在 **Secrets** 分頁按「New repository secret」，加三個：

| 名稱 | 填什麼 |
|---|---|
| `ASC_KEY_ID` | 第 4 步的金鑰 ID |
| `ASC_ISSUER_ID` | 第 4 步的 Issuer ID |
| `ASC_KEY_P8` | 用記事本打開 `.p8` 檔，整份內容全選貼上，包含頭尾的 `-----BEGIN PRIVATE KEY-----` 那兩行 |

切到 **Variables** 分頁按「New repository variable」，加兩個：

| 名稱 | 填什麼 |
|---|---|
| `TEAM_ID` | 第 2 步的 Team ID |
| `BUNDLE_ID` | 第 1 步的識別碼 |

## 6. 跟我說「設定好了」

我會推一個 `testflight-1` 標籤，雲端開始編譯上傳，大概十到二十分鐘。

上傳成功後 Apple 還要處理一陣子。處理完你再做兩件事：

1. App Store Connect → 你的 app →「TestFlight」→「內部測試」→ 建一個群組，把自己加進去。
2. iPhone 上裝「TestFlight」這個 app，用同一個 Apple ID 登入，就會看到蘿讀，按安裝。

要給姊姊裝的話，之後在同一個地方加「外部測試」群組，填她的 email。外部測試第一次要等 Apple 審一下。

## 如果失敗

第一次跑簽章流程常會卡。失敗的話跟我說，我去看雲端的紀錄。這條流程我寫好了但還沒實際跑過，要等你的金鑰設定好才驗得到。
