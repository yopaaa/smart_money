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
import '../../widgets/action_button.dart';
import '../../widgets/animated_tab_bar.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionModel? editTransaction;
  final TransactionModel? copyFromTransaction;

  const TransactionFormScreen({
    super.key,
    this.editTransaction,
    this.copyFromTransaction,
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
  final TextEditingController _amountController = TextEditingController(
    text: 'Rp 0',
  );
  final FocusNode _amountFocusNode = FocusNode();
  final TextEditingController _feeController = TextEditingController(
    text: 'Rp 0',
  );
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
    final copyTx = widget.copyFromTransaction;

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
      _selectedTime = TimeOfDay(
        hour: tx.dateTime.hour,
        minute: tx.dateTime.minute,
      );
      _imagePath = tx.img;
    } else if (copyTx != null) {
      _type = copyTx.type;
      _titleController.text = copyTx.title;
      _amount = copyTx.amount;
      _amountController.text = 'Rp ${CurrencyFormatter.formatNumber(_amount)}';
      _fee = copyTx.fee;
      _feeController.text = 'Rp ${CurrencyFormatter.formatNumber(_fee)}';
      _descController.text = copyTx.description ?? '';
      _selectedAccount = provider.findAccount(copyTx.accountId);
      _selectedTargetAccount = provider.findAccount(copyTx.targetAccountId);
      _selectedCategory = provider.getCategoryById(copyTx.category);
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputMode == 'keyboard') {
        _amountFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
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

  int get _typeIndex {
    if (_type == 'income') return 0;
    if (_type == 'expense') return 1;
    return 2;
  }

  void _onTypeTabChanged(int index) {
    const keys = ['income', 'expense', 'transfer'];
    final key = keys[index.clamp(0, 2)];
    setState(() {
      _type = key;
      final provider = context.read<TransactionProvider>();
      final cats = provider.getCategoriesByType(key);
      if (cats.isNotEmpty) {
        _selectedCategory = cats.first;
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
        final savedImage = await File(
          picked.path,
        ).copy('${appDir.path}/$fileName');
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
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade200),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
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
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade200),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '( ${CurrencyFormatter.format(acc.balance, provider.currency)} )',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih akun sumber')));
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
          const SnackBar(
            content: Text('Akun asal dan tujuan tidak boleh sama'),
          ),
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
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      if (lower.contains('makan') ||
          lower.contains('dinner') ||
          lower.contains('lunch') ||
          lower.contains('kue')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('makan'),
          orElse: () => provider.categories.first,
        );
      } else if (lower.contains('kopi') || lower.contains('minum')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('minum'),
          orElse: () => provider.categories.first,
        );
      } else if (lower.contains('gaji')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('gaji'),
          orElse: () => provider.categories.first,
        );
      }
    }

    final account = provider.accounts.isNotEmpty
        ? provider.accounts.first
        : null;
    if (account == null) return;

    final newTx = TransactionModel(
      id: '',
      title: raw,
      description: 'Input via Chat',
      amount: parsedAmount > 0 ? parsedAmount : 10000,
      type: (matchedCat != null && matchedCat.type == 'income')
          ? 'income'
          : 'expense',
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
      resizeToAvoidBottomInset: true,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _inputMode == 'keyboard'
                            ? theme.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'keyboard'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
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
                              fontWeight: _inputMode == 'keyboard'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _inputMode = 'chat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _inputMode == 'chat'
                            ? theme.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'chat'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inputMode == 'chat'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                        title: Text(
                          tx.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(tx.dateTime),
                        ),
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
  // Keyboard form view matching clean, compact vertical layout
  Widget _buildKeyboardModeBody(ThemeData theme, TransactionProvider provider) {
    final currency = provider.currency;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final borderColor = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final labelColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented Tab container: Income | Expense | Transfer
                AnimatedTabBar(
                  width: double.infinity,
                  height: 44,
                  activeIndex: _typeIndex,
                  onTabChanged: _onTypeTabChanged,
                  tabs: const [
                    TabItem(key: 'income', label: 'Income'),
                    TabItem(key: 'expense', label: 'Expense'),
                    TabItem(key: 'transfer', label: 'Transfer'),
                  ],
                ),
                const SizedBox(height: 14),

                // Date & Time Row (side by side, vertical labels)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFormField(
                        label: 'Tanggal',
                        labelColor: labelColor,
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
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildFormField(
                        label: 'Waktu',
                        labelColor: labelColor,
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
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Judul Transaksi
                _buildFormField(
                  label: 'Judul Transaksi',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Misal: Makan Siang, Belanja, Gaji...',
                      hintStyle: TextStyle(color: hintColor, fontSize: 13),
                      filled: true,
                      fillColor: cardBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Jumlah (Rp)
                _buildFormField(
                  label: 'Jumlah (${currency.symbol})',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onAmountChanged,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Kategori (if not transfer)
                if (_type != 'transfer') ...[
                  _buildFormField(
                    label: 'Kategori',
                    labelColor: labelColor,
                    child: GestureDetector(
                      onTap: _showCategoryDialog,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCategory != null)
                              Icon(
                                AppIcons.getIcon(_selectedCategory!.icon),
                                color: AppColors.parseHex(
                                  _selectedCategory!.color,
                                ),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCategory?.name ?? 'Pilih Kategori',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: _selectedCategory != null
                                      ? textColor
                                      : hintColor,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],

                // Akun Sumber
                _buildFormField(
                  label: _type == 'transfer' ? 'Akun Sumber' : 'Akun',
                  labelColor: labelColor,
                  child: GestureDetector(
                    onTap: () => _showAccountDialog(isTarget: false),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          if (_selectedAccount != null)
                            Icon(
                              AppIcons.getIcon(_selectedAccount!.icon),
                              color: AppColors.parseHex(
                                _selectedAccount!.iconColor,
                              ),
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedAccount?.name ?? 'Pilih Akun',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedAccount != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${CurrencyFormatter.format(_selectedAccount!.balance, currency)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: subtextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Transfer specific rows
                if (_type == 'transfer') ...[
                  _buildFormField(
                    label: 'Akun Tujuan',
                    labelColor: labelColor,
                    child: GestureDetector(
                      onTap: () => _showAccountDialog(isTarget: true),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            if (_selectedTargetAccount != null)
                              Icon(
                                AppIcons.getIcon(_selectedTargetAccount!.icon),
                                color: AppColors.parseHex(
                                  _selectedTargetAccount!.iconColor,
                                ),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedTargetAccount?.name ??
                                          'Pilih Akun Tujuan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedTargetAccount != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${CurrencyFormatter.format(_selectedTargetAccount!.balance, currency)})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildFormField(
                    label: 'Biaya Admin (${currency.symbol})',
                    labelColor: labelColor,
                    child: TextField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onFeeChanged,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],

                // Deskripsi & Lampiran Foto
                _buildFormField(
                  label: 'Deskripsi & Foto (Opsional)',
                  labelColor: labelColor,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descController,
                          maxLines: 3,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Tambahkan catatan transaksi...',
                            hintStyle: TextStyle(
                              color: hintColor,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: cardBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          InkWell(
                            onTap: () => _pickImage(ImageSource.camera),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickImage(ImageSource.gallery),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Image preview if selected
                if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        File(_imagePath!).existsSync()
                            ? Image.file(
                                File(_imagePath!),
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Sticky Bottom Action Bar pinned above the keyboard
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: borderColor.withOpacity(0.6), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ActionButton(
              title: widget.editTransaction != null
                  ? 'Update Transaksi'
                  : 'Tambah Transaksi',
              height: 48,
              borderRadius: 8,
              isLoading: _isLoading,
              onPress: _submit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    Color? labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: labelColor ?? const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}
