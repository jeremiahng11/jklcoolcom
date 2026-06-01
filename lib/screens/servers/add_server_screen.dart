import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/private_key.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';

/// Connect a new server to the active Coolify instance.
class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _ip = TextEditingController();
  final _user = TextEditingController(text: 'root');
  final _port = TextEditingController(text: '22');
  String? _privateKeyUuid;
  String _proxyType = 'traefik';
  bool _isBuildServer = false;
  bool _instantValidate = true;

  @override
  void dispose() {
    for (final c in [_name, _description, _ip, _user, _port]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(privateKeysProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add server')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text(
                'Provision a new Hetzner server',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/servers/hetzner'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Or connect an existing server below — works with any provider '
            '(Hetzner, DigitalOcean, AWS, Linode, your own VPS…) over SSH.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/servers/connect-cloud'),
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Using another cloud? How to connect'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ip,
            decoration: const InputDecoration(
              labelText: 'IP address / hostname',
              prefixIcon: Icon(Icons.lan_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'SSH user',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'SSH port',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 12),
          keys.when(
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _privateKeyUuid,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'SSH private key',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              items: list
                  .map(
                    (PrivateKey k) => DropdownMenuItem(
                      value: k.uuid,
                      child: Text(k.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _privateKeyUuid = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load keys: $e'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _proxyType,
            decoration: const InputDecoration(
              labelText: 'Proxy',
              prefixIcon: Icon(Icons.alt_route),
            ),
            items: const [
              DropdownMenuItem(value: 'traefik', child: Text('Traefik')),
              DropdownMenuItem(value: 'caddy', child: Text('Caddy')),
              DropdownMenuItem(value: 'none', child: Text('None')),
            ],
            onChanged: (v) => setState(() => _proxyType = v ?? 'traefik'),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            title: const Text('Use as build server'),
            value: _isBuildServer,
            onChanged: (v) => setState(() => _isBuildServer = v),
          ),
          SwitchListTile(
            title: const Text('Validate immediately'),
            value: _instantValidate,
            onChanged: (v) => setState(() => _instantValidate = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty ||
        _ip.text.trim().isEmpty ||
        _privateKeyUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, IP and an SSH key are required.')),
      );
      return;
    }
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () async => client.createServer({
        'name': _name.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'ip': _ip.text.trim(),
        'user': _user.text.trim(),
        'port': int.tryParse(_port.text.trim()) ?? 22,
        'private_key_uuid': _privateKeyUuid,
        'proxy_type': _proxyType,
        'is_build_server': _isBuildServer,
        'instant_validate': _instantValidate,
      }),
      success: 'Server added',
      running: 'Connecting…',
    );
    if (ok && mounted) {
      ref.invalidate(serversProvider);
      context.pop();
    }
  }
}
