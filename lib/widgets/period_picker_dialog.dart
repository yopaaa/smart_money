import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../utils/date_utils.dart';

class PeriodOptionData {
  final ViewMode mode;
  final String title;
  final String englishTitle;
  final String subtitle;
  final IconData icon;
  final Color color;

  const PeriodOptionData({
    required this.mode,
    required this.title,
    required this.englishTitle,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const List<PeriodOptionData> kPeriodOptions = [
  PeriodOptionData(
    mode: ViewMode.week,
    title: 'Minggu',
    englishTitle: 'Week',
    subtitle: 'Rentang 7 hari (Senin - Minggu)',
    icon: Ionicons.calendarOutline,
    color: Color(0xFF2196F3),
  ),
  PeriodOptionData(
    mode: ViewMode.month,
    title: 'Bulan',
    englishTitle: 'Month',
    subtitle: 'Bulan kalender standar',
    icon: Ionicons.calendar,
    color: Color(0xFF4CAF50),
  ),
  PeriodOptionData(
    mode: ViewMode.quarter,
    title: 'Kuartal',
    englishTitle: 'Quarter',
    subtitle: 'Periode 3 bulan (Q1 - Q4)',
    icon: Ionicons.pieChartOutline,
    color: Color(0xFFFF9800),
  ),
  PeriodOptionData(
    mode: ViewMode.year,
    title: 'Tahun',
    englishTitle: 'Year',
    subtitle: 'Akumulasi satu tahun penuh',
    icon: Ionicons.albumsOutline,
    color: Color(0xFF9C27B0),
  ),
];

PeriodOptionData getPeriodOption(ViewMode mode) {
  return kPeriodOptions.firstWhere(
    (opt) => opt.mode == mode,
    orElse: () => kPeriodOptions[1],
  );
}

Future<ViewMode?> showPeriodPickerDialog(
  BuildContext context,
  ViewMode currentMode, {
  bool asBottomSheet = true,
}) {
  if (asBottomSheet) {
    return showModalBottomSheet<ViewMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => PeriodPickerSheet(currentMode: currentMode),
    );
  } else {
    return showDialog<ViewMode>(
      context: context,
      builder: (ctx) => PeriodPickerDialog(currentMode: currentMode),
    );
  }
}

class PeriodPickerSheet extends StatelessWidget {
  final ViewMode currentMode;

  const PeriodPickerSheet({super.key, required this.currentMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Rentang Waktu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF11181C),
                      ),
                    ),
                    
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Options List
          ...kPeriodOptions.map(
            (opt) => _buildOptionCard(
              context,
              option: opt,
              isSelected: opt.mode == currentMode,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class PeriodPickerDialog extends StatelessWidget {
  final ViewMode currentMode;

  const PeriodPickerDialog({super.key, required this.currentMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Rentang Waktu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF11181C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Filter riwayat transaksi & statistik',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...kPeriodOptions.map(
              (opt) => _buildOptionCard(
                context,
                option: opt,
                isSelected: opt.mode == currentMode,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildOptionCard(
  BuildContext context, {
  required PeriodOptionData option,
  required bool isSelected,
  required bool isDark,
}) {
  final textColor = isDark ? Colors.white : const Color(0xFF11181C);

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, option.mode),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? option.color.withOpacity(0.18)
                      : option.color.withOpacity(0.08))
                : (isDark ? const Color(0xFF262626) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? option.color
                  : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Signature colored icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: option.color.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(option.icon, color: option.color, size: 22),
              ),
              const SizedBox(width: 14),

              // Title, English badge, Active pill, and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          option.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? option.color : textColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Text(
                        //   '(${option.englishTitle})',
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     fontWeight: FontWeight.w500,
                        //     color: isDark
                        //         ? Colors.grey[400]
                        //         : const Color(0xFF6B7280),
                        //   ),
                        // ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: option.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Selection checkmark or empty indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
