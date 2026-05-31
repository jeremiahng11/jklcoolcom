import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lock_provider.dart';
import '../providers/splash_provider.dart';

/// Wraps the whole app (via MaterialApp.builder). When the biometric lock is
/// enabled and engaged, it overlays an opaque lock screen on top of [child]
/// (which keeps the navigation stack alive underneath) and prompts for auth.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final notifier = ref.read(appLockProvider.notifier);
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      notifier.lock();
    } else if (lifecycle == AppLifecycleState.resumed) {
      _maybePrompt();
    }
  }

  Future<void> _maybePrompt() async {
    if (_prompting) return;
    // Wait for the launch splash to finish so the OS prompt doesn't pop over it.
    if (!ref.read(splashDoneProvider)) return;
    final state = ref.read(appLockProvider);
    if (!state.isLocked) return;
    _prompting = true;
    await ref.read(appLockProvider.notifier).authenticate();
    _prompting = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The lock flag is loaded from prefs asynchronously, so it can engage after
    // initState's prompt already ran. Auto-prompt the moment it becomes locked
    // so the user never has to tap "Unlock" first.
    ref.listen<AppLockState>(appLockProvider, (prev, next) {
      if (next.isLocked && !(prev?.isLocked ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
      }
    });
    // When the splash finishes, prompt if we're already locked.
    ref.listen<bool>(splashDoneProvider, (prev, done) {
      if (done && (prev != true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
      }
    });
    final locked = ref.watch(appLockProvider).isLocked;
    return Stack(
      children: [
        widget.child,
        if (locked) _LockScreen(onUnlock: _maybePrompt),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Coolify Companion is locked',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
