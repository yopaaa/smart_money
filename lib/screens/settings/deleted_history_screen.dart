import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';

class DeletedHistoryScreen extends StatefulWidget {
  const DeletedHistoryScreen({super.key});

  @override
  State<DeletedHistoryScreen> createState() => _DeletedHistoryScreenState();
}

class _DeletedHistoryScreenState extends State<DeletedHistoryScreen> {
  List<TransactionModel> _deletedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeleted();
  }

  Future<void> _loadDeleted() async {
    final provider = context.read<TransactionProvider>();
    final list = await provider.getDeletedTransactions();
    if (mounted) {
      setState(() {
        _deletedList = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _restore(TransactionModel tx) async {
    final provider = context.read<TransactionProvider>();
    await provider.restoreDeletedTransaction(tx.id);
    await _loadDeleted();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored "${tx.title}"')),
      );
    }
  }

  Future<void> _permanentlyDelete(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: const Text('This transaction will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.permanentlyDeleteTransaction(tx.id);
      await _loadDeleted();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Permanently remove all items in trash bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.clearAllDeletedTransactions();
      await _loadDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          if (_deletedList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedList.isEmpty
              ? const Center(
                  child: Text(
                    'Recycle bin is empty',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _deletedList.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                  itemBuilder: (context, index) {
                    final tx = _deletedList[index];
                    final cat = provider.getCategoryById(tx.category);
                    final iconColor = cat != null
                        ? AppColors.parseHex(cat.color)
                        : Colors.grey;

                    String deletedTimeStr = '';
                    if (tx.deletedAt != null) {
                      final ms = int.tryParse(tx.deletedAt!);
                      if (ms != null) {
                        deletedTimeStr = DateFormat('dd MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
                      }
                    }

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(AppIcons.getIcon(cat?.icon), color: iconColor, size: 22),
                      ),
                      title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Deleted: $deletedTimeStr • ${CurrencyFormatter.format(tx.amount, currency)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: AppColors.primary),
                            onPressed: () => _restore(tx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: () => _permanentlyDelete(tx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
