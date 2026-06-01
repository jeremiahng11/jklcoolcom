import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/server_metrics.dart';
import 'instances_provider.dart';

/// A single poll result from the metrics agent — either [data] or an [error]
/// message. Using a snapshot (instead of throwing) lets the stream keep polling
/// through transient failures so the card recovers on its own.
class MetricsSnapshot {
  const MetricsSnapshot({this.data, this.error});
  final ServerMetrics? data;
  final String? error;
}

/// Polls the active instance's metrics agent every few seconds. Emits nothing
/// (no value) when no agent URL is configured for the active account.
final liveMetricsProvider = StreamProvider<MetricsSnapshot>((ref) async* {
  final instance = ref.watch(activeInstanceProvider);
  if (instance == null || !instance.hasMetrics) return;

  final store = ref.read(instanceStoreProvider);
  final token = await store.metricsTokenFor(instance.id) ?? '';
  final url = Uri.parse('${instance.metricsUrl}/metrics');
  final client = http.Client();
  ref.onDispose(client.close);

  while (true) {
    try {
      final res = await client
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        yield MetricsSnapshot(
          data: ServerMetrics.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>,
          ),
        );
      } else if (res.statusCode == 401) {
        yield const MetricsSnapshot(
          error: 'Agent rejected the token (401). Check the agent token.',
        );
      } else {
        yield MetricsSnapshot(error: 'Agent returned HTTP ${res.statusCode}.');
      }
    } catch (_) {
      yield const MetricsSnapshot(
        error: 'Agent unreachable. Is it running and on the same network?',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});
