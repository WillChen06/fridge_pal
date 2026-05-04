import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/app.dart';

void main() {
  testWidgets('app boots with bottom navigation tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FridgePalApp()));
    await tester.pumpAndSettle();

    expect(find.text('庫存'), findsWidgets);
    expect(find.text('買菜'), findsOneWidget);
    expect(find.text('掃描'), findsOneWidget);
    expect(find.text('食譜'), findsOneWidget);
  });
}
