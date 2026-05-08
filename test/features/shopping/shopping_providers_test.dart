import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/features/shopping/shopping_providers.dart';

void main() {
  late AppDatabase database;
  late ShoppingRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ShoppingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createRecord matches existing ingredients case-insensitively',
    () async {
      final now = DateTime(2026, 5, 6);
      final ingredientId = await database.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: 'Milk',
          category: const Value('乳製品'),
          quantity: 1,
          unit: '瓶',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final recordId = await repository.createRecord(
        ShoppingRecordInput(
          date: now,
          items: const [
            ShoppingItemInput(
              name: ' milk ',
              quantity: 2,
              unit: '瓶',
              cost: 120,
            ),
          ],
        ),
      );

      final ingredient = await database.ingredientDao.getById(ingredientId);
      final record = await database.shoppingRecordDao.getByIdWithItems(
        recordId,
      );

      expect(ingredient?.quantity, 3);
      expect(record?.record.totalCost, 120);
      expect(record?.items.single.ingredientId, ingredientId);
      expect(record?.items.single.nameSnapshot, 'milk');
    },
  );

  test('createRecord creates unmatched ingredients as uncategorized', () async {
    final recordId = await repository.createRecord(
      ShoppingRecordInput(
        date: DateTime(2026, 5, 6),
        note: '新的食材',
        items: const [ShoppingItemInput(name: '豆腐', quantity: 1, unit: '盒')],
      ),
    );

    final ingredients = await database.ingredientDao.getAll();
    final record = await database.shoppingRecordDao.getByIdWithItems(recordId);

    expect(ingredients.single.name, '豆腐');
    expect(ingredients.single.category, '未分類');
    expect(ingredients.single.quantity, 1);
    expect(record?.items.single.ingredientId, ingredients.single.id);
  });
}
