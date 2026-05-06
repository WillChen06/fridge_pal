import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'shopping_providers.dart';
import 'widgets/shopping_formatters.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(shoppingRecordListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('買菜紀錄')),
      body: records.when(
        data: (items) {
          if (items.isEmpty) {
            return const _ShoppingEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final record = items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.shopping_basket_outlined),
                  ),
                  title: Text(formatShoppingDate(record.record.date)),
                  subtitle: Text('${record.itemCount} 項品項'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record.record.totalCost != null)
                        Text(formatShoppingCost(record.record.totalCost!)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/shopping/${record.record.id}'),
                ),
              );
            },
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('買菜紀錄讀取失敗：$error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/shopping/new'),
        icon: const Icon(Icons.add),
        label: const Text('新增紀錄'),
      ),
    );
  }
}

class _ShoppingEmptyState extends StatelessWidget {
  const _ShoppingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有買菜紀錄',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '新增買菜紀錄後，品項會同步進庫存數量。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
