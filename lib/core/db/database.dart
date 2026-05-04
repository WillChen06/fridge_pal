import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';
part 'ingredient_dao.dart';

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

@DriftDatabase(tables: [Ingredients], daos: [IngredientDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fridge_pal'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (migrator) => migrator.createAll());
}
