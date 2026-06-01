import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/project.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: AsyncValueView<List<Project>>(
        value: projects,
        onRetry: () => ref.invalidate(projectsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              title: 'No projects',
              message: 'Create a project to organise your resources.',
              action: FilledButton.icon(
                onPressed: () => _createProject(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New project'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(projectsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(p.name),
                    subtitle: Text(
                      p.description.isEmpty
                          ? '${p.environments.length} environment'
                                '${p.environments.length == 1 ? '' : 's'}'
                          : p.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/projects/${p.uuid}'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New project'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
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
      action: () => client.createProject({'name': name}),
      success: 'Project created',
    );
    if (ok) ref.invalidate(projectsProvider);
  }
}
