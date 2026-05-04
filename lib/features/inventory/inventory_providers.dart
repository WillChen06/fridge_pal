import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

class IngredientInput {
  const IngredientInput({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.lowStockThreshold,
    this.location,
  });

  final String name;
  final String category;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final double? lowStockThreshold;
  final String? location;
}

class IngredientRepository {
  const IngredientRepository(this._dao);

  final IngredientDao _dao;

  Stream<List<Ingredient>> watchAll() => _dao.watchAll();

  Stream<Ingredient?> watchById(int id) => _dao.watchById(id);

  Future<int> create(IngredientInput input) {
    final now = DateTime.now();
    return _dao.insertIngredient(
      IngredientsCompanion.insert(
        name: input.name.trim(),
        category: Value(_cleanRequired(input.category, fallback: '未分類')),
        quantity: input.quantity,
        unit: input.unit.trim(),
        expiryDate: Value(input.expiryDate),
        lowStockThreshold: Value(input.lowStockThreshold),
        location: Value(_cleanOptional(input.location)),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<bool> updateExisting(Ingredient ingredient, IngredientInput input) {
    return _dao.updateIngredient(
      IngredientsCompanion(
        id: Value(ingredient.id),
        name: Value(input.name.trim()),
        category: Value(_cleanRequired(input.category, fallback: '未分類')),
        quantity: Value(input.quantity),
        unit: Value(input.unit.trim()),
        expiryDate: Value(input.expiryDate),
        lowStockThreshold: Value(input.lowStockThreshold),
        location: Value(_cleanOptional(input.location)),
        createdAt: Value(ingredient.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> delete(int id) => _dao.deleteIngredient(id);

  static String _cleanRequired(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  static String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  return IngredientRepository(ref.watch(ingredientDaoProvider));
});

final ingredientListProvider = StreamProvider<List<Ingredient>>((ref) {
  return ref.watch(ingredientRepositoryProvider).watchAll();
});

final ingredientByIdProvider = StreamProvider.family<Ingredient?, int>((
  ref,
  id,
) {
  return ref.watch(ingredientRepositoryProvider).watchById(id);
});
