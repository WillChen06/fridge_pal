# Fridge Pal — Flutter 食材管家 App 執行計畫

## Context

從零打造一個跨 iOS / Android 的 Flutter App，主要解決「家裡食材調味料管理失控、過期浪費、不知道剩下的東西能煮什麼」的問題。

四大核心功能：
1. 買菜紀錄 + 食材/調味料庫存控管
2. 食材快用完 / 接近到期跳通知
3. 拍標籤 OCR 自動建檔
4. 串 Claude API，根據剩下的食材推薦食譜

開發流程上採 Codex Agent 寫 code → GitHub PR → Claude Code Action 自動 review → merge → Telegram 通知；commit 走小單位 + 簡化 GitFlow（`main` + `feature/*`）。

---

## 可行性評估

| 項目 | 結論 | 備註 |
|---|---|---|
| Flutter 環境 | ✅ 已安裝（`/Users/kuan-chungchen/flutter/bin/flutter`）| SDK 3.11.5，支援 Dart 3 |
| 本地 DB（SQLite/Drift） | ✅ 成熟 | `drift` 提供型別安全 query + migration |
| OCR（Google ML Kit） | ✅ 裝置端、免費、離線 | `google_mlkit_text_recognition` 支援中文 |
| 本地通知 | ✅ | `flutter_local_notifications` + `workmanager` 排程 |
| Claude API 串接 | ✅ | 走 HTTP（`dio`）打 Messages API；在 prompt 開 cache |
| CI/CD（GitHub Actions） | ✅ | `flutter analyze` + `flutter test` + `anthropics/claude-code-action@v1` + Telegram step |
| Codex Agent 開發 | ✅ | Codex Cloud 在 feature 分支推 commit、開 PR |

**整體：完全可行**，沒有需要自架後端、沒有需要 App Store 帳號（先 sideload / Android 先行）。風險點集中在：(1) ML Kit 對皺褶/反光標籤辨識率、(2) Claude API key 不能進 repo。

---

## 技術選型總結

| 面向 | 選擇 |
|---|---|
| App 名稱 / Bundle | `fridge_pal` / `com.willchen.fridgepal` |
| 平台 | iOS + Android |
| 狀態管理 | Riverpod（type-safe、testable，比 Provider 適合 medium app） |
| 本地資料庫 | Drift（SQLite，generated code，migration 友善） |
| OCR | `google_mlkit_text_recognition`（裝置端） |
| 拍照 | `image_picker`（相簿 + 相機） |
| 本地通知 | `flutter_local_notifications` + `workmanager` |
| AI Provider | Claude（Anthropic Messages API，模型 `claude-sonnet-4-6`，啟用 prompt caching） |
| API Key 管理 | `.env` + `--dart-define-from-file`，`.env` 加入 `.gitignore`；CI 用 GitHub Secrets |
| HTTP | `dio`（攔截器友善、log 方便） |
| 路由 | `go_router` |
| 國際化 | `flutter_localizations` + zh_TW（先做繁中，預留英文） |

---

## 專案結構

```
fridge_pal/
├── .github/
│   └── workflows/
│       ├── pr-check.yml          # analyze + test
│       ├── claude-review.yml     # Claude Code Action 自動 review PR
│       └── notify.yml            # merge 後 Telegram 通知
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp + Router + Theme
│   ├── core/
│   │   ├── db/                   # Drift database, DAOs, migrations
│   │   ├── api/claude_client.dart
│   │   ├── ocr/ocr_service.dart
│   │   ├── notifications/notification_service.dart
│   │   └── env.dart              # dart-define 讀 API key
│   ├── features/
│   │   ├── inventory/            # 食材列表 / 詳情 / 編輯
│   │   ├── shopping/             # 買菜紀錄
│   │   ├── scan/                 # 拍照 + OCR + 結構化 (未來可選擇接 AI 解析)
│   │   └── recipes/              # AI 食譜建議
│   └── shared/
│       ├── widgets/
│       └── models/
├── test/                         # unit + widget tests
├── integration_test/             # 端到端流程
├── .env.example                  # 範例（無 key）
├── .gitignore                    # 含 .env
├── analysis_options.yaml         # 嚴格 lint
└── pubspec.yaml
```

---

## 資料模型（Drift schema 草案）

```dart
// ingredients
class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();          // 蔬菜/肉類/調味料/...
  RealColumn get quantity => real()();
  TextColumn get unit => text()();              // g / ml / 個 / 包
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get lowStockThreshold => real().nullable()();
  TextColumn get location => text().nullable()(); // 冷藏 / 冷凍 / 常溫
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// shopping_records
class ShoppingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  RealColumn get totalCost => real().nullable()();
}

// shopping_items（多對一 → ShoppingRecord）
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recordId => integer().references(ShoppingRecords, #id)();
  IntColumn get ingredientId => integer().nullable().references(Ingredients, #id)();
  TextColumn get nameSnapshot => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get cost => real().nullable()();
}
```

---

## 開發 Roadmap（每個 phase 一個 feature 分支系列、每階段獨立可跑）

### Phase 0 — Bootstrap（基礎建設）
**Branch：`feature/bootstrap`**
- `flutter create fridge_pal --org com.willchen --platforms=ios,android`
- 設定 `analysis_options.yaml`（啟用 `flutter_lints` + 自訂 strict）
- 加入依賴：`drift` `drift_flutter` `riverpod` `flutter_riverpod` `go_router` `dio` `google_mlkit_text_recognition` `image_picker` `flutter_local_notifications` `workmanager` `flutter_dotenv` `intl`
- 建立 `.env.example`、`.gitignore` 加入 `.env`、`*.iml`、`build/`
- `lib/core/env.dart`：`String.fromEnvironment('ANTHROPIC_API_KEY')`
- 設定 `MaterialApp` + `go_router` 殼 + dark/light theme
- `git init` + 第一個 commit + 推上 GitHub
- 寫 `README.md`：跑法 + dart-define 範例

### Phase 1 — 食材庫存 CRUD
**Branch：`feature/inventory-crud`**
- Drift database + `Ingredients` table + DAO
- Riverpod providers（`ingredientListProvider` / `ingredientByIdProvider`）
- 三個畫面：列表（依類別 group）、詳情、編輯/新增
- 單元測試：DAO insert/update/delete + provider 邏輯

### Phase 2 — 買菜紀錄
**Branch：`feature/shopping-record`**
- `ShoppingRecords` + `ShoppingItems` schema
- 「新增買菜紀錄」流程：選日期 → 加品項 → 自動同步進 `Ingredients`（quantity 累加 / 新建）
- 紀錄列表頁

### Phase 3 — OCR 拍標籤建檔
**Branch：`feature/ocr-scan`**
- `image_picker` 啟動相機/相簿
- `core/ocr/ocr_service.dart` 包 ML Kit → 回傳 raw text
- 簡單 parser 從 OCR 文字提：商品名、保存期限（regex `YYYY/MM/DD`、`保存期限`）、容量
- 預填到「新增食材」表單供使用者確認

### Phase 4 — 過期 / 低庫存通知
**Branch：`feature/notifications`**
- 初始化 `flutter_local_notifications`（iOS 權限 + Android channel）
- `workmanager` 註冊每天 09:00 任務：掃 `Ingredients`，找出
  - `expiryDate` 在 3 天內
  - `quantity <= lowStockThreshold`
  - 發本地通知，每樣只發一次（用 `notified_at` 欄位避免騷擾）
- 設定頁可調提醒時間 / 提前天數

### Phase 5 — Claude AI 食譜建議
**Branch：`feature/ai-recipes`**
- `core/api/claude_client.dart`：dio 打 `https://api.anthropic.com/v1/messages`
- System prompt 開 `cache_control: ephemeral` 省成本
- 食譜頁：「根據冰箱現有食材推薦」按鈕 → 帶目前 inventory JSON → 串流回應
- 結果存本地（最近 10 筆食譜歷史，可重看）

### Phase 6 — 收尾
**Branch：`feature/polish`**
- App icon + splash（`flutter_launcher_icons` / `flutter_native_splash`）
- 空狀態、loading、error 處理一輪
- 中文 UI 文案校稿

---

## CI / CD Pipeline

### 工作流程圖
```
Codex Agent
  ↓ commit (小單位)
feature/* branch
  ↓ git push
GitHub
  ↓ open PR → main
┌─────────────────────────────────┐
│ pr-check.yml                    │  ← 必過
│  • flutter analyze              │
│  • flutter test                 │
├─────────────────────────────────┤
│ claude-review.yml               │  ← 自動跑
│  • anthropics/claude-code-action│
│    @v1 對 diff 做 review        │
│  • 留 review comment 在 PR      │
└─────────────────────────────────┘
  ↓ 人工確認 review 沒問題後 merge
main
  ↓
notify.yml
  • 打 Telegram Bot API → 指定 chat
```

### Workflow 檔案規劃

**`.github/workflows/pr-check.yml`**
- trigger: `pull_request`
- 步驟：`subosito/flutter-action@v2` → `flutter pub get` → `flutter analyze` → `flutter test`

**`.github/workflows/claude-review.yml`**
- trigger: `pull_request` (opened, synchronize)
- 用 `anthropics/claude-code-action@v1`，傳入 `ANTHROPIC_API_KEY` secret
- prompt 強調：檢查 Dart/Flutter 慣例、null safety、state management 正確性、是否破壞既有 schema migration

**`.github/workflows/notify.yml`**
- trigger: `push` to `main`
- curl Telegram Bot API：`https://api.telegram.org/bot<TOKEN>/sendMessage`
- 帶 commit message + author + PR 連結

### Secrets 清單（GitHub repo settings → Secrets）
- `ANTHROPIC_API_KEY` — Claude API key（**不可推上 repo**）
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

### 本地 API key 不外流的措施
- `.gitignore` 包 `.env`
- 加 pre-commit hook（用 `lefthook` 或簡單 bash）擋 `sk-ant-` 開頭字串
- README 範例只用 `.env.example` 佔位
- Codex Agent 在指示中強調「絕不可把 key 寫進任何檔案，只能讀 `--dart-define`」

---

## Commit 規範（小單位原則）

採 Conventional Commits + 1 commit = 1 邏輯單元：
- `feat(inventory): add Ingredient drift table`
- `feat(inventory): wire up ingredient list provider`
- `feat(inventory): build inventory list screen`
- `test(inventory): cover IngredientDao crud`
- `chore(ci): add pr-check workflow`

每個 PR 包 3–8 個小 commit，避免「一個 PR 改 30 個檔做 5 件事」。

---

## 關鍵檔案（建立後重點關注）

| 路徑 | 用途 |
|---|---|
| `pubspec.yaml` | 依賴版本鎖定 |
| `lib/core/env.dart` | API key 讀取單一入口 |
| `lib/core/db/database.dart` | Drift schema + migration |
| `lib/core/api/claude_client.dart` | Claude API 包裝（含 cache + 錯誤處理） |
| `lib/core/ocr/ocr_service.dart` | ML Kit 包裝 + parser |
| `lib/core/notifications/notification_service.dart` | 本地通知排程 |
| `.github/workflows/*.yml` | CI 三件組 |
| `.env.example` / `.gitignore` | 安全邊界 |

---

## 驗證方式

每個 phase 完成後跑：
1. **靜態檢查**：`flutter analyze`（必須零警告）
2. **單元測試**：`flutter test`（DAO、provider、parser 都要有 case）
3. **iOS Simulator** + **Android Emulator** 跑過該 phase 的 user flow
4. **Phase 0 完成時**：開一個 dummy PR 走完整 CI（pr-check 過 → Claude review 留言 → merge → 收到 Telegram 通知）以驗證 pipeline

整體 MVP 完成驗收：
- 拍一張食材標籤 → 自動建立進庫存
- 把某項食材改成低庫存 → 隔天 09:00 收到本地通知
- 點「推薦食譜」→ Claude 回 ≥ 1 個可行食譜
- 從 feature 分支開 PR → 自動 review → merge → Telegram 通知

---

## 預估時程（單人 + Codex Agent 輔助）

| Phase | 估時 |
|---|---|
| 0 Bootstrap + CI | 1 天 |
| 1 Inventory CRUD | 2 天 |
| 2 Shopping Record | 1 天 |
| 3 OCR | 1.5 天 |
| 4 Notifications | 1 天 |
| 5 Claude Recipes | 1.5 天 |
| 6 Polish | 1 天 |
| **合計** | **~9 天** |

---

## 開放決策（之後再敲定，不影響先動工）

- App icon / 配色主題
- 食材分類預設清單（先給一個常用 20 項，使用者可加）
- 是否要做食材條碼（barcode）掃描 → Phase 7+ 再評估
- 是否上架（先 sideload + Android APK 自用即可）
