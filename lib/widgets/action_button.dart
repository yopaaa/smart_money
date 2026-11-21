import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable action button component used across the Smart Money application.
///
/// Corresponds to React Native's `ActionButton.jsx` and provides consistent
/// touch feedback, loading states, disable states, and theming.
class ActionButton extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final VoidCallback? onPress;
  final Color backgroundColor;
  final Color textColor;
  final bool disabled;
  final bool isLoading;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry? padding;
  final BorderSide? border;

  const ActionButton({
    super.key,
    this.title,
    this.icon,
    this.onPress,
    this.backgroundColor = AppColors.primary,
    this.textColor = Colors.white,
    this.disabled = false,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.borderRadius = 10.0,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.bold,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || isLoading || onPress == null;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: effectiveDisabled ? backgroundColor.withOpacity(0.45) : backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        elevation: effectiveDisabled ? 0 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: effectiveDisabled ? null : onPress,
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: border != null ? Border.fromBorderSide(border!) : null,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: textColor),
                        if (title != null) const SizedBox(width: 8),
                      ],
                      if (title != null)
                        Flexible(
                          child: Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: fontSize,
                              fontWeight: fontWeight,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
