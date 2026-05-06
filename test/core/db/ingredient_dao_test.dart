import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/db/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('inserts and reads ingredients ordered by category then name', () async {
    final now = DateTime(2026, 5, 4);

    await database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '牛奶',
        category: const Value('乳製品'),
        quantity: 1,
        unit: '瓶',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '白菜',
        category: const Value('蔬菜'),
        quantity: 2,
        unit: '顆',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final ingredients = await database.ingredientDao.watchAll().first;

    expect(ingredients.map((ingredient) => ingredient.name), ['牛奶', '白菜']);
    expect(ingredients.first.category, '乳製品');
  });

  test('updates an existing ingredient', () async {
    final createdAt = DateTime(2026, 5, 4);
    final updatedAt = DateTime(2026, 5, 5);
    final id = await database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '雞蛋',
        category: const Value('蛋類'),
        quantity: 6,
        unit: '顆',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    final updated = await database.ingredientDao.updateIngredient(
      IngredientsCompanion(
        id: Value(id),
        name: const Value('雞蛋'),
        category: const Value('蛋類'),
        quantity: const Value(4),
        unit: const Value('顆'),
        lowStockThreshold: const Value(3),
        location: const Value('冷藏'),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ),
    );

    final ingredient = await database.ingredientDao.getById(id);

    expect(updated, isTrue);
    expect(ingredient?.quantity, 4);
    expect(ingredient?.lowStockThreshold, 3);
    expect(ingredient?.location, '冷藏');
    expect(ingredient?.updatedAt, updatedAt);
  });

  test('deletes an ingredient', () async {
    final now = DateTime(2026, 5, 4);
    final id = await database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '豆腐',
        category: const Value('豆製品'),
        quantity: 1,
        unit: '盒',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final deleted = await database.ingredientDao.deleteIngredient(id);
    final ingredient = await database.ingredientDao.getById(id);

    expect(deleted, 1);
    expect(ingredient, isNull);
  });
}
