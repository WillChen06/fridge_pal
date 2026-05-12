part of 'database.dart';

@DriftAccessor(tables: [Recipes])
class RecipeDao extends DatabaseAccessor<AppDatabase> with _$RecipeDaoMixin {
  RecipeDao(super.db);

  Future<int> insert(RecipesCompanion companion) {
    return into(recipes).insert(companion);
  }

  Stream<List<Recipe>> watchRecent(int limit) {
    final query = select(recipes)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);
    return query.watch();
  }

  Future<Recipe?> getById(int id) {
    final query = select(recipes)..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> deleteById(int id) {
    return (delete(recipes)..where((table) => table.id.equals(id))).go();
  }
}
