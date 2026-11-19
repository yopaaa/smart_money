import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

enum ViewMode { week, month, quarter, year }

class AppDateUtils {
  static DateTime getStartOfPeriod(DateTime date, ViewMode mode) {
    switch (mode) {
      case ViewMode.week:
        // Start from Monday
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - (weekday - 1), 0, 0, 0);
      case ViewMode.month:
        return DateTime(date.year, date.month, 1, 0, 0, 0);
      case ViewMode.quarter:
        final quarterMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, quarterMonth, 1, 0, 0, 0);
      case ViewMode.year:
        return DateTime(date.year, 1, 1, 0, 0, 0);
    }
  }

  static DateTime getEndOfPeriod(DateTime date, ViewMode mode) {
    switch (mode) {
      case ViewMode.week:
        final weekday = date.weekday;
        return DateTime(date.year, date.day + (7 - weekday), 23, 59, 59, 999);
      case ViewMode.month:
        final lastDay = DateTime(date.year, date.month + 1, 0).day;
        return DateTime(date.year, date.month, lastDay, 23, 59, 59, 999);
      case ViewMode.quarter:
        final quarterMonth = ((date.month - 1) ~/ 3) * 3 + 3;
        final lastDay = DateTime(date.year, quarterMonth + 1, 0).day;
        return DateTime(date.year, quarterMonth, lastDay, 23, 59, 59, 999);
      case ViewMode.year:
        return DateTime(date.year, 12, 31, 23, 59, 59, 999);
    }
  }

  static String formatPeriodTitle(DateTime date, ViewMode mode) {
    switch (mode) {
      case ViewMode.week:
        final start = getStartOfPeriod(date, mode);
        final end = getEndOfPeriod(date, mode);
        return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
      case ViewMode.month:
        return DateFormat('MMMM yyyy').format(date);
      case ViewMode.quarter:
        final quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year}';
      case ViewMode.year:
        return DateFormat('yyyy').format(date);
    }
  }

  static DateTime addPeriod(DateTime date, ViewMode mode, int count) {
    switch (mode) {
      case ViewMode.week:
        return date.add(Duration(days: 7 * count));
      case ViewMode.month:
        return DateTime(date.year, date.month + count, date.day);
      case ViewMode.quarter:
        return DateTime(date.year, date.month + (3 * count), date.day);
      case ViewMode.year:
        return DateTime(date.year + count, date.month, date.day);
    }
  }

  static List<GroupedTransaction> groupTransactionsByDate(List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> map = {};
    final Map<String, int> timestamps = {};
    final Map<String, int> totals = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      final txDate = tx.dateTime;
      final txDay = DateTime(txDate.year, txDate.month, txDate.day);

      String dateKey;
      if (txDay == today) {
        dateKey = 'Today';
      } else if (txDay == yesterday) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('dd MMM yyyy').format(txDay);
      }

      map.putIfAbsent(dateKey, () => []);
      map[dateKey]!.add(tx);

      timestamps[dateKey] = txDay.millisecondsSinceEpoch;

      final val = tx.type == 'income'
          ? tx.amount
          : tx.type == 'expense'
              ? -tx.amount
              : 0;
      totals[dateKey] = (totals[dateKey] ?? 0) + val;
    }

    final groups = map.entries.map((entry) {
      return GroupedTransaction(
        date: entry.key,
        timestamp: timestamps[entry.key] ?? 0,
        total: totals[entry.key] ?? 0,
        transactions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return groups;
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'a day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('HH:mm, dd MMM yyyy').format(dateTime);
    }
  }
}
