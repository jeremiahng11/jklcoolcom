import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/monitor.dart';
import 'notifications_provider.dart';

/// In-app alerts: while the app is open, polls the active Coolify instance and
/// raises local notifications on status changes. There is no background worker —
/// for alerts while the app is closed, users wire Coolify's own notification
/// channels (Telegram / ntfy / webhook), which the guide screen explains.
class MonitorNotifier extends Notifier<bool> {
  static const _key = 'inapp_alerts_enabled';
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? false;
    if (enabled) _start();
    state = enabled;
  }

  void _start() {
    _timer?.cancel();
    // Foreground poll. Run one immediately, then on an interval.
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  Future<void> _tick() async {
    await runMonitorCheck();
    await ref.read(notificationsProvider.notifier).reload();
  }

  /// Re-check now (e.g. on app resume).
  Future<void> refreshNow() async {
    if (state) await _tick();
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final granted = await requestNotificationPermission();
      if (!granted) {
        state = false;
        await prefs.setBool(_key, false);
        return;
      }
      _start();
    } else {
      _timer?.cancel();
    }
    await prefs.setBool(_key, value);
    state = value;
  }
}

final monitorProvider = NotifierProvider<MonitorNotifier, bool>(
  MonitorNotifier.new,
);
