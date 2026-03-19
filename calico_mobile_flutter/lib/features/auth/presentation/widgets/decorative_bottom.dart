import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DecorativeBottom extends StatelessWidget {
  const DecorativeBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 320,
      child: CustomPaint(
        painter: _WavePainter(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.decorativeSurface,
    );

    _drawWave(
      canvas,
      size,
      color: const Color(0xFFEDE5D0),
      startY: 0.38,
      cp1X: 0.25,
      cp1Y: 0.18,
      cp2X: 0.55,
      cp2Y: 0.48,
      endY: 0.28,
    );

    _drawWave(
      canvas,
      size,
      color: const Color(0xFFE5D8C0),
      startY: 0.56,
      cp1X: 0.30,
      cp1Y: 0.40,
      cp2X: 0.68,
      cp2Y: 0.68,
      endY: 0.50,
    );

    _drawWave(
      canvas,
      size,
      color: const Color(0xFFD9CBB0),
      startY: 0.72,
      cp1X: 0.22,
      cp1Y: 0.60,
      cp2X: 0.58,
      cp2Y: 0.82,
      endY: 0.66,
    );

    _drawWave(
      canvas,
      size,
      color: const Color(0xFFCFC09E),
      startY: 0.86,
      cp1X: 0.18,
      cp1Y: 0.76,
      cp2X: 0.65,
      cp2Y: 0.95,
      endY: 0.80,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required Color color,
    required double startY,
    required double cp1X,
    required double cp1Y,
    required double cp2X,
    required double cp2Y,
    required double endY,
  }) {
    final path = Path()
      ..moveTo(0, size.height * startY)
      ..cubicTo(
        size.width * cp1X, size.height * cp1Y,
        size.width * cp2X, size.height * cp2Y,
        size.width, size.height * endY,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
