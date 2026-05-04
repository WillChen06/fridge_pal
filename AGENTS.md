# AGENTS.md — Fridge Pal 開發守則

> 這份檔案是給 AI coding agent（Codex / Claude Code）看的。人類請看 [README.md](README.md)。完整 roadmap 在 [docs/plan.md](docs/plan.md)。

## 1. 你正在做什麼

Fridge Pal 是一個 Flutter App（iOS + Android），功能：食材庫存、買菜紀錄、OCR 標籤建檔、Claude AI 食譜推薦。資料純本地（Drift / SQLite）。

**當前 phase**：見 [docs/plan.md](docs/plan.md) 的 Roadmap 章節。每次接到 task 先確認自己在哪個 phase。

## 2. 開工前必跑

```bash
flutter pub get
flutter analyze       # 必須 zero issues
flutter test          # 必須 all pass
```

任何一個不過 → 先排除環境問題，不要硬上。

## 3. 開發鐵則（**違反這些 PR 會被 Claude review 退**）

### 3.1 Commit 顆粒度
- **1 commit = 1 個邏輯單元**。不要把「加 schema + 寫 UI + 改 router」放同一個 commit。
- **Conventional Commits**：`feat(<scope>): ...`、`fix(<scope>): ...`、`chore: ...`、`test(<scope>): ...`、`ci: ...`、`docs: ...`、`refactor(<scope>): ...`
- 範例：
  - ✅ `feat(inventory): add Ingredient drift table`
  - ✅ `feat(inventory): wire up ingredient list provider`
  - ✅ `feat(inventory): build inventory list screen`
  - ✅ `test(inventory): cover IngredientDao crud`
  - ❌ `feat: inventory feature`（太大顆）

### 3.2 分支
- 從 `main` 切：`git checkout -b feature/<short-desc>`
- 一個 phase 一個 feature 分支系列；中途想切割 PR 就再開新分支

### 3.3 機密
- **絕對不可** 把 `sk-ant-`、Telegram token、任何 secret 寫進任何 tracked file
- API key 只能透過 `String.fromEnvironment('ANTHROPIC_API_KEY')` 讀（[lib/core/env.dart](lib/core/env.dart)）
- 跑 App 用 `flutter run --dart-define-from-file=env.json`
- `env.json` 已在 .gitignore 內；**永遠不要把它加入 git**
- 改 .gitignore 的 secret 區段前停下來，open issue 討論

### 3.4 程式風格
- 跑 `dart format .` 後再 commit；CI 會擋未 format 的 PR
- 嚴格 lint 已開（`strict-casts` / `strict-inference` / `strict-raw-types` + `prefer_const_*` + `require_trailing_commas` + `unawaited_futures`）
- 不要為了過 lint 加 `// ignore:`，先想是否能改成符合 lint

### 3.5 State management
- 用 Riverpod，不要混 Provider / GetX / Bloc
- Provider 命名：`<noun>Provider`（如 `ingredientListProvider`）
- 不要在 build method 內呼叫 `ref.read`，請用 `ref.watch`

### 3.6 Drift schema 變更
- 改 table 結構必須補對應的 `MigrationStrategy`
- schema version bump
- 如果有疑慮，在 PR 描述寫清楚 migration 策略

### 3.7 平台權限
- 加相機 / 通知功能必須**同時**改 `ios/Runner/Info.plist` 與 `android/app/src/main/AndroidManifest.xml`，不能只改一邊

## 4. PR 流程

1. 推 `feature/*` 分支
2. 開 PR 到 `main`（描述清楚：解決什麼、怎麼測）
3. 等 CI 跑：
   - `pr-check.yml` — format + analyze + test
   - `claude-review.yml` — Claude 自動 review
4. 兩個都過、Claude review 沒重大意見就可以 merge
5. merge 後 `notify.yml` 會 ping Telegram

## 5. 檔案 / 目錄速查

| 路徑 | 用途 |
|---|---|
| [docs/plan.md](docs/plan.md) | 完整 roadmap、技術選型、每個 phase 的工作清單 |
| [lib/core/env.dart](lib/core/env.dart) | 機密讀取入口（永遠改這裡，不要散落各處） |
| `lib/core/db/` | Drift schema + DAO（Phase 1+ 建立） |
| `lib/core/api/claude_client.dart` | Claude API 包裝（Phase 5 建立） |
| `lib/core/ocr/ocr_service.dart` | ML Kit 包裝（Phase 3 建立） |
| `lib/core/notifications/` | 本地通知排程（Phase 4 建立） |
| `lib/features/<name>/` | 功能模組（screen + providers + widgets） |
| `lib/shared/widgets/` | 跨功能共用 widget |
| `.github/workflows/` | CI 三件組，**改 workflow 必須在 PR 描述特別說明** |

## 6. 不確定怎麼辦

- **架構決策疑慮** → 先讀 [docs/plan.md](docs/plan.md) 看是否已有規劃
- **找不到該動哪裡** → grep / find，**禁止憑空建立** parallel 結構
- **測試不會寫** → 看 `test/widget_test.dart` 範例
- **依賴不夠用** → 在 PR 描述說明為什麼要加，避免亂塞

## 7. 完成 task 的「definition of done」

- [ ] `flutter analyze` 零警告
- [ ] `flutter test` 全過
- [ ] `dart format .` 已跑
- [ ] commit message 符合 Conventional Commits
- [ ] 沒有 secret 漏出（用 `git diff` 自己掃過 `sk-ant` / `bot` token / `chat_id`）
- [ ] PR 描述寫了：解決什麼、怎麼測、有沒有 schema migration、有沒有改權限
