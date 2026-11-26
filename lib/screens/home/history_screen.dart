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
import '../../widgets/period_navigator.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/transaction_item.dart';
import '../transactions/transaction_detail_screen.dart';
import 'gallery_screen.dart';
import 'search_screen.dart';

sealed class _HistoryEntry {
  const _HistoryEntry();
}

class _HistoryHeaderEntry extends _HistoryEntry {
  final GroupedTransaction group;
  const _HistoryHeaderEntry(this.group);
}

class _HistoryTxEntry extends _HistoryEntry {
  final TransactionModel transaction;
  const _HistoryTxEntry(this.transaction);
}

class _HistorySpacerEntry extends _HistoryEntry {
  const _HistorySpacerEntry();
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ViewMode _viewMode = ViewMode.month;
  DateTime _selectedDate = DateTime.now();
  late final ValueNotifier<int> _tabNotifier;
  late final PageController _pageController;

  List<_HistoryEntry> _entries = const [];
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _netTotal = 0;
  late int _periodStartMs;
  late int _periodEndMs;

  bool _isLoading = false;
  int _fetchRequestId = 0;
  TransactionProvider? _provider;

  @override
  void initState() {
    super.initState();
    _tabNotifier = ValueNotifier<int>(0);
    _pageController = PageController(initialPage: 0);
    _recomputePeriodBounds();
    _fetchTransactions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TransactionProvider>();
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider?.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _tabNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _recomputePeriodBounds() {
    _periodStartMs = AppDateUtils.getStartOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
    _periodEndMs = AppDateUtils.getEndOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _fetchTransactions(showLoading: false);
  }

  void _rebuildCachedData(List<TransactionModel> transactions) {
    int income = 0;
    int expense = 0;
    for (final tx in transactions) {
      if (tx.type == 'income') {
        income += tx.amount;
      } else if (tx.type == 'expense') {
        expense += tx.amount;
      }
    }

    final grouped = AppDateUtils.groupTransactionsByDate(transactions);
    final entries = <_HistoryEntry>[];
    for (final group in grouped) {
      entries.add(_HistoryHeaderEntry(group));
      for (final tx in group.transactions) {
        entries.add(_HistoryTxEntry(tx));
      }
      entries.add(const _HistorySpacerEntry());
    }

    _totalIncome = income;
    _totalExpense = expense;
    _netTotal = income - expense;
    _entries = entries;
  }

  Future<void> _fetchTransactions({bool showLoading = true}) async {
    final requestId = ++_fetchRequestId;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final provider = _provider ?? context.read<TransactionProvider>();
      final txs = await provider.filterTransactions(
        startDate: _periodStartMs,
        endDate: _periodEndMs,
      );

      if (mounted && requestId == _fetchRequestId) {
        setState(() {
          _rebuildCachedData(txs);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _fetchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updatePeriod({DateTime? date, ViewMode? mode}) {
    setState(() {
      if (date != null) _selectedDate = date;
      if (mode != null) _viewMode = mode;
      _recomputePeriodBounds();
    });
    _fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        title: ValueListenableBuilder<int>(
          valueListenable: _tabNotifier,
          builder: (_, activeTab, _) => AnimatedTabBar(
            activeIndex: activeTab,
            onTabChanged: (index) {
              _tabNotifier.value = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
          ),
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
              ).then((_) => _fetchTransactions(showLoading: false));
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
                _updatePeriod(mode: selected);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: PeriodNavigator(
                selectedDate: _selectedDate,
                viewMode: _viewMode,
                onDateChange: (date) => _updatePeriod(date: date),
                onModeChange: (mode) => _updatePeriod(mode: mode),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  _tabNotifier.value = index;
                },
                children: [
                  _HistoryListTab(
                    isLoading: _isLoading,
                    entries: _entries,
                    totalIncome: _totalIncome,
                    totalExpense: _totalExpense,
                    netTotal: _netTotal,
                    currency: currency,
                    provider: provider,
                    onRefresh: () async {
                      await provider.loadData();
                      await _fetchTransactions(showLoading: false);
                    },
                    onTransactionTap: (tx) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionDetailScreen(transactionId: tx.id),
                        ),
                      ).then((_) => _fetchTransactions(showLoading: false));
                    },
                  ),
                  GalleryScreen(
                    startDate: _periodStartMs,
                    endDate: _periodEndMs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryListTab extends StatefulWidget {
  final bool isLoading;
  final List<_HistoryEntry> entries;
  final int totalIncome;
  final int totalExpense;
  final int netTotal;
  final CurrencyModel currency;
  final TransactionProvider provider;
  final Future<void> Function() onRefresh;
  final ValueChanged<TransactionModel> onTransactionTap;

  const _HistoryListTab({
    required this.isLoading,
    required this.entries,
    required this.totalIncome,
    required this.totalExpense,
    required this.netTotal,
    required this.currency,
    required this.provider,
    required this.onRefresh,
    required this.onTransactionTap,
  });

  @override
  State<_HistoryListTab> createState() => _HistoryListTabState();
}

class _HistoryListTabState extends State<_HistoryListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final descColor = isDark ? Colors.white60 : const Color(0xFF777777);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
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
                      Text(
                        'Income',
                        style: TextStyle(color: descColor, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          widget.totalIncome,
                          widget.currency,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expense',
                        style: TextStyle(color: descColor, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          -widget.totalExpense,
                          widget.currency,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(color: descColor, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          widget.netTotal,
                          widget.currency,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: widget.netTotal >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.entries.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: Center(
                  child: Text(
                    'Tidak ada transaksi pada periode ini',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList.builder(
                addAutomaticKeepAlives: false,
                itemCount: widget.entries.length,
                itemBuilder: (context, index) {
                  final entry = widget.entries[index];
                  switch (entry) {
                    case _HistoryHeaderEntry():
                      return TransactionDateHeader(
                        group: entry.group,
                        currency: widget.currency,
                      );
                    case _HistoryTxEntry():
                      final tx = entry.transaction;
                      return RepaintBoundary(
                        child: TransactionItemTile(
                          key: ValueKey(tx.id),
                          item: tx,
                          category: widget.provider.getCategoryById(
                            tx.category,
                          ),
                          currency: widget.currency,
                          onTap: () => widget.onTransactionTap(tx),
                        ),
                      );
                    case _HistorySpacerEntry():
                      return const SizedBox(height: 15);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
