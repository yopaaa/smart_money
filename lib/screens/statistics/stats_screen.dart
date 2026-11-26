import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../services/monthly_report_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../../widgets/custom_pie_chart.dart';
import '../../widgets/period_navigator.dart';
import '../../widgets/period_picker_dialog.dart';
import '../../widgets/slide_select.dart';
import '../transactions/per_category_screen.dart';

class StatsScreen extends StatefulWidget {
  final bool isActive;

  const StatsScreen({super.key, this.isActive = true});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedType = 'expense'; // 'expense' | 'income'
  ViewMode _viewMode = ViewMode.month;
  DateTime _selectedDate = DateTime.now();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isExportingPdf = false;
  int? _selectedCategoryIndex;
  int _fetchRequestId = 0;
  int _chartAnimationSeed = 0;
  TransactionProvider? _provider;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      setState(() {
        _chartAnimationSeed++;
      });
    }
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
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _fetchStats(showLoading: false);
  }

  Future<void> _fetchStats({bool showLoading = true}) async {
    final requestId = ++_fetchRequestId;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final provider = _provider ?? context.read<TransactionProvider>();
    final start = AppDateUtils.getStartOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;
    final end = AppDateUtils.getEndOfPeriod(
      _selectedDate,
      _viewMode,
    ).millisecondsSinceEpoch;

    try {
      final txs = await provider.filterTransactions(
        type: _selectedType,
        startDate: start,
        endDate: end,
      );

      if (mounted && requestId == _fetchRequestId) {
        setState(() {
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted && requestId == _fetchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDownloadPdfReport() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final provider = _provider ?? context.read<TransactionProvider>();
      await provider.loadData();
      final allTxs = await provider.filterTransactions();

      final file = await MonthlyReportService.instance.exportAndShareReport(
        accounts: provider.accounts,
        categories: provider.categories,
        allTransactions: allTxs,
        currency: provider.currency,
        selectedDate: _selectedDate,
        viewMode: _viewMode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Laporan PDF siap: ${file.uri.pathSegments.last}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat laporan PDF: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  List<CategoryStatModel> _computeCategoryStats(TransactionProvider provider) {
    final Map<String, int> amounts = {};
    int total = 0;

    for (var tx in _transactions) {
      final catId = tx.category ?? 'other';
      amounts[catId] = (amounts[catId] ?? 0) + tx.amount;
      total += tx.amount;
    }

    final List<CategoryStatModel> stats = [];
    for (var entry in amounts.entries) {
      final category =
          provider.getCategoryById(entry.key) ??
          CategoryModel(
            id: entry.key,
            name: 'Lainnya',
            icon: 'dots-horizontal',
            color: '#b0bec5',
            type: _selectedType,
          );

      final percent = total > 0 ? (entry.value / total) * 100 : 0.0;
      stats.add(
        CategoryStatModel(
          categoryId: entry.key,
          categoryName: category.name,
          amount: entry.value,
          percent: percent,
          category: category,
        ),
      );
    }

    stats.sort((a, b) => b.amount.compareTo(a.amount));
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final stats = _computeCategoryStats(provider);
    final totalAmount = stats.fold<int>(0, (sum, item) => sum + item.amount);

    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Top Header Row matching ss/Untitled.jpg:
                // [ SlideSelect ]   Statistics   [ Calendar ]
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: SlideSelect (Expense / Income) with smooth animation
                    SlideSelect(
                      selectedType: _selectedType,
                      onChanged: (val) {
                        setState(() {
                          _selectedType = val;
                          _selectedCategoryIndex = null;
                        });
                        _fetchStats();
                      },
                    ),

                    // Middle: Statistics Title
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right: Calendar & PDF Download Action Icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.calendar_month_outlined,
                            size: 24,
                            color: textColor,
                          ),
                          tooltip: 'Pilih Periode',
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          padding: const EdgeInsets.all(6),
                          onPressed: () async {
                            final selected = await showPeriodPickerDialog(
                              context,
                              _viewMode,
                            );
                            if (selected != null && selected != _viewMode) {
                              setState(() => _viewMode = selected);
                              _fetchStats();
                            }
                          },
                        ),
                        IconButton(
                          icon: _isExportingPdf
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textColor,
                                  ),
                                )
                              : Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 23,
                                  color: textColor,
                                ),
                          tooltip: 'Unduh Laporan PDF',
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          padding: const EdgeInsets.all(6),
                          onPressed:
                              _isExportingPdf ? null : _handleDownloadPdfReport,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Period Navigator matching ss/Untitled.jpg with interactive badge & selector
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: PeriodNavigator(
                    selectedDate: _selectedDate,
                    viewMode: _viewMode,
                    onDateChange: (date) {
                      setState(() => _selectedDate = date);
                      _fetchStats();
                    },
                    onModeChange: (mode) {
                      setState(() => _viewMode = mode);
                      _fetchStats();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  // Solid Pie Chart with Outside Labels matching ss/Untitled.jpg
                  CustomPieChart(
                    stats: stats,
                    selectedIndex: _selectedCategoryIndex,
                    animationTrigger: _chartAnimationSeed,
                    onSliceTap: (index) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Total Summary matching ss/Untitled.jpg
                  Column(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalAmount, currency),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedType == 'expense'
                            ? 'Pengeluaran'
                            : 'Pemasukan',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  

                  // Category Cards List matching ss/Untitled.jpg
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stats.length,
                    padding: const EdgeInsets.only(bottom: 110),
                    itemBuilder: (context, index) {
                      final item = stats[index];
                      final catColor = AppColors.parseHex(item.category.color);
                      final isSelected = _selectedCategoryIndex == index;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? theme.dividerColor
                                      : Colors.transparent),
                            width: isSelected ? 1.5 : 1,
                          ),
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
                              setState(() {
                                _selectedCategoryIndex = index;
                              });
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PerCategoryScreen(
                                    category: item.category,
                                    initialDate: _selectedDate,
                                    initialViewMode: _viewMode,
                                    startDate: AppDateUtils.getStartOfPeriod(
                                      _selectedDate,
                                      _viewMode,
                                    ).millisecondsSinceEpoch,
                                    endDate: AppDateUtils.getEndOfPeriod(
                                      _selectedDate,
                                      _viewMode,
                                    ).millisecondsSinceEpoch,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Center(
                                      child: Icon(
                                        AppIcons.getIcon(item.category.icon),
                                        color: catColor,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.categoryName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          CurrencyFormatter.format(
                                            item.amount,
                                            currency,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color ??
                                                Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.percent.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
