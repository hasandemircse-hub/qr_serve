import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'floor_layout_models.dart';

/// Salon düzleminde masaları [CustomPainter] ile çizer (kare / yuvarlak).
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({
    required this.tables,
    this.gridStep = 32,
  });

  final List<TableLayoutNode> tables;
  final double gridStep;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final t in tables) {
      final rect = Rect.fromLTWH(t.x, t.y, t.width, t.height);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = _fillFor(t.availability);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black87;

      canvas.save();
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      canvas.translate(cx, cy);
      canvas.rotate(t.rotation * math.pi / 180);
      canvas.translate(-cx, -cy);

      if (t.shape == TableShape.round) {
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
      } else {
        final rrect = RRect.fromRectXY(rect, 6, 6);
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: t.label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 4);

      final offset = Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      );
      tp.paint(canvas, offset);
      canvas.restore();
    }
  }

  Color _fillFor(TableAvailability a) {
    return switch (a) {
      TableAvailability.occupied => Colors.redAccent.withValues(alpha: 0.35),
      TableAvailability.reserved => Colors.orangeAccent.withValues(alpha: 0.4),
      TableAvailability.empty => Colors.greenAccent.withValues(alpha: 0.25),
    };
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    return oldDelegate.tables != tables || oldDelegate.gridStep != gridStep;
  }
}
