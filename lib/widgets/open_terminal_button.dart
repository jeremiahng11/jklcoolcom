import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/instances_provider.dart';

/// App-bar action that opens Coolify's web terminal for the active instance.
///
/// Coolify's terminal runs over a session-authenticated websocket (not the
/// REST API), so it can't be embedded — we hand off to the browser instead,
/// where the user picks the server/container and gets a real shell.
class OpenTerminalButton extends ConsumerWidget {
  const OpenTerminalButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeInstanceProvider);
    return IconButton(
      tooltip: 'Open terminal in Coolify',
      onPressed: active == null
          ? null
          : () async {
              final uri = Uri.tryParse(active.terminalUrl);
              if (uri == null) return;
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the browser.')),
                );
              }
            },
      icon: const Icon(Icons.terminal),
    );
  }
}
