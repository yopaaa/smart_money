import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../constants/app_colors.dart';

/// Representation of an individual tab item in [AnimatedTabBar].
class TabItem {
  final String? key;
  final String? label;
  final IconData? icon;

  const TabItem({
    this.key,
    this.label,
    this.icon,
  });
}

/// A reusable animated slider tab bar with a sliding capsule/pill indicator.
///
/// Supports 2 or more tabs, icons, text labels, or both.
class AnimatedTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  final List<TabItem>? tabs;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? pillColor;
  final Color? activeColor;
  final Color? inactiveColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  const AnimatedTabBar({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
    this.tabs,
    this.width = 150.0,
    this.height = 38.0,
    this.backgroundColor,
    this.pillColor,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius,
    this.padding = const EdgeInsets.all(3.0),
  });

  static const List<TabItem> defaultTabs = [
    TabItem(key: 'list', icon: Ionicons.list),
    TabItem(key: 'images', icon: Ionicons.images),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveTabs = tabs ?? defaultTabs;
    final count = effectiveTabs.length;

    final effectiveBg = backgroundColor ??
        (isDark ? const Color(0xFF13222D) : const Color(0xFFE5E7EB));
    final effectivePill = pillColor ??
        (isDark ? const Color(0xFF0A1A24) : Colors.white);
    final effectiveActive = activeColor ?? AppColors.primary;
    final effectiveInactive = inactiveColor ??
        (isDark ? Colors.white54 : const Color(0xFF999999));
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    final double alignX = count <= 1
        ? 0.0
        : -1.0 + (2.0 * activeIndex.clamp(0, count - 1) / (count - 1));

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
      ),
      child: Stack(
        children: [
          // Sliding indicator pill with smooth animation
          AnimatedAlign(
            alignment: Alignment(alignX, 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: count > 0 ? 1.0 / count : 1.0,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: effectivePill,
                  borderRadius: effectiveRadius,
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

          // Tappable Tab Items Row
          Row(
            children: List.generate(count, (index) {
              final tab = effectiveTabs[index];
              final isSelected = activeIndex == index;
              final currentColor = isSelected ? effectiveActive : effectiveInactive;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTabChanged(index),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(
                            tab.icon,
                            size: tab.label != null ? 18 : 22,
                            color: currentColor,
                          ),
                          if (tab.label != null) const SizedBox(width: 4),
                        ],
                        if (tab.label != null)
                          Flexible(
                            child: Text(
                              tab.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: currentColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
