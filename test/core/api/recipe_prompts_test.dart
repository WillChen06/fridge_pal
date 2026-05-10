import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/api/recipe_prompts.dart';

void main() {
  test('buildUserMessage filters to 50 ingredients ordered by expiry date', () {
    final ingredients = <IngredientInput>[
      const IngredientInput(name: '鹽', quantity: 1, unit: '罐'),
      IngredientInput(
        name: '高麗菜',
        quantity: 0.5,
        unit: '顆',
        expiryDate: DateTime(2026, 5, 12),
      ),
      IngredientInput(
        name: '雞蛋',
        quantity: 6,
        unit: '顆',
        expiryDate: DateTime(2026, 5, 10),
      ),
      for (var i = 0; i < 60; i += 1)
        IngredientInput(
          name: '食材$i',
          quantity: i.toDouble(),
          unit: '份',
          expiryDate: DateTime(2026, 6, 1).add(Duration(days: i)),
        ),
    ];

    final message = RecipePromptBuilder.buildUserMessage(ingredients);
    final jsonText = RegExp(
      r'```json\n([\s\S]+?)\n```',
    ).firstMatch(message)!.group(1)!;
    final decoded = jsonDecode(jsonText) as List<dynamic>;
    final first = decoded.first as Map<String, dynamic>;
    final second = decoded[1] as Map<String, dynamic>;

    expect(decoded, hasLength(50));
    expect(first, <String, dynamic>{
      'name': '雞蛋',
      'quantity': 6.0,
      'unit': '顆',
      'expiryDate': '2026-05-10',
    });
    expect(second['name'], '高麗菜');
    expect(message, contains('請推薦 1–3 道我可以做的菜。'));
    expect(message, isNot(contains('id')));
    expect(message, isNot(contains('location')));
  });
}
