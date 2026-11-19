import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../providers/transaction_provider.dart';

class EditAccountScreen extends StatefulWidget {
  final AccountModel account;

  const EditAccountScreen({
    super.key,
    required this.account,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;

  late String _selectedType;
  late bool _isLiability;
  late bool _hidden;
  late bool _isFavorite;
  late String _selectedColor;
  late String _selectedIcon;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _types = [
    {'key': 'cash', 'name': 'Cash', 'icon': 'cash', 'color': '#81c784', 'isLiability': false},
    {'key': 'saving', 'name': 'Saving / Bank', 'icon': 'bank', 'color': '#4db6ac', 'isLiability': false},
    {'key': 'debit', 'name': 'Debit Card', 'icon': 'credit-card-outline', 'color': '#7986cb', 'isLiability': false},
    {'key': 'card', 'name': 'Credit Card', 'icon': 'credit-card', 'color': '#64b5f6', 'isLiability': true},
    {'key': 'invest', 'name': 'Investment', 'icon': 'chart-line', 'color': '#ffb74d', 'isLiability': false},
    {'key': 'liability', 'name': 'Liability', 'icon': 'file-document', 'color': '#e57373', 'isLiability': true},
    {'key': 'debt', 'name': 'Debt (Hutang)', 'icon': 'account-cash', 'color': '#f06292', 'isLiability': true},
    {'key': 'receivable', 'name': 'Receivable (Piutang)', 'icon': 'account-arrow-left', 'color': '#9575cd', 'isLiability': false},
    {'key': 'expense-buffer', 'name': 'Emergency Fund', 'icon': 'umbrella', 'color': '#ba68c8', 'isLiability': false},
    {'key': 'other', 'name': 'Other', 'icon': 'dots-horizontal', 'color': '#90a4ae', 'isLiability': false},
  ];

  final List<String> _colorOptions = [
    '#4caf50', '#81c784', '#2196f3', '#64b5f6', '#9c27b0',
    '#ba68c8', '#ff9800', '#ffb74d', '#f44336', '#e57373',
    '#009688', '#4db6ac', '#3f51b5', '#7986cb', '#607d8b'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _descController = TextEditingController(text: widget.account.description);
    _selectedType = widget.account.type;
    _isLiability = widget.account.isLiability;
    _hidden = widget.account.hidden;
    _isFavorite = widget.account.isFavorite;
    _selectedColor = widget.account.iconColor;
    _selectedIcon = widget.account.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter bucket name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final updated = widget.account.copyWith(
      name: name,
      type: _selectedType,
      isLiability: _isLiability,
      hidden: _hidden,
      isFavorite: _isFavorite,
      icon: _selectedIcon,
      iconColor: _selectedColor,
      description: _descController.text.trim(),
    );

    try {
      final provider = context.read<TransactionProvider>();
      await provider.editAccount(widget.account.id, updated);
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bucket'),
        content: Text('Are you sure you want to delete "${widget.account.name}"?'),
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
      await provider.deleteAccount(widget.account.id);
      if (mounted) {
        Navigator.pop(context, true);
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bucket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Bucket Name',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Bucket Type',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              items: _types.map((t) {
                return DropdownMenuItem<String>(
                  value: t['key'] as String,
                  child: Row(
                    children: [
                      Icon(AppIcons.getIcon(t['icon'] as String), size: 18),
                      const SizedBox(width: 10),
                      Text(t['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                    final matched = _types.firstWhere((element) => element['key'] == val);
                    _selectedIcon = matched['icon'] as String;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Is Liability / Debt?'),
              value: _isLiability,
              onChanged: (val) => setState(() => _isLiability = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hide Bucket from Total Balance'),
              value: _hidden,
              onChanged: (val) => setState(() => _hidden = val),
            ),
            const SizedBox(height: 16),
            const Text('Color Accent', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((c) {
                final isSelected = _selectedColor.toLowerCase() == c.toLowerCase();
                final color = AppColors.parseHex(c);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('UPDATE BUCKET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
