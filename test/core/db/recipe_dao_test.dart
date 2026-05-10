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

  test('recipe dao inserts watches recent gets and deletes recipes', () async {
    final olderId = await database.recipeDao.insert(
      RecipesCompanion.insert(
        createdAt: DateTime(2026, 5, 4),
        title: '番茄炒蛋',
        inventorySnapshot: '[]',
        response: '## 第一道：番茄炒蛋',
        inputTokens: const Value(100),
        outputTokens: const Value(200),
        cacheReadTokens: const Value(0),
      ),
    );
    final newerId = await database.recipeDao.insert(
      RecipesCompanion.insert(
        createdAt: DateTime(2026, 5, 5),
        title: '高麗菜煎蛋',
        inventorySnapshot: '[]',
        response: '## 第一道：高麗菜煎蛋',
        inputTokens: const Value(80),
        outputTokens: const Value(160),
        cacheReadTokens: const Value(40),
      ),
    );

    final recent = await database.recipeDao.watchRecent(1).first;
    final newer = await database.recipeDao.getById(newerId);
    final deleted = await database.recipeDao.deleteById(olderId);
    final older = await database.recipeDao.getById(olderId);

    expect(recent.map((recipe) => recipe.id), [newerId]);
    expect(newer?.title, '高麗菜煎蛋');
    expect(newer?.cacheReadTokens, 40);
    expect(deleted, 1);
    expect(older, isNull);
  });

  test('v2 data survives v3 recipe migration', () async {
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
          db.execute('''
            CREATE TABLE shopping_records (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              date INTEGER NOT NULL,
              note TEXT NULL,
              total_cost REAL NULL
            );
          ''');
          db.execute('''
            CREATE TABLE shopping_items (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              record_id INTEGER NOT NULL REFERENCES shopping_records(id)
                ON DELETE CASCADE,
              ingredient_id INTEGER NULL REFERENCES ingredients(id)
                ON DELETE SET NULL,
              name_snapshot TEXT NOT NULL
                CHECK (length(name_snapshot) BETWEEN 1 AND 80),
              quantity REAL NOT NULL,
              unit TEXT NOT NULL CHECK (length(unit) BETWEEN 1 AND 24),
              cost REAL NULL
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
          db.execute('PRAGMA user_version = 2;');
        },
      ),
    );

    final ingredients = await database.ingredientDao.getAll();
    final recipeId = await database.recipeDao.insert(
      RecipesCompanion.insert(
        createdAt: DateTime(2026, 5, 6),
        title: '牛奶燉蛋',
        inventorySnapshot: '[]',
        response: '## 第一道：牛奶燉蛋',
      ),
    );

    expect(ingredients.single.name, '牛奶');
    expect(recipeId, 1);
  });
}
