import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/instances_provider.dart';
import '../../../providers/resource_providers.dart';
import '../../../widgets/action_runner.dart';
import 'create_common.dart';

/// The five ways Coolify can create an application.
enum AppSource {
  publicRepo('Public Git repo'),
  privateDeployKey('Private repo (deploy key)'),
  privateGithubApp('Private repo (GitHub App)'),
  dockerfile('Dockerfile'),
  dockerImage('Docker image');

  const AppSource(this.label);
  final String label;
}

class CreateApplicationScreen extends ConsumerStatefulWidget {
  const CreateApplicationScreen({super.key});

  @override
  ConsumerState<CreateApplicationScreen> createState() =>
      _CreateApplicationScreenState();
}

class _CreateApplicationScreenState
    extends ConsumerState<CreateApplicationScreen> {
  DeploymentTarget _target = const DeploymentTarget();
  AppSource _source = AppSource.publicRepo;

  final _name = TextEditingController();
  final _repo = TextEditingController(text: 'https://github.com/');
  final _branch = TextEditingController(text: 'main');
  final _ports = TextEditingController(text: '3000');
  final _image = TextEditingController();
  final _imageTag = TextEditingController(text: 'latest');
  final _dockerfile = TextEditingController();
  bool _instantDeploy = true;
  String? _privateKeyUuid;
  String? _githubAppUuid;
  String _buildPack = 'nixpacks';

  @override
  void dispose() {
    for (final c in [
      _name,
      _repo,
      _branch,
      _ports,
      _image,
      _imageTag,
      _dockerfile,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _needsRepo =>
      _source == AppSource.publicRepo ||
      _source == AppSource.privateDeployKey ||
      _source == AppSource.privateGithubApp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New application')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TargetSelector(
            target: _target,
            onChanged: (t) => setState(() => _target = t),
          ),
          const Divider(height: 32),
          DropdownButtonFormField<AppSource>(
            initialValue: _source,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Source',
              prefixIcon: Icon(Icons.source_outlined),
            ),
            items: AppSource.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _source = v ?? _source),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          if (_needsRepo) ...[
            TextField(
              controller: _repo,
              decoration: const InputDecoration(
                labelText: 'Git repository',
                prefixIcon: Icon(Icons.code),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _branch,
              decoration: const InputDecoration(
                labelText: 'Branch',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ports,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Exposed port',
                prefixIcon: Icon(Icons.lan_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _buildPack,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Build pack',
                prefixIcon: Icon(Icons.construction_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'nixpacks', child: Text('Nixpacks')),
                DropdownMenuItem(value: 'static', child: Text('Static site')),
                DropdownMenuItem(
                  value: 'dockerfile',
                  child: Text('Dockerfile (in repo)'),
                ),
                DropdownMenuItem(
                  value: 'dockercompose',
                  child: Text('Docker Compose (in repo)'),
                ),
              ],
              onChanged: (v) => setState(() => _buildPack = v ?? 'nixpacks'),
            ),
            if (_source == AppSource.privateDeployKey) ...[
              const SizedBox(height: 12),
              _PrivateKeyPicker(
                value: _privateKeyUuid,
                onChanged: (v) => setState(() => _privateKeyUuid = v),
              ),
            ],
            if (_source == AppSource.privateGithubApp) ...[
              const SizedBox(height: 12),
              _GithubAppPicker(
                value: _githubAppUuid,
                onChanged: (v) => setState(() => _githubAppUuid = v),
              ),
            ],
          ],
          if (_source == AppSource.dockerImage) ...[
            TextField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'Docker image',
                hintText: 'nginx',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageTag,
              decoration: const InputDecoration(labelText: 'Tag'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ports,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Exposed port'),
            ),
          ],
          if (_source == AppSource.dockerfile)
            TextField(
              controller: _dockerfile,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Dockerfile',
                alignLabelWithHint: true,
                hintText: 'FROM nginx:alpine\n…',
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
              label: const Text('Create application'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (!_target.isComplete) {
      _snack('Select a server, project and environment first.');
      return;
    }
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;

    final body = <String, dynamic>{
      ..._target.toBody(),
      if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
      'instant_deploy': _instantDeploy,
    };

    Future<String> Function() call;
    switch (_source) {
      case AppSource.publicRepo:
        body.addAll({
          'git_repository': _repo.text.trim(),
          'git_branch': _branch.text.trim(),
          'build_pack': _buildPack,
          'ports_exposes': _ports.text.trim(),
        });
        call = () => client.createPublicApp(body);
        break;
      case AppSource.privateDeployKey:
        if (_privateKeyUuid == null) {
          _snack('Select an SSH private key.');
          return;
        }
        body.addAll({
          'git_repository': _repo.text.trim(),
          'git_branch': _branch.text.trim(),
          'build_pack': _buildPack,
          'ports_exposes': _ports.text.trim(),
          'private_key_uuid': _privateKeyUuid,
        });
        call = () => client.createPrivateDeployKeyApp(body);
        break;
      case AppSource.privateGithubApp:
        if (_githubAppUuid == null) {
          _snack('Select a connected GitHub App.');
          return;
        }
        body.addAll({
          'git_repository': _repo.text.trim(),
          'git_branch': _branch.text.trim(),
          'build_pack': _buildPack,
          'ports_exposes': _ports.text.trim(),
          'github_app_uuid': _githubAppUuid,
        });
        call = () => client.createPrivateGithubApp(body);
        break;
      case AppSource.dockerfile:
        body['dockerfile'] = _dockerfile.text;
        call = () => client.createDockerfileApp(body);
        break;
      case AppSource.dockerImage:
        body.addAll({
          'docker_registry_image_name': _image.text.trim(),
          'docker_registry_image_tag': _imageTag.text.trim(),
          'ports_exposes': _ports.text.trim(),
        });
        call = () => client.createDockerImageApp(body);
        break;
    }

    final ok = await runAction(
      context,
      action: () async => call(),
      success: 'Application created',
      running: 'Creating…',
    );
    if (ok && mounted) {
      ref.invalidate(applicationsProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _PrivateKeyPicker extends ConsumerWidget {
  const _PrivateKeyPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(privateKeysProvider);
    return keys.when(
      data: (list) {
        if (list.isEmpty) {
          return const Text(
            'No SSH keys yet. Add one under Settings → SSH keys first.',
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'SSH private key',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          items: list
              .map(
                (k) => DropdownMenuItem(
                  value: k.uuid,
                  child: Text(k.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load keys: $e'),
    );
  }
}

class _GithubAppPicker extends ConsumerWidget {
  const _GithubAppPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(githubAppsProvider);
    return apps.when(
      data: (list) {
        if (list.isEmpty) {
          return const Text(
            'No GitHub Apps connected. Connect one in the Coolify dashboard first.',
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'GitHub App',
            prefixIcon: Icon(Icons.code),
          ),
          items: list
              .map(
                (a) => DropdownMenuItem(
                  value: a.uuid,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load GitHub Apps: $e'),
    );
  }
}
