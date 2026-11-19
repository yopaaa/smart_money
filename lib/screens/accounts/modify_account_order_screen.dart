import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';

class ModifyAccountOrderScreen extends StatefulWidget {
  const ModifyAccountOrderScreen({super.key});

  @override
  State<ModifyAccountOrderScreen> createState() => _ModifyAccountOrderScreenState();
}

class _ModifyAccountOrderScreenState extends State<ModifyAccountOrderScreen> {
  List<AccountGroup> _orderedGroups = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _orderedGroups = List.from(provider.groupedAccounts);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _orderedGroups.removeAt(oldIndex);
      _orderedGroups.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  void _reset() {
    final provider = context.read<TransactionProvider>();
    setState(() {
      _orderedGroups = List.from(provider.groupedAccounts);
      _hasChanges = false;
    });
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account order saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Modify Account Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Blue Info Box matching Screenshot 5
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hold and drag the ::: handle up/down to reorder',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reorderable list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _orderedGroups.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final group = _orderedGroups[index];
                final iconColor = AppColors.parseHex(group.color);

                return ListTile(
                  key: ValueKey(group.title),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_indicator, color: Colors.grey, size: 22),
                      const SizedBox(width: 12),
                      Icon(
                        AppIcons.getIcon(group.icon),
                        color: iconColor,
                        size: 22,
                      ),
                    ],
                  ),
                  title: Text(
                    group.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  trailing: Text(
                    CurrencyFormatter.format(group.balance, currency),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: group.balance < 0 ? AppColors.expense : AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom action buttons matching Screenshot 5
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _reset,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasChanges ? AppColors.primary : Colors.grey.shade100,
                        foregroundColor: _hasChanges ? Colors.white : Colors.grey.shade400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _hasChanges ? _saveChanges : null,
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
}
