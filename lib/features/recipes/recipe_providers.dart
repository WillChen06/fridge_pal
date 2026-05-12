import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/claude_client.dart';
import '../../core/api/recipe_prompts.dart' as prompts;
import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../inventory/inventory_providers.dart';

class RecipeSaveInput {
  const RecipeSaveInput({
    required this.title,
    required this.inventorySnapshot,
    required this.response,
    required this.usage,
  });

  final String title;
  final String inventorySnapshot;
  final String response;
  final RecipeUsage usage;
}

class RecipeRepository {
  const RecipeRepository(this._dao);

  final RecipeDao _dao;

  Stream<List<Recipe>> watchRecent([int limit = 10]) {
    return _dao.watchRecent(limit);
  }

  Future<Recipe?> getById(int id) => _dao.getById(id);

  Future<int> save(RecipeSaveInput input) {
    return _dao.insert(
      RecipesCompanion.insert(
        createdAt: DateTime.now(),
        title: input.title,
        inventorySnapshot: input.inventorySnapshot,
        response: input.response,
        inputTokens: Value(input.usage.inputTokens),
        outputTokens: Value(input.usage.outputTokens),
        cacheReadTokens: Value(input.usage.cacheReadTokens),
      ),
    );
  }

  Future<int> deleteById(int id) => _dao.deleteById(id);
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(recipeDaoProvider));
});

final recentRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchRecent(10);
});

final recipeByIdProvider = FutureProvider.family<Recipe?, int>((ref, id) {
  return ref.watch(recipeRepositoryProvider).getById(id);
});

final recipeIngredientSnapshotProvider =
    FutureProvider<List<prompts.IngredientInput>>((ref) async {
      final ingredients = await ref
          .watch(ingredientRepositoryProvider)
          .getAll();
      return prompts.RecipePromptBuilder.filterAndSort(
        ingredients
            .map(
              (ingredient) => prompts.IngredientInput(
                name: ingredient.name,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                expiryDate: ingredient.expiryDate,
              ),
            )
            .toList(),
      );
    });

String encodeInventorySnapshot(List<prompts.IngredientInput> ingredients) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(prompts.RecipePromptBuilder.buildInventorySnapshot(ingredients));
}

String extractRecipeTitle(String response) {
  final firstHeading = response
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.startsWith('## '), orElse: () => '');
  final title = firstHeading
      .replaceFirst(RegExp(r'^##\s*第[一二三123]道[:：]\s*'), '')
      .trim();
  if (title.isNotEmpty) {
    return title;
  }
  final firstLine = response
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  return firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
}
