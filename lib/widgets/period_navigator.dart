import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class PeriodNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ViewMode viewMode;
  final ValueChanged<DateTime> onDateChange;

  const PeriodNavigator({
    super.key,
    required this.selectedDate,
    required this.viewMode,
    required this.onDateChange,
  });

  @override
  Widget build(BuildContext context) {
    final title = AppDateUtils.formatPeriodTitle(selectedDate, viewMode);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              onDateChange(AppDateUtils.addPeriod(selectedDate, viewMode, -1));
            },
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              onDateChange(AppDateUtils.addPeriod(selectedDate, viewMode, 1));
            },
          ),
        ],
      ),
    );
  }
}
