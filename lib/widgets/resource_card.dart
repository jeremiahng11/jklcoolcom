import 'package:flutter/material.dart';

import '../models/resource.dart';
import '../models/status.dart';
import 'status_badge.dart';

IconData iconForKind(ResourceKind kind) {
  switch (kind) {
    case ResourceKind.application:
      return Icons.rocket_launch_outlined;
    case ResourceKind.database:
      return Icons.storage_rounded;
    case ResourceKind.service:
      return Icons.widgets_outlined;
    case ResourceKind.unknown:
      return Icons.dashboard_outlined;
  }
}

/// A tappable card representing any resource, with an icon, name, type and
/// status badge.
class ResourceCard extends StatelessWidget {
  const ResourceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ResourceStatus status;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: status.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ?? StatusBadge(status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
