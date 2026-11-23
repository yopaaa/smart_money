import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/transaction_item.dart';
import '../accounts/edit_account_screen.dart';
import 'transaction_detail_screen.dart';

class PerAccountScreen extends StatefulWidget {
  final AccountModel account;

  const PerAccountScreen({super.key, required this.account});

  @override
  State<PerAccountScreen> createState() => _PerAccountScreenState();
}

class _PerAccountScreenState extends State<PerAccountScreen> {
  late AccountModel _account;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  ViewMode _viewMode = ViewMode.month;

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

    final start = AppDateUtils.getStartOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
    final end = AppDateUtils.getEndOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;

    final txs = await provider.filterTransactions(
      accountId: _account.id,
      startDate: start,
      endDate: end,
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
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF11181C);
    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final descColor = isDark ? Colors.white60 : const Color(0xFF777777);
    final groupedList = AppDateUtils.groupTransactionsByDate(_transactions);

    // Calculate overview totals for this account within the selected period
    int totalIncome = 0;
    int totalExpense = 0;
    int totalTransferIn = 0;
    int totalTransferOut = 0;

    for (final tx in _transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.targetAccountId == _account.id) {
          totalTransferIn += tx.amount;
        } else if (tx.accountId == _account.id) {
          totalTransferOut += tx.amount;
        }
      }
    }

    final netTotal =
        totalIncome - totalExpense + totalTransferIn - totalTransferOut;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        title: Text(
          _account.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            tooltip: 'Edit Bucket',
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
          // Month navigator matching design in per_category_screen.dart & detail per categori ui.jpg
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Sebelumnya',
                  onPressed: () {
                    setState(() {
                      _selectedDate = AppDateUtils.addPeriod(
                        _selectedDate,
                        _viewMode,
                        -1,
                      );
                    });
                    _loadTransactions();
                  },
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final selected = await showPeriodPickerDialog(
                        context,
                        _viewMode,
                      );
                      if (selected != null && selected != _viewMode) {
                        setState(() => _viewMode = selected);
                        _loadTransactions();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        AppDateUtils.formatPeriodTitle(
                          _selectedDate,
                          _viewMode,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Berikutnya',
                  onPressed: () {
                    setState(() {
                      _selectedDate = AppDateUtils.addPeriod(
                        _selectedDate,
                        _viewMode,
                        1,
                      );
                    });
                    _loadTransactions();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Account Summary Card
                
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      children: [
                        // Overview Box matching HistoryScreen
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4.0,
                            bottom: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Overview for ${AppDateUtils.formatPeriodTitle(_selectedDate, _viewMode)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: descColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Income',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      totalIncome,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      -totalExpense,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Transfer In',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      totalTransferIn,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Transfer Out',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      -totalTransferOut,
                                      currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      netTotal,
                                      currency,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: netTotal >= 0
                                          ? AppColors.income
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Balance',
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      _account.balance,
                                      currency,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _account.balance >= 0
                                          ? AppColors.income
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (groupedList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48.0),
                            child: Center(
                              child: Text(
                                'Tidak ada transaksi pada periode ini',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...groupedList.map((group) {
                            return TransactionGroupWidget(
                              group: group,
                              currency: currency,
                              onTransactionTap: (tx) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                      transactionId: tx.id,
                                    ),
                                  ),
                                ).then((_) => _loadTransactions());
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
