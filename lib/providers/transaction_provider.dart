import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/currency_model.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<AccountModel> _accounts = [];
  List<AccountGroup> _groupedAccounts = [];
  List<CategoryModel> _categories = [];
  Map<String, CategoryModel> _categoryMap = {};
  CurrencyModel _currency = CurrencyModel.defaultCurrency;

  bool _isLoading = true;
  bool _isNewUser = false;

  List<AccountModel> get accounts => _accounts;
  List<AccountGroup> get groupedAccounts => _groupedAccounts;
  List<CategoryModel> get categories => _categories;
  CurrencyModel get currency => _currency;
  bool get isLoading => _isLoading;
  bool get isNewUser => _isNewUser;

  TransactionProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load currency setting
      final savedCurrency = await _db.getSetting('@currency');
      if (savedCurrency != null && savedCurrency is Map<String, dynamic>) {
        _currency = CurrencyModel.fromMap(savedCurrency);
      }

      // Load categories
      _categories = await _db.getAllCategories();
      _categoryMap = {for (var c in _categories) c.id: c};

      // Load accounts
      _accounts = await _db.getAccounts();
      _isNewUser = _accounts.isEmpty;

      // Group accounts
      await _groupAccounts();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _groupAccounts() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/groupLabels.json');
      final List<dynamic> groupLabels = jsonDecode(jsonStr);

      final Map<String, List<AccountModel>> groupMap = {};
      final Map<String, int> groupBalance = {};

      for (var acc in _accounts) {
        final key = acc.type.isEmpty ? 'other' : acc.type;
        groupMap.putIfAbsent(key, () => []);
        groupMap[key]!.add(acc);

        if (!acc.hidden) {
          groupBalance[key] = (groupBalance[key] ?? 0) + acc.balance;
        }
      }

      final List<AccountGroup> groups = [];
      for (var label in groupLabels) {
        final key = label['key']?.toString() ?? '';
        if (groupMap.containsKey(key)) {
          groups.add(AccountGroup(
            title: label['name']?.toString() ?? key,
            icon: label['icon']?.toString() ?? 'wallet',
            color: label['color']?.toString() ?? '#81c784',
            balance: groupBalance[key] ?? 0,
            accounts: groupMap[key]!,
          ));
        }
      }

      _groupedAccounts = groups;
    } catch (e) {
      debugPrint('Error grouping accounts: $e');
    }
  }

  // ================= CATEGORY LOOKUP =================

  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    return _categoryMap[id];
  }

  List<CategoryModel> getCategoriesByType(String type) {
    return _categories.where((c) => c.type == type).toList();
  }

  // ================= ACCOUNT ACTIONS =================

  Future<void> addAccount(AccountModel account, {int initialBalance = 0}) async {
    await _db.addAccount(account, initialBalance: initialBalance);
    await loadData();
  }

  Future<void> editAccount(String id, AccountModel updated) async {
    await _db.editAccount(id, updated);
    await loadData();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    await loadData();
  }

  AccountModel? findAccount(String? id) {
    if (id == null) return null;
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ================= TRANSACTION ACTIONS =================

  Future<void> addTransaction(TransactionModel tx) async {
    await _db.addTransaction(tx);
    await loadData();
  }

  Future<void> editTransaction(String id, TransactionModel tx) async {
    await _db.editTransaction(id, tx);
    await loadData();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    await loadData();
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    return await _db.getTransactionById(id);
  }

  Future<List<TransactionModel>> filterTransactions({
    String? search,
    String? type,
    String? category,
    String? accountId,
    int? minAmount,
    int? maxAmount,
    int? startDate,
    int? endDate,
    bool? hasImage,
    int? limit,
    int? offset,
  }) async {
    return await _db.filterTransactions(
      search: search,
      type: type,
      category: category,
      accountId: accountId,
      minAmount: minAmount,
      maxAmount: maxAmount,
      startDate: startDate,
      endDate: endDate,
      hasImage: hasImage,
      limit: limit,
      offset: offset,
    );
  }

  // ================= RECYCLE BIN =================

  Future<List<TransactionModel>> getDeletedTransactions() async {
    return await _db.getDeletedTransactions();
  }

  Future<void> restoreDeletedTransaction(String id) async {
    await _db.restoreDeletedTransaction(id);
    await loadData();
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    await _db.permanentlyDeleteTransaction(id);
    notifyListeners();
  }

  Future<void> clearAllDeletedTransactions() async {
    await _db.clearAllDeletedTransactions();
    notifyListeners();
  }

  // ================= CATEGORY ACTIONS =================

  Future<void> addCategory(CategoryModel category) async {
    await _db.addCategory(category);
    await loadData();
  }

  Future<void> editCategory(String id, CategoryModel category) async {
    await _db.editCategory(id, category);
    await loadData();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    await loadData();
  }

  // ================= SETTINGS ACTIONS =================

  Future<void> setCurrency(CurrencyModel currency) async {
    _currency = currency;
    await _db.saveSetting('@currency', currency.toMap());
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _db.resetTables();
    await loadData();
  }
}
