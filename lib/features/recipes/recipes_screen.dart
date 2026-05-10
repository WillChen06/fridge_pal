import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/claude_client.dart';
import '../../core/db/database.dart';
import 'recipe_providers.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recentRecipesProvider);
    final ingredients = ref.watch(recipeIngredientSnapshotProvider);
    final hasClient = ref.watch(claudeClientProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 食譜推薦')),
      body: recipes.when(
        data: (items) {
          if (items.isEmpty) {
            return const _RecipeEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _RecipeHistoryCard(recipe: items[index]),
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('食譜歷史讀取失敗：$error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: ingredients.when(
        data: (items) {
          final reason = _disabledReason(
            hasClient: hasClient,
            itemCount: items.length,
          );
          final canGenerate = reason == null;
          return FloatingActionButton.extended(
            onPressed: canGenerate
                ? () => context.push('/recipes/new', extra: items)
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('推薦食譜'),
            tooltip: reason,
          );
        },
        error: (error, stackTrace) => const FloatingActionButton.extended(
          onPressed: null,
          icon: Icon(Icons.auto_awesome),
          label: Text('推薦食譜'),
          tooltip: '庫存讀取失敗',
        ),
        loading: () => const FloatingActionButton.extended(
          onPressed: null,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('推薦食譜'),
        ),
      ),
      bottomNavigationBar: ingredients.when(
        data: (items) {
          final reason = _disabledReason(
            hasClient: hasClient,
            itemCount: items.length,
          );
          if (reason == null) {
            return null;
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        },
        error: (error, stackTrace) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('庫存讀取失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        loading: () => null,
      ),
    );
  }

  static String? _disabledReason({
    required bool hasClient,
    required int itemCount,
  }) {
    if (!hasClient) {
      return '請在 env.json 設定 ANTHROPIC_API_KEY 後重啟';
    }
    if (itemCount == 0) {
      return '冰箱空空，先加一些食材吧';
    }
    return null;
  }
}

class _RecipeEmptyState extends StatelessWidget {
  const _RecipeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有食譜建議，點下方按鈕開始',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeHistoryCard extends StatelessWidget {
  const _RecipeHistoryCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(recipe.title),
        subtitle: Text(_relativeTime(recipe.createdAt, DateTime.now())),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/recipes/${recipe.id}'),
      ),
    );
  }

  String _relativeTime(DateTime createdAt, DateTime now) {
    final elapsed = now.difference(createdAt);
    if (elapsed.inMinutes < 1) {
      return '剛剛';
    }
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes} 分鐘前';
    }
    if (elapsed.inDays < 1) {
      return '${elapsed.inHours} 小時前';
    }
    if (elapsed.inDays < 7) {
      return '${elapsed.inDays} 天前';
    }
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day';
  }
}
