import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/transaction_item.dart';
import '../accounts/edit_account_screen.dart';
import 'transaction_detail_screen.dart';

class PerAccountScreen extends StatefulWidget {
  final AccountModel account;

  const PerAccountScreen({
    super.key,
    required this.account,
  });

  @override
  State<PerAccountScreen> createState() => _PerAccountScreenState();
}

class _PerAccountScreenState extends State<PerAccountScreen> {
  late AccountModel _account;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final provider = context.read<TransactionProvider>();
    final updatedAccount = provider.findAccount(_account.id);
    if (updatedAccount != null) {
      _account = updatedAccount;
    }

    final txs = await provider.filterTransactions(
      accountId: _account.id,
    );

    if (mounted) {
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final iconColor = AppColors.parseHex(_account.iconColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(_account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditAccountScreen(account: _account),
                ),
              );
              if (result == true) {
                _loadTransactions();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Account Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: theme.cardColor,
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.getIcon(_account.icon),
                          color: iconColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _account.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(_account.balance, currency),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _account.isLiability || _account.balance < 0
                              ? AppColors.expense
                              : AppColors.income,
                        ),
                      ),
                      if (_account.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _account.description,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text(
                            'No transactions for this account yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];
                            return TransactionItemTile(
                              item: tx,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                                  ),
                                ).then((_) => _loadTransactions());
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
