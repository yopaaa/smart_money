import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../models/category_model.dart';
import '../models/currency_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';

class TransactionItemTile extends StatelessWidget {
  final TransactionModel item;
  final CategoryModel? category;
  final CurrencyModel? currency;
  final VoidCallback? onTap;

  const TransactionItemTile({
    super.key,
    required this.item,
    this.category,
    this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedCategory =
        category ??
        context.select<TransactionProvider, CategoryModel?>(
          (p) => p.getCategoryById(item.category),
        );
    final resolvedCurrency =
        currency ??
        context.select<TransactionProvider, CurrencyModel>((p) => p.currency);
    final theme = Theme.of(context);

    final isIncome = item.type == 'income';
    final isExpense = item.type == 'expense';

    final Color amountColor = isIncome
        ? AppColors.income
        : isExpense
        ? AppColors.expense
        : AppColors.transfer;

    final String prefix = isIncome
        ? '+'
        : isExpense
        ? '-'
        : '';

    final iconName =
        resolvedCategory?.icon ??
        (item.type == 'transfer' ? 'bank-transfer' : 'dots-horizontal');
    final iconColor = resolvedCategory != null
        ? AppColors.parseHex(resolvedCategory.color)
        : (item.type == 'transfer' ? AppColors.transfer : Colors.grey);

    final timeAgoStr = AppDateUtils.formatTimeAgo(item.dateTime);

    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF777777);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.045),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      AppIcons.getIcon(iconName),
                      color: iconColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        timeAgoStr,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${CurrencyFormatter.format(item.amount, resolvedCurrency)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
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

class TransactionDateHeader extends StatelessWidget {
  static final DateFormat _dayFmt = DateFormat('dd');
  static final DateFormat _dayNameFmt = DateFormat('EEEE');
  static final DateFormat _monthYearFmt = DateFormat('MMM yyyy');

  final GroupedTransaction group;
  final CurrencyModel currency;

  const TransactionDateHeader({
    super.key,
    required this.group,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF11181C);

    final isExpense = group.total < 0;
    final amountColor = isExpense
        ? const Color(0xFFC62828)
        : (group.total > 0 ? const Color(0xFF2E7D32) : textColor);

    final isSpecialDate = group.date == 'Today' || group.date == 'Yesterday';
    final dt = DateTime.fromMillisecondsSinceEpoch(group.timestamp);
    final dayNumber = _dayFmt.format(dt);
    final dayName = _dayNameFmt.format(dt);
    final monthYear = _monthYearFmt.format(dt);

    final formattedAmount = CurrencyFormatter.format(group.total, currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: 18.0,
            bottom: 8.0,
            left: 4.0,
            right: 4.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSpecialDate)
                Text(
                  group.date,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      dayNumber,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          monthYear,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF666666),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              Text(
                formattedAmount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: isDark ? Colors.white12 : const Color(0xFFE5E5E5),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class TransactionGroupWidget extends StatelessWidget {
  final GroupedTransaction group;
  final CurrencyModel currency;
  final ValueChanged<TransactionModel>? onTransactionTap;

  const TransactionGroupWidget({
    super.key,
    required this.group,
    required this.currency,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TransactionDateHeader(group: group, currency: currency),
        ...group.transactions.map((tx) {
          return TransactionItemTile(
            item: tx,
            onTap: onTransactionTap != null
                ? () => onTransactionTap!(tx)
                : null,
          );
        }),

        SizedBox(height: 15),
      ],
    );
  }
}
