import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../constants/app_colors.dart';

class AnimatedTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  final double width;
  final double height;

  const AnimatedTabBar({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
    this.width = 150.0,
    this.height = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor = isDark ? const Color(0xFF13222D) : const Color(0xFFE5E7EB);
    final pillColor = isDark ? const Color(0xFF0A1A24) : Colors.white;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Sliding indicator pill with smooth animation
          AnimatedAlign(
            alignment: activeIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tappable Tab Icons Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTabChanged(0),
                  child: Center(
                    child: Icon(
                      Ionicons.list,
                      size: 24,
                      color: activeIndex == 0
                          ? AppColors.primary
                          : const Color(0xFF999999),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTabChanged(1),
                  child: Center(
                    child: Icon(
                      Ionicons.images,
                      size: 24,
                      color: activeIndex == 1
                          ? AppColors.primary
                          : const Color(0xFF999999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
