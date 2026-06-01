import 'package:flutter/material.dart';

import '../../widgets/guide_widgets.dart';

/// Explains how to use any cloud provider with Coolify by connecting an
/// existing server over SSH (since Coolify's API only *provisions* Hetzner).
class ConnectCloudGuideScreen extends StatelessWidget {
  const ConnectCloudGuideScreen({super.key});

  static const _providers = <(IconData, String, String)>[
    (Icons.water_drop_outlined, 'DigitalOcean', 'Create a Droplet (Ubuntu)'),
    (Icons.cloud_outlined, 'AWS', 'Launch an EC2 instance'),
    (Icons.dns_outlined, 'Linode / Akamai', 'Create a Linode'),
    (Icons.bolt_outlined, 'Vultr', 'Deploy a Cloud Compute instance'),
    (Icons.public, 'Oracle Cloud', 'Create a VM (generous free tier)'),
    (Icons.computer_outlined, 'Your own VPS / bare metal', 'Any Linux host'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Connect a cloud server')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Coolify connects to any Linux server over SSH, so you can use any '
            'provider. In-app one-click provisioning is Hetzner-only (that\'s '
            'the only provider Coolify\'s API can create) — for everything else, '
            'create the server on that provider, then connect it here.',
            style: theme.textTheme.bodyMedium,
          ),

          const GuideSection('Common providers'),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (icon, name, hint) in _providers)
                    ListTile(
                      dense: true,
                      leading: Icon(icon, size: 20),
                      title: Text(name),
                      subtitle: Text(hint),
                    ),
                ],
              ),
            ),
          ),

          const GuideStep(
            n: 1,
            title: 'Create the server',
            body:
                'Spin up a fresh Ubuntu 22.04/24.04 or Debian server on your '
                'provider. Add your SSH public key during creation if it lets '
                'you (most do).',
          ),

          const GuideStep(
            n: 2,
            title: 'Note its connection details',
            body: 'Public IP, SSH user (often root or ubuntu) and port (22).',
          ),

          const GuideStep(
            n: 3,
            title: 'Add your SSH key',
            body:
                'If you didn\'t set a key at creation, add your private key '
                'under Settings → SSH keys so Coolify can connect.',
          ),

          const GuideStep(
            n: 4,
            title: 'Connect it here',
            body:
                'On "Add server", fill in the IP / user / port, pick the SSH '
                'key, choose a proxy (Traefik), and validate.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Coolify installs what it needs (Docker, proxy) when it validates '
              'the connection — a clean Ubuntu/Debian server is all you need.',
              style: muted,
            ),
          ),
        ],
      ),
    );
  }
}
