import 'package:flutter/material.dart';

import '../../widgets/guide_widgets.dart';

/// Guide for the advanced path: in-app push via a self-hosted push server.
/// Requires the user's own Firebase project, which means building the app from
/// source — the store build is tied to the publisher's Firebase keys.
class PushServerGuideScreen extends StatelessWidget {
  const PushServerGuideScreen({super.key});

  static const _base64 = 'base64 -w0 service-account.json   # copy the output';

  static const _docker =
      'docker run -d --name coolify-companion-push --restart unless-stopped \\\n'
      '  -p 8090:8090 -v "\$PWD/data:/app/data" \\\n'
      '  -e COOLIFY_URL=http://192.168.0.147:8000 \\\n'
      '  -e COOLIFY_TOKEN=your_coolify_token \\\n'
      '  -e FIREBASE_SERVICE_ACCOUNT_BASE64=<paste-base64> \\\n'
      '  <your-image>';

  static const _verify = 'curl https://push.yourdomain.com/status';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('In-app push (self-hosted)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Advanced. This requires your OWN Firebase project, which means '
              'building the app from source — the installed (store) app uses the '
              'publisher\'s Firebase keys, which can\'t send pushes on your '
              'behalf. Most people should use the no-server option (Coolify '
              'notifications) instead.',
              style: muted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'For notifications branded inside Coolify Companion, run the small '
            'push server (in the project repo under push-server/). It watches '
            'your Coolify and sends FCM pushes that deep-link into the app.',
            style: theme.textTheme.bodyMedium,
          ),

          const GuideStep(
            n: 1,
            title: 'Build the app with your Firebase',
            body:
                'Create a Firebase project, add an Android app, run '
                '`flutterfire configure`, and build the app yourself.',
          ),

          const GuideStep(
            n: 2,
            title: 'Get a service-account key',
            body:
                'Firebase → Project settings → Service accounts → Generate '
                'new private key. Base64-encode it for the server env:',
          ),
          const CodeBlock(_base64),

          const GuideStep(
            n: 3,
            title: 'Deploy the push server',
            body:
                'From push-server/ — build the Dockerfile (e.g. as a Coolify '
                'app) and run it with your env. Expose port 8090 and add a '
                'volume at /app/data.',
          ),
          const CodeBlock(_docker),

          const GuideStep(
            n: 4,
            title: 'Verify',
            body: 'Should report the token count and watched Coolify.',
          ),
          const CodeBlock(_verify),

          const GuideStep(
            n: 5,
            title: 'Connect it',
            body:
                'In the app: Settings → Notifications → enable push → set the '
                'Notification server URL. The token registers automatically.',
          ),

          const SizedBox(height: 16),
          Text(
            'The server prunes dead tokens, seeds silently on first run (no '
            'spam about existing state), and watches one Coolify instance. Full '
            'details are in push-server/README.md.',
            style: muted,
          ),
        ],
      ),
    );
  }
}
