import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/db/database_provider.dart';
import 'package:fridge_pal/features/inventory/inventory_providers.dart';

void main() {
  test('ingredient providers expose created inventory items', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final repository = container.read(ingredientRepositoryProvider);
    final id = await repository.create(
      const IngredientInput(
        name: '番茄',
        category: '蔬菜',
        quantity: 3,
        unit: '顆',
        location: '冷藏',
      ),
    );

    final ingredients = await container.read(ingredientListProvider.future);
    final ingredient = await container.read(ingredientByIdProvider(id).future);

    expect(ingredients, hasLength(1));
    expect(ingredients.single.name, '番茄');
    expect(ingredient?.category, '蔬菜');
    expect(ingredient?.location, '冷藏');
  });
}
