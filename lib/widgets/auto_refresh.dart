import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for a [ConsumerState] that periodically invalidates providers while
/// the app is in the foreground, and once more when it returns to foreground.
///
/// Uses an internal [WidgetsBindingObserver] (which has default no-op
/// implementations) so we don't have to implement the full observer interface.
mixin AutoRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _timer;
  late final _LifecycleObserver _observer;

  /// Called on each tick / on resume. Override to invalidate providers.
  void onAutoRefresh();

  /// Polling interval.
  Duration get refreshInterval => const Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _observer = _LifecycleObserver(
      onResume: () {
        refreshNow();
        _start();
      },
      onPause: () => _timer?.cancel(),
    );
    WidgetsBinding.instance.addObserver(_observer);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refreshNow());
  }

  void refreshNow() {
    if (!mounted) return;
    onAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({required this.onResume, required this.onPause});

  final VoidCallback onResume;
  final VoidCallback onPause;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    } else if (state == AppLifecycleState.paused) {
      onPause();
    }
  }
}
