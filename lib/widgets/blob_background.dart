import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _BlobPainter(),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.navy, AppColors.darkNavy],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Large wavy blob – top right
    final blob1Paint = Paint()
      ..color = AppColors.slateBlue.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final blob1Path = Path();
    blob1Path.moveTo(size.width * 0.4, 0);
    blob1Path.cubicTo(
      size.width * 0.9, size.height * 0.0,
      size.width * 1.1, size.height * 0.25,
      size.width * 0.85, size.height * 0.38,
    );
    blob1Path.cubicTo(
      size.width * 0.65, size.height * 0.50,
      size.width * 0.55, size.height * 0.30,
      size.width * 0.4, 0,
    );
    canvas.drawPath(blob1Path, blob1Paint);

    // Mid blob – left side
    final blob2Paint = Paint()
      ..color = AppColors.steelTeal.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;
    final blob2Path = Path();
    blob2Path.moveTo(0, size.height * 0.30);
    blob2Path.cubicTo(
      size.width * 0.25, size.height * 0.20,
      size.width * 0.45, size.height * 0.40,
      size.width * 0.20, size.height * 0.55,
    );
    blob2Path.cubicTo(
      -size.width * 0.10, size.height * 0.65,
      -size.width * 0.05, size.height * 0.42,
      0, size.height * 0.30,
    );
    canvas.drawPath(blob2Path, blob2Paint);

    // Small glassy circle – top right
    _drawGlossyCircle(
      canvas,
      Offset(size.width * 0.78, size.height * 0.08),
      size.width * 0.10,
      AppColors.skyBlue.withValues(alpha: 0.70),
    );

    // Medium glassy circle – top left
    _drawGlossyCircle(
      canvas,
      Offset(size.width * 0.18, size.height * 0.07),
      size.width * 0.12,
      AppColors.slateBlue.withValues(alpha: 0.60),
    );

    // Large dark circle – bottom left
    _drawGlossyCircle(
      canvas,
      Offset(size.width * 0.12, size.height * 0.72),
      size.width * 0.16,
      AppColors.darkNavy.withValues(alpha: 0.80),
    );

    // Small glassy circle – center right
    _drawGlossyCircle(
      canvas,
      Offset(size.width * 0.88, size.height * 0.55),
      size.width * 0.07,
      AppColors.softTeal.withValues(alpha: 0.55),
    );
  }

  void _drawGlossyCircle(
      Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          color,
          color.withValues(alpha: 0.50),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    // Subtle highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.25),
      radius * 0.35,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
