import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/notifications/notification_settings.dart';
import '../inventory/inventory_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  NotificationSettings? _draft;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: settings.when(
        data: (loaded) {
          final draft = _draft ?? loaded;
          _draft ??= loaded;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              SwitchListTile(
                key: const ValueKey('notifications-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('啟用通知'),
                value: draft.enabled,
                onChanged: (value) {
                  setState(() {
                    _draft = draft.copyWith(enabled: value);
                  });
                },
              ),
              ListTile(
                key: const ValueKey('notification-time-tile'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('提醒時間'),
                subtitle: Text(_formatTime(draft)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickTime(draft),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('提前幾天'),
                subtitle: Text(_formatDaysBefore(draft.daysBefore)),
              ),
              Slider(
                key: const ValueKey('notification-days-slider'),
                min: 0,
                max: 14,
                divisions: 14,
                label: _formatDaysBefore(draft.daysBefore),
                value: draft.daysBefore.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _draft = draft.copyWith(daysBefore: value.round());
                  });
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const ValueKey('test-notification-button'),
                onPressed: _showTestNotification,
                icon: const Icon(Icons.notification_add_outlined),
                label: const Text('測試通知'),
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text('通知設定讀取失敗：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const ValueKey('save-notification-settings-button'),
            onPressed: _isSaving || _draft == null ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('儲存'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(NotificationSettings draft) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: draft.reminderHour,
        minute: draft.reminderMinute,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(
        reminderHour: picked.hour,
        reminderMinute: picked.minute,
      );
    });
  }

  Future<void> _showTestNotification() async {
    try {
      await ref.read(notificationServiceProvider).showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已送出測試通知')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('測試通知失敗：$error')));
      }
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(notificationSettingsProvider.notifier).save(draft);
      final ingredients = await ref.read(ingredientRepositoryProvider).getAll();
      await ref
          .read(notificationServiceProvider)
          .rescheduleAll(ingredients, draft);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通知設定已儲存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('通知設定儲存失敗：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatTime(NotificationSettings settings) {
    final hour = settings.reminderHour.toString().padLeft(2, '0');
    final minute = settings.reminderMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDaysBefore(int daysBefore) {
    if (daysBefore == 0) {
      return '當天';
    }
    return '$daysBefore 天前';
  }
}
