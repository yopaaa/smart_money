import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/currency_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../../widgets/animated_tab_bar.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/transaction_item.dart';
import '../transactions/transaction_detail_screen.dart';
import 'gallery_screen.dart';
import 'search_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ViewMode _viewMode = ViewMode.month;
  DateTime _selectedDate = DateTime.now();
  int _currentTab = 0; // 0: List, 1: Gallery
  late final PageController _pageController;
  List<TransactionModel> _currentTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchTransactions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<TransactionProvider>();
      final start = AppDateUtils.getStartOfPeriod(_selectedDate, _viewMode).millisecondsSinceEpoch;
      final end = AppDateUtils.getEndOfPeriod(_selectedDate, _viewMode).millisecondsSinceEpoch;

      final txs = await provider.filterTransactions(
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        setState(() {
          _currentTransactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);

    // Calculate overview
    int totalIncome = 0;
    int totalExpense = 0;
    for (var tx in _currentTransactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      }
    }
    final netTotal = totalIncome - totalExpense;

    final groupedList = AppDateUtils.groupTransactionsByDate(_currentTransactions);

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        title: AnimatedTabBar(
          activeIndex: _currentTab,
          onTabChanged: (index) {
            setState(() => _currentTab = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Ionicons.search,
              size: 24,
              color: isDark ? Colors.white : const Color(0xFF11181C),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ).then((_) => _fetchTransactions());
            },
          ),
          IconButton(
            icon: Icon(
              Ionicons.calendar,
              size: 24,
              color: isDark ? Colors.white : const Color(0xFF11181C),
            ),
            onPressed: () async {
              final selected = await showPeriodPickerDialog(context, _viewMode);
              if (selected != null && selected != _viewMode) {
                setState(() => _viewMode = selected);
                _fetchTransactions();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadData();
          await _fetchTransactions();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Date Navigator (No Box, pure text and arrows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        size: 28,
                        color: isDark ? Colors.white : const Color(0xFF11181C),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedDate = AppDateUtils.addPeriod(_selectedDate, _viewMode, -1);
                        });
                        _fetchTransactions();
                      },
                    ),
                    Text(
                      AppDateUtils.formatPeriodTitle(_selectedDate, _viewMode),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF11181C),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        size: 28,
                        color: isDark ? Colors.white : const Color(0xFF11181C),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedDate = AppDateUtils.addPeriod(_selectedDate, _viewMode, 1);
                        });
                        _fetchTransactions();
                      },
                    ),
                  ],
                ),
              ),

              // Content with smooth sliding PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentTab = index);
                  },
                  children: [
                    // Tab 0: History List View
                    _buildHistoryListView(
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                      netTotal: netTotal,
                      currency: currency,
                      groupedList: groupedList,
                      theme: theme,
                    ),

                    // Tab 1: Gallery View
                    GalleryScreen(
                      startDate: AppDateUtils.getStartOfPeriod(_selectedDate, _viewMode).millisecondsSinceEpoch,
                      endDate: AppDateUtils.getEndOfPeriod(_selectedDate, _viewMode).millisecondsSinceEpoch,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryListView({
    required int totalIncome,
    required int totalExpense,
    required int netTotal,
    required CurrencyModel currency,
    required List<GroupedTransaction> groupedList,
    required ThemeData theme,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final descColor = isDark ? Colors.white60 : const Color(0xFF777777);

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Overview Box
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline, size: 16, color: descColor),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Income', style: TextStyle(color: descColor, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(totalIncome, currency),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Expense', style: TextStyle(color: descColor, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(-totalExpense, currency),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: TextStyle(color: descColor, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(netTotal, currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: netTotal >= 0 ? AppColors.income : AppColors.expense,
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
            final isPositive = group.total >= 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 14.0,
                    bottom: 6.0,
                    left: 2.0,
                    right: 2.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group.date,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(group.total, currency),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isPositive ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                // Individual transaction cards
                ...group.transactions.map((tx) {
                  return TransactionItemTile(
                    item: tx,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                        ),
                      ).then((_) => _fetchTransactions());
                    },
                  );
                }),
              ],
            );
          }),
      ],
    );
  }
}
