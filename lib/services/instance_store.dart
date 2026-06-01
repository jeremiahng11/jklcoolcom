import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/instance.dart';

/// Persists the user's Coolify accounts.
///
/// Non-secret metadata (label, URL, accent) is stored as a JSON list in
/// [SharedPreferences]; the API token for each instance is stored separately in
/// [FlutterSecureStorage] under `token_<id>`.
class InstanceStore {
  InstanceStore({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _secure;

  static const _instancesKey = 'instances';
  static const _activeKey = 'active_instance_id';
  static String _tokenKey(String id) => 'token_$id';
  static String _metricsTokenKey(String id) => 'metrics_token_$id';

  Future<List<CoolifyInstance>> loadInstances() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_instancesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CoolifyInstance.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<CoolifyInstance> instances) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _instancesKey,
      jsonEncode(instances.map((i) => i.toJson()).toList()),
    );
  }

  Future<String?> activeInstanceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveInstanceId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  /// Adds or updates an instance, storing secrets securely if provided.
  /// [metricsToken] may be an empty string to clear it.
  Future<void> save(
    CoolifyInstance instance, {
    String? token,
    String? metricsToken,
  }) async {
    final instances = await loadInstances();
    final idx = instances.indexWhere((i) => i.id == instance.id);
    if (idx >= 0) {
      instances[idx] = instance;
    } else {
      instances.add(instance);
    }
    await _persist(instances);
    if (token != null && token.isNotEmpty) {
      await _secure.write(key: _tokenKey(instance.id), value: token);
    }
    if (metricsToken != null) {
      if (metricsToken.isEmpty) {
        await _secure.delete(key: _metricsTokenKey(instance.id));
      } else {
        await _secure.write(
          key: _metricsTokenKey(instance.id),
          value: metricsToken,
        );
      }
    }
  }

  Future<void> delete(String id) async {
    final instances = await loadInstances();
    instances.removeWhere((i) => i.id == id);
    await _persist(instances);
    await _secure.delete(key: _tokenKey(id));
    await _secure.delete(key: _metricsTokenKey(id));
    final active = await activeInstanceId();
    if (active == id) {
      await setActiveInstanceId(
        instances.isNotEmpty ? instances.first.id : null,
      );
    }
  }

  Future<String?> tokenFor(String id) => _secure.read(key: _tokenKey(id));

  Future<String?> metricsTokenFor(String id) =>
      _secure.read(key: _metricsTokenKey(id));
}
