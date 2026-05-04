import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:fridge_pal/app.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/features/inventory/inventory_providers.dart';

void main() {
  testWidgets('app boots with bottom navigation tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientListProvider.overrideWith(
            (ref) => Stream<List<Ingredient>>.value(const <Ingredient>[]),
          ),
        ],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('庫存'), findsWidgets);
    expect(find.text('還沒有庫存'), findsOneWidget);
    expect(find.text('買菜'), findsOneWidget);
    expect(find.text('掃描'), findsOneWidget);
    expect(find.text('食譜'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
