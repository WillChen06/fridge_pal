import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shopping_providers.dart';
import 'widgets/shopping_formatters.dart';

class ShoppingRecordDetailScreen extends ConsumerWidget {
  const ShoppingRecordDetailScreen({required this.recordId, super.key});

  final int recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(shoppingRecordByIdProvider(recordId));

    return Scaffold(
      appBar: AppBar(title: const Text('買菜詳情')),
      body: record.when(
        data: (recordWithItems) {
          if (recordWithItems == null) {
            return const Center(child: Text('找不到這筆買菜紀錄'));
          }

          final record = recordWithItems.record;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                formatShoppingDate(record.date),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (record.totalCost != null) ...[
                const SizedBox(height: 8),
                Text(
                  formatShoppingCost(record.totalCost!),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              if (record.note != null) ...[
                const SizedBox(height: 16),
                Text(record.note!),
              ],
              const SizedBox(height: 24),
              Text('品項', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final item in recordWithItems.items)
                Card(
                  child: ListTile(
                    title: Text(item.nameSnapshot),
                    subtitle: Text(
                      formatShoppingQuantity(item.quantity, item.unit),
                    ),
                    trailing: item.cost == null
                        ? null
                        : Text(formatShoppingCost(item.cost!)),
                  ),
                ),
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text('買菜紀錄讀取失敗：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
