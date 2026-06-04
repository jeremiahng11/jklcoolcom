import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/instances_provider.dart';
import '../../../providers/resource_providers.dart';
import '../../../widgets/action_runner.dart';
import 'create_common.dart';

/// A small curated set of Coolify one-click service types. The API accepts the
/// full catalogue via the `type` field; users can also paste a docker-compose.
const _oneClickServices = <String, String>{
  'activepieces': 'Activepieces',
  'appwrite': 'Appwrite',
  'cloudflare-ddns': 'Cloudflare DDNS',
  'directus': 'Directus',
  'emqx-enterprise': 'EMQX',
  'ghost': 'Ghost',
  'gitea': 'Gitea',
  'grafana': 'Grafana',
  'healthchecks': 'Healthchecks',
  'hermes-agent-with-webui': 'Hermes Agent + WebUI',
  'metabase': 'Metabase',
  'minio': 'MinIO',
  'n8n': 'n8n',
  'nocodb': 'NocoDB',
  'openobserve': 'OpenObserve',
  'plausible': 'Plausible Analytics',
  'pocketbase': 'PocketBase',
  'umami': 'Umami',
  'uptime-kuma': 'Uptime Kuma',
  'vaultwarden': 'Vaultwarden',
  'wordpress-with-mysql': 'WordPress + MySQL',
};

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  DeploymentTarget _target = const DeploymentTarget();
  bool _useCompose = false;
  String? _type = 'pocketbase';
  final _name = TextEditingController();
  final _compose = TextEditingController();
  bool _instantDeploy = true;

  @override
  void dispose() {
    _name.dispose();
    _compose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TargetSelector(
            target: _target,
            onChanged: (t) => setState(() => _target = t),
          ),
          const Divider(height: 32),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('One-click')),
              ButtonSegment(value: true, label: Text('Docker Compose')),
            ],
            selected: {_useCompose},
            onSelectionChanged: (s) => setState(() => _useCompose = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          if (!_useCompose)
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Service',
                prefixIcon: Icon(Icons.widgets_outlined),
              ),
              items: _oneClickServices.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v),
            )
          else
            TextField(
              controller: _compose,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'docker-compose.yml',
                alignLabelWithHint: true,
                hintText: 'services:\n  app:\n    image: …',
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Deploy immediately'),
            value: _instantDeploy,
            onChanged: (v) => setState(() => _instantDeploy = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Create service'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (!_target.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a server, project and environment first.'),
        ),
      );
      return;
    }
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;

    final body = <String, dynamic>{
      ..._target.toBody(),
      if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
      'instant_deploy': _instantDeploy,
    };
    if (_useCompose) {
      if (_compose.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paste a docker-compose file.')),
        );
        return;
      }
      // docker_compose_raw is base64-encoded.
      body['docker_compose_raw'] = base64.encode(utf8.encode(_compose.text));
    } else {
      body['type'] = _type;
    }

    final ok = await runAction(
      context,
      action: () async => client.createService(body),
      success: 'Service created',
      running: 'Creating…',
    );
    if (ok && mounted) {
      ref.invalidate(servicesProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }
}
