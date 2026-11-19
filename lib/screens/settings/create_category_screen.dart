import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';

class CreateCategoryScreen extends StatefulWidget {
  final CategoryModel? editCategory;

  const CreateCategoryScreen({
    super.key,
    this.editCategory,
  });

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  late TextEditingController _nameController;
  late String _type;
  late String _selectedIcon;
  late String _selectedColor;
  bool _isLoading = false;

  final List<String> _icons = [
    'silverware-fork-knife', 'cup-water', 'bus', 'shopping',
    'movie', 'heart-pulse', 'school', 'hand-heart',
    'cash', 'gift', 'cart', 'bank', 'chart-line',
    'wallet', 'cellphone', 'home', 'face-woman', 'dots-horizontal'
  ];

  final List<String> _colors = [
    '#e57373', '#f06292', '#ba68c8', '#9575cd', '#7986cb',
    '#64b5f6', '#4db6ac', '#81c784', '#ffb74d', '#ff8a65',
    '#a1887f', '#90a4ae', '#607d8b'
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.editCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _type = cat?.type ?? 'expense';
    _selectedIcon = cat?.icon ?? 'dots-horizontal';
    _selectedColor = cat?.color ?? '#e57373';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter category name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<TransactionProvider>();
    final newCat = CategoryModel(
      id: widget.editCategory?.id ?? '',
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
      type: _type,
    );

    try {
      if (widget.editCategory != null) {
        await provider.editCategory(widget.editCategory!.id, newCat);
      } else {
        await provider.addCategory(newCat);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editCategory != null ? 'Edit Category' : 'New Category'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Type: Expense | Income
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'expense' ? AppColors.expense.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Expense',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _type == 'expense' ? AppColors.expense : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'income' ? AppColors.income.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Income',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _type == 'income' ? AppColors.income : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Coffee, Groceries',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Select Icon
            const Text('Choose Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = iconName),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : theme.dividerColor,
                      ),
                    ),
                    child: Icon(
                      AppIcons.getIcon(iconName),
                      color: isSelected ? Colors.white : AppColors.parseHex(_selectedColor),
                      size: 22,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Select Color
            const Text('Choose Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((c) {
                final isSelected = _selectedColor.toLowerCase() == c.toLowerCase();
                final color = AppColors.parseHex(c);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            // Submit
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
                    : Text(
                        widget.editCategory != null ? 'UPDATE CATEGORY' : 'SAVE CATEGORY',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
