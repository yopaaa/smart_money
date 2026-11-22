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
    final opt = getPeriodOption(viewMode);

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
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Icon(
                        //   Icons.keyboard_arrow_down_rounded,
                        //   size: 18,
                        //   color: textColor.withOpacity(0.5),
                        // ),
                      ],
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
