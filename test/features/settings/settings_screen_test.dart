import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/db/database_provider.dart';
import 'package:fridge_pal/core/notifications/notification_service.dart';
import 'package:fridge_pal/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  testWidgets('settings screen saves changes and reschedules notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.now();
    await database.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '優格',
        quantity: 2,
        unit: '杯',
        expiryDate: Value(now.add(const Duration(days: 8))),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final client = _RecordingNotificationsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          localNotificationsClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('notifications-enabled-switch')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('save-notification-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(client.calls, ['cancelAll']);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('notification_enabled'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _RecordingNotificationsClient implements LocalNotificationsClient {
  final calls = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> createExpiryChannel() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required String payload,
  }) async {
    calls.add('schedule:$id');
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    calls.add('show:$id');
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel:$id');
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
  }
}
