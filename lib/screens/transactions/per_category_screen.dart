import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/date_utils.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

class _MonthlyCategoryData {
  final DateTime date;
  final int amount;

  _MonthlyCategoryData({required this.date, required this.amount});
}

class PerCategoryScreen extends StatefulWidget {
  final CategoryModel category;
  final DateTime? initialDate;
  final ViewMode? initialViewMode;
  final int? startDate;
  final int? endDate;

  const PerCategoryScreen({
    super.key,
    required this.category,
    this.initialDate,
    this.initialViewMode,
    this.startDate,
    this.endDate,
  });

  @override
  State<PerCategoryScreen> createState() => _PerCategoryScreenState();
}

class _PerCategoryScreenState extends State<PerCategoryScreen> {
  late DateTime _selectedDate;
  late DateTime _chartAnchorDate;
  late ViewMode _viewMode;
  List<TransactionModel> _transactions = [];
  List<_MonthlyCategoryData> _monthlyData = [];
  int _preWindowMonthAmount = 0; // Amount for month before Bar 0 for percentage comparison
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate =
        widget.initialDate ??
        (widget.startDate != null
            ? DateTime.fromMillisecondsSinceEpoch(widget.startDate!)
            : DateTime.now());
    _chartAnchorDate = _selectedDate;
    _viewMode = widget.initialViewMode ?? ViewMode.month;
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool checkAnchorBounds = true}) async {
    // If selectedDate moved outside the 6-month chart window, update chartAnchorDate
    if (checkAnchorBounds) {
      final windowStart = DateTime(
        _chartAnchorDate.year,
        _chartAnchorDate.month - 5,
        1,
      );
      final windowEnd = DateTime(
        _chartAnchorDate.year,
        _chartAnchorDate.month,
        1,
      );
      final selMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        1,
      );

      if (selMonth.isBefore(windowStart) || selMonth.isAfter(windowEnd)) {
        _chartAnchorDate = _selectedDate;
      }
    }

    final start = AppDateUtils.getStartOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
    final end = AppDateUtils.getEndOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;

    final provider = context.read<TransactionProvider>();

    // Load transactions for the currently selected period (list view)
    final txs = await provider.filterTransactions(
      category: widget.category.id,
      startDate: start,
      endDate: end,
    );

    // 6-Month Comparison Range based on _chartAnchorDate:
    // We load from 6 months before _chartAnchorDate so even Bar 0 has a previous month to calculate percentage from
    final earliestMonth = DateTime(
      _chartAnchorDate.year,
      _chartAnchorDate.month - 6,
      1,
    );
    final earliestStart = DateTime(
      earliestMonth.year,
      earliestMonth.month,
      1,
      0,
      0,
      0,
    ).millisecondsSinceEpoch;
    final latestEnd = DateTime(
      _chartAnchorDate.year,
      _chartAnchorDate.month + 1,
      0,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final chartTxs = await provider.filterTransactions(
      category: widget.category.id,
      startDate: earliestStart,
      endDate: latestEnd,
    );

    // Calculate sum for month before Bar 0
    int preWindowSum = 0;
    for (final tx in chartTxs) {
      final dt = tx.dateTime;
      if (dt.year == earliestMonth.year && dt.month == earliestMonth.month) {
        preWindowSum += tx.amount;
      }
    }

    // 6 bars from (_chartAnchorDate - 5 months) to _chartAnchorDate
    final List<_MonthlyCategoryData> monthlyData = [];
    for (int i = 5; i >= 0; i--) {
      final mDate = DateTime(
        _chartAnchorDate.year,
        _chartAnchorDate.month - i,
        1,
      );
      int sum = 0;
      for (final tx in chartTxs) {
        final dt = tx.dateTime;
        if (dt.year == mDate.year && dt.month == mDate.month) {
          sum += tx.amount;
        }
      }
      monthlyData.add(_MonthlyCategoryData(date: mDate, amount: sum));
    }

    if (mounted) {
      setState(() {
        _transactions = txs;
        _monthlyData = monthlyData;
        _preWindowMonthAmount = preWindowSum;
        _isLoading = false;
      });
    }
  }

  String _formatCompactAmount(int amount) {
    if (amount == 0) return '0';
    if (amount >= 1000000000) {
      final v = amount / 1000000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '')}B';
    }
    if (amount >= 1000000) {
      final v = amount / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '')}M';
    }
    if (amount >= 1000) {
      final v = amount / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '')}k';
    }
    return amount.toString();
  }

  Widget _buildMonthlyComparisonChart(
    ThemeData theme,
    Color categoryColor,
    bool isDark,
  ) {
    if (_monthlyData.isEmpty) return const SizedBox.shrink();

    final titleColor = isDark ? Colors.white : const Color(0xFF11181C);
    final descColor = isDark ? Colors.white60 : const Color(0xFF777777);

    // Calculate maximum amount across the 6 months for scaling
    int maxAmount = 0;
    for (final m in _monthlyData) {
      if (m.amount > maxAmount) maxAmount = m.amount;
    }

    // Find the currently selected month index in _monthlyData
    int selectedIndex = _monthlyData.indexWhere(
      (m) =>
          m.date.year == _selectedDate.year &&
          m.date.month == _selectedDate.month,
    );
    if (selectedIndex == -1) {
      // Default to the last bar (current anchor month) if not in range
      selectedIndex = _monthlyData.length - 1;
    }

    final isIncomeCat = widget.category.type == 'income';

    // Calculate percentage change for the selected month relative to previous month
    final currentAmount = _monthlyData[selectedIndex].amount;
    final int prevAmount = selectedIndex > 0
        ? _monthlyData[selectedIndex - 1].amount
        : _preWindowMonthAmount;

    late final String selectedPctText;
    Color selectedPctColor = Colors.grey;
    IconData? selectedPctIcon;

    if (prevAmount == 0) {
      if (currentAmount > 0) {
        selectedPctText = '+100%';
        selectedPctColor = isIncomeCat ? AppColors.income : AppColors.expense;
        selectedPctIcon = Icons.arrow_upward_rounded;
      } else {
        selectedPctText = '0%';
        selectedPctColor = Colors.grey;
      }
    } else {
      final double change =
          ((currentAmount - prevAmount) / prevAmount) * 100;
      if (change > 0) {
        selectedPctText =
            '+${change.toStringAsFixed(change.truncateToDouble() == change ? 0 : 1)}%';
        selectedPctColor = isIncomeCat ? AppColors.income : AppColors.expense;
        selectedPctIcon = Icons.arrow_upward_rounded;
      } else if (change < 0) {
        selectedPctText =
            '${change.toStringAsFixed(change.truncateToDouble() == change ? 0 : 1)}%';
        selectedPctColor = isIncomeCat ? AppColors.expense : AppColors.income;
        selectedPctIcon = Icons.arrow_downward_rounded;
      } else {
        selectedPctText = '0%';
        selectedPctColor = Colors.grey;
      }
    }

    const double maxBarHeight = 80.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Perbandingan 6 Bulan Terakhir',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selectedPctColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedPctIcon != null) ...[
                      Icon(selectedPctIcon, size: 13, color: selectedPctColor),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      selectedPctText,
                      style: TextStyle(
                        color: selectedPctColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6 Interactive Bars Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_monthlyData.length, (index) {
              final data = _monthlyData[index];
              final isSelected = index == selectedIndex;

              final double heightRatio =
                  maxAmount > 0 ? (data.amount / maxAmount) : 0.0;
              final double barHeight = maxAmount > 0
                  ? math.max(6.0, heightRatio * maxBarHeight)
                  : 6.0;

              final rawMonth = DateFormat('MMM').format(data.date);
              final label = rawMonth.length > 3
                  ? rawMonth.substring(0, 3)
                  : rawMonth;

              final barColor = isSelected
                  ? categoryColor
                  : categoryColor.withOpacity(0.35);

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      // Switch to tapped month and update history transactions below,
                      // while preserving the chart's 6-month window!
                      setState(() {
                        _selectedDate = DateTime(data.date.year, data.date.month, 1);
                        _viewMode = ViewMode.month;
                      });
                      _loadTransactions(checkAnchorBounds: false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Percentage badge above the selected bar
                          SizedBox(
                            height: 16,
                            child: isSelected
                                ? Text(
                                    selectedPctText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: selectedPctColor,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 2),

                          // Amount above bar
                          Text(
                            _formatCompactAmount(data.amount),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? titleColor : descColor,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Bar container with background track
                          Container(
                            width: 22,
                            height: maxBarHeight,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(
                                      color: categoryColor.withOpacity(0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Container(
                              width: 22,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 3-letter month label below bar
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? categoryColor : descColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF11181C);
    final categoryColor = AppColors.parseHex(widget.category.color);

    final groupedList = AppDateUtils.groupTransactionsByDate(_transactions);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        title: Text(
          '${widget.category.name} Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Date navigator in AppBar matching ss/detail per categori ui.jpg
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
                    _loadTransactions(checkAnchorBounds: true);
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
                        _loadTransactions(checkAnchorBounds: true);
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
                    _loadTransactions(checkAnchorBounds: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadTransactions(checkAnchorBounds: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 40.0),
                children: [
                  // 6-Month Comparison Bar Chart
                  _buildMonthlyComparisonChart(theme, categoryColor, isDark),
                  const SizedBox(height: 16),

                  // Transactions list or empty placeholder
                  if (groupedList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada transaksi pada periode ini',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
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
                          ).then((_) => _loadTransactions(checkAnchorBounds: false));
                        },
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
