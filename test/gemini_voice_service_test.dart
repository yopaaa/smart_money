import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/services/gemini_voice_service.dart';

void main() {
  group('GeminiVoiceService & ParsedVoiceTransaction Unit Tests', () {
    final accounts = [
      AccountModel(id: 'acc_cash', name: 'Cash', type: 'cash', balance: 500000),
      AccountModel(id: 'acc_bca', name: 'BCA', type: 'bank', balance: 2000000),
      AccountModel(id: 'acc_gopay', name: 'GoPay', type: 'e-wallet', balance: 150000),
    ];

    final categories = [
      CategoryModel(id: 'cat_food', name: 'Makanan & Minuman', type: 'expense', icon: 'food', color: '#FF5722'),
      CategoryModel(id: 'cat_fuel', name: 'Bensin & Transport', type: 'expense', icon: 'car', color: '#2196F3'),
      CategoryModel(id: 'cat_salary', name: 'Gaji', type: 'income', icon: 'wallet', color: '#4CAF50'),
    ];

    test('Parses expense transaction with informative voice marker description', () {
      final json = {
        'title': 'Beli Bensin',
        'amount': 30000,
        'type': 'expense',
        'account_id': 'acc_cash',
        'account_name': 'Cash',
        'category_id': 'cat_fuel',
        'category_name': 'Bensin & Transport',
        'target_account_id': null,
        'date_time': '2026-11-24T10:15:00',
        'description': 'Pertalite 30 ribu pakai uang tunai',
      };

      final parsed = ParsedVoiceTransaction.fromJson(
        json,
        availableAccounts: accounts,
        availableCategories: categories,
      );

      expect(parsed.title, 'Beli Bensin');
      expect(parsed.amount, 30000);
      expect(parsed.type, 'expense');
      expect(parsed.accountId, 'acc_cash');
      expect(parsed.accountName, 'Cash');
      expect(parsed.categoryId, 'cat_fuel');
      expect(parsed.categoryName, 'Bensin & Transport');
      // Description must be formatted as an informative voice marker
      expect(parsed.description, '🎙️ Transaksi Suara: Pertalite 30 ribu pakai uang tunai');
      expect(parsed.dateTime.year, 2026);
      expect(parsed.dateTime.month, 11);
      expect(parsed.dateTime.day, 24);

      final txModel = parsed.toTransactionModel();
      expect(txModel.title, 'Beli Bensin');
      expect(txModel.amount, 30000);
      expect(txModel.type, 'expense');
      expect(txModel.accountId, 'acc_cash');
      expect(txModel.category, 'cat_fuel');
      expect(txModel.targetAccountId, isNull);
    });

    test('Does not echo title in description when description is empty or duplicates title', () {
      final json = {
        'title': 'Makan Bakso',
        'amount': 25000,
        'type': 'expense',
        'account_id': 'acc_cash',
        'category_id': 'cat_food',
        'description': 'Makan Bakso', // simply duplicating title
      };

      final parsed = ParsedVoiceTransaction.fromJson(
        json,
        availableAccounts: accounts,
        availableCategories: categories,
      );

      // Description should be transformed into an informative voice marker
      expect(parsed.description, '🎙️ Transaksi Suara: Makan Bakso');
    });

    test('Parses transfer transaction with source and destination accounts', () {
      final json = {
        'title': 'Transfer ke GoPay',
        'amount': 100000,
        'type': 'transfer',
        'account_id': 'acc_bca',
        'account_name': 'BCA',
        'category_id': null,
        'target_account_id': 'acc_gopay',
        'target_account_name': 'GoPay',
        'date_time': '2026-11-24T12:00:00',
        'description': '🎙️ Transaksi Suara: Top up GoPay dari rekening BCA',
      };

      final parsed = ParsedVoiceTransaction.fromJson(
        json,
        availableAccounts: accounts,
        availableCategories: categories,
      );

      expect(parsed.title, 'Transfer ke GoPay');
      expect(parsed.amount, 100000);
      expect(parsed.type, 'transfer');
      expect(parsed.accountId, 'acc_bca');
      expect(parsed.targetAccountId, 'acc_gopay');
      expect(parsed.categoryId, isNull);
      expect(parsed.description, '🎙️ Transaksi Suara: Top up GoPay dari rekening BCA');

      final txModel = parsed.toTransactionModel();
      expect(txModel.type, 'transfer');
      expect(txModel.targetAccountId, 'acc_gopay');
      expect(txModel.category, isNull);
    });

    test('Falls back gracefully if account or category does not match perfectly', () {
      final json = {
        'title': 'Jajan Tak Dikenal',
        'amount': '15000',
        'type': 'expense',
        'account_id': 'non_existent_acc',
        'account_name': 'Dompet Gaib',
        'category_id': 'non_existent_cat',
        'category_name': 'Kategori Asing',
        'description': 'Beli snack',
      };

      final parsed = ParsedVoiceTransaction.fromJson(
        json,
        availableAccounts: accounts,
        availableCategories: categories,
      );

      expect(parsed.amount, 15000);
      expect(parsed.type, 'expense');
      // Should fallback to first available account
      expect(parsed.accountId, accounts.first.id);
      // Category should match first expense category
      expect(parsed.categoryId, 'cat_food');
      expect(parsed.description, '🎙️ Transaksi Suara: Beli snack');
    });
  });
}
