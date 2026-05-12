import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';
part 'ingredient_dao.dart';
part 'recipe_dao.dart';
part 'shopping_item_dao.dart';
part 'shopping_record_dao.dart';

class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get category =>
      text().withLength(min: 1, max: 48).withDefault(const Constant('未分類'))();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withLength(min: 1, max: 24)();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get lowStockThreshold => real().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class ShoppingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  RealColumn get totalCost => real().nullable()();
}

class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recordId =>
      integer().references(ShoppingRecords, #id, onDelete: KeyAction.cascade)();
  IntColumn get ingredientId => integer().nullable().references(
    Ingredients,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get nameSnapshot => text().withLength(min: 1, max: 80)();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withLength(min: 1, max: 24)();
  RealColumn get cost => real().nullable()();
}

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get title => text()();
  TextColumn get inventorySnapshot => text()();
  TextColumn get response => text()();
  IntColumn get inputTokens => integer().nullable()();
  IntColumn get outputTokens => integer().nullable()();
  IntColumn get cacheReadTokens => integer().nullable()();
}

@DriftDatabase(
  tables: [Ingredients, ShoppingRecords, ShoppingItems, Recipes],
  daos: [IngredientDao, ShoppingRecordDao, ShoppingItemDao, RecipeDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fridge_pal'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(shoppingRecords);
        await migrator.createTable(shoppingItems);
      }
      if (from < 3) {
        await migrator.createTable(recipes);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
