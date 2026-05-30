import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/env_var_editor.dart';
import '../../widgets/status_badge.dart';
import 'detail_widgets.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(serviceProvider(uuid));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(svc.value?.name ?? 'Service'),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(serviceProvider(uuid)),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Environment'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: AsyncValueView<CoolifyService>(
          value: svc,
          onRetry: () => ref.invalidate(serviceProvider(uuid)),
          data: (s) => TabBarView(
            children: [
              _Overview(svc: s),
              EnvVarEditor(kind: 'services', uuid: uuid),
              _Settings(svc: s),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.svc});
  final CoolifyService svc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(coolifyClientProvider);

    Future<void> run(Future<void> Function() fn, String msg) async {
      final ok = await runAction(context, action: fn, success: msg);
      if (ok) {
        ref.invalidate(serviceProvider(svc.uuid));
        ref.invalidate(resourcesProvider);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(serviceProvider(svc.uuid)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailHeader(
            title: svc.name,
            subtitle: svc.serviceType.isEmpty ? 'Service' : svc.serviceType,
            statusBadge: StatusBadge(svc.status),
            actions: client == null
                ? const SizedBox.shrink()
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => run(
                          () => client.startService(svc.uuid),
                          'Starting',
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Stop service',
                            message: 'Stop "${svc.name}"?',
                            confirmLabel: 'Stop',
                          );
                          if (ok && context.mounted) {
                            run(() => client.stopService(svc.uuid), 'Stopping');
                          }
                        },
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Stop'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => run(
                          () => client.restartService(svc.uuid),
                          'Restarting',
                        ),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Restart'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          DetailSection(
            title: 'Details',
            children: [
              InfoRow(
                'Type',
                svc.serviceType.isEmpty ? 'Custom' : svc.serviceType,
              ),
              if (svc.description.isNotEmpty)
                InfoRow('Description', svc.description),
              InfoRow('UUID', svc.uuid),
            ],
          ),
        ],
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.svc});
  final CoolifyService svc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditableField(
          label: 'Name',
          initialValue: svc.name,
          onSave: (v) => _patch(context, ref, {'name': v}),
        ),
        EditableField(
          label: 'Description',
          initialValue: svc.description,
          onSave: (v) => _patch(context, ref, {'description': v}),
        ),
        const SizedBox(height: 24),
        DangerZone(
          label: 'Delete service',
          description: 'Permanently delete this service and its volumes.',
          onDelete: () => _delete(context, ref),
        ),
      ],
    );
  }

  Future<void> _patch(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> body,
  ) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.updateService(svc.uuid, body),
      success: 'Saved',
    );
    if (ok) ref.invalidate(serviceProvider(svc.uuid));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete service',
      message: 'This permanently deletes "${svc.name}". Continue?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      action: () => client.deleteService(svc.uuid),
      success: 'Service deleted',
    );
    if (done && context.mounted) {
      ref.invalidate(servicesProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }
}
