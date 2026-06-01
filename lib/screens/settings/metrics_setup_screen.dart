import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/instances_provider.dart';

/// In-app guide for installing the metrics agent on a server. Self-contained
/// (the agent script + service file are bundled as assets) so it works in App
/// Store builds without the source repo.
class MetricsSetupScreen extends ConsumerWidget {
  const MetricsSetupScreen({super.key});

  static const _install =
      'sudo mkdir -p /opt/coolify-companion-agent\n'
      'sudo nano /opt/coolify-companion-agent/agent.py   # paste the script, save';

  static const _token = 'openssl rand -hex 24            # copy this value';

  static const _service =
      'sudo nano /etc/systemd/system/coolify-companion-agent.service\n'
      '#   paste the service file, replace CHANGE_ME with your token';

  static const _enable =
      'sudo systemctl daemon-reload\n'
      'sudo systemctl enable --now coolify-companion-agent';

  static const _verify =
      'curl -H "Authorization: Bearer <token>" http://localhost:8088/metrics';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeInstanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Live metrics setup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Coolify\'s API doesn\'t expose realtime CPU / memory / disk, so '
            'live metrics come from a tiny agent you run on your server. It '
            'only reads system stats, needs no root, and stays on your LAN.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          const _Step(
            n: 1,
            title: 'Get the agent script',
            body:
                'Copy the script and save it on your server as '
                '/opt/coolify-companion-agent/agent.py.',
          ),
          const _AssetBlock(
            asset: 'agent/agent.py',
            copyLabel: 'Copy agent.py',
          ),
          const _CodeBlock(text: _install),

          const _Step(n: 2, title: 'Create a secret token'),
          const _CodeBlock(text: _token),

          const _Step(
            n: 3,
            title: 'Install the service',
            body:
                'Save the service file and replace CHANGE_ME with your token.',
          ),
          const _AssetBlock(
            asset: 'agent/coolify-companion-agent.service',
            copyLabel: 'Copy service file',
          ),
          const _CodeBlock(text: _service),

          const _Step(n: 4, title: 'Start it'),
          const _CodeBlock(text: _enable),

          const _Step(
            n: 5,
            title: 'Verify (optional)',
            body: 'Should return a JSON blob of metrics.',
          ),
          const _CodeBlock(text: _verify),

          const _Step(
            n: 6,
            title: 'Connect it in the app',
            body:
                'Edit your account → Live metrics → set the agent URL '
                '(http://<server-ip>:8088) and the token from step 2.',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.pushReplacement(
              active != null ? '/edit-instance/${active.id}' : '/add-instance',
            ),
            icon: const Icon(Icons.tune),
            label: const Text('Open account settings'),
          ),
          const SizedBox(height: 24),
          Text(
            'The agent only needs Python 3 (preinstalled on Raspberry Pi OS / '
            'Debian). It runs as a non-root service, only reads system stats, '
            'and should stay on your local network.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, this.body});
  final int n;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$n',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A copyable code/command block.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.5,
                color: Color(0xFFD1D5DB),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(context, text),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads a bundled asset and offers to copy it (used for the agent files).
class _AssetBlock extends StatelessWidget {
  const _AssetBlock({required this.asset, required this.copyLabel});
  final String asset;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(asset),
      builder: (context, snap) {
        final ready = snap.hasData;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ready ? () => _copy(context, snap.data!) : null,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(
                    ready ? copyLabel : 'Loading…',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
}
