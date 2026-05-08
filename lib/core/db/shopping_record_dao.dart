part of 'database.dart';

class ShoppingRecordWithItems {
  const ShoppingRecordWithItems({required this.record, required this.items});

  final ShoppingRecord record;
  final List<ShoppingItem> items;

  int get itemCount => items.length;
}

@DriftAccessor(tables: [ShoppingRecords, ShoppingItems])
class ShoppingRecordDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingRecordDaoMixin {
  ShoppingRecordDao(super.db);

  Stream<List<ShoppingRecordWithItems>> watchAllWithItems() {
    final query =
        select(shoppingRecords).join([
          leftOuterJoin(
            shoppingItems,
            shoppingItems.recordId.equalsExp(shoppingRecords.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(shoppingRecords.date),
          OrderingTerm.desc(shoppingRecords.id),
        ]);

    return query.watch().map(_groupJoinedRows);
  }

  Future<List<ShoppingRecordWithItems>> getAllWithItems() async {
    final query =
        select(shoppingRecords).join([
          leftOuterJoin(
            shoppingItems,
            shoppingItems.recordId.equalsExp(shoppingRecords.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(shoppingRecords.date),
          OrderingTerm.desc(shoppingRecords.id),
        ]);

    final rows = await query.get();
    return _groupJoinedRows(rows);
  }

  Stream<ShoppingRecordWithItems?> watchByIdWithItems(int id) {
    final query =
        select(shoppingRecords).join([
            leftOuterJoin(
              shoppingItems,
              shoppingItems.recordId.equalsExp(shoppingRecords.id),
            ),
          ])
          ..where(shoppingRecords.id.equals(id))
          ..orderBy([OrderingTerm.asc(shoppingItems.id)]);

    return query.watch().map((rows) {
      final grouped = _groupJoinedRows(rows);
      if (grouped.isEmpty) {
        return null;
      }
      return grouped.single;
    });
  }

  Future<ShoppingRecordWithItems?> getByIdWithItems(int id) async {
    final record = await getRecordById(id);
    if (record == null) {
      return null;
    }
    final items = await db.shoppingItemDao.getByRecordId(id);
    return ShoppingRecordWithItems(record: record, items: items);
  }

  Future<ShoppingRecord?> getRecordById(int id) {
    final query = select(shoppingRecords)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> insertRecord(ShoppingRecordsCompanion companion) {
    return into(shoppingRecords).insert(companion);
  }

  Future<bool> updateRecord(ShoppingRecordsCompanion companion) {
    return update(shoppingRecords).replace(companion);
  }

  Future<int> deleteRecord(int id) {
    return (delete(
      shoppingRecords,
    )..where((table) => table.id.equals(id))).go();
  }

  List<ShoppingRecordWithItems> _groupJoinedRows(List<TypedResult> rows) {
    final grouped = <int, ShoppingRecordWithItems>{};
    for (final row in rows) {
      final record = row.readTable(shoppingRecords);
      final item = row.readTableOrNull(shoppingItems);
      final existing = grouped.putIfAbsent(
        record.id,
        () => ShoppingRecordWithItems(record: record, items: <ShoppingItem>[]),
      );
      if (item != null) {
        existing.items.add(item);
      }
    }
    return grouped.values.toList(growable: false);
  }
}
