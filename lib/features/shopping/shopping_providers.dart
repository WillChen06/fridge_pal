import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

class ShoppingItemInput {
  const ShoppingItemInput({
    required this.name,
    required this.quantity,
    required this.unit,
    this.cost,
  });

  final String name;
  final double quantity;
  final String unit;
  final double? cost;
}

class ShoppingRecordInput {
  const ShoppingRecordInput({
    required this.date,
    required this.items,
    this.note,
  });

  final DateTime date;
  final String? note;
  final List<ShoppingItemInput> items;
}

class ShoppingRepository {
  const ShoppingRepository(this._database);

  final AppDatabase _database;

  Stream<List<ShoppingRecordWithItems>> watchAll() {
    return _database.shoppingRecordDao.watchAllWithItems();
  }

  Stream<ShoppingRecordWithItems?> watchById(int id) {
    return _database.shoppingRecordDao.watchByIdWithItems(id);
  }

  Future<int> createRecord(ShoppingRecordInput input) {
    if (input.items.isEmpty) {
      throw ArgumentError.value(input.items, 'items', 'must not be empty');
    }

    return _database.transaction(() async {
      final cleanedItems = input.items
          .map(_CleanShoppingItemInput.from)
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
      if (cleanedItems.isEmpty) {
        throw ArgumentError.value(input.items, 'items', 'must not be empty');
      }

      final recordId = await _database.shoppingRecordDao.insertRecord(
        ShoppingRecordsCompanion.insert(
          date: input.date,
          note: Value(_cleanOptional(input.note)),
          totalCost: Value(_totalCostFor(cleanedItems)),
        ),
      );

      final existingIngredients = await _database.ingredientDao.getAll();
      final ingredientsByName = {
        for (final ingredient in existingIngredients)
          _normalizeName(ingredient.name): ingredient,
      };

      final companions = <ShoppingItemsCompanion>[];
      for (final item in cleanedItems) {
        final normalizedName = _normalizeName(item.name);
        final existingIngredient = ingredientsByName[normalizedName];
        final syncedIngredient = existingIngredient == null
            ? await _createIngredientFor(item)
            : await _incrementIngredient(existingIngredient, item.quantity);
        ingredientsByName[normalizedName] = syncedIngredient;

        companions.add(
          ShoppingItemsCompanion.insert(
            recordId: recordId,
            ingredientId: Value(syncedIngredient.id),
            nameSnapshot: item.name,
            quantity: item.quantity,
            unit: item.unit,
            cost: Value(item.cost),
          ),
        );
      }

      await _database.shoppingItemDao.insertItems(companions);
      return recordId;
    });
  }

  Future<int> delete(int id) => _database.shoppingRecordDao.deleteRecord(id);

  Future<Ingredient> _createIngredientFor(_CleanShoppingItemInput item) async {
    final now = DateTime.now();
    final id = await _database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: item.name,
        category: const Value('未分類'),
        quantity: item.quantity,
        unit: item.unit,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Ingredient(
      id: id,
      name: item.name,
      category: '未分類',
      quantity: item.quantity,
      unit: item.unit,
      expiryDate: null,
      lowStockThreshold: null,
      location: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Ingredient> _incrementIngredient(
    Ingredient ingredient,
    double quantity,
  ) async {
    final updated = ingredient.copyWith(
      quantity: ingredient.quantity + quantity,
      updatedAt: DateTime.now(),
    );
    await _database.ingredientDao.updateIngredient(
      IngredientsCompanion(
        id: Value(updated.id),
        name: Value(updated.name),
        category: Value(updated.category),
        quantity: Value(updated.quantity),
        unit: Value(updated.unit),
        expiryDate: Value(updated.expiryDate),
        lowStockThreshold: Value(updated.lowStockThreshold),
        location: Value(updated.location),
        createdAt: Value(updated.createdAt),
        updatedAt: Value(updated.updatedAt),
      ),
    );
    return updated;
  }

  static double? _totalCostFor(List<_CleanShoppingItemInput> items) {
    var hasCost = false;
    var total = 0.0;
    for (final item in items) {
      final cost = item.cost;
      if (cost != null) {
        hasCost = true;
        total += cost;
      }
    }
    return hasCost ? total : null;
  }

  static String _normalizeName(String value) => value.trim().toLowerCase();

  static String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _CleanShoppingItemInput {
  const _CleanShoppingItemInput({
    required this.name,
    required this.quantity,
    required this.unit,
    this.cost,
  });

  factory _CleanShoppingItemInput.from(ShoppingItemInput input) {
    return _CleanShoppingItemInput(
      name: input.name.trim(),
      quantity: input.quantity,
      unit: input.unit.trim(),
      cost: input.cost,
    );
  }

  final String name;
  final double quantity;
  final String unit;
  final double? cost;
}

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(ref.watch(appDatabaseProvider));
});

final shoppingRecordListProvider =
    StreamProvider<List<ShoppingRecordWithItems>>((ref) {
      return ref.watch(shoppingRepositoryProvider).watchAll();
    });

final shoppingRecordByIdProvider =
    StreamProvider.family<ShoppingRecordWithItems?, int>((ref, id) {
      return ref.watch(shoppingRepositoryProvider).watchById(id);
    });
