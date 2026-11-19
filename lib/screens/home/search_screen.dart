import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../../widgets/transaction_item.dart';
import '../transactions/transaction_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;
  List<TransactionModel> _results = [];

  @override
  void initState() {
    super.initState();
    _performSearch();
    _searchController.addListener(_performSearch);
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    final provider = context.read<TransactionProvider>();

    final txs = await provider.filterTransactions(
      search: query.isEmpty ? null : query,
      type: _selectedType,
    );

    if (mounted) {
      setState(() {
        _results = txs;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final groupedList = AppDateUtils.groupTransactionsByDate(_results);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Transactions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title or description...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // 3 Filter Pills: Income | Expense | Transfer (Screenshot 8)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                _buildFilterPill('income', 'Income'),
                const SizedBox(width: 8),
                _buildFilterPill('expense', 'Expense'),
                const SizedBox(width: 8),
                _buildFilterPill('transfer', 'Transfer'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Grouped Results List
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No matching transactions found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: groupedList.length,
                    itemBuilder: (context, groupIndex) {
                      final group = groupedList[groupIndex];
                      final isPositive = group.total >= 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 12.0,
                              bottom: 6.0,
                              left: 4.0,
                              right: 4.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.date,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
                          ...group.transactions.map((tx) {
                            return TransactionItemTile(
                              item: tx,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                                  ),
                                ).then((_) => _performSearch());
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String type, String label) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = isSelected ? null : type;
          });
          _performSearch();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade200 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.black87 : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black87 : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
