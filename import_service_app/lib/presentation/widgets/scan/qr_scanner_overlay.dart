import 'package:flutter/material.dart';

/// Рамка сканера (как в tdtime): затемнение + окно по центру.
class QrScannerOverlay extends StatelessWidget {
  const QrScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(
        painter: QrScannerOverlayPainter(),
      ),
    );
  }
}

class QrScannerOverlayPainter extends CustomPainter {
  const QrScannerOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double windowWidth = 280;
    const double windowHeight = 280;
    const double cornerRadius = 22;
    const double strokeWidth = 4;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: windowWidth,
      height: windowHeight,
    );

    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanRect, const Radius.circular(cornerRadius)),
      );
    final mask = Path.combine(PathOperation.difference, overlay, hole);

    canvas.drawPath(
      mask,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(cornerRadius)),
      Paint()
        ..color = Colors.white
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
