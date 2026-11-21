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
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final TransactionModel? initialTransaction;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.initialTransaction,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _transaction;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFormEditable = true;

  // Transaction type: 'income', 'expense', 'transfer'
  String _type = 'expense';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: 'Rp 0',
  );
  final TextEditingController _feeController = TextEditingController(
    text: 'Rp 0',
  );
  final TextEditingController _descController = TextEditingController();

  int _amount = 0;
  int _fee = 0;

  AccountModel? _selectedAccount;
  AccountModel? _selectedTargetAccount;
  CategoryModel? _selectedCategory;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      _applyTransaction(widget.initialTransaction!);
    }
    _loadTransaction();
  }

  void _applyTransaction(TransactionModel tx) {
    final provider = context.read<TransactionProvider>();
    _transaction = tx;
    _isLoading = false;
    _type = tx.type;
    _isFormEditable = tx.category != 'Biaya Admin';
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    try {
      final provider = context.read<TransactionProvider>();
      TransactionModel? tx = widget.initialTransaction;
      tx ??= await provider.getTransactionById(widget.transactionId);
      if (!mounted) return;

      if (tx != null) {
        setState(() {
          _applyTransaction(tx!);
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onAmountChanged(String val) {
    if (!_isFormEditable) return;
    final unformatted = CurrencyFormatter.unformat(val);
    _amount = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onFeeChanged(String val) {
    if (!_isFormEditable) return;
    final unformatted = CurrencyFormatter.unformat(val);
    _fee = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _feeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isFormEditable) return;
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

  void _showImageModal(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog() {
    if (!_isFormEditable) return;
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
    if (!_isFormEditable) return;
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

  Future<void> _handleEdit() async {
    if (!_isFormEditable) return;
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
      _isSaving = true;
    });

    final provider = context.read<TransactionProvider>();
    final txDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final updatedTx = TransactionModel(
      id: widget.transactionId,
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
      await provider.editTransaction(widget.transactionId, updatedTx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil diperbarui')),
        );
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
          _isSaving = false;
        });
      }
    }
  }

  void _handleCopy() {
    if (_transaction == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TransactionFormScreen(copyFromTransaction: _transaction!),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    if (!_isFormEditable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus transaksi ini? Transaksi akan dipindahkan ke Recycle Bin dan saldo akun akan disesuaikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.deleteTransaction(widget.transactionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dihapus')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Transaksi')),
        body: const Center(child: Text('Transaksi tidak ditemukan')),
      );
    }

    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
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

    String appTitle = 'Expense Details';
    if (_type == 'income') appTitle = 'Income Details';
    if (_type == 'transfer') appTitle = 'Transfer Details';

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
      ),
      body: Column(
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
                  // Date & Time Row (side by side, vertical labels)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildFormField(
                          label: 'Tanggal',
                          labelColor: labelColor,
                          child: GestureDetector(
                            onTap: _isFormEditable
                                ? () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                    }
                                  }
                                : null,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                            onTap: _isFormEditable
                                ? () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _selectedTime,
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedTime = picked);
                                    }
                                  }
                                : null,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                      enabled: _isFormEditable,
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
                      enabled: _isFormEditable,
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
                                  AppIcons.getIcon(
                                    _selectedTargetAccount!.icon,
                                  ),
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
                        enabled: _isFormEditable,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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

                  // Deskripsi & Foto
                  _buildFormField(
                    label: 'Deskripsi',
                    labelColor: labelColor,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _descController,
                            enabled: _isFormEditable,
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
                        if (_isFormEditable) ...[
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
                      ],
                    ),
                  ),

                  // Image attachment preview if exists
                  if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildFormField(
                      label: 'Lampiran Gambar / Bukti Struk',
                      labelColor: labelColor,
                      child: GestureDetector(
                        onTap: () {
                          if (File(_imagePath!).existsSync()) {
                            _showImageModal(_imagePath!);
                          }
                        },
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: File(_imagePath!).existsSync()
                                  ? Image.file(
                                      File(_imagePath!),
                                      width: double.infinity,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 100,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            color: subtextColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'File gambar tidak ditemukan',
                                            style: TextStyle(
                                              color: subtextColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            if (File(_imagePath!).existsSync())
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ketuk untuk perbesar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_isFormEditable)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _imagePath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
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
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action Bar with 3 buttons matching old React Native app
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: borderColor.withOpacity(0.6), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      title: 'Hapus',
                      backgroundColor: const Color(0xFFF44336),
                      height: 46,
                      borderRadius: 8,
                      disabled: !_isFormEditable,
                      onPress: _deleteTransaction,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      title: 'Salin',
                      backgroundColor: const Color(0xFF2196F3),
                      height: 46,
                      borderRadius: 8,
                      onPress: _handleCopy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      title: 'Edit',
                      backgroundColor: const Color(0xFF4CAF50),
                      height: 46,
                      borderRadius: 8,
                      isLoading: _isSaving,
                      disabled: !_isFormEditable,
                      onPress: _handleEdit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
