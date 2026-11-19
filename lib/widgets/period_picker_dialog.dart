import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../utils/date_utils.dart';

Future<ViewMode?> showPeriodPickerDialog(BuildContext context, ViewMode currentMode) {
  return showDialog<ViewMode>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(
              ctx,
              icon: Ionicons.calendarOutline,
              color: const Color(0xFF2196F3),
              title: 'Week',
              mode: ViewMode.week,
              isSelected: currentMode == ViewMode.week,
            ),
            const Divider(height: 1),
            _buildOption(
              ctx,
              icon: Ionicons.calendar,
              color: const Color(0xFF4CAF50),
              title: 'Month',
              mode: ViewMode.month,
              isSelected: currentMode == ViewMode.month,
            ),
            const Divider(height: 1),
            _buildOption(
              ctx,
              icon: Ionicons.calendarClearOutline,
              color: const Color(0xFFFF9800),
              title: 'Quarter',
              mode: ViewMode.quarter,
              isSelected: currentMode == ViewMode.quarter,
            ),
            const Divider(height: 1),
            _buildOption(
              ctx,
              icon: Ionicons.albumsOutline,
              color: const Color(0xFF9C27B0),
              title: 'Year',
              mode: ViewMode.year,
              isSelected: currentMode == ViewMode.year,
            ),
            const Divider(height: 1),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Tutup',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildOption(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required ViewMode mode,
  required bool isSelected,
}) {
  return ListTile(
    leading: Icon(icon, color: color, size: 24),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
    ),
    onTap: () => Navigator.pop(context, mode),
  );
}
