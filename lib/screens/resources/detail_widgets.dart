import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Header block at the top of a resource detail screen: title, status badge,
/// and a row of action buttons.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.statusBadge,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final Widget statusBadge;
  final Widget actions;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                statusBadge,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            actions,
          ],
        ),
      ),
    );
  }
}

/// A titled card grouping [InfoRow]s or other detail widgets. Renders nothing
/// when [children] is empty.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A label/value pair with long-press to copy the value.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied $label')));
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline-editable text field with a save button that fires [onSave].
class EditableField extends StatefulWidget {
  const EditableField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSave,
    this.maxLines = 1,
  });

  final String label;
  final String initialValue;
  final Future<void> Function(String value) onSave;
  final int maxLines;

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialValue,
  );
  bool _dirty = false;

  @override
  void didUpdateWidget(covariant EditableField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue && !_dirty) {
      _c.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c,
        maxLines: widget.maxLines,
        onChanged: (_) {
          if (!_dirty) setState(() => _dirty = true);
        },
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: _dirty
              ? IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    await widget.onSave(_c.text);
                    if (mounted) setState(() => _dirty = false);
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// A red-bordered destructive-action card.
class DangerZone extends StatelessWidget {
  const DangerZone({
    super.key,
    required this.onDelete,
    required this.label,
    required this.description,
  });

  final VoidCallback onDelete;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danger zone',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
