import 'package:flutter/material.dart';

import '../../widgets/guide_widgets.dart';

/// In-app guide explaining how to find your Coolify instance URL and create an
/// API token — shown from the add-account screen for first-time users.
class ConnectGuideScreen extends StatelessWidget {
  const ConnectGuideScreen({super.key});

  static const _scopes = <(String, String)>[
    ('read', 'View resources (apps, databases, services, servers)'),
    ('write', 'Create / edit / delete resources & env vars'),
    ('deploy', 'Trigger deploys, start / stop / restart'),
    ('read:sensitive', 'See secret env values & DB connection strings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Connect your Coolify')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'To add an account you need two things: your Coolify instance URL '
            'and an API token. Here\'s where to find both.',
            style: theme.textTheme.bodyMedium,
          ),

          const GuideStep(
            n: 1,
            title: 'Your instance URL',
            body:
                'It\'s simply the address you open your Coolify dashboard at '
                '— the app adds /api/v1 for you.',
          ),
          _UrlRow('Coolify Cloud', 'https://app.coolify.io', muted),
          _UrlRow(
            'Self-hosted (domain)',
            'https://coolify.yourdomain.com',
            muted,
          ),
          _UrlRow('Self-hosted (IP)', 'http://your-server-ip:8000', muted),
          const SizedBox(height: 8),
          Text(
            'On the same Wi-Fi you can use a local address like '
            'http://192.168.0.10:8000 — plain http to a LAN box is supported.',
            style: muted,
          ),

          const GuideStep(
            n: 2,
            title: 'Create an API token',
            body:
                'In Coolify, open Keys & Tokens → API Tokens (or your profile '
                'menu → API Tokens), then Create New Token.',
          ),
          _Bullet('Give it a name, e.g. "Companion app".', muted),
          _Bullet(
            'Pick the permissions you want (see below), then create it.',
            muted,
          ),
          _Bullet(
            'Copy the token immediately — Coolify shows it only once. It looks '
            'like  1|abcDEF…',
            muted,
          ),

          const SizedBox(height: 12),
          GuideSection('Token permissions (scopes)'),
          const SizedBox(height: 4),
          Text(
            'For full app functionality choose read, write & deploy. Add '
            'read:sensitive to view secret env values and DB connection strings.',
            style: muted,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (scope, desc) in _scopes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline, size: 18),
                      title: Text(
                        scope,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(desc),
                    ),
                ],
              ),
            ),
          ),

          const GuideStep(
            n: 3,
            title: 'Add it in the app',
            body:
                'Back on the previous screen, enter the URL and token, tap '
                'Test connection, then Add account.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your token is stored securely on this device (Keychain / '
                    'Keystore) and is only ever sent to your Coolify.',
                    style: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow(this.label, this.url, this.muted);
  final String label;
  final String url;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: muted)),
          Expanded(
            child: SelectableText(
              url,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, this.muted);
  final String text;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: muted),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );
  }
}
