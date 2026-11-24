import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/transactions/voice_transaction_review_sheet.dart';
import 'package:smart_money/services/gemini_voice_service.dart';

class MockReviewTransactionProvider extends ChangeNotifier
    implements TransactionProvider {
  final List<TransactionModel> addedTransactions = [];

  @override
  CurrencyModel get currency => CurrencyModel.defaultCurrency;

  @override
  List<AccountModel> get accounts => [
        AccountModel(id: 'acc_cash', name: 'Cash', type: 'cash', balance: 500000),
        AccountModel(id: 'acc_bca', name: 'BCA', type: 'bank', balance: 2000000),
      ];

  @override
  List<CategoryModel> get categories => [
        CategoryModel(
          id: 'cat_food',
          name: 'Makanan & Minuman',
          type: 'expense',
          icon: 'food',
          color: '#FF5722',
        ),
      ];

  @override
  Future<void> addTransactions(List<TransactionModel> txList) async {
    addedTransactions.addAll(txList);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('VoiceTransactionReviewSheet renders items with checkboxes checked by default',
      (WidgetTester tester) async {
    final mockProvider = MockReviewTransactionProvider();

    final testItems = [
      ParsedVoiceTransaction(
        id: '1',
        title: 'Makan Bakso',
        amount: 25000,
        type: 'expense',
        accountId: 'acc_cash',
        accountName: 'Cash',
        categoryId: 'cat_food',
        categoryName: 'Makanan & Minuman',
        description: 'Makan bakso siang',
      ),
      ParsedVoiceTransaction(
        id: '2',
        title: 'Beli Kopi',
        amount: 18000,
        type: 'expense',
        accountId: 'acc_bca',
        accountName: 'BCA',
        categoryId: 'cat_food',
        categoryName: 'Makanan & Minuman',
        description: 'Kopi susu',
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: mockProvider,
        child: MaterialApp(
          home: Scaffold(
            body: VoiceTransactionReviewSheet(
              initialTransactions: testItems,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify Title and Subtitle
    expect(find.text('Tinjau Transaksi AI'), findsOneWidget);
    expect(find.text('Ditemukan 2 transaksi dari ucapan Anda'), findsOneWidget);

    // Verify transaction names & descriptions
    expect(find.text('Makan Bakso'), findsOneWidget);
    expect(find.text('Makan bakso siang'), findsOneWidget);
    expect(find.text('Beli Kopi'), findsOneWidget);
    expect(find.text('Kopi susu'), findsOneWidget);

    // Checkboxes checked by default: 2 checkboxes for items
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(2));
    for (var element in checkboxes.evaluate()) {
      final cb = element.widget as Checkbox;
      expect(cb.value, isTrue);
    }

    // Save button label includes total count
    expect(find.text('Simpan Semua Transaksi (2)'), findsOneWidget);

    // Tap save button
    await tester.tap(find.text('Simpan Semua Transaksi (2)'));
    await tester.pumpAndSettle();

    // Verify mock provider received both transactions
    expect(mockProvider.addedTransactions.length, 2);
    expect(mockProvider.addedTransactions[0].title, 'Makan Bakso');
    expect(mockProvider.addedTransactions[1].title, 'Beli Kopi');
  });
}
