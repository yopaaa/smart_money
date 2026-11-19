import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import 'edit_account_screen.dart';

class ShowAndHideAccountScreen extends StatefulWidget {
  const ShowAndHideAccountScreen({super.key});

  @override
  State<ShowAndHideAccountScreen> createState() => _ShowAndHideAccountScreenState();
}

class _ShowAndHideAccountScreenState extends State<ShowAndHideAccountScreen> {
  Future<void> _toggleHide(AccountModel account) async {
    final provider = context.read<TransactionProvider>();
    final updated = account.copyWith(hidden: !account.hidden);
    await provider.editAccount(account.id, updated);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Show And Hide Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: provider.groupedAccounts.length,
        itemBuilder: (context, groupIndex) {
          final group = provider.groupedAccounts[groupIndex];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Icon(
                      AppIcons.getIcon(group.icon),
                      color: AppColors.parseHex(group.color),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(group.balance, currency),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: group.balance < 0 ? AppColors.expense : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Account Items in Group
              ...group.accounts.map((acc) {
                final isHidden = acc.hidden;
                final iconColor = AppColors.parseHex(acc.iconColor);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Icon(
                        AppIcons.getIcon(acc.icon),
                        color: iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          acc.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isHidden ? Icons.visibility_off : Icons.visibility,
                          color: isHidden ? Colors.red.shade700 : Colors.green.shade700,
                          size: 22,
                        ),
                        onPressed: () => _toggleHide(acc),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditAccountScreen(account: acc),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }
}
