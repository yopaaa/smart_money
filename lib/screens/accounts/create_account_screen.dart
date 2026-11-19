import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _initialBalance = 0;
  bool _isVisible = true;
  bool _isLoading = false;

  late Map<String, dynamic> _selectedType;
  late String _selectedIcon;
  late String _selectedColor;

  final List<Map<String, dynamic>> _types = [
    {
      'key': 'cash',
      'name': 'Cash',
      'icon': 'cash',
      'color': '#81c784',
      'isLiability': false,
    },
    {
      'key': 'card',
      'name': 'Credit Card',
      'icon': 'credit-card',
      'color': '#64b5f6',
      'isLiability': true,
    },
    {
      'key': 'debit',
      'name': 'Debit Card',
      'icon': 'credit-card-outline',
      'color': '#7986cb',
      'isLiability': false,
    },
    {
      'key': 'saving',
      'name': 'Saving Account',
      'icon': 'bank',
      'color': '#4db6ac',
      'isLiability': false,
    },
    {
      'key': 'invest',
      'name': 'Investasi',
      'icon': 'chart-line',
      'color': '#ffb74d',
      'isLiability': false,
    },
    {
      'key': 'liability',
      'name': 'Liabilities',
      'icon': 'file-document',
      'color': '#e57373',
      'isLiability': true,
    },
    {
      'key': 'debt',
      'name': 'Hutang',
      'icon': 'account-cash',
      'color': '#f06292',
      'isLiability': true,
    },
    {
      'key': 'receivable',
      'name': 'Piutang',
      'icon': 'account-arrow-left',
      'color': '#9575cd',
      'isLiability': false,
    },
    {
      'key': 'expense-buffer',
      'name': 'Emergency Fund',
      'icon': 'umbrella',
      'color': '#ba68c8',
      'isLiability': false,
    },
    {
      'key': 'other',
      'name': 'Lainnya',
      'icon': 'dots-horizontal',
      'color': '#90a4ae',
      'isLiability': false,
    },
  ];

  final List<String> _iconOptions = [
    'cash',
    'credit-card',
    'credit-card-outline',
    'bank',
    'chart-line',
    'file-document',
    'account-cash',
    'account-arrow-left',
    'umbrella',
    'dots-horizontal',
    'account-cash',
    'wallet',
    'piggy-bank',
    'briefcase',
    'safe',
    'hand-coin',
    'bank-transfer',
    'currency-usd',
    'account-circle',
    'calendar-month',
    'store',
    'shopping',
  ];

  final List<String> _colorOptions = [
    '#81c784',
    '#64b5f6',
    '#7986cb',
    '#4db6ac',
    '#ffb74d',
    '#e57373',
    '#f06292',
    '#9575cd',
    '#ba68c8',
    '#90a4ae',
    '#66bb6a',
    '#ef5350',
    '#42a5f5',
    '#ab47bc',
    '#26a69a',
    '#ec407a',
    '#5c6bc0',
    '#8d6e63',
    '#00acc1',
    '#4dd0e1',
    '#ffa726',
    '#ffca28',
    '#ff7043',
    '#d4e157',
    '#4caf50',
    '#2196f3',
    '#9c27b0',
    '#ff9800',
    '#f44336',
    '#009688',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = _types[0];
    _selectedIcon = _selectedType['icon'] as String;
    _selectedColor = _selectedType['color'] as String;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final unformatted = CurrencyFormatter.unformat(val);
    _initialBalance = unformatted;
    final formatted = CurrencyFormatter.formatNumber(unformatted);
    _balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Pilih Kategori',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = _types[index];
                final iconName = t['icon'] as String;
                final color = AppColors.parseHex(t['color'] as String);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Icon(
                    AppIcons.getIcon(iconName),
                    color: color,
                    size: 24,
                  ),
                  title: Text(
                    t['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedType = t;
                      _selectedIcon = t['icon'] as String;
                      _selectedColor = t['color'] as String;
                    });
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final dialogBg = isDark ? theme.cardColor : Colors.white;
        final itemBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F1F1);
        final color = AppColors.parseHex(_selectedColor);

        return Dialog(
          backgroundColor: dialogBg,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _iconOptions.length,
                  itemBuilder: (context, index) {
                    final icon = _iconOptions[index];
                    final isSelected = _selectedIcon == icon;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: color.withOpacity(0.8), width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            AppIcons.getIcon(icon),
                            size: 28,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    child: Text(
                      'Tutup',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final dialogBg = isDark ? theme.cardColor : Colors.white;

        return Dialog(
          backgroundColor: dialogBg,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _colorOptions.length,
                  itemBuilder: (context, index) {
                    final c = _colorOptions[index];
                    final color = AppColors.parseHex(c);
                    final isSelected = _selectedColor.toLowerCase() == c.toLowerCase();

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = c;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.white,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    child: Text(
                      'Tutup',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi nama akun dengan benar')),
      );
      return;
    }

    final provider = context.read<TransactionProvider>();
    final isExist = provider.accounts.any(
      (a) => a.name.toLowerCase() == name.toLowerCase(),
    );

    if (isExist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama akun sudah digunakan, silakan gunakan nama lain'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final newAccount = AccountModel(
      id: '',
      name: name,
      balance: 0,
      type: _selectedType['key'] as String,
      isLiability: _selectedType['isLiability'] as bool,
      hidden: !_isVisible,
      icon: _selectedIcon,
      iconColor: _selectedColor,
      description: _descController.text.trim(),
    );

    try {
      await provider.addAccount(newAccount, initialBalance: _initialBalance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun berhasil ditambahkan')),
        );
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

  Widget _buildCircleArrowDown() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.arrow_drop_down,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final borderColor = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Buat Akun',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Nama Akun
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      'Nama Akun',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(fontSize: 15, color: textColor),
                        decoration: const InputDecoration(
                          hintText: 'Tabungan, Bank dll',
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 2: Jumlah
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      'Jumlah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _balanceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: _onAmountChanged,
                        style: TextStyle(fontSize: 15, color: textColor),
                        decoration: const InputDecoration(
                          hintText: 'Rp 0',
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 3: Kategori
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      'Kategori',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showCategoryPicker,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.getIcon(_selectedIcon),
                              size: 26,
                              color: AppColors.parseHex(_selectedColor),
                            ),
                            Expanded(
                              child: Text(
                                _selectedType['name'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            ),
                            _buildCircleArrowDown(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 4: Side by Side (Pilih Ikon & Pilih Warna)
              Row(
                children: [
                  // Column 1: Pilih Ikon
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Ikon',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showIconPicker,
                          child: Container(
                            height: 76,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(
                                  AppIcons.getIcon(_selectedIcon),
                                  size: 44,
                                  color: AppColors.parseHex(_selectedColor),
                                ),
                                _buildCircleArrowDown(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Column 2: Pilih Warna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Warna',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showColorPicker,
                          child: Container(
                            height: 76,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.parseHex(_selectedColor),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                _buildCircleArrowDown(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 5: Tampilkan Saldo Akun Ini ke Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Tampilkan Saldo Akun Ini ke Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isVisible,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF4CAF50),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade300,
                    onChanged: (val) {
                      setState(() {
                        _isVisible = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 6: Deskripsi
              Text(
                'Deskripsi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _descController,
                  maxLines: 4,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan deskripsi (opsional)',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Row 7: Button TAMBAH TRANSAKSI
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'TAMBAH TRANSAKSI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
