import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final ingredientDaoProvider = Provider<IngredientDao>((ref) {
  return ref.watch(appDatabaseProvider).ingredientDao;
});
