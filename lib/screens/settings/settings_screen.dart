import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/instances_provider.dart';
import '../../providers/lock_provider.dart';
import '../../providers/push_provider.dart';
import '../../providers/resource_providers.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/account_action.dart';
import '../instance_switcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final active = ref.watch(activeInstanceProvider);
    final version = ref.watch(versionProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const AccountAction(),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _header(context, 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: active == null
                  ? Colors.grey
                  : Color(active.accentColor),
              child: Text(
                (active?.label.isNotEmpty ?? false)
                    ? active!.label[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(active?.label ?? 'No account'),
            subtitle: Text(active?.host ?? 'Add a Coolify instance'),
            trailing: const Icon(Icons.swap_horiz),
            onTap: () => showInstanceSwitcher(context),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add another account'),
            onTap: () => context.push('/add-instance'),
          ),
          const Divider(),
          _header(context, 'Manage'),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/team'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/servers'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Projects'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/projects'),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('SSH keys'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/keys'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Cloud tokens & provisioning'),
            subtitle: const Text('Provision Hetzner servers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/cloud-tokens'),
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Live metrics setup'),
            subtitle: const Text('Install the agent for CPU / RAM / disk'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/metrics-setup'),
          ),
          const Divider(),
          _header(context, 'Notifications'),
          _PushTile(),
          const Divider(),
          _header(context, 'Security'),
          _AppLockTile(),
          const Divider(),
          _header(context, 'Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (m) {
              if (m != null) ref.read(themeModeProvider.notifier).set(m);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                  secondary: Icon(Icons.dark_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                  secondary: Icon(Icons.light_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Follow system'),
                  secondary: Icon(Icons.brightness_auto_outlined),
                ),
              ],
            ),
          ),
          const Divider(),
          _header(context, 'About'),
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: const Text('Open Coolify dashboard'),
            subtitle: Text(active?.dashboardUrl ?? ''),
            enabled: active != null,
            onTap: active == null
                ? null
                : () {
                    final uri = Uri.tryParse(active.dashboardUrl);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
          ),
          const ListTile(
            leading: Icon(Icons.token_outlined),
            title: Text('Token scopes'),
            subtitle: Text(
              'For full control, your API token needs read, write & deploy. '
              'Connection strings and secret env values also need '
              'read:sensitive.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flutter_dash),
            title: const Text('Coolify Companion'),
            subtitle: Text(
              version.maybeWhen(
                data: (v) =>
                    v.isEmpty ? 'App v1.0.0' : 'App v1.0.0  ·  Coolify v$v',
                orElse: () => 'App v1.0.0',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _PushTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PushTile> createState() => _PushTileState();
}

class _PushTileState extends ConsumerState<_PushTile> {
  final _server = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final push = ref.watch(pushProvider);
    final theme = Theme.of(context);
    if (!_seeded && push.serverUrl.isNotEmpty) {
      _server.text = push.serverUrl;
      _seeded = true;
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Push notifications'),
          subtitle: Text(
            push.available
                ? 'Get notified about deployments and resource health'
                : 'Not available — Firebase isn\'t configured for this build',
          ),
          value: push.enabled,
          onChanged: push.available
              ? (v) => ref.read(pushProvider.notifier).setEnabled(v)
              : null,
        ),
        if (push.enabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Notification server URL',
                          hintText: 'https://push.yourdomain.com',
                          isDense: true,
                          prefixIcon: const Icon(Icons.dns_outlined),
                          helperText: push.serverUrl.isEmpty
                              ? 'Optional — for automatic deploy/health alerts'
                              : (push.registered
                                    ? 'Registered ✓'
                                    : 'Not registered — check the URL'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => ref
                          .read(pushProvider.notifier)
                          .setServerUrl(_server.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (push.token != null)
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Device token'),
              subtitle: Text(
                push.token!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: push.token!));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Token copied')));
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'No server? You can still send test notifications from the '
              'Firebase console using the token above.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Require biometric unlock'),
      subtitle: const Text(
        'Protect saved API tokens with Face ID / fingerprint',
      ),
      value: lock.enabled,
      onChanged: (v) async {
        final notifier = ref.read(appLockProvider.notifier);
        if (v) {
          final supported = await notifier.isSupported();
          if (!supported) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No biometrics or device passcode set up on this device.',
                  ),
                ),
              );
            }
            return;
          }
        }
        await notifier.setEnabled(v);
      },
    );
  }
}
