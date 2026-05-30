import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/status.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/account_action.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/auto_refresh.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/resource_card.dart';

/// Lets other screens (e.g. the dashboard count tiles) request which tab the
/// Resources screen should show when navigated to.
class ResourcesTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int tab) => state = tab;
}

final resourcesTabProvider = NotifierProvider<ResourcesTabNotifier, int>(
  ResourcesTabNotifier.new,
);

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen>
    with TickerProviderStateMixin, AutoRefreshMixin {
  late final TabController _tab = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  String _query = '';

  @override
  void onAutoRefresh() {
    ref.invalidate(applicationsProvider);
    ref.invalidate(databasesProvider);
    ref.invalidate(servicesProvider);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour deep-tab requests from other screens.
    ref.listen<int>(resourcesTabProvider, (_, next) {
      if (next != _tab.index) _tab.animateTo(next);
    });
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const AccountAction(),
        title: const Text('Resources'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search resources',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Apps'),
                  Tab(text: 'Databases'),
                  Tab(text: 'Services'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AppsTab(query: _query),
          _DatabasesTab(query: _query),
          _ServicesTab(query: _query),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, _) => FloatingActionButton.extended(
          onPressed: () {
            switch (_tab.index) {
              case 0:
                context.push('/resources/create/app');
                break;
              case 1:
                context.push('/resources/create/db');
                break;
              case 2:
                context.push('/resources/create/service');
                break;
            }
          },
          icon: const Icon(Icons.add),
          label: Text(switch (_tab.index) {
            0 => 'New app',
            1 => 'New database',
            _ => 'New service',
          }),
        ),
      ),
    );
  }
}

bool _matches(String name, String q) =>
    q.isEmpty || name.toLowerCase().contains(q.toLowerCase());

class _AppsTab extends ConsumerWidget {
  const _AppsTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(applicationsProvider);
    return AsyncValueView(
      value: apps,
      onRetry: () => ref.invalidate(applicationsProvider),
      data: (list) {
        final filtered = list.where((a) => _matches(a.name, query)).toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.rocket_launch_outlined,
            title: 'No applications',
            message: 'Create your first app with the + button.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(applicationsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = filtered[i];
              return ResourceCard(
                icon: Icons.rocket_launch_outlined,
                title: a.name,
                subtitle: a.domains.isNotEmpty
                    ? a.domains.first
                    : (a.gitRepository.isNotEmpty
                          ? a.gitRepository
                          : a.buildPack),
                status: a.status,
                onTap: () => context.push('/resources/app/${a.uuid}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _DatabasesTab extends ConsumerWidget {
  const _DatabasesTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbs = ref.watch(databasesProvider);
    return AsyncValueView(
      value: dbs,
      onRetry: () => ref.invalidate(databasesProvider),
      data: (list) {
        final filtered = list.where((d) => _matches(d.name, query)).toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.storage_rounded,
            title: 'No databases',
            message: 'Provision a database with the + button.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(databasesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = filtered[i];
              return ResourceCard(
                icon: Icons.storage_rounded,
                title: d.name,
                subtitle: d.engineLabel,
                status: d.status,
                onTap: () => context.push('/resources/db/${d.uuid}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svcs = ref.watch(servicesProvider);
    return AsyncValueView(
      value: svcs,
      onRetry: () => ref.invalidate(servicesProvider),
      data: (list) {
        final filtered = list.where((s) => _matches(s.name, query)).toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.widgets_outlined,
            title: 'No services',
            message: 'Deploy a one-click service with the + button.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(servicesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = filtered[i];
              return ResourceCard(
                icon: Icons.widgets_outlined,
                title: s.name,
                subtitle: s.serviceType.isEmpty ? 'Service' : s.serviceType,
                status: s.status.raw.isEmpty
                    ? ResourceStatus.parse('running')
                    : s.status,
                onTap: () => context.push('/resources/service/${s.uuid}'),
              );
            },
          ),
        );
      },
    );
  }
}
