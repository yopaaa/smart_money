import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionModel? editTransaction;

  const TransactionFormScreen({
    super.key,
    this.editTransaction,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  // Input mode: 'keyboard' or 'chat'
  String _inputMode = 'keyboard';

  // Transaction type: 'income', 'expense', 'transfer'
  String _type = 'expense';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: 'Rp 0');
  final TextEditingController _feeController = TextEditingController(text: 'Rp 0');
  final TextEditingController _descController = TextEditingController();

  // Chat mode input
  final TextEditingController _chatInputController = TextEditingController();
  final List<TransactionModel> _chatTransactions = [];

  int _amount = 0;
  int _fee = 0;

  AccountModel? _selectedAccount;
  AccountModel? _selectedTargetAccount;
  CategoryModel? _selectedCategory;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    final tx = widget.editTransaction;

    if (tx != null) {
      _type = tx.type;
      _titleController.text = tx.title;
      _amount = tx.amount;
      _amountController.text = 'Rp ${CurrencyFormatter.formatNumber(_amount)}';
      _fee = tx.fee;
      _feeController.text = 'Rp ${CurrencyFormatter.formatNumber(_fee)}';
      _descController.text = tx.description ?? '';
      _selectedAccount = provider.findAccount(tx.accountId);
      _selectedTargetAccount = provider.findAccount(tx.targetAccountId);
      _selectedCategory = provider.getCategoryById(tx.category);
      _selectedDate = tx.dateTime;
      _selectedTime = TimeOfDay(hour: tx.dateTime.hour, minute: tx.dateTime.minute);
      _imagePath = tx.img;
    } else {
      if (provider.accounts.isNotEmpty) {
        _selectedAccount = provider.accounts.first;
        if (provider.accounts.length > 1) {
          _selectedTargetAccount = provider.accounts[1];
        }
      }
      final expenseCats = provider.getCategoriesByType('expense');
      if (expenseCats.isNotEmpty) {
        _selectedCategory = expenseCats.first;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _descController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final unformatted = CurrencyFormatter.unformat(val);
    _amount = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onFeeChanged(String val) {
    final unformatted = CurrencyFormatter.unformat(val);
    _fee = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _feeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
        final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
        setState(() {
          _imagePath = savedImage.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showCategoryDialog() {
    final provider = context.read<TransactionProvider>();
    final categories = provider.getCategoriesByType(_type);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          constraints: const BoxConstraints(maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final color = AppColors.parseHex(cat.color);

                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 32,
                        child: Icon(
                          AppIcons.getIcon(cat.icon),
                          color: color,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountDialog({required bool isTarget}) {
    final provider = context.read<TransactionProvider>();
    final accounts = provider.accounts;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final acc = accounts[index];
                    final color = AppColors.parseHex(acc.iconColor);

                    return ListTile(
                      leading: SizedBox(
                        width: 32,
                        child: Icon(
                          AppIcons.getIcon(acc.icon),
                          color: color,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        acc.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '( ${CurrencyFormatter.format(acc.balance, provider.currency)} )',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      onTap: () {
                        setState(() {
                          if (isTarget) {
                            _selectedTargetAccount = acc;
                          } else {
                            _selectedAccount = acc;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul transaksi harus diisi')),
      );
      return;
    }

    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah nominal harus lebih dari 0')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun sumber')),
      );
      return;
    }

    if (_type == 'transfer') {
      if (_selectedTargetAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih akun tujuan transfer')),
        );
        return;
      }
      if (_selectedAccount!.id == _selectedTargetAccount!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun asal dan tujuan tidak boleh sama')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<TransactionProvider>();
    final txDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final tx = TransactionModel(
      id: widget.editTransaction?.id ?? '',
      title: title,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      amount: _amount,
      type: _type,
      accountId: _selectedAccount!.id,
      targetAccountId: _type == 'transfer' ? _selectedTargetAccount?.id : null,
      createdAt: txDateTime.millisecondsSinceEpoch.toString(),
      category: _type == 'transfer' ? '52841730' : _selectedCategory?.id,
      fee: _type == 'transfer' ? _fee : 0,
      img: _imagePath,
    );

    try {
      if (widget.editTransaction != null) {
        await provider.editTransaction(widget.editTransaction!.id, tx);
      } else {
        await provider.addTransaction(tx);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Parse natural chat input like "dinner 50" or "makan 35000"
  Future<void> _handleChatSubmit() async {
    final raw = _chatInputController.text.trim();
    if (raw.isEmpty) return;

    final lower = raw.toLowerCase();
    final match = RegExp(r'\d+').firstMatch(lower);
    int parsedAmount = match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    if (parsedAmount > 0 && parsedAmount < 1000) {
      // e.g. 50 -> 50000 if users type abbreviations
      parsedAmount = parsedAmount * 1000;
    }

    final provider = context.read<TransactionProvider>();
    CategoryModel? matchedCat;
    for (var cat in provider.categories) {
      if (lower.contains(cat.name.toLowerCase())) {
        matchedCat = cat;
        break;
      }
    }

    if (matchedCat == null) {
      if (lower.contains('makan') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('kue')) {
        matchedCat = provider.categories.firstWhere((c) => c.name.toLowerCase().contains('makan'),
            orElse: () => provider.categories.first);
      } else if (lower.contains('kopi') || lower.contains('minum')) {
        matchedCat = provider.categories.firstWhere((c) => c.name.toLowerCase().contains('minum'),
            orElse: () => provider.categories.first);
      } else if (lower.contains('gaji')) {
        matchedCat = provider.categories.firstWhere((c) => c.name.toLowerCase().contains('gaji'),
            orElse: () => provider.categories.first);
      }
    }

    final account = provider.accounts.isNotEmpty ? provider.accounts.first : null;
    if (account == null) return;

    final newTx = TransactionModel(
      id: '',
      title: raw,
      description: 'Input via Chat',
      amount: parsedAmount > 0 ? parsedAmount : 10000,
      type: (matchedCat != null && matchedCat.type == 'income') ? 'income' : 'expense',
      accountId: account.id,
      createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
      category: matchedCat?.id,
    );

    await provider.addTransaction(newTx);
    setState(() {
      _chatTransactions.insert(0, newTx);
      _chatInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();

    String appTitle = 'Expense';
    if (_type == 'income') appTitle = 'Income';
    if (_type == 'transfer') appTitle = 'Transfer';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Keyboard vs Chat Mode Switcher Pill (matching Screenshot 1 & 3)
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _inputMode = 'keyboard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _inputMode == 'keyboard' ? theme.cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'keyboard'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.keyboard, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Keyboard',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inputMode == 'keyboard' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _inputMode = 'chat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _inputMode == 'chat' ? theme.cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'chat'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inputMode == 'chat' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chat_bubble, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _inputMode == 'chat'
          ? _buildChatModeBody()
          : _buildKeyboardModeBody(theme, provider),
    );
  }

  // Chat input view matching Screenshot 1
  Widget _buildChatModeBody() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Transaksi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: dinner 50',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => _handleChatSubmit(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _handleChatSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'TAMBAH',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: _chatTransactions.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada transaksi.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _chatTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _chatTransactions[index];
                      return ListTile(
                        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(tx.dateTime)),
                        trailing: Text(
                          CurrencyFormatter.format(tx.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Keyboard form view matching Screenshot 3
  Widget _buildKeyboardModeBody(ThemeData theme, TransactionProvider provider) {
    final currency = provider.currency;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Segmented Tab container: Income | Expense | Transfer (Screenshot 3)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                _buildSegmentTab('income', 'Income'),
                _buildSegmentTab('expense', 'Expense'),
                _buildSegmentTab('transfer', 'Transfer'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Date Row
          _buildFormRow(
            label: 'Date',
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('M/d/yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Judul Transaksi Row
          _buildFormRow(
            label: 'Judul Transaksi',
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'dinner, gaji, or transfer',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Jumlah (Rp) Row
          _buildFormRow(
            label: 'Jumlah (${currency.symbol})',
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onAmountChanged,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Kategori Row (if not transfer)
          if (_type != 'transfer') ...[
            _buildFormRow(
              label: 'Kategori',
              child: GestureDetector(
                onTap: _showCategoryDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      if (_selectedCategory != null)
                        Icon(
                          AppIcons.getIcon(_selectedCategory!.icon),
                          color: AppColors.parseHex(_selectedCategory!.color),
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedCategory?.name ?? 'Pilih Kategori',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Akun Sumber Row
          _buildFormRow(
            label: _type == 'transfer' ? 'Akun Sumber' : 'Akun Sumber',
            child: GestureDetector(
              onTap: () => _showAccountDialog(isTarget: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    if (_selectedAccount != null)
                      Icon(
                        AppIcons.getIcon(_selectedAccount!.icon),
                        color: AppColors.parseHex(_selectedAccount!.iconColor),
                        size: 22,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAccount?.name ?? 'Pilih Akun',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (_selectedAccount != null)
                            Text(
                              '( ${CurrencyFormatter.format(_selectedAccount!.balance, currency)} )',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Transfer specific rows
          if (_type == 'transfer') ...[
            _buildFormRow(
              label: 'Akun Tujuan',
              child: GestureDetector(
                onTap: () => _showAccountDialog(isTarget: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      if (_selectedTargetAccount != null)
                        Icon(
                          AppIcons.getIcon(_selectedTargetAccount!.icon),
                          color: AppColors.parseHex(_selectedTargetAccount!.iconColor),
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTargetAccount?.name ?? 'Pilih Akun Tujuan',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (_selectedTargetAccount != null)
                              Text(
                                '( ${CurrencyFormatter.format(_selectedTargetAccount!.balance, currency)} )',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildFormRow(
              label: 'Biaya Admin (${currency.symbol})',
              child: TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onFeeChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Deskripsi Row + Photo Buttons (Screenshot 3)
          _buildFormRow(
            label: 'Deskripsi',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan deskripsi (opsional)',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    InkWell(
                      onTap: () => _pickImage(ImageSource.camera),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickImage(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Image preview if selected
          if (_imagePath != null && _imagePath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: File(_imagePath!).existsSync()
                      ? Image.file(
                          File(_imagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => setState(() => _imagePath = null),
                ),
              ],
            ),
          ],
          const SizedBox(height: 36),

          // Full-width Bottom Button matching Screenshot 3
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      widget.editTransaction != null ? 'Update Transaksi' : 'Tambah Transaksi',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFormRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildSegmentTab(String key, String label) {
    final isSelected = _type == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = key;
            final provider = context.read<TransactionProvider>();
            final cats = provider.getCategoriesByType(key);
            if (cats.isNotEmpty) {
              _selectedCategory = cats.first;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
