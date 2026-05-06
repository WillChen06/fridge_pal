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

  test('shopping record dao inserts and reads records with items', () async {
    final olderDate = DateTime(2026, 5, 4);
    final newerDate = DateTime(2026, 5, 5);
    final olderId = await database.shoppingRecordDao.insertRecord(
      ShoppingRecordsCompanion.insert(date: olderDate),
    );
    final newerId = await database.shoppingRecordDao.insertRecord(
      ShoppingRecordsCompanion.insert(
        date: newerDate,
        note: const Value('補牛奶'),
        totalCost: const Value(120),
      ),
    );

    await database.shoppingItemDao.insertItem(
      ShoppingItemsCompanion.insert(
        recordId: olderId,
        nameSnapshot: '白菜',
        quantity: 1,
        unit: '顆',
      ),
    );
    await database.shoppingItemDao.insertItem(
      ShoppingItemsCompanion.insert(
        recordId: newerId,
        nameSnapshot: '牛奶',
        quantity: 2,
        unit: '瓶',
        cost: const Value(120),
      ),
    );

    final records = await database.shoppingRecordDao.watchAllWithItems().first;
    final newerRecord = await database.shoppingRecordDao.getByIdWithItems(
      newerId,
    );

    expect(records.map((entry) => entry.record.id), [newerId, olderId]);
    expect(records.first.itemCount, 1);
    expect(newerRecord?.record.note, '補牛奶');
    expect(newerRecord?.items.single.nameSnapshot, '牛奶');
  });

  test('shopping record and item daos update and delete rows', () async {
    final recordId = await database.shoppingRecordDao.insertRecord(
      ShoppingRecordsCompanion.insert(date: DateTime(2026, 5, 4)),
    );
    final itemId = await database.shoppingItemDao.insertItem(
      ShoppingItemsCompanion.insert(
        recordId: recordId,
        nameSnapshot: '雞蛋',
        quantity: 6,
        unit: '顆',
      ),
    );

    final itemUpdated = await database.shoppingItemDao.updateItem(
      ShoppingItemsCompanion(
        id: Value(itemId),
        recordId: Value(recordId),
        nameSnapshot: const Value('雞蛋'),
        quantity: const Value(10),
        unit: const Value('顆'),
        cost: const Value(80),
      ),
    );
    final recordUpdated = await database.shoppingRecordDao.updateRecord(
      ShoppingRecordsCompanion(
        id: Value(recordId),
        date: Value(DateTime(2026, 5, 5)),
        note: const Value('更新'),
        totalCost: const Value(80),
      ),
    );

    final items = await database.shoppingItemDao.getByRecordId(recordId);
    final deleted = await database.shoppingRecordDao.deleteRecord(recordId);
    final deletedItems = await database.shoppingItemDao.getByRecordId(recordId);

    expect(itemUpdated, isTrue);
    expect(recordUpdated, isTrue);
    expect(items.single.quantity, 10);
    expect(items.single.cost, 80);
    expect(deleted, 1);
    expect(deletedItems, isEmpty);
  });

  test('v1 ingredients survive v2 migration', () async {
    await database.close();
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (db) {
          db.execute('''
            CREATE TABLE ingredients (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
              category TEXT NOT NULL DEFAULT '未分類'
                CHECK (length(category) BETWEEN 1 AND 48),
              quantity REAL NOT NULL,
              unit TEXT NOT NULL CHECK (length(unit) BETWEEN 1 AND 24),
              expiry_date INTEGER NULL,
              low_stock_threshold REAL NULL,
              location TEXT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          db.execute(
            '''
            INSERT INTO ingredients (
              name, category, quantity, unit, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?);
            ''',
            ['牛奶', '乳製品', 1.0, '瓶', 0, 0],
          );
          db.execute('PRAGMA user_version = 1;');
        },
      ),
    );

    final ingredients = await database.ingredientDao.getAll();
    final recordId = await database.shoppingRecordDao.insertRecord(
      ShoppingRecordsCompanion.insert(date: DateTime(2026, 5, 6)),
    );

    expect(ingredients.single.name, '牛奶');
    expect(recordId, 1);
  });
}
