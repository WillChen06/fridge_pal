import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/app.dart';
import 'package:fridge_pal/core/api/claude_client.dart';
import 'package:fridge_pal/core/api/recipe_prompts.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/db/database_provider.dart';
import 'package:fridge_pal/features/recipes/recipe_generation_screen.dart';

void main() {
  testWidgets('recipes tab lists saved recipe history', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.recipeDao.insert(
      RecipesCompanion.insert(
        createdAt: DateTime.now(),
        title: '番茄炒蛋',
        inventorySnapshot: '[]',
        response: '## 第一道：番茄炒蛋',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          claudeClientProvider.overrideWithValue(_FakeClaudeClient()),
        ],
        child: const FridgePalApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('食譜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('番茄炒蛋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('generation screen renders stream updates', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claudeClientProvider.overrideWithValue(
            _FakeClaudeClient(stream: _scriptedRecipeStream()),
          ),
        ],
        child: const MaterialApp(
          home: RecipeGenerationScreen(
            ingredients: [IngredientInput(name: '雞蛋', quantity: 6, unit: '顆')],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('番茄炒蛋'), findsOneWidget);

    await tester.pump();

    expect(find.text('儲存到歷史'), findsOneWidget);
    expect(find.textContaining('cache read 40'), findsOneWidget);
  });
}

Stream<RecipeStreamEvent> _scriptedRecipeStream() async* {
  await Future<void>.delayed(Duration.zero);
  yield const RecipeDelta('## 第一道：番茄炒蛋\n\n');
  await Future<void>.delayed(Duration.zero);
  yield const RecipeDone(
    RecipeUsage(inputTokens: 100, outputTokens: 60, cacheReadTokens: 40),
  );
}

class _FakeClaudeClient extends ClaudeClient {
  _FakeClaudeClient({Stream<RecipeStreamEvent>? stream})
    : _stream = stream ?? const Stream<RecipeStreamEvent>.empty(),
      super(apiKey: 'test-key', model: 'claude-sonnet-4-6');

  final Stream<RecipeStreamEvent> _stream;

  @override
  Stream<RecipeStreamEvent> streamRecipes({
    required List<IngredientInput> ingredients,
  }) {
    return _stream;
  }
}
