import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import 'inventory_providers.dart';
import 'widgets/ingredient_formatters.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(ingredientListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('庫存')),
      body: ingredients.when(
        data: (items) {
          if (items.isEmpty) {
            return const _InventoryEmptyState();
          }

          final grouped = _groupByCategory(items);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final category = grouped.keys.elementAt(index);
              final categoryItems = grouped[category]!;
              return _IngredientCategorySection(
                category: category,
                ingredients: categoryItems,
              );
            },
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('庫存讀取失敗：$error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/new'),
        icon: const Icon(Icons.add),
        label: const Text('新增食材'),
      ),
    );
  }

  Map<String, List<Ingredient>> _groupByCategory(List<Ingredient> ingredients) {
    final grouped = <String, List<Ingredient>>{};
    for (final ingredient in ingredients) {
      grouped
          .putIfAbsent(ingredient.category, () => <Ingredient>[])
          .add(ingredient);
    }
    return grouped;
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.kitchen_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有庫存',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '新增第一個食材後，就能在這裡追蹤數量、保存位置與到期日。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientCategorySection extends StatelessWidget {
  const _IngredientCategorySection({
    required this.category,
    required this.ingredients,
  });

  final String category;
  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              category,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          for (final ingredient in ingredients)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.local_dining)),
                title: Text(ingredient.name),
                subtitle: Text(_subtitleFor(ingredient)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/inventory/${ingredient.id}'),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleFor(Ingredient ingredient) {
    final parts = <String>[
      formatIngredientAmount(ingredient.quantity, ingredient.unit),
    ];
    if (ingredient.location != null) {
      parts.add(ingredient.location!);
    }
    if (ingredient.expiryDate != null) {
      parts.add('到期 ${formatIngredientDate(ingredient.expiryDate!)}');
    }
    return parts.join(' · ');
  }
}
