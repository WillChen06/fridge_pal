import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';
import 'notification_settings.dart';

const expiryReminderChannelId = 'expiry_reminder';
const lowStockNotificationIdOffset = 100000;

DateTime? calculateExpiryReminderFireTime(
  DateTime expiryDate,
  int daysBefore,
  int hour,
  int minute, {
  DateTime? now,
}) {
  RangeError.checkValueInInterval(daysBefore, 0, 14, 'daysBefore');
  RangeError.checkValueInInterval(hour, 0, 23, 'hour');
  RangeError.checkValueInInterval(minute, 0, 59, 'minute');

  final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
  final reminderDay = expiryDay.subtract(Duration(days: daysBefore));
  final fireAt = DateTime(
    reminderDay.year,
    reminderDay.month,
    reminderDay.day,
    hour,
    minute,
  );
  if (!fireAt.isAfter(now ?? DateTime.now())) {
    return null;
  }
  return fireAt;
}

abstract class LocalNotificationsClient {
  Future<void> initialize();

  Future<void> createExpiryChannel();

  Future<void> requestPermissions();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required String payload,
  });

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

class FlutterLocalNotificationsClient implements LocalNotificationsClient {
  FlutterLocalNotificationsClient(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    expiryReminderChannelId,
    '食材提醒',
    description: '食材到期與低庫存提醒',
    importance: Importance.high,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      expiryReminderChannelId,
      '食材提醒',
      channelDescription: '食材到期與低庫存提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initializationSettings);
  }

  @override
  Future<void> createExpiryChannel() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  @override
  Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      fireAt,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      _notificationDetails,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

class NotificationService {
  const NotificationService(this._client);

  final LocalNotificationsClient _client;

  Future<void> init() async {
    if (!kIsWeb) {
      tz_data.initializeTimeZones();
      if (!Platform.isLinux) {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      }
    }
    await _client.initialize();
    await _client.createExpiryChannel();
    await _client.requestPermissions();
  }

  Future<void> scheduleExpiryReminder(
    Ingredient ingredient,
    NotificationSettings settings,
  ) async {
    if (!settings.enabled) {
      return;
    }
    final expiryDate = ingredient.expiryDate;
    if (expiryDate == null) {
      return;
    }

    final fireAt = calculateExpiryReminderFireTime(
      expiryDate,
      settings.daysBefore,
      settings.reminderHour,
      settings.reminderMinute,
    );
    if (fireAt == null) {
      return;
    }

    await _client.schedule(
      id: ingredient.id,
      title: '食材快到期',
      body: '${ingredient.name} 即將到期，記得安排料理。',
      fireAt: tz.TZDateTime.from(fireAt, tz.local),
      payload: 'ingredient:${ingredient.id}',
    );
  }

  Future<void> cancelForIngredient(int ingredientId) async {
    await _client.cancel(ingredientId);
    await _client.cancel(lowStockNotificationIdOffset + ingredientId);
  }

  Future<void> showLowStockNow(Ingredient ingredient) {
    return _client.show(
      id: lowStockNotificationIdOffset + ingredient.id,
      title: '庫存偏低',
      body:
          '${ingredient.name} 庫存只剩 ${ingredient.quantity} ${ingredient.unit}。',
      payload: 'ingredient:${ingredient.id}',
    );
  }

  Future<void> showTestNotification() {
    return _client.show(
      id: lowStockNotificationIdOffset - 1,
      title: 'Fridge Pal 測試通知',
      body: '通知設定正常運作。',
      payload: 'settings:test',
    );
  }

  Future<void> rescheduleAll(
    List<Ingredient> all,
    NotificationSettings settings,
  ) async {
    await _client.cancelAll();
    for (final ingredient in all) {
      await scheduleExpiryReminder(ingredient, settings);
    }
  }
}

final localNotificationsClientProvider = Provider<LocalNotificationsClient>((
  ref,
) {
  return FlutterLocalNotificationsClient(FlutterLocalNotificationsPlugin());
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(localNotificationsClientProvider));
});
