part of 'database.dart';

@DriftAccessor(tables: [ShoppingItems])
class ShoppingItemDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingItemDaoMixin {
  ShoppingItemDao(super.db);

  Stream<List<ShoppingItem>> watchByRecordId(int recordId) {
    final query = select(shoppingItems)
      ..where((table) => table.recordId.equals(recordId))
      ..orderBy([(table) => OrderingTerm.asc(table.id)]);
    return query.watch();
  }

  Future<List<ShoppingItem>> getByRecordId(int recordId) {
    final query = select(shoppingItems)
      ..where((table) => table.recordId.equals(recordId))
      ..orderBy([(table) => OrderingTerm.asc(table.id)]);
    return query.get();
  }

  Future<int> insertItem(ShoppingItemsCompanion companion) {
    return into(shoppingItems).insert(companion);
  }

  Future<void> insertItems(List<ShoppingItemsCompanion> companions) async {
    await batch((batch) {
      batch.insertAll(shoppingItems, companions);
    });
  }

  Future<bool> updateItem(ShoppingItemsCompanion companion) {
    return update(shoppingItems).replace(companion);
  }

  Future<int> deleteItem(int id) {
    return (delete(shoppingItems)..where((table) => table.id.equals(id))).go();
  }

  Future<int> deleteByRecordId(int recordId) {
    return (delete(
      shoppingItems,
    )..where((table) => table.recordId.equals(recordId))).go();
  }
}
