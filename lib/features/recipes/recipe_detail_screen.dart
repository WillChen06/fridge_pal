import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'recipe_providers.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({required this.recipeId, super.key});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeByIdProvider(recipeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('食譜內容'),
        actions: [
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(recipeRepositoryProvider).deleteById(recipeId);
              if (context.mounted) {
                context.go('/recipes');
              }
            },
          ),
        ],
      ),
      body: recipe.when(
        data: (value) {
          if (value == null) {
            return const Center(child: Text('找不到這筆食譜'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              MarkdownBody(data: value.response),
              const SizedBox(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('庫存快照'),
                children: [SelectableText(value.inventorySnapshot)],
              ),
              const SizedBox(height: 12),
              Text(
                _formatUsage(
                  inputTokens: value.inputTokens,
                  outputTokens: value.outputTokens,
                  cacheReadTokens: value.cacheReadTokens,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('食譜讀取失敗：$error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  String _formatUsage({
    required int? inputTokens,
    required int? outputTokens,
    required int? cacheReadTokens,
  }) {
    return 'tokens：input ${inputTokens ?? '-'} / '
        'output ${outputTokens ?? '-'} / '
        'cache read ${cacheReadTokens ?? '-'}';
  }
}
