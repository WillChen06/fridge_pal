import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'low_stock_notification_throttle.dart';
import 'notification_service.dart';
import 'notification_settings.dart';

abstract class InventoryNotificationActions {
  Future<void> scheduleCreated(Ingredient ingredient);

  Future<void> scheduleUpdated(Ingredient ingredient);

  Future<void> cancelDeleted(int ingredientId);

  Future<void> notifyLowStockIfNeeded(Ingredient ingredient);
}

class RiverpodInventoryNotificationActions
    implements InventoryNotificationActions {
  const RiverpodInventoryNotificationActions(this._ref);

  final Ref _ref;

  @override
  Future<void> scheduleCreated(Ingredient ingredient) async {
    if (ingredient.expiryDate == null) {
      return;
    }
    final settings = await _ref.read(notificationSettingsProvider.future);
    await _ref
        .read(notificationServiceProvider)
        .scheduleExpiryReminder(ingredient, settings);
  }

  @override
  Future<void> scheduleUpdated(Ingredient ingredient) async {
    final service = _ref.read(notificationServiceProvider);
    await service.cancelForIngredient(ingredient.id);
    await scheduleCreated(ingredient);
  }

  @override
  Future<void> cancelDeleted(int ingredientId) {
    return _ref
        .read(notificationServiceProvider)
        .cancelForIngredient(ingredientId);
  }

  @override
  Future<void> notifyLowStockIfNeeded(Ingredient ingredient) async {
    final threshold = ingredient.lowStockThreshold;
    if (threshold == null || ingredient.quantity > threshold) {
      return;
    }
    final settings = await _ref.read(notificationSettingsProvider.future);
    if (!settings.enabled) {
      return;
    }

    final throttle = _ref.read(lowStockNotificationThrottleProvider);
    if (!await throttle.canNotify(ingredient.id)) {
      return;
    }

    await _ref.read(notificationServiceProvider).showLowStockNow(ingredient);
    await throttle.markNotified(ingredient.id);
  }
}

final lowStockNotificationThrottleProvider =
    Provider<LowStockNotificationThrottle>((ref) {
      return LowStockNotificationThrottle();
    });

final inventoryNotificationActionsProvider =
    Provider<InventoryNotificationActions>((ref) {
      return RiverpodInventoryNotificationActions(ref);
    });
