import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/utils/currency_formatter.dart';
import 'package:smart_money/utils/date_utils.dart';

void main() {
  group('Model serialization tests', () {
    test('AccountModel serialization and deserialization', () {
      final account = AccountModel(
        id: 'acc-1',
        name: 'Dompet Utama',
        balance: 500000,
        type: 'cash',
        isLiability: false,
        hidden: false,
        icon: 'cash',
        iconColor: '#81c784',
        description: 'Dompet saku',
      );

      final map = account.toMap();
      final fromMap = AccountModel.fromMap(map);

      expect(fromMap.id, 'acc-1');
      expect(fromMap.name, 'Dompet Utama');
      expect(fromMap.balance, 500000);
      expect(fromMap.type, 'cash');
      expect(fromMap.isLiability, false);
    });

    test('TransactionModel serialization and date parsing', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx-1',
        title: 'Makan Siang',
        amount: 35000,
        type: 'expense',
        accountId: 'acc-1',
        createdAt: now.millisecondsSinceEpoch.toString(),
        category: 'food',
      );

      final map = tx.toMap();
      final fromMap = TransactionModel.fromMap(map);

      expect(fromMap.id, 'tx-1');
      expect(fromMap.title, 'Makan Siang');
      expect(fromMap.amount, 35000);
      expect(fromMap.type, 'expense');
      expect(fromMap.dateTime.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('CategoryModel serialization', () {
      final cat = CategoryModel(
        id: 'cat-1',
        name: 'Makanan',
        icon: 'silverware-fork-knife',
        color: '#e57373',
        type: 'expense',
      );

      final map = cat.toMap();
      final fromMap = CategoryModel.fromMap(map);

      expect(fromMap.name, 'Makanan');
      expect(fromMap.type, 'expense');
    });
  });

  group('CurrencyFormatter tests', () {
    test('Formats IDR correctly', () {
      final formatted = CurrencyFormatter.format(150000, CurrencyModel.defaultCurrency);
      expect(formatted.contains('150'), isTrue);
      expect(formatted.contains('Rp'), isTrue);
    });

    test('Unformats string to int correctly', () {
      final unformatted = CurrencyFormatter.unformat('Rp 250.000');
      expect(unformatted, 250000);
    });
  });

  group('DateUtils grouping tests', () {
    test('Groups transactions by day', () {
      final today = DateTime.now();
      final tx1 = TransactionModel(
        id: '1',
        title: 'Kopi',
        amount: 20000,
        type: 'expense',
        accountId: 'acc-1',
        createdAt: today.millisecondsSinceEpoch.toString(),
      );
      final tx2 = TransactionModel(
        id: '2',
        title: 'Gaji',
        amount: 5000000,
        type: 'income',
        accountId: 'acc-1',
        createdAt: today.millisecondsSinceEpoch.toString(),
      );

      final grouped = AppDateUtils.groupTransactionsByDate([tx1, tx2]);
      expect(grouped.length, 1);
      expect(grouped.first.date, 'Today');
      expect(grouped.first.total, 4980000);
      expect(grouped.first.transactions.length, 2);
    });
  });
}
