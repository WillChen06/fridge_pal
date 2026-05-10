import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/notifications/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('NotificationSettingsRepository saves and loads settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = NotificationSettingsRepository();
    const settings = NotificationSettings(
      reminderHour: 18,
      reminderMinute: 45,
      daysBefore: 2,
      enabled: false,
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.reminderHour, 18);
    expect(loaded.reminderMinute, 45);
    expect(loaded.daysBefore, 2);
    expect(loaded.enabled, isFalse);
  });
}
