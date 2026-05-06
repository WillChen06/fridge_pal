import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:fridge_pal/app.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/db/database_provider.dart';

void main() {
  testWidgets('shopping tab lists existing records', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final recordId = await database.shoppingRecordDao.insertRecord(
      ShoppingRecordsCompanion.insert(
        date: DateTime(2026, 5, 6),
        totalCost: const Value(120),
      ),
    );
    await database.shoppingItemDao.insertItem(
      ShoppingItemsCompanion.insert(
        recordId: recordId,
        nameSnapshot: '牛奶',
        quantity: 2,
        unit: '瓶',
        cost: const Value(120),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('買菜'));
    await tester.pumpAndSettle();

    expect(find.text('2026-05-06'), findsOneWidget);
    expect(find.text('1 項品項'), findsOneWidget);
    expect(find.text(r'$120.00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('add shopping record flow syncs inventory quantity', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 5, 6);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('買菜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增紀錄'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('shopping-item-name-0')),
      ' 牛奶 ',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('shopping-item-quantity-0')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shopping-item-cost-0')),
      '80',
    );
    await tester.tap(find.text('儲存紀錄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final ingredients = await database.ingredientDao.getAll();
    final records = await database.shoppingRecordDao.getAllWithItems();

    expect(ingredients.single.quantity, 3);
    expect(records.single.items.single.ingredientId, ingredients.single.id);
    expect(find.text('1 項品項'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('add item button pages to the newest shopping item card', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('買菜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加品項'));
    await tester.pumpAndSettle();

    final newestNameField = find.byKey(const ValueKey('shopping-item-name-2'));
    final newestFieldRect = tester.getRect(newestNameField);
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(newestFieldRect.left, lessThan(80));
    expect(newestFieldRect.left, lessThan(screenWidth));
    expect(newestFieldRect.right, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
