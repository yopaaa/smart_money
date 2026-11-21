import 'package:flutter/material.dart';

/// Representation of an option item in [SlideSelect].
class SlideOption {
  final String key;
  final String label;
  final IconData icon;

  const SlideOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

/// A highly reusable animated toggle widget matching React Native's `SlideSelect.jsx`.
///
/// Features two adjacent white capsule cards that smoothly expand and contract
/// in width (default 108px <-> 36px) like an accordion with pinned icon badges
/// and cross-fading text labels.
class SlideSelect extends StatefulWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;
  final List<SlideOption>? options;
  final double activeWidth;
  final double inactiveWidth;
  final double height;

  const SlideSelect({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.options,
    this.activeWidth = 108.0,
    this.inactiveWidth = 36.0,
    this.height = 40.0,
  });

  static const List<SlideOption> defaultOptions = [
    SlideOption(key: 'income', label: 'Income', icon: Icons.arrow_downward),
    SlideOption(key: 'expense', label: 'Expense', icon: Icons.arrow_upward),
  ];

  @override
  State<SlideSelect> createState() => _SlideSelectState();
}

class _SlideSelectState extends State<SlideSelect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  late final Animation<double> _firstWidth;
  late final Animation<double> _secondWidth;
  late final Animation<double> _firstOpacity;
  late final Animation<double> _secondOpacity;

  List<SlideOption> get _effectiveOptions => widget.options ?? SlideSelect.defaultOptions;
  SlideOption get _firstOption => _effectiveOptions[0];
  SlideOption get _secondOption => _effectiveOptions.length > 1 ? _effectiveOptions[1] : _effectiveOptions[0];

  @override
  void initState() {
    super.initState();
    final isSecond = widget.selectedType == _secondOption.key;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: isSecond ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _firstWidth = Tween<double>(
      begin: widget.activeWidth,
      end: widget.inactiveWidth,
    ).animate(_anim);

    _secondWidth = Tween<double>(
      begin: widget.inactiveWidth,
      end: widget.activeWidth,
    ).animate(_anim);

    _firstOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_anim);

    _secondOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_anim);
  }

  @override
  void didUpdateWidget(covariant SlideSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedType != oldWidget.selectedType) {
      if (widget.selectedType == _secondOption.key) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(String type) {
    if (widget.selectedType == type) return;
    widget.onChanged(type);
    if (type == _secondOption.key) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Widget _buildIconBadge(IconData icon, bool isDark) {
    return Container(
      width: 24.0,
      height: 24.0,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.black87,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 13.0,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final itemHeight = widget.height - 6.0;
    final itemRadius = BorderRadius.circular(itemHeight / 2);

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. First Item (Income / Option 0)
              GestureDetector(
                onTap: () => _select(_firstOption.key),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: _firstWidth.value,
                  height: itemHeight,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: itemRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: 6.0,
                        child: _buildIconBadge(_firstOption.icon, isDark),
                      ),
                      Positioned(
                        left: 36.0,
                        child: Opacity(
                          opacity: _firstOpacity.value.clamp(0.0, 1.0),
                          child: Text(
                            _firstOption.label,
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4.0),

              // 2. Second Item (Expense / Option 1)
              GestureDetector(
                onTap: () => _select(_secondOption.key),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: _secondWidth.value,
                  height: itemHeight,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: itemRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Positioned(
                        right: 6.0,
                        child: _buildIconBadge(_secondOption.icon, isDark),
                      ),
                      Positioned(
                        right: 36.0,
                        child: Opacity(
                          opacity: _secondOpacity.value.clamp(0.0, 1.0),
                          child: Text(
                            _secondOption.label,
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
