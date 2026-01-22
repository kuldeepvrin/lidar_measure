import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Represents a measurement line projected onto 2D screen coordinates
class ProjectedLine {
  final Offset start;
  final Offset end;
  final String label;

  ProjectedLine({
    required this.start,
    required this.end,
    required this.label,
  });
}

/// Custom painter for drawing measurement overlay elements
class MeasurementOverlayPainter extends CustomPainter {
  final bool showCrosshair;
  final String? statusText;
  final bool isTracking;
  final bool hasSurface;
  final List<ProjectedLine> lines;

  MeasurementOverlayPainter({
    this.showCrosshair = true,
    this.statusText,
    this.isTracking = false,
    this.hasSurface = false,
    this.lines = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMeasurementLines(canvas, size);
    
    if (showCrosshair) {
      _drawCrosshair(canvas, size);
    }
  }

  void _drawMeasurementLines(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final line in lines) {
      // Draw the line
      canvas.drawLine(line.start, line.end, linePaint);

      // Draw end points
      canvas.drawCircle(line.start, 4, dotPaint);
      canvas.drawCircle(line.end, 4, dotPaint);

      // Draw label in the middle (only if label is not empty)
      if (line.label.isNotEmpty) {
        _drawText(canvas, line.label, (line.start + line.end) / 2);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Position text in center of midpoint
    final offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      Paint()..color = Colors.black54,
    );

    textPainter.paint(canvas, offset);
  }

  void _drawCrosshair(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Color logic:
    // 1. Red if no surface (cannot measure)
    // 2. Yellow if tracking (measuring)
    // 3. Green if surface detected and ready to measure
    Color crosshairColor = Colors.red;
    if (isTracking) {
      crosshairColor = Colors.yellow;
    } else if (hasSurface) {
      crosshairColor = Colors.greenAccent;
    }

    final paint = Paint()
      ..color = crosshairColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw center circle
    canvas.drawCircle(center, 4, paint);

    // Draw crosshair lines
    final lineLength = 20.0;
    
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - lineLength, center.dy),
      Offset(center.dx + lineLength, center.dy),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - lineLength),
      Offset(center.dx, center.dy + lineLength),
      paint,
    );

    // Draw outer circle
    canvas.drawCircle(center, 30, paint);
  }

  @override
  bool shouldRepaint(MeasurementOverlayPainter oldDelegate) {
    return oldDelegate.showCrosshair != showCrosshair ||
        oldDelegate.statusText != statusText ||
        oldDelegate.isTracking != isTracking ||
        oldDelegate.hasSurface != hasSurface ||
        oldDelegate.lines != lines;
  }
}

/// Widget that displays the measurement overlay
class MeasurementOverlay extends StatelessWidget {
  final bool showCrosshair;
  final String? statusText;
  final bool isTracking;
  final bool hasSurface;
  final List<ProjectedLine> lines;

  const MeasurementOverlay({
    super.key,
    this.showCrosshair = true,
    this.statusText,
    this.isTracking = false,
    this.hasSurface = false,
    this.lines = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Crosshair and 2D Lines
        CustomPaint(
          painter: MeasurementOverlayPainter(
            showCrosshair: showCrosshair,
            statusText: statusText,
            isTracking: isTracking,
            hasSurface: hasSurface,
            lines: lines,
          ),
          size: Size.infinite,
        ),
        
        // Status text
        if (statusText != null)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget to display a single measurement result
class MeasurementCard extends StatelessWidget {
  final String distance;
  final int index;
  final VoidCallback? onDelete;

  const MeasurementCard({
    super.key,
    required this.distance,
    required this.index,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Measurement',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
