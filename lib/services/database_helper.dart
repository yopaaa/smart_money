import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String accountTableName = 'accounts';
  static const String transactionTableName = 'transactions';
  static const String deletedTransactionsTableName = 'deleted_transactions';
  static const String categoriesTableName = 'categories';
  static const String settingsTableName = 'settings';

  final _uuid = const Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_money.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $accountTableName (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        balance INTEGER NOT NULL,
        type TEXT NOT NULL,
        isLiability INTEGER DEFAULT 0,
        hidden INTEGER DEFAULT 0,
        icon TEXT,
        iconColor TEXT,
        description TEXT,
        isFavorite INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $transactionTableName (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        accountId TEXT NOT NULL,
        targetAccountId TEXT,
        createdAt TEXT NOT NULL,
        category TEXT,
        fee INTEGER DEFAULT 0,
        img TEXT,
        FOREIGN KEY (accountId) REFERENCES accounts(id),
        FOREIGN KEY (targetAccountId) REFERENCES accounts(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $deletedTransactionsTableName (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        accountId TEXT NOT NULL,
        targetAccountId TEXT,
        createdAt TEXT NOT NULL,
        deletedAt TEXT NOT NULL,
        category TEXT,
        fee INTEGER DEFAULT 0,
        img TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $categoriesTableName (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        type TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $settingsTableName (
        id TEXT PRIMARY KEY NOT NULL,
        key TEXT UNIQUE NOT NULL,
        value TEXT
      );
    ''');

    // Create performance indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON $transactionTableName (createdAt DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account ON $transactionTableName (accountId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_target_account ON $transactionTableName (targetAccountId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON $transactionTableName (category);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON $transactionTableName (type);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_type ON $categoriesTableName (type);',
    );

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    try {
      final existing = await db.rawQuery(
        'SELECT COUNT(*) as total FROM $categoriesTableName',
      );
      final count = Sqflite.firstIntValue(existing) ?? 0;
      if (count == 0) {
        final jsonStr = await rootBundle.loadString(
          'assets/json/defaultCategories.json',
        );
        final List<dynamic> list = jsonDecode(jsonStr);
        final batch = db.batch();
        for (var item in list) {
          batch.insert(categoriesTableName, {
            'id': item['id']?.toString() ?? _uuid.v4(),
            'name': item['name']?.toString() ?? '',
            'icon': item['icon']?.toString() ?? 'dots-horizontal',
            'color': item['color']?.toString() ?? '#90a4ae',
            'type': item['type']?.toString() ?? 'expense',
          });
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      // Continue even if seeding fails on web or during test
    }
  }

  // ================= ACCOUNT OPERATIONS =================

  Future<List<AccountModel>> getAccounts() async {
    final db = await database;
    final maps = await db.query(accountTableName);
    return maps.map((e) => AccountModel.fromMap(e)).toList();
  }

  Future<AccountModel?> getAccountById(String id) async {
    final db = await database;
    final maps = await db.query(
      accountTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return AccountModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> addAccount(
    AccountModel account, {
    int initialBalance = 0,
  }) async {
    final db = await database;
    final accountId = account.id.isEmpty ? _uuid.v4() : account.id;

    await db.insert(
      accountTableName,
      account.copyWith(id: accountId, balance: 0).toMap(),
    );

    if (initialBalance != 0) {
      final transactionType = account.isLiability ? 'expense' : 'income';
      final transactionTitle = 'Initial balance for ${account.name}';
      final nowMs = DateTime.now().millisecondsSinceEpoch.toString();

      await addTransaction(
        TransactionModel(
          id: _uuid.v4(),
          title: transactionTitle,
          description: 'Initial balance setup for account ${account.name}',
          amount: initialBalance.abs(),
          type: transactionType,
          accountId: accountId,
          createdAt: nowMs,
          category: 'initial-balance',
        ),
      );
    }
  }

  Future<void> editAccount(String id, AccountModel updated) async {
    final db = await database;
    await db.update(
      accountTableName,
      {
        'name': updated.name,
        'type': updated.type,
        'isLiability': updated.isLiability ? 1 : 0,
        'hidden': updated.hidden ? 1 : 0,
        'icon': updated.icon,
        'iconColor': updated.iconColor,
        'description': updated.description,
        'isFavorite': updated.isFavorite ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.delete(accountTableName, where: 'id = ?', whereArgs: [id]);
  }

  // ================= TRANSACTION OPERATIONS =================

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final maps = await db.query(
      transactionTableName,
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query(
      transactionTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TransactionModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final db = await database;
    final txId = tx.id.isEmpty ? _uuid.v4() : tx.id;

    await db.transaction((txn) async {
      await txn.insert(transactionTableName, tx.copyWith(id: txId).toMap());

      final accounts = await txn.query(
        accountTableName,
        where: 'id = ?',
        whereArgs: [tx.accountId],
      );
      if (accounts.isEmpty) throw Exception('Akun tidak ditemukan');
      final currentBalance = (accounts.first['balance'] as num).toInt();

      if (tx.type == 'income') {
        final newBalance = currentBalance + tx.amount;
        await txn.update(
          accountTableName,
          {'balance': newBalance},
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );
      } else if (tx.type == 'expense') {
        final newBalance = currentBalance - tx.amount;
        await txn.update(
          accountTableName,
          {'balance': newBalance},
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );
      } else if (tx.type == 'transfer') {
        if (tx.targetAccountId == null || tx.targetAccountId!.isEmpty) {
          throw Exception('Akun tujuan transfer harus diisi');
        }

        // Deduct from source account (amount + fee)
        final totalDeduction = tx.amount + tx.fee;
        final newSourceBalance = currentBalance - totalDeduction;
        await txn.update(
          accountTableName,
          {'balance': newSourceBalance},
          where: 'id = ?',
          whereArgs: [tx.accountId],
        );

        // Add to target account
        final targetAccounts = await txn.query(
          accountTableName,
          where: 'id = ?',
          whereArgs: [tx.targetAccountId],
        );
        if (targetAccounts.isEmpty) {
          throw Exception('Akun tujuan tidak ditemukan');
        }
        final targetCurrentBalance = (targetAccounts.first['balance'] as num)
            .toInt();
        final newTargetBalance = targetCurrentBalance + tx.amount;
        await txn.update(
          accountTableName,
          {'balance': newTargetBalance},
          where: 'id = ?',
          whereArgs: [tx.targetAccountId],
        );

        // Record fee as separate expense transaction if exists
        if (tx.fee > 0) {
          final feeId = _uuid.v4();
          final feeTime =
              (int.tryParse(tx.createdAt) ??
                  DateTime.now().millisecondsSinceEpoch) +
              1;
          await txn.insert(transactionTableName, {
            'id': feeId,
            'title': 'Biaya transfer',
            'description': 'Biaya transfer ke ${targetAccounts.first['name']}',
            'amount': tx.fee,
            'type': 'expense',
            'accountId': tx.accountId,
            'targetAccountId': tx.targetAccountId,
            'createdAt': feeTime.toString(),
            'category': 'Biaya Admin',
            'fee': 0,
            'img': '',
          });
        }
      }
    });
  }

  Future<void> editTransaction(String id, TransactionModel updated) async {
    final db = await database;

    await db.transaction((txn) async {
      final oldTxMaps = await txn.query(
        transactionTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (oldTxMaps.isEmpty) throw Exception('Transaksi tidak ditemukan');
      final oldTx = TransactionModel.fromMap(oldTxMaps.first);

      // Rollback old balance effects
      if (oldTx.type == 'income') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [oldTx.amount, oldTx.accountId],
        );
      } else if (oldTx.type == 'expense') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [oldTx.amount, oldTx.accountId],
        );
      } else if (oldTx.type == 'transfer') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [oldTx.amount + oldTx.fee, oldTx.accountId],
        );
        if (oldTx.targetAccountId != null) {
          await txn.rawUpdate(
            'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
            [oldTx.amount, oldTx.targetAccountId],
          );
        }
      }

      // Update the transaction record
      await txn.update(
        transactionTableName,
        {
          'title': updated.title,
          'description': updated.description,
          'amount': updated.amount,
          'type': updated.type,
          'accountId': updated.accountId,
          'targetAccountId': updated.targetAccountId,
          'createdAt': updated.createdAt,
          'category': updated.category,
          'fee': updated.fee,
          'img': updated.img ?? '',
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Apply new balance effects
      if (updated.type == 'income') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [updated.amount, updated.accountId],
        );
      } else if (updated.type == 'expense') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [updated.amount, updated.accountId],
        );
      } else if (updated.type == 'transfer') {
        final totalDeduction = updated.amount + updated.fee;
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [totalDeduction, updated.accountId],
        );
        if (updated.targetAccountId != null) {
          await txn.rawUpdate(
            'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
            [updated.amount, updated.targetAccountId],
          );
        }
      }
    });
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;

    await db.transaction((txn) async {
      final txMaps = await txn.query(
        transactionTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (txMaps.isEmpty) throw Exception('Transaksi tidak ditemukan');
      final tx = TransactionModel.fromMap(txMaps.first);

      // Insert to deleted_transactions
      await txn.insert(deletedTransactionsTableName, {
        'id': tx.id,
        'title': tx.title,
        'description': tx.description,
        'amount': tx.amount,
        'type': tx.type,
        'accountId': tx.accountId,
        'targetAccountId': tx.targetAccountId,
        'createdAt': tx.createdAt,
        'deletedAt': DateTime.now().millisecondsSinceEpoch.toString(),
        'category': tx.category,
        'fee': tx.fee,
        'img': tx.img ?? '',
      });

      // Rollback balance
      if (tx.type == 'income') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.type == 'expense') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.type == 'transfer') {
        final totalDeduction = tx.amount + tx.fee;
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [totalDeduction, tx.accountId],
        );
        if (tx.targetAccountId != null) {
          await txn.rawUpdate(
            'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
            [tx.amount, tx.targetAccountId],
          );
        }

        // Delete fee transaction if exists
        final feeTime = (int.tryParse(tx.createdAt) ?? 0) + 1;
        await txn.delete(
          transactionTableName,
          where: "title = 'Biaya transfer' AND createdAt = ? AND accountId = ?",
          whereArgs: [feeTime.toString(), tx.accountId],
        );
      }

      // Delete main transaction
      await txn.delete(transactionTableName, where: 'id = ?', whereArgs: [id]);
    });
  }

  // ================= RECYCLE BIN / DELETED TRANSACTIONS =================

  Future<List<TransactionModel>> getDeletedTransactions() async {
    final db = await database;
    final maps = await db.query(
      deletedTransactionsTableName,
      orderBy: 'deletedAt DESC',
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<void> restoreDeletedTransaction(String id) async {
    final db = await database;

    await db.transaction((txn) async {
      final maps = await txn.query(
        deletedTransactionsTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) throw Exception('Transaksi terhapus tidak ditemukan');
      final tx = TransactionModel.fromMap(maps.first);

      // Re-insert into transactions table
      await txn.insert(transactionTableName, {
        'id': tx.id,
        'title': tx.title,
        'description': tx.description,
        'amount': tx.amount,
        'type': tx.type,
        'accountId': tx.accountId,
        'targetAccountId': tx.targetAccountId,
        'createdAt': tx.createdAt,
        'category': tx.category,
        'fee': tx.fee,
        'img': tx.img ?? '',
      });

      // Restore balances
      if (tx.type == 'income') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.type == 'expense') {
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.type == 'transfer') {
        final totalDeduction = tx.amount + tx.fee;
        await txn.rawUpdate(
          'UPDATE $accountTableName SET balance = balance - ? WHERE id = ?',
          [totalDeduction, tx.accountId],
        );
        if (tx.targetAccountId != null) {
          await txn.rawUpdate(
            'UPDATE $accountTableName SET balance = balance + ? WHERE id = ?',
            [tx.amount, tx.targetAccountId],
          );
        }
      }

      // Remove from deleted_transactions
      await txn.delete(
        deletedTransactionsTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      deletedTransactionsTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllDeletedTransactions() async {
    final db = await database;
    await db.delete(deletedTransactionsTableName);
  }

  // ================= FILTER & SEARCH TRANSACTIONS =================

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
    final db = await database;
    String sql = 'SELECT * FROM $transactionTableName WHERE 1=1';
    final List<dynamic> params = [];

    if (search != null && search.trim().isNotEmpty) {
      sql += ' AND (title LIKE ? OR description LIKE ?)';
      params.add('%$search%');
      params.add('%$search%');
    }

    if (type != null && type.isNotEmpty) {
      sql += ' AND type = ?';
      params.add(type);
    }

    if (category != null && category.isNotEmpty) {
      sql += ' AND category = ?';
      params.add(category);
    }

    if (accountId != null && accountId.isNotEmpty) {
      sql += ' AND (accountId = ? OR targetAccountId = ?)';
      params.add(accountId);
      params.add(accountId);
    }

    if (minAmount != null) {
      sql += ' AND amount >= ?';
      params.add(minAmount);
    }

    if (maxAmount != null) {
      sql += ' AND amount <= ?';
      params.add(maxAmount);
    }

    if (startDate != null) {
      sql += ' AND CAST(createdAt AS INTEGER) >= ?';
      params.add(startDate);
    }

    if (endDate != null) {
      sql += ' AND CAST(createdAt AS INTEGER) <= ?';
      params.add(endDate);
    }

    if (hasImage == true) {
      sql += " AND img IS NOT NULL AND img != ''";
    }

    sql += ' ORDER BY CAST(createdAt AS INTEGER) DESC';

    if (limit != null) {
      sql += ' LIMIT ?';
      params.add(limit);
      if (offset != null) {
        sql += ' OFFSET ?';
        params.add(offset);
      }
    }

    final maps = await db.rawQuery(sql, params);
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // ================= CATEGORIES OPERATIONS =================

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final maps = await db.query(categoriesTableName);
    return maps.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<CategoryModel?> getCategoryById(String? id) async {
    if (id == null || id.isEmpty) return null;
    final db = await database;
    final maps = await db.query(
      categoriesTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CategoryModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    final db = await database;
    final maps = await db.query(
      categoriesTableName,
      where: 'type = ?',
      whereArgs: [type],
    );
    return maps.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<void> addCategory(CategoryModel category) async {
    final db = await database;
    final id = category.id.isEmpty ? _uuid.v4() : category.id;
    await db.insert(categoriesTableName, category.copyWith(id: id).toMap());
  }

  Future<void> editCategory(String id, CategoryModel category) async {
    final db = await database;
    await db.update(
      categoriesTableName,
      {
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'type': category.type,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete(categoriesTableName, where: 'id = ?', whereArgs: [id]);
  }

  // ================= SETTINGS OPERATIONS =================

  Future<void> saveSetting(String key, dynamic value) async {
    final db = await database;
    final valueStr = value is String ? value : jsonEncode(value);

    final existing = await db.query(
      settingsTableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (existing.isNotEmpty) {
      await db.update(
        settingsTableName,
        {'value': valueStr},
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      await db.insert(settingsTableName, {
        'id': _uuid.v4(),
        'key': key,
        'value': valueStr,
      });
    }
  }

  Future<dynamic> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      settingsTableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      final val = maps.first['value'] as String?;
      if (val == null) return null;
      try {
        return jsonDecode(val);
      } catch (_) {
        return val;
      }
    }
    return null;
  }

  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> recalculateAccountBalances() async {
    final db = await database;
    await db.transaction((txn) async {
      final accounts = await txn.query(accountTableName);
      for (var acc in accounts) {
        final accId = acc['id'] as String;

        // Income transactions on this account
        final incomeRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM $transactionTableName WHERE accountId = ? AND type = 'income'",
          [accId],
        );
        final income = (incomeRes.first['total'] as num?)?.toInt() ?? 0;

        // Expense transactions on this account
        final expenseRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM $transactionTableName WHERE accountId = ? AND type = 'expense'",
          [accId],
        );
        final expense = (expenseRes.first['total'] as num?)?.toInt() ?? 0;

        // Transfer out from this account (only amount, fee is recorded as separate expense)
        final transferOutRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM $transactionTableName WHERE accountId = ? AND type = 'transfer'",
          [accId],
        );
        final transferOut =
            (transferOutRes.first['total'] as num?)?.toInt() ?? 0;

        // Transfer in to this account
        final transferInRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM $transactionTableName WHERE targetAccountId = ? AND type = 'transfer'",
          [accId],
        );
        final transferIn = (transferInRes.first['total'] as num?)?.toInt() ?? 0;

        final calculatedBalance = income - expense - transferOut + transferIn;
        await txn.update(
          accountTableName,
          {'balance': calculatedBalance},
          where: 'id = ?',
          whereArgs: [accId],
        );
      }
    });
  }

  // ================= RESET DATABASE =================

  Future<void> resetTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DROP TABLE IF EXISTS $accountTableName');
      await txn.execute('DROP TABLE IF EXISTS $transactionTableName');
      await txn.execute('DROP TABLE IF EXISTS $deletedTransactionsTableName');
      await txn.execute('DROP TABLE IF EXISTS $categoriesTableName');
      await txn.execute('DROP TABLE IF EXISTS $settingsTableName');
    });
    await _createDB(db, 1);
  }
}
