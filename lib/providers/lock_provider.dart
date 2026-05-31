import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockState {
  const AppLockState({required this.enabled, required this.unlocked});

  final bool enabled;
  final bool unlocked;

  /// Whether the lock screen should currently block the UI.
  bool get isLocked => enabled && !unlocked;

  AppLockState copyWith({bool? enabled, bool? unlocked}) => AppLockState(
    enabled: enabled ?? this.enabled,
    unlocked: unlocked ?? this.unlocked,
  );
}

/// Biometric app-lock state. When [enabled], the app starts locked and re-locks
/// when it goes to the background; the user unlocks with biometrics/passcode.
class AppLockNotifier extends Notifier<AppLockState> {
  static const _key = 'app_lock_enabled';
  final _auth = LocalAuthentication();

  @override
  AppLockState build() {
    _load();
    // Until prefs load we assume unlocked; _load() locks if needed.
    return const AppLockState(enabled: false, unlocked: true);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? false;
    state = AppLockState(enabled: enabled, unlocked: !enabled);
  }

  /// Whether the device can actually do biometric / device-credential auth.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    // Enabling leaves the app unlocked for the current session.
    state = state.copyWith(enabled: value, unlocked: true);
  }

  /// Re-lock (e.g. when backgrounded).
  void lock() {
    if (state.enabled) state = state.copyWith(unlocked: false);
  }

  /// Prompt for biometrics; unlocks on success. Returns success.
  Future<bool> authenticate() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Coolify Companion',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok) state = state.copyWith(unlocked: true);
      return ok;
    } catch (_) {
      return false;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, AppLockState>(
  AppLockNotifier.new,
);
