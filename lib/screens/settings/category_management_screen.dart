import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import 'create_category_screen.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete category "${cat.name}"?'),
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
      await context.read<TransactionProvider>().deleteCategory(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final expenseCats = provider.getCategoriesByType('expense');
    final incomeCats = provider.getCategoriesByType('income');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateCategoryScreen()),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReorderableCategoryTab(
            type: 'expense',
            categories: expenseCats,
            onDelete: _deleteCategory,
          ),
          _ReorderableCategoryTab(
            type: 'income',
            categories: incomeCats,
            onDelete: _deleteCategory,
          ),
        ],
      ),
    );
  }
}

class _ReorderableCategoryTab extends StatefulWidget {
  final String type;
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onDelete;

  const _ReorderableCategoryTab({
    required this.type,
    required this.categories,
    required this.onDelete,
  });

  @override
  State<_ReorderableCategoryTab> createState() =>
      _ReorderableCategoryTabState();
}

class _ReorderableCategoryTabState extends State<_ReorderableCategoryTab> {
  late List<CategoryModel> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.categories);
  }

  @override
  void didUpdateWidget(covariant _ReorderableCategoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories) {
      _items = List.of(widget.categories);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });

    await context.read<TransactionProvider>().updateCategoryOrder(
      widget.type,
      _items.map((c) => c.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(child: Text('No categories in this group.'));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Text(
            'Tahan & geser ikon :: untuk mengurutkan',
            style: TextStyle(fontSize: 12, color: hintColor),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _items.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final cat = _items[index];
              final color = AppColors.parseHex(cat.color);

              return Material(
                key: ValueKey(cat.id),
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateCategoryScreen(editCategory: cat),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              AppIcons.getIcon(cat.icon),
                              color: color,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: const EdgeInsets.all(5),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: hintColor,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreateCategoryScreen(editCategory: cat),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: const EdgeInsets.all(5),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.expense,
                              ),
                              onPressed: () => widget.onDelete(cat),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.7,
                      indent: 14,
                      endIndent: 14,
                      color: dividerColor,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
