import 'package:flutter/material.dart';
import '../utils/date_utils.dart';
import 'period_picker_dialog.dart';

class PeriodNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ViewMode viewMode;
  final ValueChanged<DateTime> onDateChange;
  final ValueChanged<ViewMode>? onModeChange;

  const PeriodNavigator({
    super.key,
    required this.selectedDate,
    required this.viewMode,
    required this.onDateChange,
    this.onModeChange,
  });

  @override
  Widget build(BuildContext context) {
    final title = AppDateUtils.formatPeriodTitle(selectedDate, viewMode);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF11181C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, size: 28, color: textColor),
            splashRadius: 22,
            tooltip: 'Sebelumnya',
            onPressed: () {
              onDateChange(AppDateUtils.addPeriod(selectedDate, viewMode, -1));
            },
          ),
          Expanded(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final selected = await showPeriodPickerDialog(
                      context,
                      viewMode,
                    );
                    if (selected != null && selected != viewMode) {
                      onModeChange?.call(selected);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, size: 28, color: textColor),
            splashRadius: 22,
            tooltip: 'Berikutnya',
            onPressed: () {
              onDateChange(AppDateUtils.addPeriod(selectedDate, viewMode, 1));
            },
          ),
        ],
      ),
    );
  }
}
