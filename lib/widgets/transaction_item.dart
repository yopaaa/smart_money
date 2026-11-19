import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';

class TransactionItemTile extends StatelessWidget {
  final TransactionModel item;
  final VoidCallback? onTap;

  const TransactionItemTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final category = provider.getCategoryById(item.category);
    final currency = provider.currency;
    final theme = Theme.of(context);

    final isIncome = item.type == 'income';
    final isExpense = item.type == 'expense';

    final Color amountColor = isIncome
        ? AppColors.income
        : isExpense
            ? AppColors.expense
            : AppColors.transfer;

    final String prefix = isIncome ? '+' : isExpense ? '-' : '';

    final iconName = category?.icon ?? (item.type == 'transfer' ? 'bank-transfer' : 'dots-horizontal');
    final iconColor = category != null
        ? AppColors.parseHex(category.color)
        : (item.type == 'transfer' ? AppColors.transfer : Colors.grey);

    final timeAgoStr = AppDateUtils.formatTimeAgo(item.dateTime);

    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF777777);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${CurrencyFormatter.format(item.amount, currency)}',
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
