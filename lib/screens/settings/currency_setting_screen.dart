import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/currency_model.dart';
import '../../providers/transaction_provider.dart';

class CurrencySettingScreen extends StatefulWidget {
  const CurrencySettingScreen({super.key});

  @override
  State<CurrencySettingScreen> createState() => _CurrencySettingScreenState();
}

class _CurrencySettingScreenState extends State<CurrencySettingScreen> {
  List<CurrencyModel> _allCurrencies = [];
  List<CurrencyModel> _filteredCurrencies = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _searchController.addListener(_onSearch);
  }

  Future<void> _loadCurrencies() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/currency.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      final currencies = list.map((e) => CurrencyModel.fromMap(e)).toList();
      setState(() {
        _allCurrencies = currencies;
        _filteredCurrencies = currencies;
      });
    } catch (e) {
      debugPrint('Error loading currencies: $e');
    }
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCurrencies = _allCurrencies.where((c) {
        return c.name.toLowerCase().contains(query) ||
            c.currency.toLowerCase().contains(query) ||
            c.symbol.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currentCurrency = provider.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search currency...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _filteredCurrencies.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
                itemBuilder: (context, index) {
                  final curr = _filteredCurrencies[index];
                  final isSelected = curr.currency == currentCurrency.currency;

                  return ListTile(
                    title: Text(
                      curr.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('${curr.currency} (${curr.symbol})'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await provider.setCurrency(curr);
                      if (mounted) {
                        nav.pop();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
