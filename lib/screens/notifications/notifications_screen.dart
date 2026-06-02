import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty) ...[
            IconButton(
              tooltip: 'Mark all read',
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              icon: const Icon(Icons.done_all),
            ),
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => ref.read(notificationsProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message:
                  'Enable in-app alerts in Settings → Notifications and alerts '
                  'will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _Tile(item: items[i]),
            ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.read
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          child: Icon(
            item.read ? Icons.notifications_none : Icons.notifications_active,
            color: item.read
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.body.isNotEmpty) Text(item.body),
            const SizedBox(height: 2),
            Text(
              DateFormat.MMMd().add_jm().format(item.time.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: item.body.isNotEmpty,
        trailing: item.route != null ? const Icon(Icons.chevron_right) : null,
        onTap: () {
          ref.read(notificationsProvider.notifier).markRead(item.id);
          if (item.route != null) context.push(item.route!);
        },
      ),
    );
  }
}
