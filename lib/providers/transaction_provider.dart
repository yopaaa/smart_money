import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/currency_model.dart';
import '../models/transaction_model.dart';
import '../services/backup_sync_service.dart';
import '../services/database_helper.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<AccountModel> _accounts = [];
  List<AccountGroup> _groupedAccounts = [];
  List<CategoryModel> _categories = [];
  Map<String, CategoryModel> _categoryMap = {};
  CurrencyModel _currency = CurrencyModel.defaultCurrency;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isNewUser = false;

  List<AccountModel> get accounts => _accounts;
  List<AccountGroup> get groupedAccounts => _groupedAccounts;
  List<CategoryModel> get categories => _categories;
  CurrencyModel get currency => _currency;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isNewUser => _isNewUser;

  TransactionProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;

    try {
      // Load currency setting
      final savedCurrency = await _db.getSetting('@currency');
      if (savedCurrency != null && savedCurrency is Map<String, dynamic>) {
        _currency = CurrencyModel.fromMap(savedCurrency);
      }

      // Load categories and apply custom order if saved
      _categories = await _db.getAllCategories();
      await _applyCategoryOrder();

      // Load accounts
      _accounts = await _db.getAccounts();
      _isNewUser = _accounts.isEmpty;

      // Group accounts and align flat account list with AccountsScreen display order
      await _groupAccounts();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _groupAccounts() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/json/groupLabels.json',
      );
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

      final savedAccountOrder = await _db.getSetting('@account_order');
      if (savedAccountOrder != null &&
          savedAccountOrder is List &&
          savedAccountOrder.isNotEmpty) {
        final accountOrderIds =
            savedAccountOrder.map((e) => e.toString()).toList();
        for (final list in groupMap.values) {
          _sortByOrderList(list, accountOrderIds, (a) => a.id);
        }
      }

      final List<AccountGroup> groups = [];
      for (var label in groupLabels) {
        final key = label['key']?.toString() ?? '';
        if (groupMap.containsKey(key)) {
          groups.add(
            AccountGroup(
              title: label['name']?.toString() ?? key,
              icon: label['icon']?.toString() ?? 'wallet',
              color: label['color']?.toString() ?? '#81c784',
              balance: groupBalance[key] ?? 0,
              accounts: groupMap[key]!,
            ),
          );
        }
      }

      // Apply saved group order if exists
      final savedOrder = await _db.getSetting('@account_group_order');
      if (savedOrder != null && savedOrder is List && savedOrder.isNotEmpty) {
        final orderList = savedOrder.map((e) => e.toString()).toList();
        _sortByOrderList(groups, orderList, (g) => g.title);
      }

      _groupedAccounts = groups;

      // Align _accounts with the exact top-to-bottom order shown in AccountsScreen.
      if (groups.isNotEmpty) {
        final ordered = <AccountModel>[];
        final seenIds = <String>{};
        for (final g in groups) {
          for (final acc in g.accounts) {
            if (seenIds.add(acc.id)) {
              ordered.add(acc);
            }
          }
        }
        for (final acc in _accounts) {
          if (seenIds.add(acc.id)) {
            ordered.add(acc);
          }
        }
        _accounts = ordered;
      }
    } catch (e) {
      debugPrint('Error grouping accounts: $e');
    }
  }

  /// Sorts [items] in-place so keys appearing in [orderIds] come first in that
  /// exact order, preserving relative order for unordered items.
  void _sortByOrderList<T>(
    List<T> items,
    List<String> orderIds,
    String Function(T) keyOf,
  ) {
    final indexMap = <String, int>{};
    for (int i = 0; i < orderIds.length; i++) {
      indexMap.putIfAbsent(orderIds[i], () => i);
    }
    items.sort((a, b) {
      final idxA = indexMap[keyOf(a)];
      final idxB = indexMap[keyOf(b)];
      if (idxA == null && idxB == null) return 0;
      if (idxA == null) return 1;
      if (idxB == null) return -1;
      return idxA.compareTo(idxB);
    });
  }

  Future<void> _applyCategoryOrder() async {
    try {
      final savedOrder = await _db.getSetting('@category_order');
      if (savedOrder != null && savedOrder is List && savedOrder.isNotEmpty) {
        final orderIds = savedOrder.map((e) => e.toString()).toList();
        _sortByOrderList(_categories, orderIds, (c) => c.id);
      }
    } catch (e) {
      debugPrint('Error applying category order: $e');
    }
    _categoryMap = {for (var c in _categories) c.id: c};
  }

  // ================= CATEGORY LOOKUP =================

  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    return _categoryMap[id];
  }

  List<CategoryModel> getCategoriesByType(String type) {
    return _categories.where((c) => c.type == type).toList();
  }

  Future<void> updateCategoryOrder(
    String type,
    List<String> orderedTypeIds,
  ) async {
    final mergedOrder = <String>[];
    final seen = <String>{};

    // Preserve other types before/around while updating the reordered type's sequence.
    int insertedIdx = 0;
    for (final cat in _categories) {
      if (cat.type == type) {
        if (insertedIdx < orderedTypeIds.length) {
          final nextId = orderedTypeIds[insertedIdx++];
          if (seen.add(nextId)) {
            mergedOrder.add(nextId);
          }
        }
      } else {
        if (seen.add(cat.id)) {
          mergedOrder.add(cat.id);
        }
      }
    }
    while (insertedIdx < orderedTypeIds.length) {
      final nextId = orderedTypeIds[insertedIdx++];
      if (seen.add(nextId)) {
        mergedOrder.add(nextId);
      }
    }

    await _db.saveSetting('@category_order', mergedOrder);
    await BackupSyncService.instance.markDataChanged();
    _sortByOrderList(_categories, mergedOrder, (c) => c.id);
    _categoryMap = {for (var c in _categories) c.id: c};
    notifyListeners();
  }

  // ================= ACCOUNT ACTIONS =================

  Future<void> addAccount(
    AccountModel account, {
    int initialBalance = 0,
  }) async {
    await _db.addAccount(account, initialBalance: initialBalance);
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> editAccount(String id, AccountModel updated) async {
    await _db.editAccount(id, updated);
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> updateAccountOrder(
    List<String> orderedTitles, {
    List<String>? orderedAccountIds,
  }) async {
    await _db.saveSetting('@account_group_order', orderedTitles);
    if (orderedAccountIds != null) {
      await _db.saveSetting(
        '@account_order',
        orderedAccountIds.isEmpty ? null : orderedAccountIds,
      );
      if (orderedAccountIds.isEmpty) {
        _accounts = await _db.getAccounts();
      }
    }
    await BackupSyncService.instance.markDataChanged();
    await _groupAccounts();
    notifyListeners();
  }

  Future<void> resetAccountOrder() async {
    await _db.saveSetting('@account_group_order', null);
    await _db.saveSetting('@account_order', null);
    _accounts = await _db.getAccounts();
    await BackupSyncService.instance.markDataChanged();
    await _groupAccounts();
    notifyListeners();
  }

  Future<List<String>> getDefaultAccountOrder() async {
    try {
      final rawAccounts = await _db.getAccounts();
      return rawAccounts.map((a) => a.id).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getDefaultGroupOrder() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/json/groupLabels.json',
      );
      final List<dynamic> groupLabels = jsonDecode(jsonStr);
      return groupLabels
          .map((l) => l['name']?.toString() ?? l['key']?.toString() ?? '')
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    await BackupSyncService.instance.markDataChanged();
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
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> addTransactions(List<TransactionModel> txList) async {
    for (final tx in txList) {
      await _db.addTransaction(tx);
    }
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> editTransaction(String id, TransactionModel tx) async {
    await _db.editTransaction(id, tx);
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    await BackupSyncService.instance.markDataChanged();
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
    await BackupSyncService.instance.markDataChanged();
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
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> editCategory(String id, CategoryModel category) async {
    await _db.editCategory(id, category);
    await BackupSyncService.instance.markDataChanged();
    await loadData();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    await BackupSyncService.instance.markDataChanged();
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
