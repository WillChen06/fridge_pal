import 'dart:convert';

const kRecipeSystemPrompt = '''
你是一個熟悉台灣家常菜的 AI 廚房助手。使用者會給你冰箱現有食材清單（JSON），請推薦 1–3 道他可以做的菜。

輸出格式（繁體中文 + Markdown）：

## 第一道：<菜名>

**用到的庫存食材**：<列出 1–N 樣，逗號分隔>
**額外可能需要**：<常見備料，可選；若無寫「無」>
**預計時間**：<X 分鐘>

### 做法
1. ...
2. ...

---

（依需要繼續第二道、第三道）

規則：
- 優先用使用者提供的食材，不要硬塞冰箱沒有的
- 即將過期的食材（expiryDate 近的）優先用
- 食譜要實際可行，避免複雜技巧
- 簡短、不要過度解釋
- 只輸出菜譜本身，不要前言或結尾客套話
''';

class IngredientInput {
  const IngredientInput({
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
  });

  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': expiryDate == null ? null : _formatDate(expiryDate!),
    };
  }
}

class RecipePromptBuilder {
  const RecipePromptBuilder._();

  static List<IngredientInput> filterAndSort(
    List<IngredientInput> ingredients,
  ) {
    final sorted = [...ingredients]
      ..sort((a, b) {
        final aExpiry = a.expiryDate;
        final bExpiry = b.expiryDate;
        if (aExpiry == null && bExpiry == null) {
          return 0;
        }
        if (aExpiry == null) {
          return 1;
        }
        if (bExpiry == null) {
          return -1;
        }
        return aExpiry.compareTo(bExpiry);
      });
    return sorted.take(50).toList(growable: false);
  }

  static String buildUserMessage(List<IngredientInput> ingredients) {
    final filtered = filterAndSort(ingredients);
    const encoder = JsonEncoder.withIndent('  ');
    final inventoryJson = encoder.convert(
      filtered.map((ingredient) => ingredient.toJson()).toList(),
    );
    return '''
冰箱現有食材（按到期日近 → 遠 / 無期限）：

```json
$inventoryJson
```

請推薦 1–3 道我可以做的菜。
''';
  }

  static List<Map<String, Object?>> buildInventorySnapshot(
    List<IngredientInput> ingredients,
  ) {
    return filterAndSort(
      ingredients,
    ).map((ingredient) => ingredient.toJson()).toList(growable: false);
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
