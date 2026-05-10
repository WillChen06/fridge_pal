import 'package:shared_preferences/shared_preferences.dart';

class LowStockNotificationThrottle {
  static const Duration throttleWindow = Duration(hours: 24);
  static const _keyPrefix = 'last_low_stock_';

  Future<bool> canNotify(int ingredientId, {DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final lastTimestamp = preferences.getInt(_keyFor(ingredientId));
    if (lastTimestamp == null) {
      return true;
    }

    final currentTime = now ?? DateTime.now();
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
    return currentTime.difference(lastTime) >= throttleWindow;
  }

  Future<void> markNotified(int ingredientId, {DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final currentTime = now ?? DateTime.now();
    await preferences.setInt(
      _keyFor(ingredientId),
      currentTime.millisecondsSinceEpoch,
    );
  }

  static String _keyFor(int ingredientId) => '$_keyPrefix$ingredientId';
}
