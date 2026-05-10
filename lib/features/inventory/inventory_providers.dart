import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/notifications/inventory_notification_actions.dart';

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
  const IngredientRepository(this._dao, {this.notifications});

  final IngredientDao _dao;
  final InventoryNotificationActions? notifications;

  Stream<List<Ingredient>> watchAll() => _dao.watchAll();

  Stream<Ingredient?> watchById(int id) => _dao.watchById(id);

  Future<List<Ingredient>> getAll() => _dao.getAll();

  Future<int> create(IngredientInput input) async {
    final now = DateTime.now();
    final name = input.name.trim();
    final category = _cleanRequired(input.category, fallback: '未分類');
    final unit = input.unit.trim();
    final location = _cleanOptional(input.location);
    final id = await _dao.insertIngredient(
      IngredientsCompanion.insert(
        name: name,
        category: Value(category),
        quantity: input.quantity,
        unit: unit,
        expiryDate: Value(input.expiryDate),
        lowStockThreshold: Value(input.lowStockThreshold),
        location: Value(location),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final ingredient = Ingredient(
      id: id,
      name: name,
      category: category,
      quantity: input.quantity,
      unit: unit,
      expiryDate: input.expiryDate,
      lowStockThreshold: input.lowStockThreshold,
      location: location,
      createdAt: now,
      updatedAt: now,
    );
    await notifications?.scheduleCreated(ingredient);
    await notifications?.notifyLowStockIfNeeded(ingredient);
    return id;
  }

  Future<bool> updateExisting(
    Ingredient ingredient,
    IngredientInput input,
  ) async {
    final updated = ingredient.copyWith(
      name: input.name.trim(),
      category: _cleanRequired(input.category, fallback: '未分類'),
      quantity: input.quantity,
      unit: input.unit.trim(),
      expiryDate: Value(input.expiryDate),
      lowStockThreshold: Value(input.lowStockThreshold),
      location: Value(_cleanOptional(input.location)),
      updatedAt: DateTime.now(),
    );
    final didUpdate = await _dao.updateIngredient(
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
    if (didUpdate) {
      await notifications?.scheduleUpdated(updated);
      await notifications?.notifyLowStockIfNeeded(updated);
    }
    return didUpdate;
  }

  Future<int> delete(int id) async {
    final deleted = await _dao.deleteIngredient(id);
    if (deleted > 0) {
      await notifications?.cancelDeleted(id);
    }
    return deleted;
  }

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
  return IngredientRepository(
    ref.watch(ingredientDaoProvider),
    notifications: ref.watch(inventoryNotificationActionsProvider),
  );
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
