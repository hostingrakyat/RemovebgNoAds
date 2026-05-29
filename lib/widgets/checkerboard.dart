import 'package:flutter/material.dart';

/// Classic checkerboard backdrop to preview transparency.
class Checkerboard extends StatelessWidget {
  const Checkerboard({super.key, this.cell = 16});

  final double cell;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerPainter(cell: cell),
      size: Size.infinite,
    );
  }
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter({required this.cell});

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFE0E0E0);
    canvas.drawRect(Offset.zero & size, light);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) => old.cell != cell;
}
