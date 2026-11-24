import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../services/chat_history_service.dart';
import '../../services/gemini_voice_service.dart';
import '../../utils/currency_formatter.dart';

class VoiceTransactionReviewSheet extends StatefulWidget {
  final List<ParsedVoiceTransaction> initialTransactions;
  final String? transcript;

  const VoiceTransactionReviewSheet({
    super.key,
    required this.initialTransactions,
    this.transcript,
  });

  /// Helper static method to show the review modal bottom sheet.
  static Future<bool?> show({
    required BuildContext context,
    required List<ParsedVoiceTransaction> transactions,
    String? transcript,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceTransactionReviewSheet(
        initialTransactions: transactions,
        transcript: transcript,
      ),
    );
  }

  @override
  State<VoiceTransactionReviewSheet> createState() =>
      _VoiceTransactionReviewSheetState();
}

class _VoiceTransactionReviewSheetState
    extends State<VoiceTransactionReviewSheet> {
  late List<ParsedVoiceTransaction> _items;
  late Set<String> _selectedIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialTransactions);
    // All items checked by default as requested!
    _selectedIds = _items.map((e) => e.id).toSet();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _items.map((e) => e.id).toSet();
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      final id = _items[index].id;
      _items.removeAt(index);
      _selectedIds.remove(id);
    });

    if (_items.isEmpty && mounted) {
      Navigator.pop(context, false);
    }
  }

  Future<void> _handleSaveSelected() async {
    final selectedItems =
        _items.where((e) => _selectedIds.contains(e.id)).toList();
    if (selectedItems.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final txProvider = context.read<TransactionProvider>();
      final txModels = selectedItems.map((e) => e.toTransactionModel()).toList();

      await txProvider.addTransactions(txModels);

      // Save transcript & result to Chat History
      try {
        String transcript;
        if (widget.transcript != null && widget.transcript!.trim().isNotEmpty) {
          transcript = widget.transcript!.trim();
        } else {
          final transcriptParts = selectedItems.map((e) {
            final desc =
                e.description.replaceAll('', '').trim();
            return desc.isNotEmpty ? desc : e.title;
          }).toList();
          transcript = transcriptParts.join(', ');
        }

        await ChatHistoryService.instance.addVoiceTransactionChat(
          transcript: transcript,
          savedTransactions: txModels,
        );
      } catch (err) {
        debugPrint('Failed to save to chat history: $err');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${selectedItems.length} transaksi berhasil disimpan!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txProvider = context.watch<TransactionProvider>();
    final currency = txProvider.currency;
    final accounts = txProvider.accounts;
    final categories = txProvider.categories;

    final sheetBg = isDark ? const Color(0xFF13222D) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final selectedCount = _selectedIds.length;
    final isAllSelected = selectedCount == _items.length && _items.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tinjau Transaksi AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Ditemukan ${_items.length} transaksi dari ucapan Anda',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Select All Text Button
                  TextButton(
                    onPressed: _items.isEmpty ? null : _toggleSelectAll,
                    child: Text(
                      isAllSelected ? 'Batal Semua' : 'Pilih Semua',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: borderColor),

            // Scrollable List of Transaction Cards
            Flexible(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isChecked = _selectedIds.contains(item.id);
                  return _buildTransactionCard(
                    item: item,
                    index: index,
                    isChecked: isChecked,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    accounts: accounts,
                    categories: categories,
                    currency: currency,
                    isDark: isDark,
                  );
                },
              ),
            ),

            Divider(height: 1, color: borderColor),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: selectedCount > 0 && !_isSaving
                      ? _handleSaveSelected
                      : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          selectedCount == _items.length
                              ? 'Simpan Semua Transaksi ($selectedCount)'
                              : 'Simpan $selectedCount Transaksi Terpilih',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required ParsedVoiceTransaction item,
    required int index,
    required bool isChecked,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required dynamic currency,
    required bool isDark,
  }) {
    final isExpense = item.type == 'expense';
    final isIncome = item.type == 'income';
    final isTransfer = item.type == 'transfer';

    final Color typeColor = isExpense
        ? AppColors.expense
        : (isIncome ? AppColors.income : AppColors.transfer);

    final String typeLabel = isExpense
        ? 'Pengeluaran'
        : (isIncome ? 'Pemasukan' : 'Transfer');

    // Find category details
    final cat = categories.where((c) => c.id == item.categoryId);
    final categoryModel = cat.isNotEmpty ? cat.first : null;

    return Material(
      color: isChecked ? cardBg : cardBg.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isChecked
              ? AppColors.primary.withOpacity(0.35)
              : borderColor,
          width: isChecked ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Title, Amount & Delete Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: isChecked,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(item.id);
                        } else {
                          _selectedIds.remove(item.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(item.dateTime),
                        style: TextStyle(fontSize: 11.5, color: subtextColor),
                      ),
                    ],
                  ),
                ),

                // Amount
                Text(
                  CurrencyFormatter.format(item.amount, currency),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),

                // Delete Item Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.grey,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),

            // Chips Row: Category, Account, & Transfer Target
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Category Chip (if not transfer)
                if (!isTransfer)
                  _buildSelectorChip(
                    icon: categoryModel != null
                        ? AppIcons.getIcon(categoryModel.icon)
                        : Icons.category_outlined,
                    iconColor: categoryModel != null
                        ? AppColors.parseHex(categoryModel.color)
                        : AppColors.primary,
                    label: item.categoryName ?? 'Pilih Kategori',
                    onTap: () => _showCategoryPicker(item, categories),
                    textColor: textColor,
                    isDark: isDark,
                  ),

                // Account Chip
                _buildSelectorChip(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.primary,
                  label: item.accountName ?? 'Pilih Akun',
                  onTap: () => _showAccountPicker(item, accounts, isTarget: false),
                  textColor: textColor,
                  isDark: isDark,
                ),

                // Target Account Chip (for Transfer)
                if (isTransfer)
                  _buildSelectorChip(
                    icon: Icons.arrow_forward_rounded,
                    iconColor: AppColors.transfer,
                    label: item.targetAccountName != null
                        ? 'Ke: ${item.targetAccountName}'
                        : 'Pilih Akun Tujuan',
                    onTap: () => _showAccountPicker(item, accounts, isTarget: true),
                    textColor: textColor,
                    isDark: isDark,
                  ),
              ],
            ),

            // Description / Note (if returned by AI)
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _editDescription(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: subtextColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: subtextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: subtextColor.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: textColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  void _editDescription(ParsedVoiceTransaction item) {
    final controller = TextEditingController(text: item.description);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Deskripsi / Catatan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Tulis deskripsi atau catatan transaksi...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  item.description = controller.text.trim();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Simpan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryPicker(
    ParsedVoiceTransaction item,
    List<CategoryModel> categories,
  ) {
    final filteredCategories =
        categories.where((c) => c.type == item.type).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Pilih Kategori',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredCategories.length,
                  itemBuilder: (_, idx) {
                    final cat = filteredCategories[idx];
                    final color = AppColors.parseHex(cat.color);
                    return ListTile(
                      leading: Icon(AppIcons.getIcon(cat.icon), color: color),
                      title: Text(cat.name),
                      trailing: item.categoryId == cat.id
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          item.categoryId = cat.id;
                          item.categoryName = cat.name;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountPicker(
    ParsedVoiceTransaction item,
    List<AccountModel> accounts, {
    required bool isTarget,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                isTarget ? 'Pilih Akun Tujuan' : 'Pilih Akun',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  itemBuilder: (_, idx) {
                    final acc = accounts[idx];
                    final isSelected = isTarget
                        ? item.targetAccountId == acc.id
                        : item.accountId == acc.id;
                    return ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(acc.name),
                      subtitle: Text(acc.type.toUpperCase(),
                          style: const TextStyle(fontSize: 11)),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          if (isTarget) {
                            item.targetAccountId = acc.id;
                            item.targetAccountName = acc.name;
                          } else {
                            item.accountId = acc.id;
                            item.accountName = acc.name;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
