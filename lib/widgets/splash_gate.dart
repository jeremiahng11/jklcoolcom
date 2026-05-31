import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shows an animated splash on first launch for ~3s, then fades out to reveal
/// [child]. The app builds underneath while the splash plays, so the splash
/// also masks initial load. Wrapped via MaterialApp.builder so it sits above
/// everything (including the lock gate).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
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
        if (mounted) setState(() => _fadingOut = true);
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
            (0.6 +
                    0.25 * math.sin(t * math.pi * 2 * 3) +
                    0.15 * math.sin(t * math.pi * 2 * 7.3))
                .clamp(0.0, 1.0);
        // A bright "strike" flash that peaks just as the bolt lands.
        final e = _enter.value;
        final flash = (1 - ((e - 0.22).abs() / 0.16)).clamp(0.0, 1.0);

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
                    opacity: _boltFade.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * _boltScale.value.clamp(0.0, 1.2),
                      child: CustomPaint(
                        size: const Size(120, 120),
                        painter: _BoltPainter(glow: flicker),
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

/// Paints the same lightning bolt as the app icon, in white with a soft glow.
class _BoltPainter extends CustomPainter {
  _BoltPainter({required this.glow});

  final double glow; // 0..1 pulse intensity

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w * 0.5;
    final cy = size.height * 0.5;
    final h = w * 0.92;

    final path = Path()
      ..moveTo(cx + 0.06 * h, cy - 0.52 * h)
      ..lineTo(cx - 0.30 * h, cy + 0.07 * h)
      ..lineTo(cx - 0.03 * h, cy + 0.07 * h)
      ..lineTo(cx - 0.10 * h, cy + 0.52 * h)
      ..lineTo(cx + 0.32 * h, cy - 0.10 * h)
      ..lineTo(cx + 0.05 * h, cy - 0.10 * h)
      ..close();

    // Glow halo.
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + 0.35 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + 10 * glow);
    canvas.drawPath(path, glowPaint);

    // Solid bolt.
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.glow != glow;
}
