import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/home/gallery_screen.dart';
import 'package:smart_money/widgets/transaction_item.dart';

class FakeTransactionProvider extends ChangeNotifier
    implements TransactionProvider {
  final List<TransactionModel> _fakeImages;

  FakeTransactionProvider(this._fakeImages);

  @override
  CurrencyModel get currency => CurrencyModel.defaultCurrency;

  @override
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
    return _fakeImages;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('GalleryScreen shows empty state when no receipt photos exist', (
    WidgetTester tester,
  ) async {
    final fakeProvider = FakeTransactionProvider([]);

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: fakeProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: GalleryScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tidak ada foto struk transaksi'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets(
      'GalleryScreen groups photos by date and displays date headers & time correctly',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final today1 = DateTime(now.year, now.month, now.day, 14, 30);
    final today2 = DateTime(now.year, now.month, now.day, 9, 15);
    final pastDate = DateTime(2026, 1, 15, 18, 45);

    final fakeImages = [
      TransactionModel(
        id: 'tx_1',
        title: 'Makan Siang',
        amount: 35000,
        type: 'expense',
        category: 'cat_food',
        accountId: 'acc_cash',
        createdAt: today1.millisecondsSinceEpoch.toString(),
        img: '/fake/path/receipt1.jpg',
      ),
      TransactionModel(
        id: 'tx_2',
        title: 'Kopi Pagi',
        amount: 20000,
        type: 'expense',
        category: 'cat_food',
        accountId: 'acc_cash',
        createdAt: today2.millisecondsSinceEpoch.toString(),
        img: '/fake/path/receipt2.jpg',
      ),
      TransactionModel(
        id: 'tx_3',
        title: 'Belanja Buku',
        amount: 150000,
        type: 'expense',
        category: 'cat_book',
        accountId: 'acc_bank',
        createdAt: pastDate.millisecondsSinceEpoch.toString(),
        img: '/fake/path/receipt3.jpg',
      ),
    ];

    final fakeProvider = FakeTransactionProvider(fakeImages);

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: fakeProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: GalleryScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Date Headers exist using TransactionDateHeader
    expect(find.byType(TransactionDateHeader), findsNWidgets(2));

    // Verify Today group header is present
    expect(find.text('Today'), findsOneWidget);

    // Verify past date header has day '15' and month 'Jan 2026'
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Jan 2026'), findsOneWidget);

    // Verify times ("jam") are formatted with DateFormat('HH:mm')
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
    expect(find.text('18:45'), findsOneWidget);

    // Verify clock icons are rendered for each photo tile
    expect(find.byIcon(Icons.access_time_rounded), findsNWidgets(3));
  });
}
