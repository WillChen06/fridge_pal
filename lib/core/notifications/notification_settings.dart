import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  const NotificationSettings({
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.daysBefore = 3,
    this.enabled = true,
  });

  final int reminderHour;
  final int reminderMinute;
  final int daysBefore;
  final bool enabled;

  NotificationSettings copyWith({
    int? reminderHour,
    int? reminderMinute,
    int? daysBefore,
    bool? enabled,
  }) {
    return NotificationSettings(
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      daysBefore: daysBefore ?? this.daysBefore,
      enabled: enabled ?? this.enabled,
    );
  }
}

class NotificationSettingsRepository {
  static const _reminderHourKey = 'notification_reminder_hour';
  static const _reminderMinuteKey = 'notification_reminder_minute';
  static const _daysBeforeKey = 'notification_days_before';
  static const _enabledKey = 'notification_enabled';

  Future<NotificationSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    const defaults = NotificationSettings();
    return NotificationSettings(
      reminderHour: _clampInt(
        preferences.getInt(_reminderHourKey),
        min: 0,
        max: 23,
        fallback: defaults.reminderHour,
      ),
      reminderMinute: _clampInt(
        preferences.getInt(_reminderMinuteKey),
        min: 0,
        max: 59,
        fallback: defaults.reminderMinute,
      ),
      daysBefore: _clampInt(
        preferences.getInt(_daysBeforeKey),
        min: 0,
        max: 14,
        fallback: defaults.daysBefore,
      ),
      enabled: preferences.getBool(_enabledKey) ?? defaults.enabled,
    );
  }

  Future<void> save(NotificationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_reminderHourKey, settings.reminderHour);
    await preferences.setInt(_reminderMinuteKey, settings.reminderMinute);
    await preferences.setInt(_daysBeforeKey, settings.daysBefore);
    await preferences.setBool(_enabledKey, settings.enabled);
  }

  static int _clampInt(
    int? value, {
    required int min,
    required int max,
    required int fallback,
  }) {
    if (value == null) {
      return fallback;
    }
    if (value < min || value > max) {
      return fallback;
    }
    return value;
  }
}

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() {
    return ref.watch(notificationSettingsRepositoryProvider).load();
  }

  Future<void> save(NotificationSettings settings) async {
    state = const AsyncValue<NotificationSettings>.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationSettingsRepositoryProvider).save(settings);
      return settings;
    });
  }
}

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      return NotificationSettingsRepository();
    });

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );
