import 'dart:math' as math;

import 'package:flutter/material.dart';

class TeleVaultLogoMark extends StatelessWidget {
  final double size;
  final bool shadow;

  const TeleVaultLogoMark({super.key, this.size = 96, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TeleVaultLogoPainter(shadow: shadow)),
    );
  }
}

class _TeleVaultLogoPainter extends CustomPainter {
  final bool shadow;

  const _TeleVaultLogoPainter({required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final canvasRect = Offset.zero & size;
    final iconRect = Rect.fromCenter(
      center: canvasRect.center,
      width: shortest,
      height: shortest,
    );
    final radius = Radius.circular(shortest * 0.24);
    final rrect = RRect.fromRectAndRadius(iconRect, radius);

    if (shadow) {
      canvas.drawRRect(
        rrect.shift(Offset(0, shortest * 0.035)),
        Paint()
          ..color = const Color(0xFF0A84FF).withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.08),
      );
    }

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20D6FF), Color(0xFF148FFF), Color(0xFF0B4FD7)],
      ).createShader(iconRect);
    canvas.drawRRect(rrect, bgPaint);

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.65, -0.75),
        radius: 1.0,
        colors: [
          Colors.white.withValues(alpha: 0.32),
          Colors.white.withValues(alpha: 0.00),
        ],
      ).createShader(iconRect);
    canvas.drawRRect(rrect, highlightPaint);

    final cloudPaint = Paint()..color = Colors.white;
    final cx = iconRect.left;
    final cy = iconRect.top;
    final s = shortest;

    canvas.drawCircle(
      Offset(cx + s * 0.39, cy + s * 0.51),
      s * 0.15,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(cx + s * 0.54, cy + s * 0.44),
      s * 0.20,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(cx + s * 0.68, cy + s * 0.53),
      s * 0.13,
      cloudPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + s * 0.26, cy + s * 0.49, s * 0.50, s * 0.22),
        Radius.circular(s * 0.11),
      ),
      cloudPaint,
    );

    final planePaint = Paint()
      ..color = const Color(0xFF0A84FF)
      ..style = PaintingStyle.fill;
    final plane = Path()
      ..moveTo(cx + s * 0.34, cy + s * 0.53)
      ..lineTo(cx + s * 0.73, cy + s * 0.40)
      ..lineTo(cx + s * 0.60, cy + s * 0.70)
      ..lineTo(cx + s * 0.52, cy + s * 0.58)
      ..lineTo(cx + s * 0.43, cy + s * 0.65)
      ..lineTo(cx + s * 0.46, cy + s * 0.57)
      ..close();
    canvas.drawPath(plane, planePaint);

    final planeFold = Paint()
      ..color = Colors.white.withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + s * 0.52, cy + s * 0.58),
      Offset(cx + s * 0.63, cy + s * 0.47),
      planeFold,
    );

    final badgeCenter = Offset(cx + s * 0.73, cy + s * 0.73);
    canvas.drawCircle(
      badgeCenter,
      s * 0.155,
      Paint()..color = Colors.white.withValues(alpha: 0.98),
    );
    canvas.drawCircle(
      badgeCenter,
      s * 0.155,
      Paint()
        ..color = const Color(0xFF052D72).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );

    final lockPaint = Paint()
      ..color = const Color(0xFF0A66D8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + s * 0.73, cy + s * 0.755),
          width: s * 0.14,
          height: s * 0.11,
        ),
        Radius.circular(s * 0.025),
      ),
      lockPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx + s * 0.73, cy + s * 0.705),
        width: s * 0.12,
        height: s * 0.12,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF0A66D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TeleVaultLogoPainter oldDelegate) {
    return oldDelegate.shadow != shadow;
  }
}
