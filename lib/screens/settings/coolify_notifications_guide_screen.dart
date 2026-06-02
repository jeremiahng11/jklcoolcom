import 'package:flutter/material.dart';

import '../../widgets/guide_widgets.dart';

/// Guide for the no-server notification path: enabling Coolify's own
/// notification channels (Telegram / ntfy / Discord / …). Works even when
/// Coolify is on a private network, and nothing leaves the user's server.
class CoolifyNotificationsGuideScreen extends StatelessWidget {
  const CoolifyNotificationsGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Real-time alerts (no server)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'The simplest way to get notified is to let Coolify send the alerts '
            'itself — for deployments and status changes. It works even when '
            'Coolify is on your home network, nothing leaves your server, and '
            'there\'s nothing to host. You set this up once, in Coolify.',
            style: theme.textTheme.bodyMedium,
          ),

          const GuideStep(
            n: 1,
            title: 'Open Coolify notifications',
            body:
                'In Coolify: Settings → Notifications (channels can also be '
                'set per project).',
          ),

          const GuideStep(
            n: 2,
            title: 'Pick a channel',
            body: 'Coolify supports several — choose whatever you already use:',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: const [
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.campaign_outlined),
                    title: Text('ntfy'),
                    subtitle: Text('Easiest — free, open, no account'),
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.send_outlined),
                    title: Text('Telegram'),
                    subtitle: Text('Popular, reliable'),
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.discord),
                    title: Text('Discord / Slack'),
                    subtitle: Text('Post to a channel'),
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.notifications_active_outlined),
                    title: Text('Pushover / Email'),
                    subtitle: Text('Also supported'),
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.webhook_outlined),
                    title: Text('Webhook'),
                    subtitle: Text('Posts to any URL — pipe it into ntfy'),
                  ),
                ],
              ),
            ),
          ),

          const GuideSection('ntfy (recommended — easiest)'),
          _Bullet('Install the free ntfy app (iOS / Android).', muted),
          _Bullet(
            'Choose a private topic name — something random, e.g. '
            'coolify-7f3a9c.',
            muted,
          ),
          _Bullet(
            'In Coolify → Notifications → ntfy: server https://ntfy.sh and your '
            'topic.',
            muted,
          ),
          _Bullet('In the ntfy app, subscribe to that same topic.', muted),

          const GuideSection('Telegram'),
          _Bullet(
            'In Telegram, message @BotFather → /newbot → copy the bot token.',
            muted,
          ),
          _Bullet(
            'Get your chat id (message @userinfobot, or send your bot a '
            'message and read getUpdates).',
            muted,
          ),
          _Bullet(
            'In Coolify → Notifications → Telegram: paste the bot token + chat '
            'id.',
            muted,
          ),

          const GuideSection('Webhook → ntfy'),
          _Bullet(
            'Spotted the Webhook box in Coolify? It just POSTs each alert to a '
            'URL you choose. A phone can\'t receive that directly, but ntfy '
            'can — and it turns the POST into a push on your device.',
            muted,
          ),
          _Bullet(
            'Pick a private topic name (e.g. coolify-7f3a9c) and install the '
            'free ntfy app and subscribe to it.',
            muted,
          ),
          _Bullet(
            'In Coolify → Notifications → Webhook, set the URL to '
            'https://ntfy.sh/your-topic — that\'s the whole setup.',
            muted,
          ),
          _Bullet(
            'Same result as the ntfy channel above; use whichever box your '
            'Coolify version shows.',
            muted,
          ),

          const GuideStep(
            n: 3,
            title: 'Choose events & save',
            body:
                'Enable the events you want (deployments, status changes), '
                'save, and send a test.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Alerts arrive in that app (ntfy / Telegram / …), not inside '
              'Coolify Companion. For notifications branded in this app, see the '
              'self-hosted push server option — but for most people the above is '
              'the best choice.',
              style: muted,
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
