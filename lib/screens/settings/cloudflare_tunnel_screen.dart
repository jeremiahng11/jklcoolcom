import 'package:flutter/material.dart';

import '../../widgets/guide_widgets.dart';

/// In-app guide for exposing the metrics agent on a custom domain using a
/// Cloudflare Tunnel — no open ports / port-forwarding required. Mirrors the
/// project's CLOUDFLARE_TUNNEL guide so App Store users have it on-device.
class CloudflareTunnelScreen extends StatelessWidget {
  const CloudflareTunnelScreen({super.key});

  static const _install =
      '# Raspberry Pi (aarch64 / arm64):\n'
      'wget -O /tmp/cloudflared \\\n'
      '  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64\n'
      '\n'
      '# Pi 3 / Zero (armv7):\n'
      '#   ...releases/latest/download/cloudflared-linux-arm\n'
      '# x86_64:\n'
      '#   ...releases/latest/download/cloudflared-linux-amd64\n'
      '\n'
      'sudo mv /tmp/cloudflared /usr/local/bin/\n'
      'sudo chmod +x /usr/local/bin/cloudflared\n'
      'cloudflared --version';

  static const _login = 'cloudflared tunnel login';

  static const _create =
      'cloudflared tunnel create my-tunnel\n'
      'cloudflared tunnel list          # note the Tunnel ID';

  static const _config =
      '# ~/.cloudflared/config.yml\n'
      'tunnel: <YOUR_TUNNEL_ID>\n'
      'credentials-file: /home/<user>/.cloudflared/<YOUR_TUNNEL_ID>.json\n'
      '\n'
      'ingress:\n'
      '  - hostname: metrics.yourdomain.com\n'
      '    service: http://localhost:8088\n'
      '  - service: http_status:404';

  static const _dns =
      'cloudflared tunnel route dns my-tunnel metrics.yourdomain.com';

  static const _run = 'cloudflared tunnel run my-tunnel   # test it';

  static const _serviceFile =
      "sudo tee /etc/systemd/system/cloudflared-tunnel.service > /dev/null << 'EOF'\n"
      '[Unit]\n'
      'Description=Cloudflare Tunnel\n'
      'After=network.target\n'
      '\n'
      '[Service]\n'
      'Type=simple\n'
      'User=<user>\n'
      'ExecStart=/usr/local/bin/cloudflared tunnel run my-tunnel\n'
      'Restart=always\n'
      'RestartSec=10\n'
      '\n'
      '[Install]\n'
      'WantedBy=multi-user.target\n'
      'EOF';

  static const _enable =
      'sudo systemctl daemon-reload\n'
      'sudo systemctl enable --now cloudflared-tunnel\n'
      'sudo systemctl status cloudflared-tunnel';

  static const _useful =
      'cloudflared tunnel list                 # all tunnels\n'
      'cloudflared tunnel info my-tunnel        # status\n'
      'sudo systemctl restart cloudflared-tunnel\n'
      'sudo journalctl -u cloudflared-tunnel -n 50 -f   # logs\n'
      'cloudflared tunnel delete my-tunnel';

  static const _local = 'http://192.168.x.x:8088';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Cloudflare Tunnel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'A Cloudflare Tunnel securely exposes your local agent on a public '
            'domain (e.g. metrics.yourdomain.com) with no open ports and no '
            'port-forwarding. Requires a Cloudflare account with your domain on '
            'Cloudflare DNS.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Tip: step 5 below creates the correct CNAME automatically. Do '
              'NOT add an A record to your home IP — that causes a 503 "no '
              'available server".',
              style: muted,
            ),
          ),

          const GuideStep(
            n: 1,
            title: 'Install cloudflared',
            body: 'Pick the binary for your architecture.',
          ),
          const CodeBlock(_install),

          const GuideStep(
            n: 2,
            title: 'Authenticate',
            body: 'Opens a browser to log in and pick your domain.',
          ),
          const CodeBlock(_login),

          const GuideStep(n: 3, title: 'Create a tunnel'),
          const CodeBlock(_create),

          const GuideStep(
            n: 4,
            title: 'Configure it',
            body:
                'Create ~/.cloudflared/config.yml. Replace the ID, user, '
                'hostname and the local service port (8088 for the agent).',
          ),
          const CodeBlock(_config),

          const GuideStep(
            n: 5,
            title: 'Route DNS (creates the CNAME)',
            body:
                'This adds a CNAME in Cloudflare pointing the hostname at the '
                'tunnel — the right way (not an A record).',
          ),
          const CodeBlock(_dns),

          const GuideStep(n: 6, title: 'Test'),
          const CodeBlock(_run),

          const GuideSection('Auto-start on reboot (systemd)'),
          const CodeBlock(_serviceFile),
          const CodeBlock(_enable),

          const GuideSection('Troubleshooting'),
          _Bullet(
            'DNS not resolving — check Cloudflare → DNS; the record should be a '
            'CNAME to <id>.cfargotunnel.com. Allow a few minutes to propagate.',
            muted,
          ),
          _Bullet(
            '"No available server" (503) — your local service isn\'t reachable. '
            'Confirm it runs: curl http://localhost:8088/health, and that the '
            'service: URL/port in config.yml matches.',
            muted,
          ),
          _Bullet(
            'Tunnel not connecting — check logs: '
            'sudo journalctl -u cloudflared-tunnel -n 50, and that the '
            'credentials file in config.yml exists.',
            muted,
          ),

          const GuideSection('Useful commands'),
          const CodeBlock(_useful),

          const GuideSection('Security'),
          _Bullet(
            'Traffic is encrypted end-to-end and no router ports are opened. '
            'The agent token still gates access — keep it long. You can add '
            'Cloudflare Access in front for extra protection.',
            muted,
          ),

          const GuideSection('Local-only alternative'),
          Text(
            'If you only need access on the same Wi-Fi, skip the tunnel and use '
            'the agent\'s LAN address directly:',
            style: muted,
          ),
          const CodeBlock(_local),

          const SizedBox(height: 16),
          Text(
            'Once live, set the app\'s agent URL to '
            'https://metrics.yourdomain.com and the agent token.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, this.style);
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
