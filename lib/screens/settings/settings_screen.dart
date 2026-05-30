import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/instances_provider.dart';
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
    final theme = Theme.of(context);

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
          version.maybeWhen(
            data: (v) => v.isEmpty
                ? const SizedBox.shrink()
                : ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Coolify version'),
                    trailing: Text('v$v', style: theme.textTheme.bodyMedium),
                  ),
            orElse: () => const SizedBox.shrink(),
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
          const ListTile(
            leading: Icon(Icons.flutter_dash),
            title: Text('Coolify Companion'),
            subtitle: Text('Version 1.0.0'),
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
