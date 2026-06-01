import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/project.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../resources/detail_widgets.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(uuid));
    return Scaffold(
      appBar: AppBar(
        title: Text(project.value?.name ?? 'Project'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(projectProvider(uuid)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncValueView<Project>(
        value: project,
        onRetry: () => ref.invalidate(projectProvider(uuid)),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(projectProvider(uuid)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DetailSection(
                title: 'Project',
                children: [
                  InfoRow('Name', p.name),
                  if (p.description.isNotEmpty)
                    InfoRow('Description', p.description),
                  InfoRow('Environments', '${p.environments.length}'),
                  InfoRow('UUID', p.uuid),
                ],
              ),

              // Environments with add / delete.
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ENVIRONMENTS',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _createEnvironment(context, ref),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        if (p.environments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No environments yet.'),
                          )
                        else
                          for (final e in p.environments)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.layers_outlined),
                              title: Text(e.name),
                              subtitle: e.description.isEmpty
                                  ? null
                                  : Text(e.description),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _deleteEnvironment(context, ref, e.name),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),

              // Edit
              EditableField(
                label: 'Name',
                initialValue: p.name,
                onSave: (v) => _patch(context, ref, {'name': v}),
              ),
              EditableField(
                label: 'Description',
                initialValue: p.description,
                onSave: (v) => _patch(context, ref, {'description': v}),
              ),
              const SizedBox(height: 16),
              DangerZone(
                label: 'Delete project',
                description:
                    'Delete this project and all its environments. Resources in '
                    'it must be removed first.',
                onDelete: () => _delete(context, ref, p.name),
              ),
            ],
          ),
        ),
      ),
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
      action: () => client.updateProject(uuid, body),
      success: 'Saved',
    );
    if (ok) {
      ref.invalidate(projectProvider(uuid));
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _createEnvironment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New environment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Environment name',
            hintText: 'staging',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createEnvironment(uuid, name),
      success: 'Environment created',
    );
    if (ok) {
      ref.invalidate(projectProvider(uuid));
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _deleteEnvironment(
    BuildContext context,
    WidgetRef ref,
    String envName,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete environment',
      message: 'Delete environment "$envName"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteEnvironment(uuid, envName),
      success: 'Environment deleted',
    );
    if (done) {
      ref.invalidate(projectProvider(uuid));
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await confirmAction(
      context,
      title: 'Delete project',
      message: 'Delete "$name" and all its environments?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteProject(uuid),
      success: 'Project deleted',
    );
    if (done && context.mounted) {
      ref.invalidate(projectsProvider);
      context.pop();
    }
  }
}
