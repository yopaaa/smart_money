import 'package:flutter/material.dart';

/// Data item for [showCompactOptionPickerDialog].
class CompactPickerOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color color;

  const CompactPickerOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Shows a compact, shrink-wrapped selection modal with single-line icon + label
/// rows, subtle inset dividers, and a compact `'Tutup'` footer button.
Future<T?> showCompactOptionPickerDialog<T>({
  required BuildContext context,
  required List<CompactPickerOption<T>> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      final textColor = theme.textTheme.bodyLarge?.color;
      final closeColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      final maxHeight = MediaQuery.of(ctx).size.height * 0.65;

      return Dialog(
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Text(
                    'Tidak ada data',
                    style: TextStyle(fontSize: 14, color: closeColor),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.7,
                      indent: 16,
                      endIndent: 16,
                      color: dividerColor,
                    ),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, option.value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10.5,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Center(
                                  child: Icon(
                                    option.icon,
                                    color: option.color,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w400,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Divider(
                height: 1,
                thickness: 0.7,
                indent: 16,
                endIndent: 16,
                color: dividerColor,
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: closeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
