import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/category_model.dart';

class CustomPieChart extends StatelessWidget {
  final List<CategoryStatModel> stats;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceTap;

  const CustomPieChart({
    super.key,
    required this.stats,
    this.selectedIndex,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final total = stats.fold<int>(0, (sum, item) => sum + item.amount);

    if (stats.isEmpty || total == 0) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.pie_chart_outline,
                  size: 54,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum atau tidak ada data',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 270.0;

        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            size: Size(width, height),
            painter: _PieChartPainter(
              stats: stats,
              total: total,
              selectedIndex: selectedIndex,
              textColor: textColor,
            ),
          ),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategoryStatModel> stats;
  final int total;
  final int? selectedIndex;
  final Color textColor;

  _PieChartPainter({
    required this.stats,
    required this.total,
    required this.selectedIndex,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.28; // ~76-80px

    final strokePaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // If only 1 category, draw full circle
    if (stats.length == 1) {
      final color = AppColors.parseHex(stats[0].category.color);
      final fillPaint = Paint()..color = color;
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);

      _drawLabel(
        canvas: canvas,
        center: center,
        labelX: center.dx,
        labelY: center.dy - radius - 24,
        label: stats[0].categoryName,
        percent: '100 %',
        textColor: textColor,
      );
      return;
    }

    double cumulativeAngle = 0.0;

    for (int i = 0; i < stats.length; i++) {
      final item = stats[i];
      final sweepAngleDegrees = (item.amount / total) * 360.0;
      final startAngleDegrees = cumulativeAngle;
      final isSelected = selectedIndex == i;

      final startAngleRad = ((startAngleDegrees - 90.0) * pi) / 180.0;
      final sweepAngleRad = (sweepAngleDegrees * pi) / 180.0;

      // Slice center offset if selected
      final midAngleDegrees = startAngleDegrees + sweepAngleDegrees / 2.0;
      final midAngleRad = ((midAngleDegrees - 90.0) * pi) / 180.0;

      Offset sliceCenter = center;
      double actualRadius = radius;
      if (isSelected) {
        sliceCenter = Offset(
          center.dx + 6 * cos(midAngleRad),
          center.dy + 6 * sin(midAngleRad),
        );
        actualRadius += 4;
      }

      final color = AppColors.parseHex(item.category.color);
      final fillPaint = Paint()..color = color;

      final path = Path();
      path.moveTo(sliceCenter.dx, sliceCenter.dy);
      path.arcTo(
        Rect.fromCircle(center: sliceCenter, radius: actualRadius),
        startAngleRad,
        sweepAngleRad,
        false,
      );
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      // Draw Outside Label if slice angle is large enough (> 14 degrees / ~3.8%)
      if (sweepAngleDegrees > 14) {
        final labelRadius = actualRadius + (isSelected ? 32.0 : 26.0);
        double labelX = sliceCenter.dx + labelRadius * cos(midAngleRad);
        double labelY = sliceCenter.dy + labelRadius * sin(midAngleRad);

        // Clamp labelX inside canvas bounds with padding
        labelX = labelX.clamp(35.0, size.width - 35.0);
        labelY = labelY.clamp(14.0, size.height - 14.0);

        _drawLabel(
          canvas: canvas,
          center: center,
          labelX: labelX,
          labelY: labelY,
          label: item.categoryName,
          percent: '${item.percent.toStringAsFixed(0)} %',
          textColor: textColor,
        );
      }

      cumulativeAngle += sweepAngleDegrees;
    }
  }

  void _drawLabel({
    required Canvas canvas,
    required Offset center,
    required double labelX,
    required double labelY,
    required String label,
    required String percent,
    required Color textColor,
  }) {
    // 1. Category name text
    final namePainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 80);

    // 2. Percentage text
    final percentPainter = TextPainter(
      text: TextSpan(
        text: percent,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor.withOpacity(0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final nameOffset = Offset(
      labelX - namePainter.width / 2,
      labelY - namePainter.height - 1,
    );
    final percentOffset = Offset(
      labelX - percentPainter.width / 2,
      labelY + 2,
    );

    namePainter.paint(canvas, nameOffset);
    percentPainter.paint(canvas, percentOffset);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.stats != stats ||
        oldDelegate.total != total ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.textColor != textColor;
  }
}
