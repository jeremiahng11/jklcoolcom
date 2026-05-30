import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/env_var.dart';
import '../providers/instances_provider.dart';
import '../providers/resource_providers.dart';
import 'action_runner.dart';
import 'async_value_view.dart';
import 'empty_state.dart';

/// Lists, creates, edits and deletes environment variables for a resource.
///
/// [kind] is the API path segment: `applications`, `databases`, `services`.
class EnvVarEditor extends ConsumerWidget {
  const EnvVarEditor({super.key, required this.kind, required this.uuid});

  final String kind;
  final String uuid;

  EnvKey get _key => (kind: kind, uuid: uuid);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envs = ref.watch(envsProvider(_key));
    return Scaffold(
      body: AsyncValueView<List<EnvVar>>(
        value: envs,
        onRetry: () => ref.invalidate(envsProvider(_key)),
        data: (vars) {
          if (vars.isEmpty) {
            return EmptyState(
              icon: Icons.tune,
              title: 'No environment variables',
              message: 'Add a variable to configure this resource.',
              action: FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add variable'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(envsProvider(_key)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: vars.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EnvTile(
                env: vars[i],
                onEdit: () => _edit(context, ref, existing: vars[i]),
                onDelete: () => _delete(context, ref, vars[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: envs.hasValue && envs.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, EnvVar env) async {
    final ok = await confirmAction(
      context,
      title: 'Delete variable',
      message: 'Remove "${env.key}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteEnv(kind, uuid, env.uuid),
      success: 'Variable deleted',
    );
    if (done) ref.invalidate(envsProvider(_key));
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    EnvVar? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EnvForm(kind: kind, uuid: uuid, existing: existing),
    );
    if (saved == true) ref.invalidate(envsProvider(_key));
  }
}

class _EnvTile extends StatelessWidget {
  const _EnvTile({
    required this.env,
    required this.onEdit,
    required this.onDelete,
  });

  final EnvVar env;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flags = <String>[
      if (env.isBuildTime) 'build',
      if (env.isPreview) 'preview',
      if (env.isLiteral) 'literal',
      if (env.isMultiline) 'multiline',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    env.key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    env.isShownOnce && env.value.isEmpty
                        ? '••••••••'
                        : env.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (flags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: flags
                          .map(
                            (f) => Chip(
                              label: Text(f),
                              labelStyle: const TextStyle(fontSize: 10),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'copy') {
                  Clipboard.setData(ClipboardData(text: env.value));
                }
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'copy', child: Text('Copy value')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvForm extends ConsumerStatefulWidget {
  const _EnvForm({required this.kind, required this.uuid, this.existing});

  final String kind;
  final String uuid;
  final EnvVar? existing;

  @override
  ConsumerState<_EnvForm> createState() => _EnvFormState();
}

class _EnvFormState extends ConsumerState<_EnvForm> {
  late final TextEditingController _key = TextEditingController(
    text: widget.existing?.key,
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.existing?.value,
  );
  late bool _preview = widget.existing?.isPreview ?? false;
  late bool _buildTime = widget.existing?.isBuildTime ?? false;
  late bool _literal = widget.existing?.isLiteral ?? false;
  late bool _multiline = widget.existing?.isMultiline ?? false;

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, insets + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'Edit variable' : 'New variable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            enabled: !editing, // key is the identifier on update
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(labelText: 'Key'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            maxLines: _multiline ? 5 : 1,
            decoration: const InputDecoration(labelText: 'Value'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Build-time'),
                selected: _buildTime,
                onSelected: (v) => setState(() => _buildTime = v),
              ),
              FilterChip(
                label: const Text('Preview'),
                selected: _preview,
                onSelected: (v) => setState(() => _preview = v),
              ),
              FilterChip(
                label: const Text('Literal'),
                selected: _literal,
                onSelected: (v) => setState(() => _literal = v),
              ),
              FilterChip(
                label: const Text('Multiline'),
                selected: _multiline,
                onSelected: (v) => setState(() => _multiline = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(editing ? 'Save' : 'Add variable'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_key.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Key is required')));
      return;
    }
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final body = {
      'key': _key.text.trim(),
      'value': _value.text,
      'is_preview': _preview,
      'is_build_time': _buildTime,
      'is_literal': _literal,
      'is_multiline': _multiline,
    };
    final ok = await runAction(
      context,
      action: () => widget.existing == null
          ? client.createEnv(widget.kind, widget.uuid, body)
          : client.updateEnv(widget.kind, widget.uuid, body),
      success: widget.existing == null ? 'Variable added' : 'Variable saved',
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
