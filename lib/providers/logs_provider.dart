import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instances_provider.dart';

/// Tracks which application log views have been paused (by uuid). A uuid not in
/// the set is "live".
class PausedLogsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String uuid) {
    final next = {...state};
    if (!next.remove(uuid)) next.add(uuid);
    state = next;
  }

  bool isLive(String uuid) => !state.contains(uuid);
}

final pausedLogsProvider = NotifierProvider<PausedLogsNotifier, Set<String>>(
  PausedLogsNotifier.new,
);

/// Live application logs, re-polled every few seconds while the view is live.
/// Watching [pausedLogsProvider] means toggling pause rebuilds this provider,
/// which starts or stops the polling loop.
final appLogsProvider = StreamProvider.family<String, String>((
  ref,
  uuid,
) async* {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return;

  final live = !ref.watch(pausedLogsProvider).contains(uuid);

  yield await client.appLogs(uuid);
  while (live) {
    await Future<void>.delayed(const Duration(seconds: 4));
    yield await client.appLogs(uuid);
  }
});
