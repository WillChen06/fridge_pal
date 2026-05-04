# Fridge Pal 🥬

食材庫存與食譜管家 — 跨 iOS / Android 的 Flutter App。

## 功能 (規劃中)

- 📋 食材 / 調味料庫存控管 + 買菜紀錄
- 🔔 食材快用完 / 接近到期跳本地通知
- 📷 拍標籤 OCR 自動建檔（Google ML Kit，裝置端）
- 🤖 串接 Claude API，根據冰箱現有食材推薦食譜

詳細 roadmap 見 `docs/plan.md`（或 Claude 計畫檔）。

## 環境需求

- Flutter SDK >= 3.11.5（Dart 3）
- iOS 模擬器或實機（macOS）
- Android emulator 或實機

## 啟動方式

```bash
# 1. 安裝依賴
flutter pub get

# 2. 複製環境變數範本，填入自己的 Anthropic key
cp env.example.json env.json
# 編輯 env.json，填上 ANTHROPIC_API_KEY

# 3. 跑 App（注意要帶 dart-define-from-file）
flutter run --dart-define-from-file=env.json
```

> ⚠️ `env.json` 在 `.gitignore` 內，**絕對不要 commit**。

## 開發流程

1. **分支命名**：`feature/<功能簡述>` ← 從 `main` 切出（簡化 GitFlow）
2. **Commit 顆粒度**：採 [Conventional Commits](https://www.conventionalcommits.org/)，每個 commit 一個邏輯單元
   - `feat(inventory): add Ingredient drift table`
   - `feat(inventory): build inventory list screen`
   - `test(inventory): cover IngredientDao crud`
3. **PR 流程**：
   - 開 PR 到 `main`
   - GitHub Actions 自動跑 `flutter analyze` + `flutter test`
   - Claude Code Action 自動 review diff，留 comment 在 PR
   - 通過後 merge → Telegram bot 通知

## CI / CD

| Workflow | Trigger | 工作 |
|---|---|---|
| `pr-check.yml` | PR opened/updated | format + analyze + test |
| `claude-review.yml` | PR opened/updated | Claude 自動 review |
| `notify.yml` | push to `main` | Telegram bot 通知 |

### GitHub Secrets 設定

repo settings → Secrets and variables → Actions：

- `ANTHROPIC_API_KEY` — Anthropic API key（給 Claude review 用）
- `TELEGRAM_BOT_TOKEN` — Telegram Bot token（從 [@BotFather](https://t.me/BotFather) 取得）
- `TELEGRAM_CHAT_ID` — 收通知的 chat id

## 本地開發指令

```bash
flutter analyze            # 靜態檢查（CI 必過）
flutter test               # 跑單元/widget 測試
dart format .              # 格式化
flutter run                # 開啟連線中的 device
flutter pub run build_runner build --delete-conflicting-outputs
                           # Drift / 任何 codegen
```

## 專案結構

```
lib/
├── main.dart                    # entry point + ProviderScope
├── app.dart                     # MaterialApp + Router + Theme
├── core/
│   ├── env.dart                 # dart-define 入口
│   ├── theme/                   # M3 主題
│   ├── router/                  # go_router 設定
│   ├── db/                      # Drift database (Phase 1+)
│   ├── api/                     # Claude API client (Phase 5)
│   ├── ocr/                     # ML Kit 包裝 (Phase 3)
│   └── notifications/           # 本地通知 (Phase 4)
├── features/
│   ├── inventory/               # 食材列表 / 詳情 / 編輯
│   ├── shopping/                # 買菜紀錄
│   ├── scan/                    # OCR
│   └── recipes/                 # AI 食譜
└── shared/
    └── widgets/                 # 共用 UI
```
