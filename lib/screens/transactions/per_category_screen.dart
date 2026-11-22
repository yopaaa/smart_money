import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/date_utils.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

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
  late ViewMode _viewMode;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate =
        widget.initialDate ??
        (widget.startDate != null
            ? DateTime.fromMillisecondsSinceEpoch(widget.startDate!)
            : DateTime.now());
    _viewMode = widget.initialViewMode ?? ViewMode.month;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final start = AppDateUtils.getStartOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
    final end = AppDateUtils.getEndOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;

    final provider = context.read<TransactionProvider>();
    final txs = await provider.filterTransactions(
      category: widget.category.id,
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
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: groupedList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
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
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: groupedList.length,
                      itemBuilder: (context, index) {
                        final group = groupedList[index];
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
                      },
                    ),
            ),
    );
  }
}
