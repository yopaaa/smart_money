import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _transaction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final provider = context.read<TransactionProvider>();
    final tx = await provider.getTransactionById(widget.transactionId);
    if (mounted) {
      setState(() {
        _transaction = tx;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    if (_transaction == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(editTransaction: _transaction!),
      ),
    );
    if (result == true) {
      _loadTransaction();
    }
  }

  void _handleCopy() {
    if (_transaction == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(copyFromTransaction: _transaction!),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? It will be moved to Recycle Bin and account balances will be adjusted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.deleteTransaction(widget.transactionId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final tx = _transaction!;
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final account = provider.findAccount(tx.accountId);
    final targetAccount = provider.findAccount(tx.targetAccountId);
    final category = provider.getCategoryById(tx.category);
    final theme = Theme.of(context);

    final isIncome = tx.type == 'income';
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';

    final Color amountColor = isIncome
        ? AppColors.income
        : isExpense
            ? AppColors.expense
            : AppColors.transfer;

    final String prefix = isIncome ? '+' : isExpense ? '-' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
            onPressed: _handleCopy,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _handleEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete',
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Amount and Title Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  Text(
                    tx.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$prefix${CurrencyFormatter.format(tx.amount, currency)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: amountColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tx.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata items
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  if (!isTransfer && category != null) ...[
                    _buildDetailRow(
                      context,
                      icon: AppIcons.getIcon(category.icon),
                      iconColor: AppColors.parseHex(category.color),
                      title: 'Category',
                      value: category.name,
                    ),
                    Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                  ],
                  _buildDetailRow(
                    context,
                    icon: AppIcons.getIcon(account?.icon),
                    iconColor: AppColors.parseHex(account?.iconColor),
                    title: isTransfer ? 'From Account' : 'Account',
                    value: account?.name ?? 'Unknown',
                  ),
                  if (isTransfer && targetAccount != null) ...[
                    Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    _buildDetailRow(
                      context,
                      icon: AppIcons.getIcon(targetAccount.icon),
                      iconColor: AppColors.parseHex(targetAccount.iconColor),
                      title: 'To Account',
                      value: targetAccount.name,
                    ),
                  ],
                  if (isTransfer && tx.fee > 0) ...[
                    Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    _buildDetailRow(
                      context,
                      icon: Icons.receipt,
                      iconColor: Colors.orange,
                      title: 'Transfer Fee',
                      value: CurrencyFormatter.format(tx.fee, currency),
                    ),
                  ],
                  Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_today,
                    iconColor: Colors.blueGrey,
                    title: 'Date & Time',
                    value: DateFormat('dd MMMM yyyy, HH:mm').format(tx.dateTime),
                  ),
                  if (tx.description != null && tx.description!.isNotEmpty) ...[
                    Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    _buildDetailRow(
                      context,
                      icon: Icons.notes,
                      iconColor: Colors.grey,
                      title: 'Notes',
                      value: tx.description!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image Receipt
            if (tx.img != null && tx.img!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receipt Attachment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        // View full screen image dialog
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.file(File(tx.img!)),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: File(tx.img!).existsSync()
                            ? Image.file(
                                File(tx.img!),
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                              )
                            : const Text('Image file not found'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: _deleteTransaction,
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: _handleCopy,
                    child: const Text(
                      'Salin',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: _handleEdit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
