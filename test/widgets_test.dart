import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/utils/date_utils.dart';
import 'package:smart_money/widgets/action_button.dart';
import 'package:smart_money/widgets/animated_tab_bar.dart';
import 'package:smart_money/widgets/custom_card.dart';
import 'package:smart_money/widgets/period_navigator.dart';
import 'package:smart_money/widgets/period_picker_dialog.dart';
import 'package:smart_money/widgets/slide_select.dart';
import 'package:smart_money/widgets/transaction_item.dart';

void main() {
  group('AnimatedTabBar Component Tests', () {
    testWidgets('renders default 2 icon tabs correctly', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              activeIndex: activeIndex,
              onTabChanged: (idx) => activeIndex = idx,
            ),
          ),
        ),
      );

      expect(find.byIcon(Ionicons.list), findsOneWidget);
      expect(find.byIcon(Ionicons.images), findsOneWidget);

      await tester.tap(find.byIcon(Ionicons.images));
      await tester.pumpAndSettle();
      expect(activeIndex, 1);
    });

    testWidgets('renders 3 text tabs and responds to selection', (
      tester,
    ) async {
      int activeIndex = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              width: 320,
              activeIndex: activeIndex,
              onTabChanged: (idx) => activeIndex = idx,
              tabs: const [
                TabItem(key: 'income', label: 'Income'),
                TabItem(key: 'expense', label: 'Expense'),
                TabItem(key: 'transfer', label: 'Transfer'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(activeIndex, 0);

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(activeIndex, 2);
    });
  });

  group('ActionButton Component Tests', () {
    testWidgets('renders title and triggers callback when pressed', (
      tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(title: 'Simpan', onPress: () => pressed = true),
          ),
        ),
      );

      expect(find.text('Simpan'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(pressed, true);
    });

    testWidgets('displays loading indicator and blocks taps when isLoading', (
      tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              title: 'Simpan',
              isLoading: true,
              onPress: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);

      await tester.tap(find.byType(ActionButton));
      await tester.pump();
      expect(pressed, false);
    });

    testWidgets('blocks interaction when disabled is true', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              title: 'Hapus',
              disabled: true,
              onPress: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Hapus'));
      await tester.pump();
      expect(pressed, false);
    });
  });

  group('CustomCard Component Tests', () {
    testWidgets('renders child content and responds to onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomCard(
              onTap: () => tapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      await tester.pump();
      expect(tapped, true);
    });
  });

  group('SlideSelect Component Tests', () {
    testWidgets('renders Income and Expense and responds to toggle', (
      tester,
    ) async {
      String selected = 'expense';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlideSelect(
              selectedType: selected,
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('Expense'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pumpAndSettle();
      expect(selected, 'income');
    });
  });

  group('PeriodPicker and PeriodNavigator Component Tests', () {
    testWidgets(
      'PeriodPickerSheet displays all 4 period options with active state',
      (tester) async {
        ViewMode? picked;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    picked = await showPeriodPickerDialog(ctx, ViewMode.month);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Rentang Waktu'), findsOneWidget);
        expect(find.text('Minggu'), findsOneWidget);
        expect(find.text('Bulan'), findsOneWidget);
        expect(find.text('Kuartal'), findsOneWidget);
        expect(find.text('Tahun'), findsOneWidget);
        expect(
          find.text('Aktif'),
          findsOneWidget,
        ); // Active indicator for current month

        // Tap on Kuartal
        await tester.tap(find.text('Kuartal'));
        await tester.pumpAndSettle();

        expect(picked, ViewMode.quarter);
      },
    );

    testWidgets(
      'PeriodNavigator renders mode badge, title, and handles date/mode changes',
      (tester) async {
        DateTime selectedDate = DateTime(2026, 9, 15);
        ViewMode currentMode = ViewMode.month;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, setState) => PeriodNavigator(
                  selectedDate: selectedDate,
                  viewMode: currentMode,
                  onDateChange: (newDate) {
                    setState(() => selectedDate = newDate);
                  },
                  onModeChange: (newMode) {
                    setState(() => currentMode = newMode);
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('September 2026'), findsOneWidget);

        // Tap next chevron
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();
        expect(find.text('October 2026'), findsOneWidget);

        // Tap previous chevron twice
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        expect(find.text('August 2026'), findsOneWidget);

        // Tap center pill to open picker
        await tester.tap(find.text('August 2026'));
        await tester.pumpAndSettle();
        expect(find.text('Pilih Rentang Waktu'), findsOneWidget);

        // Select Tahun
        await tester.tap(find.text('Tahun'));
        await tester.pumpAndSettle();

        expect(find.text('2026'), findsOneWidget);
      },
    );
  });

  group('TransactionDateHeader and TransactionGroupWidget Tests', () {
    testWidgets(
      'renders specific date with big day number, day of week, month year, and formatted total',
      (tester) async {
        final txDate = DateTime(2026, 11, 18, 12, 0);
        final group = GroupedTransaction(
          date: '18 Nov 2026',
          timestamp: txDate.millisecondsSinceEpoch,
          total: -1280000,
          transactions: [
            TransactionModel(
              id: 'tx1',
              title: 'beli hp samsung z flip 5',
              amount: 1192000,
              type: 'expense',
              category: 'cat1',
              accountId: 'acc1',
              createdAt: txDate.toIso8601String(),
            ),
            TransactionModel(
              id: 'tx2',
              title: 'kouta internet',
              amount: 88000,
              type: 'expense',
              category: 'cat1',
              accountId: 'acc1',
              createdAt: txDate.toIso8601String(),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransactionDateHeader(
                group: group,
                currency: CurrencyModel.defaultCurrency,
              ),
            ),
          ),
        );

        expect(find.text('18'), findsOneWidget);
        expect(find.text('Wednesday'), findsOneWidget);
        expect(find.text('Nov 2026'), findsOneWidget);
        expect(find.text('-Rp 1.280.000'), findsOneWidget);
      },
    );

    testWidgets('renders Yesterday date header format with total', (
      tester,
    ) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final group = GroupedTransaction(
        date: 'Yesterday',
        timestamp: yesterday.millisecondsSinceEpoch,
        total: -120000,
        transactions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionDateHeader(
              group: group,
              currency: CurrencyModel.defaultCurrency,
            ),
          ),
        ),
      );

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('-Rp 120.000'), findsOneWidget);
    });
  });
}
