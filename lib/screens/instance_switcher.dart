import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/instances_provider.dart';
import '../widgets/action_runner.dart';

/// Bottom sheet to switch between, add, edit and remove Coolify accounts.
Future<void> showInstanceSwitcher(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const _InstanceSwitcherSheet(),
  );
}

class _InstanceSwitcherSheet extends ConsumerWidget {
  const _InstanceSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instancesProvider).value;
    final instances = state?.instances ?? const [];
    final activeId = state?.active?.id;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text('Accounts', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  '${instances.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...instances.map((i) {
            final color = Color(i.accentColor);
            final active = i.id == activeId;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: Text(
                  i.label.isNotEmpty ? i.label[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(i.label),
              subtitle: Text(
                i.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active)
                    Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        Navigator.of(context).pop();
                        context.push('/edit-instance/${i.id}');
                      } else if (v == 'delete') {
                        final ok = await confirmAction(
                          context,
                          title: 'Remove account',
                          message:
                              'Remove "${i.label}"? Your Coolify data is not '
                              'affected — only this connection is removed.',
                          confirmLabel: 'Remove',
                          destructive: true,
                        );
                        if (ok) {
                          await ref
                              .read(instancesProvider.notifier)
                              .remove(i.id);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ],
              ),
              onTap: active
                  ? null
                  : () async {
                      await ref
                          .read(instancesProvider.notifier)
                          .setActive(i.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
            );
          }),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add another account'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/add-instance');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
