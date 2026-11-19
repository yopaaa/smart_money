import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

class PerCategoryScreen extends StatefulWidget {
  final CategoryModel category;
  final int? startDate;
  final int? endDate;

  const PerCategoryScreen({
    super.key,
    required this.category,
    this.startDate,
    this.endDate,
  });

  @override
  State<PerCategoryScreen> createState() => _PerCategoryScreenState();
}

class _PerCategoryScreenState extends State<PerCategoryScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final provider = context.read<TransactionProvider>();
    final txs = await provider.filterTransactions(
      category: widget.category.id,
      startDate: widget.startDate,
      endDate: widget.endDate,
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
    final totalAmount = _transactions.fold<int>(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      const Text(
                        'Total in Category',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(totalAmount, currency),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_transactions.length} Transactions',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text(
                            'No transactions found for this category',
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
