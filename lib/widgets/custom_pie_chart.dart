import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/category_model.dart';

class CustomPieChart extends StatefulWidget {
  final List<CategoryStatModel> stats;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceTap;
  final int animationTrigger;

  const CustomPieChart({
    super.key,
    required this.stats,
    this.selectedIndex,
    this.onSliceTap,
    this.animationTrigger = 0,
  });

  @override
  State<CustomPieChart> createState() => _CustomPieChartState();
}

class _CustomPieChartState extends State<CustomPieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (_hasData(widget.stats)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant CustomPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dataChanged = _statsChanged(oldWidget.stats, widget.stats);
    final triggerChanged = widget.animationTrigger != oldWidget.animationTrigger;
    if (_hasData(widget.stats) && (dataChanged || triggerChanged)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasData(List<CategoryStatModel> stats) {
    return stats.isNotEmpty && stats.fold<int>(0, (s, e) => s + e.amount) > 0;
  }

  bool _statsChanged(List<CategoryStatModel> a, List<CategoryStatModel> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i].category.id != b[i].category.id ||
          a[i].amount != b[i].amount) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final total = widget.stats.fold<int>(0, (sum, item) => sum + item.amount);

    if (widget.stats.isEmpty || total == 0) {
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
          child: AnimatedBuilder(
            animation: _sweepAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: Size(width, height),
                painter: _PieChartPainter(
                  stats: widget.stats,
                  total: total,
                  selectedIndex: widget.selectedIndex,
                  textColor: textColor,
                  progress: _sweepAnimation.value,
                ),
              );
            },
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
  final double progress;

  _PieChartPainter({
    required this.stats,
    required this.total,
    required this.selectedIndex,
    required this.textColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.28; // ~76-80px

    final strokePaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // If only 1 category, sweep circularly from 0% to 100%
    if (stats.length == 1) {
      final color = AppColors.parseHex(stats[0].category.color);
      final fillPaint = Paint()..color = color;
      final sweepRad = 2 * pi * clampedProgress;

      if (sweepRad >= 2 * pi - 0.0001) {
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
      } else {
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius),
            -pi / 2,
            sweepRad,
            false,
          )
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }

      final labelOpacity = ((clampedProgress - 0.55) / 0.35).clamp(0.0, 1.0);
      if (labelOpacity > 0) {
        _drawLabel(
          canvas: canvas,
          center: center,
          labelX: center.dx,
          labelY: center.dy - radius - 24,
          label: stats[0].categoryName,
          percent: '100 %',
          textColor: textColor,
          opacity: labelOpacity,
        );
      }
      return;
    }

    final double maxAngleDegrees = 360.0 * clampedProgress;
    double cumulativeAngle = 0.0;

    for (int i = 0; i < stats.length; i++) {
      final item = stats[i];
      final fullSweepDegrees = (item.amount / total) * 360.0;
      final startAngleDegrees = cumulativeAngle;
      cumulativeAngle += fullSweepDegrees;

      if (startAngleDegrees >= maxAngleDegrees) {
        continue;
      }

      final visibleSweepDegrees =
          min(fullSweepDegrees, maxAngleDegrees - startAngleDegrees);
      if (visibleSweepDegrees <= 0.01) continue;

      final isSelected = selectedIndex == i;

      final startAngleRad = ((startAngleDegrees - 90.0) * pi) / 180.0;
      final sweepAngleRad = (visibleSweepDegrees * pi) / 180.0;

      // Slice center offset if selected
      final midAngleDegrees = startAngleDegrees + fullSweepDegrees / 2.0;
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
      if (fullSweepDegrees > 14) {
        final sliceProgress =
            (visibleSweepDegrees / fullSweepDegrees).clamp(0.0, 1.0);
        final labelOpacity = ((sliceProgress - 0.5) / 0.5).clamp(0.0, 1.0);
        if (labelOpacity > 0) {
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
            opacity: labelOpacity,
          );
        }
      }
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
    double opacity = 1.0,
  }) {
    // 1. Category name text
    final namePainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: textColor.withOpacity(opacity),
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
          color: textColor.withOpacity(0.85 * opacity),
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
        oldDelegate.textColor != textColor ||
        oldDelegate.progress != progress;
  }
}
