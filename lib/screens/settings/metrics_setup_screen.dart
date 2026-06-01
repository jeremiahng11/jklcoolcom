import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/instances_provider.dart';
import '../../widgets/guide_widgets.dart';

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

          const GuideStep(
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
          const CodeBlock(_install),

          const GuideStep(n: 2, title: 'Create a secret token'),
          const CodeBlock(_token),

          const GuideStep(
            n: 3,
            title: 'Install the service',
            body:
                'Save the service file and replace CHANGE_ME with your token.',
          ),
          const _AssetBlock(
            asset: 'agent/coolify-companion-agent.service',
            copyLabel: 'Copy service file',
          ),
          const CodeBlock(_service),

          const GuideStep(n: 4, title: 'Start it'),
          const CodeBlock(_enable),

          const GuideStep(
            n: 5,
            title: 'Verify (optional)',
            body: 'Should return a JSON blob of metrics.',
          ),
          const CodeBlock(_verify),

          const GuideStep(
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Access from anywhere'),
              subtitle: const Text(
                'Expose the agent on your own domain with Cloudflare Tunnel '
                '(no open ports)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/cloudflare-tunnel'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The agent only needs Python 3 (preinstalled on Raspberry Pi OS / '
            'Debian). It runs as a non-root service, only reads system stats, '
            'and should stay on your local network unless tunnelled.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          child: OutlinedButton.icon(
            onPressed: ready
                ? () => copyToClipboard(context, snap.data!)
                : null,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(
              ready ? copyLabel : 'Loading…',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
