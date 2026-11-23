import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money/screens/settings/notification_settings_screen.dart';
import 'package:smart_money/services/notification_service.dart';

void main() {
  group('NotificationService & ReminderTime Model Tests', () {
    test('Default reminders are 3 PM (15:00) and 8 PM (20:00)', () {
      final defaults = NotificationService.defaultReminders;
      expect(defaults.length, 2);

      final afternoon = defaults[0];
      expect(afternoon.hour, 15);
      expect(afternoon.minute, 0);
      expect(afternoon.enabled, isTrue);
      expect(afternoon.timeFormatted, contains('15:00'));
      expect(afternoon.timeFormatted, contains('03:00 PM'));

      final night = defaults[1];
      expect(night.hour, 20);
      expect(night.minute, 0);
      expect(night.enabled, isTrue);
      expect(night.timeFormatted, contains('20:00'));
      expect(night.timeFormatted, contains('08:00 PM'));
    });

    test('ReminderTime serialization toMap and fromMap works correctly', () {
      const original = ReminderTime(
        id: 101,
        hour: 9,
        minute: 30,
        enabled: true,
        label: 'Pagi Hari',
      );

      final map = original.toMap();
      expect(map['id'], 101);
      expect(map['hour'], 9);
      expect(map['minute'], 30);
      expect(map['enabled'], isTrue);
      expect(map['label'], 'Pagi Hari');

      final reconstructed = ReminderTime.fromMap(map);
      expect(reconstructed.id, 101);
      expect(reconstructed.hour, 9);
      expect(reconstructed.minute, 30);
      expect(reconstructed.enabled, isTrue);
      expect(reconstructed.label, 'Pagi Hari');
      expect(reconstructed.timeFormatted, contains('09:30 AM'));
    });

    test('ReminderTime copyWith updates fields properly', () {
      const original = ReminderTime(
        id: 1,
        hour: 15,
        minute: 0,
        enabled: true,
      );

      final updated = original.copyWith(hour: 16, minute: 45, enabled: false);
      expect(updated.id, 1);
      expect(updated.hour, 16);
      expect(updated.minute, 45);
      expect(updated.enabled, isFalse);
    });
  });

  group('NotificationSettingsScreen Widget Tests', () {
    testWidgets('Renders AppBar, Master Switch, and Action Buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationSettingsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Kelola Notifikasi'), findsOneWidget);
      expect(find.text('STATUS NOTIFIKASI'), findsOneWidget);
      expect(find.text('Aktifkan Pengingat Harian'), findsOneWidget);
      expect(find.text('JADWAL PENGINGAT HARIAN'), findsOneWidget);
      expect(find.text('Uji Coba Notifikasi'), findsOneWidget);
      expect(find.text('Kirim Notifikasi Tes'), findsOneWidget);
    });

    testWidgets(
      'NotificationSettingsScreen renders without overflow on 320px narrow screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Kelola Notifikasi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
