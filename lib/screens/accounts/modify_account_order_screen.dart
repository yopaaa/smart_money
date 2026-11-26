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
  State<ModifyAccountOrderScreen> createState() =>
      _ModifyAccountOrderScreenState();
}

class _ModifyAccountOrderScreenState extends State<ModifyAccountOrderScreen> {
  List<_EditableAccountGroup> _orderedGroups = [];
  bool _hasChanges = false;
  bool _resetAccountsFlag = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _orderedGroups = provider.groupedAccounts
        .map(
          (g) => _EditableAccountGroup(
            title: g.title,
            icon: g.icon,
            color: g.color,
            balance: g.balance,
            accounts: List<AccountModel>.from(g.accounts),
          ),
        )
        .toList();
  }

  void _onReorderGroup(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _orderedGroups.removeAt(oldIndex);
      _orderedGroups.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  void _onReorderAccountInGroup(int groupIndex, int oldIndex, int newIndex) {
    setState(() {
      final accounts = _orderedGroups[groupIndex].accounts;
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final acc = accounts.removeAt(oldIndex);
      accounts.insert(newIndex, acc);
      _resetAccountsFlag = false;
      _hasChanges = true;
    });
  }

  Future<void> _reset() async {
    final provider = context.read<TransactionProvider>();
    final defaultGroupOrder = await provider.getDefaultGroupOrder();
    final defaultAccIds = await provider.getDefaultAccountOrder();
    final accIndexMap = <String, int>{
      for (int i = 0; i < defaultAccIds.length; i++) defaultAccIds[i]: i,
    };

    if (!mounted) return;
    setState(() {
      _orderedGroups.sort((a, b) {
        final idxA = defaultGroupOrder.indexOf(a.title);
        final idxB = defaultGroupOrder.indexOf(b.title);
        if (idxA == -1 && idxB == -1) return 0;
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });
      if (accIndexMap.isNotEmpty) {
        for (final group in _orderedGroups) {
          group.accounts.sort((a, b) {
            final idxA = accIndexMap[a.id];
            final idxB = accIndexMap[b.id];
            if (idxA == null && idxB == null) return 0;
            if (idxA == null) return 1;
            if (idxB == null) return -1;
            return idxA.compareTo(idxB);
          });
        }
      }
      _resetAccountsFlag = true;
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    final provider = context.read<TransactionProvider>();
    final orderedTitles = _orderedGroups.map((g) => g.title).toList();
    final orderedAccountIds = _resetAccountsFlag
        ? const <String>[]
        : _orderedGroups
              .expand((g) => g.accounts.map((a) => a.id))
              .toList();

    await provider.updateAccountOrder(
      orderedTitles,
      orderedAccountIds: orderedAccountIds,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account order saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Modify Account Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withOpacity(0.14)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppColors.primary, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tahan & geser ::: pada tipe atau masing-masing akun untuk mengurutkan',
                      style: TextStyle(
                        color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              itemCount: _orderedGroups.length,
              onReorder: _onReorderGroup,
              itemBuilder: (context, groupIndex) {
                final group = _orderedGroups[groupIndex];
                final groupColor = AppColors.parseHex(group.color);

                return Container(
                  key: ValueKey('group_${group.title}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Group header (drag handle reorders group/type order)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: groupIndex,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              AppIcons.getIcon(group.icon),
                              color: groupColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                group.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(group.balance, currency),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: group.balance < 0
                                    ? AppColors.expense
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (group.accounts.isNotEmpty) ...[
                        Divider(height: 1, thickness: 0.8, color: dividerColor),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          padding: EdgeInsets.zero,
                          itemCount: group.accounts.length,
                          onReorder: (oldIdx, newIdx) =>
                              _onReorderAccountInGroup(
                                groupIndex,
                                oldIdx,
                                newIdx,
                              ),
                          itemBuilder: (context, accIndex) {
                            final acc = group.accounts[accIndex];
                            final accColor = AppColors.parseHex(acc.iconColor);

                            return Material(
                              key: ValueKey('acc_${acc.id}'),
                              color: Colors.transparent,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      8,
                                      12,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: accIndex,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 4,
                                            ),
                                            child: Icon(
                                              Icons.drag_indicator,
                                              color: Colors.grey.shade500,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          AppIcons.getIcon(acc.icon),
                                          color: accColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            acc.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(
                                            acc.balance,
                                            currency,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (accIndex < group.accounts.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 0.6,
                                      indent: 26,
                                      endIndent: 12,
                                      color: dividerColor,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: const Text(
                        'Reset',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        backgroundColor: _hasChanges
                            ? AppColors.primary
                            : Colors.grey.shade100,
                        foregroundColor: _hasChanges
                            ? Colors.white
                            : Colors.grey.shade400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

class _EditableAccountGroup {
  final String title;
  final String icon;
  final String color;
  final int balance;
  final List<AccountModel> accounts;

  _EditableAccountGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.balance,
    required this.accounts,
  });
}
