import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../transactions/per_account_screen.dart';
import 'create_account_screen.dart';
import 'modify_account_order_screen.dart';
import 'show_and_hide_account_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _isHideBalance = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);

    // Compute Summary matching React Native Account.jsx
    int assets = 0;
    int liabilities = 0;
    for (var acc in provider.accounts) {
      if (acc.hidden) continue;
      if (acc.isLiability) {
        liabilities -= acc.balance;
      } else {
        assets += acc.balance;
      }
    }
    final netWorth = assets - liabilities;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Buckets And Balances',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          // Eye Icon inside blue rounded button (Screenshot 1)
          GestureDetector(
            onTap: () {
              setState(() {
                _isHideBalance = !_isHideBalance;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isHideBalance ? Icons.visibility_off : Icons.visibility,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          // 3 Dots Menu (Screenshot 2)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'add') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                );
              } else if (val == 'show_hide') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShowAndHideAccountScreen()),
                );
              } else if (val == 'modify_order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModifyAccountOrderScreen()),
                );
              } else if (val == 'delete') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShowAndHideAccountScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add',
                child: Text('Add Bucket'),
              ),
              PopupMenuItem(
                value: 'show_hide',
                child: Text('Show/Hide'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
              PopupMenuItem(
                value: 'modify_order',
                child: Text('Modify Orders'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3-Column Clean Summary matching Screenshot 1
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      title: 'Assets',
                      amount: assets,
                      color: AppColors.primary,
                      isHide: _isHideBalance,
                      currency: currency,
                    ),
                    _buildSummaryItem(
                      title: 'Liabilities',
                      amount: liabilities,
                      color: AppColors.expense,
                      isHide: _isHideBalance,
                      currency: currency,
                    ),
                    _buildSummaryItem(
                      title: 'Total',
                      amount: netWorth,
                      color: netWorth >= 0 ? AppColors.primary : AppColors.expense,
                      isHide: _isHideBalance,
                      currency: currency,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grouped accounts
              if (provider.groupedAccounts.isEmpty)
                Container(
                  height: 300,
                  alignment: Alignment.center,
                  child: const Text('No buckets found. Tap + to add one.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.groupedAccounts.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, groupIdx) {
                    final group = provider.groupedAccounts[groupIdx];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Header (Screenshot 1: uppercase CASH on left, balance on right)
                        Padding(
                          padding: const EdgeInsets.only(top: 14.0, bottom: 8.0, left: 4.0, right: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                group.title.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _isHideBalance
                                    ? '*****'
                                    : CurrencyFormatter.format(group.balance, currency),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: group.balance < 0 ? AppColors.expense : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Individual account cards matching Screenshot 1
                        ...group.accounts.map((acc) {
                          final iconColor = AppColors.parseHex(acc.iconColor);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PerAccountScreen(account: acc),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: iconColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            AppIcons.getIcon(acc.icon),
                                            color: iconColor,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          acc.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _isHideBalance
                                            ? '*****'
                                            : CurrencyFormatter.format(acc.balance, currency),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: acc.isLiability || acc.balance < 0
                                              ? AppColors.expense
                                              : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required int amount,
    required Color color,
    required bool isHide,
    required dynamic currency,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          isHide ? '*****' : CurrencyFormatter.format(amount, currency),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
