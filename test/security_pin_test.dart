import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/providers/security_provider.dart';
import 'package:smart_money/screens/settings/auto_lock_settings_screen.dart';
import 'package:smart_money/screens/settings/pin_lock_screen.dart';

void main() {
  group('SecurityProvider Unit Tests', () {
    test('Initial state is not locked when no PIN is set', () {
      final security = SecurityProvider.instance;
      // Default when freshly loaded without saved PIN
      expect(security.isLocked, isFalse);
    });

    test('Setting PIN enables lock and unlocks session for duration', () async {
      final security = SecurityProvider.instance;
      await security.setPin('1234');

      expect(security.isPinSet, isTrue);
      expect(security.isLockEnabled, isTrue);
      expect(security.isSessionUnlocked, isTrue);
      expect(security.isLocked, isFalse);
      expect(security.verifyPin('1234'), isTrue);
      expect(security.verifyPin('9999'), isFalse);

      // Explicit lock should lock session
      security.lockSession();
      expect(security.isSessionUnlocked, isFalse);
      expect(security.isLocked, isTrue);

      // Unlocking with correct PIN should unlock session
      final unlocked = security.unlock('1234');
      expect(unlocked, isTrue);
      expect(security.isLocked, isFalse);

      // Clean up for other tests
      await security.removePin();
      expect(security.isPinSet, isFalse);
      expect(security.isLocked, isFalse);
    });
  });

  group('PinLockScreen Widget Tests', () {
    testWidgets('Renders keypad and enters 4 digits properly', (
      WidgetTester tester,
    ) async {
      final security = SecurityProvider.instance;
      await security.setPin('1234');
      security.lockSession();

      bool didSucceed = false;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: security,
          child: MaterialApp(
            home: PinLockScreen(
              mode: PinMode.verify,
              canCancel: true,
              onSuccess: () => didSucceed = true,
            ),
          ),
        ),
      );

      expect(find.text('Masukkan PIN'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      // Verify digits 0-9 are present
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Enter '1', '2', '3', '4'
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();

      expect(didSucceed, isTrue);

      // Clean up
      await security.removePin();
    });

    testWidgets('Shows error on incorrect PIN', (
      WidgetTester tester,
    ) async {
      final security = SecurityProvider.instance;
      await security.setPin('1234');
      security.lockSession();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: security,
          child: const MaterialApp(
            home: PinLockScreen(
              mode: PinMode.verify,
            ),
          ),
        ),
      );

      // Enter wrong PIN: '5', '5', '5', '5'
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      expect(find.text('PIN salah, silakan coba lagi'), findsOneWidget);

      // Clean up
      await security.removePin();
    });
  });

  group('AutoLockSettingsScreen Widget Tests', () {
    testWidgets('Renders settings switch and session information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: SecurityProvider.instance,
          child: const MaterialApp(
            home: AutoLockSettingsScreen(),
          ),
        ),
      );

      expect(find.text('Kunci Aplikasi (PIN)'), findsOneWidget);
      expect(find.text('STATUS KEAMANAN'), findsOneWidget);
      expect(find.text('Kunci Aplikasi dengan PIN'), findsOneWidget);
      expect(find.text('INFORMASI SESI'), findsOneWidget);
      expect(find.textContaining('Durasi Sesi'), findsOneWidget);
    });
  });
}
