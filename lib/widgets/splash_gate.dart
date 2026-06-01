import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/splash_provider.dart';
import 'bolt_logo.dart';

/// Shows an animated splash on first launch for ~3s, then fades out to reveal
/// [child]. The app builds underneath while the splash plays, so the splash
/// also masks initial load. Wrapped via MaterialApp.builder so it sits above
/// everything (including the lock gate). It marks [splashDoneProvider] when it
/// begins fading so the lock prompt waits for the splash instead of appearing
/// over it.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  static const _hold = Duration(seconds: 3);
  static const _fade = Duration(milliseconds: 650);

  bool _fadingOut = false;
  bool _done = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _timers.add(
      Timer(_hold, () {
        if (!mounted) return;
        setState(() => _fadingOut = true);
        // Tell the lock gate it may prompt now — as the splash fades out.
        ref.read(splashDoneProvider.notifier).complete();
      }),
    );
    _timers.add(
      Timer(_hold + _fade, () {
        if (mounted) setState(() => _done = true);
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _fadingOut ? 0 : 1,
          duration: _fade,
          curve: Curves.easeOut,
          child: const IgnorePointer(child: SplashScreen()),
        ),
      ],
    );
  }
}

/// The animated splash content: a glowing lightning bolt that springs in and
/// pulses, with the app name fading up beneath it, on a violet gradient.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _boltScale = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
  );
  late final Animation<double> _boltFade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _pulse]),
      builder: (context, _) {
        // Electric flicker: layered sine waves for a lively, lightning feel.
        final t = _pulse.value;
        final flicker =
            (0.55 +
                    0.3 * math.sin(t * math.pi * 2 * 3.1) +
                    0.18 * math.sin(t * math.pi * 2 * 8.7))
                .clamp(0.0, 1.0);
        final e = _enter.value;

        // A few lightning "strikes" during entrance (triangular flashes).
        double strike(double center, double width) =>
            (1 - ((e - center).abs() / width)).clamp(0.0, 1.0);
        final flash = math.max(
          strike(0.16, 0.06),
          math.max(strike(0.27, 0.05), strike(0.40, 0.06)),
        );

        // Ignition: the bolt flickers on like a struck arc before going steady.
        final ignite = e < 0.5 ? (0.35 + 0.65 * flicker) : 1.0;
        final boltOpacity = (_boltFade.value * ignite).clamp(0.0, 1.0);

        // Tiny electric jitter, stronger during ignition.
        final jitter = (e < 0.5 ? 2.0 : 0.8) * math.sin(t * math.pi * 2 * 11);

        // Glow brightens on each strike.
        final glow = (flicker * 0.7 + flash * 0.7).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    Color(0xFF9D6BFF),
                    Color(0xFF6D28D4),
                    Color(0xFF3B1E73),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: boltOpacity,
                    child: Transform.translate(
                      offset: Offset(jitter, 0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * _boltScale.value.clamp(0.0, 1.2),
                        child: CustomPaint(
                          size: const Size(120, 120),
                          painter: BoltPainter(glow: glow),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_titleFade),
                      child: Column(
                        children: [
                          const Text(
                            'Coolify Companion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'manage · monitor · deploy',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Lightning flash overlay.
            if (flash > 0.01)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.55 * flash),
                ),
              ),
          ],
        );
      },
    );
  }
}
