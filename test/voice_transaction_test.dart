import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/home/main_navigation_screen.dart';
import 'package:smart_money/screens/transactions/voice_transaction_dialog.dart';

void main() {
  group('VoiceTransactionDialog Widget Tests', () {
    testWidgets('Renders all voice listening elements properly', (
      WidgetTester tester,
    ) async {
      String? submittedText;
      bool wasCancelled = false;

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceTransactionDialog(
              onSubmit: (text) => submittedText = text,
              onCancel: () => wasCancelled = true,
            ),
          ),
        ),
      );

      // Verify header and title elements
      expect(find.text('Mendengarkan...'), findsOneWidget);
      expect(find.text('Transaksi Suara AI'), findsNothing);
      expect(find.text('Ucapkan transaksi Anda secara jelas'), findsOneWidget);
      expect(find.text('Contoh yang bisa diucapkan:'), findsOneWidget);

      // Verify central mic icon and submit button
      expect(find.byIcon(Ionicons.mic), findsOneWidget);
      expect(find.text('Selesai / Submit'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      // Advance animation slightly
      await tester.pump(const Duration(milliseconds: 300));

      // Test submit button tap
      await tester.tap(find.text('Selesai / Submit'));
      await tester.pump();
      expect(submittedText, isNotNull);

      // Test cancel button tap
      await tester.tap(find.text('Batal'));
      await tester.pump();
      expect(wasCancelled, isTrue);
    });

    testWidgets('FAB long press in MainNavigationScreen opens Voice dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find FAB center button by its icon Ionicons.add
      final fabIconFinder = find.byIcon(Ionicons.add);
      expect(fabIconFinder, findsOneWidget);

      // Long press on FAB
      await tester.longPress(fabIconFinder);
      await tester.pump(const Duration(milliseconds: 350));

      // Voice dialog should now be visible
      expect(find.text('Mendengarkan...'), findsOneWidget);
      expect(find.text('Selesai / Submit'), findsOneWidget);

      // Dismiss dialog by tapping Batal
      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Voice dialog should be dismissed
      expect(find.text('Mendengarkan...'), findsNothing);
    });
  });
}
