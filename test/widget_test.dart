import 'package:coolifycompanion/models/instance.dart';
import 'package:coolifycompanion/models/status.dart';
import 'package:coolifycompanion/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResourceStatus.parse', () {
    test('running:healthy is healthy and green', () {
      final s = ResourceStatus.parse('running:healthy');
      expect(s.level, HealthLevel.healthy);
      expect(s.state, 'running');
      expect(s.health, 'healthy');
      expect(s.label, 'Healthy');
      expect(s.isRunning, isTrue);
    });

    test('running:unhealthy is a warning', () {
      final s = ResourceStatus.parse('running:unhealthy');
      expect(s.level, HealthLevel.warning);
      expect(s.label, 'Unhealthy');
    });

    test('degraded is a warning', () {
      expect(ResourceStatus.parse('degraded').level, HealthLevel.warning);
    });

    test('exited is down and reads as Stopped', () {
      final s = ResourceStatus.parse('exited:unhealthy');
      expect(s.level, HealthLevel.down);
      expect(s.isStopped, isTrue);
      expect(s.label, 'Stopped');
    });

    test('restarting is transitioning', () {
      expect(
        ResourceStatus.parse('restarting').level,
        HealthLevel.transitioning,
      );
    });

    test('empty / null is unknown', () {
      expect(ResourceStatus.parse('').level, HealthLevel.unknown);
      expect(ResourceStatus.parse(null).level, HealthLevel.unknown);
    });

    test('bare running with no health is treated as healthy', () {
      expect(ResourceStatus.parse('running').level, HealthLevel.healthy);
    });
  });

  group('CoolifyInstance.normaliseBaseUrl', () {
    test('adds https and /api/v1 for a bare host', () {
      expect(
        CoolifyInstance.normaliseBaseUrl('coolify.example.com'),
        'https://coolify.example.com/api/v1',
      );
    });

    test('uses http for localhost', () {
      expect(
        CoolifyInstance.normaliseBaseUrl('localhost:8000'),
        'http://localhost:8000/api/v1',
      );
    });

    test('does not double the /api/v1 suffix', () {
      expect(
        CoolifyInstance.normaliseBaseUrl('https://x.dev/api/v1'),
        'https://x.dev/api/v1',
      );
    });

    test('strips trailing slashes', () {
      expect(
        CoolifyInstance.normaliseBaseUrl('https://x.dev/'),
        'https://x.dev/api/v1',
      );
    });
  });

  testWidgets('StatusBadge renders its label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusBadge(ResourceStatus.parse('running:healthy')),
        ),
      ),
    );
    expect(find.text('Healthy'), findsOneWidget);
  });

  test('CoolifyInstance JSON round-trips', () {
    const instance = CoolifyInstance(
      id: 'inst_1',
      label: 'Home',
      baseUrl: 'https://x.dev/api/v1',
      accentColor: 0xFF8B5CF6,
    );
    final restored = CoolifyInstance.fromJson(instance.toJson());
    expect(restored.id, instance.id);
    expect(restored.label, instance.label);
    expect(restored.baseUrl, instance.baseUrl);
    expect(restored.accentColor, instance.accentColor);
  });
}
