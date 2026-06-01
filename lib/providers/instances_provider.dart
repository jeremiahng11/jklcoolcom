import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/coolify_client.dart';
import '../models/instance.dart';
import '../services/instance_store.dart';

final instanceStoreProvider = Provider<InstanceStore>((ref) => InstanceStore());

/// Snapshot of all configured accounts, their in-memory tokens, and which one
/// is active.
class InstancesState {
  const InstancesState({
    required this.instances,
    required this.tokens,
    required this.activeId,
  });

  final List<CoolifyInstance> instances;
  final Map<String, String> tokens;
  final String? activeId;

  bool get isEmpty => instances.isEmpty;

  CoolifyInstance? get active {
    if (activeId == null) return null;
    for (final i in instances) {
      if (i.id == activeId) return i;
    }
    return instances.isNotEmpty ? instances.first : null;
  }

  String? get activeToken {
    final a = active;
    return a == null ? null : tokens[a.id];
  }
}

class InstancesNotifier extends AsyncNotifier<InstancesState> {
  @override
  Future<InstancesState> build() async {
    ref.keepAlive();
    final store = ref.read(instanceStoreProvider);
    final instances = await store.loadInstances();
    final tokens = <String, String>{};
    for (final i in instances) {
      final t = await store.tokenFor(i.id);
      if (t != null) tokens[i.id] = t;
    }
    var activeId = await store.activeInstanceId();
    if ((activeId == null || !instances.any((i) => i.id == activeId)) &&
        instances.isNotEmpty) {
      activeId = instances.first.id;
    }
    return InstancesState(
      instances: instances,
      tokens: tokens,
      activeId: activeId,
    );
  }

  InstanceStore get _store => ref.read(instanceStoreProvider);

  // Mutate state in place (rather than invalidateSelf + reload-from-disk) so
  // saving/switching doesn't flash a loading state or churn the router/client.
  Future<void> addOrUpdate(
    CoolifyInstance instance, {
    String? token,
    String? metricsToken,
    bool makeActive = true,
  }) async {
    await _store.save(instance, token: token, metricsToken: metricsToken);
    if (makeActive) await _store.setActiveInstanceId(instance.id);

    final current =
        state.value ??
        const InstancesState(instances: [], tokens: {}, activeId: null);
    final instances = [...current.instances];
    final idx = instances.indexWhere((i) => i.id == instance.id);
    if (idx >= 0) {
      instances[idx] = instance;
    } else {
      instances.add(instance);
    }
    final tokens = {...current.tokens};
    if (token != null && token.isNotEmpty) tokens[instance.id] = token;

    state = AsyncData(
      InstancesState(
        instances: instances,
        tokens: tokens,
        activeId: makeActive ? instance.id : (current.activeId ?? instance.id),
      ),
    );
  }

  Future<void> setActive(String id) async {
    await _store.setActiveInstanceId(id);
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(
      InstancesState(
        instances: current.instances,
        tokens: current.tokens,
        activeId: id,
      ),
    );
  }

  Future<void> remove(String id) async {
    await _store.delete(id);
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final instances = current.instances.where((i) => i.id != id).toList();
    final tokens = {...current.tokens}..remove(id);
    var activeId = current.activeId;
    if (activeId == id) {
      activeId = instances.isNotEmpty ? instances.first.id : null;
    }
    state = AsyncData(
      InstancesState(instances: instances, tokens: tokens, activeId: activeId),
    );
  }
}

final instancesProvider =
    AsyncNotifierProvider<InstancesNotifier, InstancesState>(
      InstancesNotifier.new,
    );

/// The currently-active account, or null when none is configured.
final activeInstanceProvider = Provider<CoolifyInstance?>((ref) {
  return ref.watch(instancesProvider).value?.active;
});

/// A ready-to-use API client bound to the active account, or null when there
/// is no active account / token.
final coolifyClientProvider = Provider<CoolifyClient?>((ref) {
  final state = ref.watch(instancesProvider).value;
  final active = state?.active;
  if (state == null || active == null) return null;
  final token = state.tokens[active.id];
  if (token == null || token.isEmpty) return null;
  final client = CoolifyClient(baseUrl: active.baseUrl, token: token);
  ref.onDispose(client.dispose);
  return client;
});
