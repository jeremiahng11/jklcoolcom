import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../api/coolify_client.dart';
import '../../models/instance.dart';
import '../../models/server_metrics.dart';
import '../../providers/instances_provider.dart';
import '../../theme/app_theme.dart';

/// Add a new Coolify account or edit an existing one. Also serves as the
/// first-run welcome screen when [isFirst] is true.
class AddInstanceScreen extends ConsumerStatefulWidget {
  const AddInstanceScreen({super.key, this.instanceId, this.isFirst = false});

  final String? instanceId;
  final bool isFirst;

  @override
  ConsumerState<AddInstanceScreen> createState() => _AddInstanceScreenState();
}

class _AddInstanceScreenState extends ConsumerState<AddInstanceScreen> {
  final _label = TextEditingController();
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _metricsUrl = TextEditingController();
  final _metricsToken = TextEditingController();
  int _accent = AppTheme.accentColors.first.toARGB32();
  bool _obscure = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  bool _metricsTesting = false;
  String? _metricsTestResult;
  bool _metricsTestOk = false;

  CoolifyInstance? _editing;

  @override
  void initState() {
    super.initState();
    final id = widget.instanceId;
    if (id != null) {
      final state = ref.read(instancesProvider).value;
      _editing = state?.instances.firstWhere(
        (i) => i.id == id,
        orElse: () => state.instances.first,
      );
      if (_editing != null) {
        _label.text = _editing!.label;
        _url.text = _editing!.baseUrl;
        _accent = _editing!.accentColor;
        _token.text = state?.tokens[id] ?? '';
        _metricsUrl.text = _editing!.metricsUrl;
        // Load the (secret) metrics token from secure storage.
        ref.read(instanceStoreProvider).metricsTokenFor(id).then((t) {
          if (mounted && t != null) _metricsToken.text = t;
        });
      }
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _token.dispose();
    _metricsUrl.dispose();
    _metricsToken.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testResult = null;
      _testOk = false;
    });
    final base = CoolifyInstance.normaliseBaseUrl(_url.text);
    final client = CoolifyClient(baseUrl: base, token: _token.text.trim());
    try {
      final version = await client.version();
      final team = await client.currentTeam();
      setState(() {
        _testOk = true;
        _testResult =
            'Connected to Coolify ${version.isEmpty ? '' : 'v$version'} · team "${team.name}"';
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testResult = '$e';
      });
    } finally {
      client.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _testMetrics() async {
    FocusScope.of(context).unfocus();
    final url = CoolifyInstance.normaliseMetricsUrl(_metricsUrl.text);
    if (url.isEmpty) {
      setState(() {
        _metricsTestOk = false;
        _metricsTestResult = 'Enter the agent URL first.';
      });
      return;
    }
    setState(() {
      _metricsTesting = true;
      _metricsTestResult = null;
      _metricsTestOk = false;
    });
    try {
      final res = await http
          .get(
            Uri.parse('$url/metrics'),
            headers: {
              'Authorization': 'Bearer ${_metricsToken.text.trim()}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final m = ServerMetrics.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
        setState(() {
          _metricsTestOk = true;
          _metricsTestResult =
              'Connected · ${m.hostname.isEmpty ? 'agent' : m.hostname} · '
              '${m.cores} cores · CPU ${m.cpuPercent.toStringAsFixed(0)}%';
        });
      } else if (res.statusCode == 401) {
        setState(() {
          _metricsTestOk = false;
          _metricsTestResult = 'Agent rejected the token (401).';
        });
      } else {
        setState(() {
          _metricsTestOk = false;
          _metricsTestResult = 'Agent returned HTTP ${res.statusCode}.';
        });
      }
    } catch (_) {
      setState(() {
        _metricsTestOk = false;
        _metricsTestResult =
            'Unreachable or timed out. Check the URL and that the phone is on '
            'the same network (or the tunnel is up).';
      });
    } finally {
      if (mounted) setState(() => _metricsTesting = false);
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final base = CoolifyInstance.normaliseBaseUrl(_url.text);
    final token = _token.text.trim();
    if (label.isEmpty || base.isEmpty || token.isEmpty) {
      _snack('Label, URL and token are all required.');
      return;
    }
    final id =
        _editing?.id ??
        'inst_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final instance = CoolifyInstance(
      id: id,
      label: label,
      baseUrl: base,
      accentColor: _accent,
      metricsUrl: CoolifyInstance.normaliseMetricsUrl(_metricsUrl.text),
    );
    await ref
        .read(instancesProvider.notifier)
        .addOrUpdate(
          instance,
          token: token,
          metricsToken: _metricsToken.text.trim(),
        );
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing != null ? 'Edit account' : 'Add Coolify account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.isFirst) ...[
            Icon(
              Icons.cloud_sync_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome to Coolify Companion',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your first Coolify instance to manage and monitor your '
              'apps, databases and services. You can add more accounts later.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Home server, Coolify Cloud',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Instance URL',
              hintText: 'https://coolify.example.com  or  localhost:8000',
              prefixIcon: Icon(Icons.link),
              helperText: 'The /api/v1 suffix is added automatically.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _token,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API token',
              hintText: '67|abc…',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              helperText:
                  'Create one in Coolify → Keys & Tokens. Grant read, write & '
                  'deploy scopes for full control.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live metrics (optional)',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/metrics-setup'),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Setup guide'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Run the metrics agent on your server to see live CPU, memory, disk '
            '& uptime on the dashboard.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metricsUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Metrics agent URL',
              hintText: 'http://192.168.0.147:8088',
              prefixIcon: Icon(Icons.speed_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metricsToken,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Agent token',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
          if (_metricsTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (_metricsTestOk
                            ? StatusColors.healthy
                            : theme.colorScheme.error)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _metricsTestOk ? Icons.check_circle : Icons.error_outline,
                    color: _metricsTestOk
                        ? StatusColors.healthy
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_metricsTestResult!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _metricsTesting ? null : _testMetrics,
              icon: _metricsTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_metricsTesting ? 'Testing…' : 'Test agent'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Accent colour', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: AppTheme.accentColors.map((c) {
              final selected = c.toARGB32() == _accent;
              return GestureDetector(
                onTap: () => setState(() => _accent = c.toARGB32()),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_testResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (_testOk ? StatusColors.healthy : theme.colorScheme.error)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _testOk ? Icons.check_circle : Icons.error_outline,
                    color: _testOk
                        ? StatusColors.healthy
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_testResult!)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? 'Testing…' : 'Test connection'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_editing != null ? 'Save changes' : 'Add account'),
            ),
          ),
        ],
      ),
    );
  }
}
