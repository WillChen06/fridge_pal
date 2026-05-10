import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/notifications/notification_service.dart';
import 'package:fridge_pal/core/notifications/notification_settings.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('calculateExpiryReminderFireTime', () {
    test('returns null for an already expired reminder time', () {
      final fireAt = calculateExpiryReminderFireTime(
        DateTime(2026, 5, 8),
        1,
        9,
        0,
        now: DateTime(2026, 5, 10, 8),
      );

      expect(fireAt, isNull);
    });

    test('keeps same-day reminders when the time is still ahead', () {
      final fireAt = calculateExpiryReminderFireTime(
        DateTime(2026, 5, 10),
        0,
        18,
        30,
        now: DateTime(2026, 5, 10, 8),
      );

      expect(fireAt, DateTime(2026, 5, 10, 18, 30));
    });

    test('calculates future reminders days before expiry', () {
      final fireAt = calculateExpiryReminderFireTime(
        DateTime(2026, 5, 20),
        3,
        9,
        15,
        now: DateTime(2026, 5, 10),
      );

      expect(fireAt, DateTime(2026, 5, 17, 9, 15));
    });

    test('handles cross-year reminder dates', () {
      final fireAt = calculateExpiryReminderFireTime(
        DateTime(2027, 1, 2),
        3,
        9,
        0,
        now: DateTime(2026, 12, 1),
      );

      expect(fireAt, DateTime(2026, 12, 30, 9));
    });
  });

  group('NotificationService', () {
    test(
      'schedules future expiry reminders through the injected client',
      () async {
        final client = _RecordingNotificationsClient();
        final service = NotificationService(client);
        final expiry = DateTime.now().add(const Duration(days: 5));

        await service.scheduleExpiryReminder(
          _ingredient(expiryDate: expiry),
          const NotificationSettings(daysBefore: 1, reminderHour: 9),
        );

        expect(client.calls, ['schedule:42']);
        expect(client.scheduledIds, [42]);
      },
    );

    test('does not schedule reminders in the past', () async {
      final client = _RecordingNotificationsClient();
      final service = NotificationService(client);

      await service.scheduleExpiryReminder(
        _ingredient(
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        const NotificationSettings(daysBefore: 0),
      );

      expect(client.calls, isEmpty);
    });

    test('rescheduleAll cancels before adding active reminders', () async {
      final client = _RecordingNotificationsClient();
      final service = NotificationService(client);
      final expiry = DateTime.now().add(const Duration(days: 5));

      await service.rescheduleAll([
        _ingredient(expiryDate: expiry),
      ], const NotificationSettings(daysBefore: 1, reminderHour: 9));

      expect(client.calls, ['cancelAll', 'schedule:42']);
    });

    test('cancelForIngredient cancels expiry and low-stock ids', () async {
      final client = _RecordingNotificationsClient();
      final service = NotificationService(client);

      await service.cancelForIngredient(42);

      expect(client.calls, ['cancel:42', 'cancel:100042']);
    });
  });
}

Ingredient _ingredient({DateTime? expiryDate}) {
  final now = DateTime(2026, 5, 10);
  return Ingredient(
    id: 42,
    name: '牛奶',
    category: '乳製品',
    quantity: 1,
    unit: '瓶',
    expiryDate: expiryDate,
    lowStockThreshold: null,
    location: null,
    createdAt: now,
    updatedAt: now,
  );
}

class _RecordingNotificationsClient implements LocalNotificationsClient {
  final calls = <String>[];
  final scheduledIds = <int>[];

  @override
  Future<void> initialize() async {
    calls.add('initialize');
  }

  @override
  Future<void> createExpiryChannel() async {
    calls.add('createChannel');
  }

  @override
  Future<void> requestPermissions() async {
    calls.add('requestPermissions');
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required String payload,
  }) async {
    scheduledIds.add(id);
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
