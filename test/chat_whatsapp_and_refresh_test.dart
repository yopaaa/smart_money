import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/home/history_screen.dart';
import 'package:smart_money/screens/transactions/transaction_form_screen.dart';
import 'package:smart_money/services/chat_history_service.dart';

class MockChatTransactionProvider extends ChangeNotifier
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
          name: 'Makanan',
          type: 'expense',
          icon: 'food',
          color: '#FF5722',
        ),
      ];

  @override
  AccountModel? findAccount(String? id) {
    if (id == null) return null;
    return accounts.where((a) => a.id == id).firstOrNull;
  }

  @override
  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    return categories.where((c) => c.id == id).firstOrNull;
  }

  @override
  List<CategoryModel> getCategoriesByType(String type) {
    return categories.where((c) => c.type == type).toList();
  }

  @override
  Future<void> addTransactions(List<TransactionModel> txList) async {
    addedTransactions.addAll(txList);
    notifyListeners();
  }

  @override
  Future<void> addTransaction(TransactionModel tx) async {
    addedTransactions.add(tx);
    notifyListeners();
  }

  @override
  Future<void> loadData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatHistoryService Unit Tests', () {
    test('addVoiceTransactionChat stores user transcript and assistant reply',
        () async {
      await ChatHistoryService.instance.clearHistory();

      final now = DateTime.now().millisecondsSinceEpoch;
      final tx = TransactionModel(
        id: 'tx_1',
        title: 'Beli Kopi Kenangan',
        amount: 25000,
        type: 'expense',
        accountId: 'acc_bca',
        createdAt: now.toString(),
        description: 'Kopi gula aren via QRIS',
      );

      await ChatHistoryService.instance.addVoiceTransactionChat(
        transcript: 'beli kopi kenangan 25 ribu bayar pake bca',
        savedTransactions: [tx],
      );

      final messages = await ChatHistoryService.instance.getMessages();
      expect(messages.length, greaterThanOrEqualTo(2));

      final userMsg = messages.firstWhere((m) => m.sender == 'user');
      expect(userMsg.message, 'beli kopi kenangan 25 ribu bayar pake bca');
      expect(userMsg.isVoice, isTrue);

      final assistantMsg =
          messages.firstWhere((m) => m.sender == 'assistant');
      expect(assistantMsg.transactions.length, 1);
      expect(assistantMsg.transactions.first.title, 'Beli Kopi Kenangan');
    });
  });

  group('TransactionFormScreen WhatsApp Chat UI Tests', () {
    testWidgets(
        'Switching to Chat tab renders WhatsApp layout and input bar',
        (tester) async {
      final mockProvider = MockChatTransactionProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(
              value: mockProvider,
            ),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Chat tab pill
      final chatTabFinder = find.text('Chat');
      expect(chatTabFinder, findsOneWidget);
      await tester.tap(chatTabFinder);
      await tester.pumpAndSettle();

      // Verify WhatsApp-style header bar
      expect(find.text('Smart Money AI'), findsWidgets);
      expect(find.text('online'), findsOneWidget);

      // Verify WhatsApp bottom input bar
      expect(find.text('Ketik pesan transaksi...'), findsOneWidget);
      // Mic icon should be visible on the round action button when input text is empty
      expect(
        find.widgetWithIcon(InkWell, Icons.mic_rounded),
        findsOneWidget,
      );

      // Type text into input field
      await tester.enterText(
        find.widgetWithText(TextField, 'Ketik pesan transaksi...'),
        'makan bakso 25000',
      );
      await tester.pumpAndSettle();

      // Mic icon turns into Send icon on the action button
      expect(
        find.widgetWithIcon(InkWell, Icons.send_rounded),
        findsOneWidget,
      );

      // Tap send button
      await tester.tap(find.widgetWithIcon(InkWell, Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify user bubble and assistant transaction card appeared
      expect(find.text('makan bakso 25000'), findsNWidgets(2));
      // Verify WhatsApp double checkmark icon is present in user bubble
      expect(find.byIcon(Icons.done_all), findsWidgets);

      // Verify transaction was added to provider
      expect(mockProvider.addedTransactions.length, greaterThanOrEqualTo(1));
    });
  });

  group('HistoryScreen Pull-to-Refresh Tests', () {
    testWidgets('HistoryScreen contains RefreshIndicator and can overscroll',
        (tester) async {
      final mockProvider = MockChatTransactionProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(
              value: mockProvider,
            ),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify RefreshIndicator exists inside the view
      expect(find.byType(RefreshIndicator), findsWidgets);

      // Perform a pull-down gesture
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}
