import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cloud.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';

/// Provision a brand-new server on Hetzner Cloud from a stored cloud token.
class HetznerProvisionScreen extends ConsumerStatefulWidget {
  const HetznerProvisionScreen({super.key});

  @override
  ConsumerState<HetznerProvisionScreen> createState() =>
      _HetznerProvisionScreenState();
}

class _HetznerProvisionScreenState
    extends ConsumerState<HetznerProvisionScreen> {
  final _name = TextEditingController(text: 'coolify-node');
  String? _cloudTokenUuid;
  String? _location;
  String? _serverType;
  String? _image;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(cloudTokensProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Provision on Hetzner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Server name',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          tokens.when(
            data: (list) {
              if (list.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No cloud tokens yet. Add a Hetzner token first.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/cloud-tokens'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add cloud token'),
                    ),
                  ],
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: _cloudTokenUuid,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cloud token',
                  prefixIcon: Icon(Icons.vpn_lock_outlined),
                ),
                items: list
                    .map(
                      (CloudToken t) => DropdownMenuItem(
                        value: t.uuid,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cloudTokenUuid = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load tokens: $e'),
          ),
          const SizedBox(height: 12),
          _HetznerDropdown(
            kind: 'locations',
            label: 'Location',
            icon: Icons.place_outlined,
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 12),
          _HetznerDropdown(
            kind: 'server-types',
            label: 'Server type',
            icon: Icons.memory_outlined,
            value: _serverType,
            onChanged: (v) => setState(() => _serverType = v),
          ),
          const SizedBox(height: 12),
          _HetznerDropdown(
            kind: 'images',
            label: 'Image',
            icon: Icons.album_outlined,
            value: _image,
            onChanged: (v) => setState(() => _image = v),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _provision,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Provision server'),
          ),
          const SizedBox(height: 8),
          Text(
            'This creates a real server on your Hetzner account and may incur '
            'charges.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _provision() async {
    if (_cloudTokenUuid == null ||
        _location == null ||
        _serverType == null ||
        _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all fields first.')),
      );
      return;
    }
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () async => client.provisionHetznerServer({
        'name': _name.text.trim(),
        'cloud_token_uuid': _cloudTokenUuid,
        'location': _location,
        'server_type': _serverType,
        'image': _image,
      }),
      success: 'Server provisioning started',
      running: 'Provisioning…',
    );
    if (ok && mounted) {
      ref.invalidate(serversProvider);
      context.pop();
    }
  }
}

class _HetznerDropdown extends ConsumerWidget {
  const _HetznerDropdown({
    required this.kind,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String kind;
  final String label;
  final IconData icon;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(hetznerOptionsProvider(kind));
    return options.when(
      data: (list) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        items: list
            .map(
              (HetznerOption o) => DropdownMenuItem(
                value: o.id,
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: const LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load $label: $e'),
    );
  }
}
