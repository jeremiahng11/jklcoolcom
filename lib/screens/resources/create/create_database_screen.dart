import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/database.dart';
import '../../../providers/instances_provider.dart';
import '../../../providers/resource_providers.dart';
import '../../../widgets/action_runner.dart';
import 'create_common.dart';

class CreateDatabaseScreen extends ConsumerStatefulWidget {
  const CreateDatabaseScreen({super.key});

  @override
  ConsumerState<CreateDatabaseScreen> createState() =>
      _CreateDatabaseScreenState();
}

class _CreateDatabaseScreenState extends ConsumerState<CreateDatabaseScreen> {
  DeploymentTarget _target = const DeploymentTarget();
  DbEngine _engine = DbEngine.postgresql;
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _isPublic = false;
  bool _instantDeploy = true;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New database')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TargetSelector(
            target: _target,
            onChanged: (t) => setState(() => _target = t),
          ),
          const Divider(height: 32),
          DropdownButtonFormField<DbEngine>(
            initialValue: _engine,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Engine',
              prefixIcon: Icon(Icons.storage_rounded),
            ),
            items: DbEngine.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                .toList(),
            onChanged: (v) => setState(() => _engine = v ?? _engine),
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
          TextField(
            controller: _password,
            decoration: InputDecoration(
              labelText: '${_engine.label} password (optional)',
              helperText: 'Leave blank to let Coolify generate a secure one.',
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Publicly accessible'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          SwitchListTile(
            title: const Text('Start immediately'),
            value: _instantDeploy,
            onChanged: (v) => setState(() => _instantDeploy = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Create database'),
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
      'is_public': _isPublic,
      'instant_deploy': _instantDeploy,
    };
    final pwd = _password.text.trim();
    if (pwd.isNotEmpty) body.addAll(_passwordField(_engine, pwd));

    final ok = await runAction(
      context,
      action: () async => client.createDatabase(_engine, body),
      success: '${_engine.label} database created',
      running: 'Provisioning…',
    );
    if (ok && mounted) {
      ref.invalidate(databasesProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }

  /// Maps a password to the engine-specific field name.
  Map<String, dynamic> _passwordField(DbEngine engine, String pwd) {
    switch (engine) {
      case DbEngine.postgresql:
        return {'postgres_password': pwd};
      case DbEngine.mysql:
        return {'mysql_password': pwd, 'mysql_root_password': pwd};
      case DbEngine.mariadb:
        return {'mariadb_password': pwd, 'mariadb_root_password': pwd};
      case DbEngine.mongodb:
        return {'mongo_initdb_root_password': pwd};
      case DbEngine.redis:
        return {'redis_password': pwd};
      case DbEngine.keydb:
        return {'keydb_password': pwd};
      case DbEngine.dragonfly:
        return {'dragonfly_password': pwd};
      case DbEngine.clickhouse:
        return {'clickhouse_admin_password': pwd};
    }
  }
}
