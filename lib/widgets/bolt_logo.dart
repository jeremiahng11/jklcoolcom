import 'package:flutter/material.dart';

/// Paints the Coolify Companion lightning bolt (same shape as the app icon).
/// [glow] (0..1) adds a soft halo; [color] tints the bolt.
class BoltPainter extends CustomPainter {
  BoltPainter({this.color = Colors.white, this.glow = 0});

  final Color color;
  final double glow;

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

    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(
            alpha: (0.25 + 0.35 * glow).clamp(0.0, 1.0),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + 10 * glow),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BoltPainter old) => old.glow != glow || old.color != color;
}

/// Convenience widget for a static bolt mark.
class BoltMark extends StatelessWidget {
  const BoltMark({
    super.key,
    required this.size,
    this.color = Colors.white,
    this.glow = 0,
  });

  final double size;
  final Color color;
  final double glow;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: BoltPainter(color: color, glow: glow),
  );
}
