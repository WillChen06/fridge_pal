import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import 'inventory_providers.dart';
import 'widgets/ingredient_formatters.dart';

class IngredientDetailScreen extends ConsumerWidget {
  const IngredientDetailScreen({required this.ingredientId, super.key});

  final int ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredient = ref.watch(ingredientByIdProvider(ingredientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('食材詳情'),
        actions: [
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/inventory/$ingredientId/edit'),
          ),
        ],
      ),
      body: ingredient.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('找不到這筆食材'));
          }
          return _IngredientDetail(ingredient: item);
        },
        error: (error, stackTrace) => Center(child: Text('食材讀取失敗：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _IngredientDetail extends ConsumerWidget {
  const _IngredientDetail({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(ingredient.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          formatIngredientAmount(ingredient.quantity, ingredient.unit),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        _DetailTile(
          icon: Icons.category_outlined,
          label: '分類',
          value: ingredient.category,
        ),
        _DetailTile(
          icon: Icons.place_outlined,
          label: '位置',
          value: ingredient.location ?? '未設定',
        ),
        _DetailTile(
          icon: Icons.event_outlined,
          label: '到期日',
          value: ingredient.expiryDate == null
              ? '未設定'
              : formatIngredientDate(ingredient.expiryDate!),
        ),
        _DetailTile(
          icon: Icons.inventory_2_outlined,
          label: '低庫存門檻',
          value: ingredient.lowStockThreshold == null
              ? '未設定'
              : formatIngredientAmount(
                  ingredient.lowStockThreshold!,
                  ingredient.unit,
                ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline),
          label: const Text('刪除食材'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除食材'),
        content: Text('確定要刪除「${ingredient.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    await ref.read(ingredientRepositoryProvider).delete(ingredient.id);

    if (context.mounted) {
      context.pop();
    }
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
