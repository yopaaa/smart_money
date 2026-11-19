import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/currency_model.dart';
import 'initial_balance_screen.dart';

class SelectCurrencyScreen extends StatefulWidget {
  final String accountName;

  const SelectCurrencyScreen({
    super.key,
    required this.accountName,
  });

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  List<CurrencyModel> _allCurrencies = [];
  List<CurrencyModel> _filteredCurrencies = [];
  CurrencyModel _selectedCurrency = CurrencyModel.defaultCurrency;
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

  void _handleNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InitialBalanceScreen(
          accountName: widget.accountName,
          currency: _selectedCurrency,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Currency'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search currency (e.g. IDR, USD)',
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
                    final isSelected = curr.currency == _selectedCurrency.currency;

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
                      onTap: () {
                        setState(() {
                          _selectedCurrency = curr;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'SELECT ${_selectedCurrency.currency}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
