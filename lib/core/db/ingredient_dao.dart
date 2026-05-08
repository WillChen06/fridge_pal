part of 'database.dart';

@DriftAccessor(tables: [Ingredients])
class IngredientDao extends DatabaseAccessor<AppDatabase>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Stream<List<Ingredient>> watchAll() {
    final query = select(ingredients)
      ..orderBy([
        (table) => OrderingTerm.asc(table.category),
        (table) => OrderingTerm.asc(table.name),
      ]);
    return query.watch();
  }

  Stream<Ingredient?> watchById(int id) {
    final query = select(ingredients)..where((table) => table.id.equals(id));
    return query.watchSingleOrNull();
  }

  Future<Ingredient?> getById(int id) {
    final query = select(ingredients)..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<List<Ingredient>> getAll() {
    final query = select(ingredients)
      ..orderBy([
        (table) => OrderingTerm.asc(table.category),
        (table) => OrderingTerm.asc(table.name),
      ]);
    return query.get();
  }

  Future<int> insertIngredient(IngredientsCompanion companion) {
    return into(ingredients).insert(companion);
  }

  Future<bool> updateIngredient(IngredientsCompanion companion) {
    return update(ingredients).replace(companion);
  }

  Future<int> deleteIngredient(int id) {
    return (delete(ingredients)..where((table) => table.id.equals(id))).go();
  }
}
