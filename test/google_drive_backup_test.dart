import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/providers/backup_provider.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/settings/account_info_screen.dart';
import 'package:smart_money/screens/settings/backup_restore_screen.dart';
import 'package:smart_money/screens/settings/settings_screen.dart';
import 'package:smart_money/screens/welcome/welcome_screen.dart';
import 'package:smart_money/services/backup_sync_service.dart';
import 'package:smart_money/services/google_drive_service.dart';

class MockBackupProvider extends ChangeNotifier implements BackupProvider {
  GoogleAccountProfile? _account;
  String? _serverClientId;
  BackupSchedule _schedule;
  bool _wifiOnly;
  bool _includeReceipts;
  final DateTime? _lastBackupAt;
  final int? _lastBackupSizeBytes;
  final List<DriveBackupFile> _driveBackups;

  MockBackupProvider({
    GoogleAccountProfile? account,
    String? serverClientId,
    BackupSchedule schedule = BackupSchedule.off,
    bool wifiOnly = true,
    bool includeReceipts = true,
    DateTime? lastBackupAt,
    int? lastBackupSizeBytes,
    List<DriveBackupFile> driveBackups = const [],
  })  : _account = account,
        _serverClientId = serverClientId,
        _schedule = schedule,
        _wifiOnly = wifiOnly,
        _includeReceipts = includeReceipts,
        _lastBackupAt = lastBackupAt,
        _lastBackupSizeBytes = lastBackupSizeBytes,
        _driveBackups = driveBackups;

  @override
  GoogleAccountProfile? get account => _account;

  @override
  bool get isSignedIn => _account != null;

  @override
  String? get serverClientId => _serverClientId;

  @override
  BackupSchedule get schedule => _schedule;

  @override
  bool get wifiOnly => _wifiOnly;

  @override
  bool get includeReceipts => _includeReceipts;

  @override
  DateTime? get lastBackupAt => _lastBackupAt;

  @override
  int? get lastBackupSizeBytes => _lastBackupSizeBytes;

  @override
  List<DriveBackupFile> get driveBackups => _driveBackups;

  @override
  bool get isInitialized => true;

  @override
  bool get isSigningIn => false;

  @override
  bool get isBackingUp => false;

  @override
  bool get isRestoring => false;

  @override
  bool get isLoadingDriveList => false;

  @override
  Future<void> setSchedule(BackupSchedule newSchedule) async {
    _schedule = newSchedule;
    notifyListeners();
  }

  @override
  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    notifyListeners();
  }

  @override
  Future<void> setIncludeReceipts(bool value) async {
    _includeReceipts = value;
    notifyListeners();
  }

  @override
  Future<void> saveServerClientId(String clientId) async {
    _serverClientId = clientId;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _account = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSimpleTxProvider extends ChangeNotifier
    implements TransactionProvider {
  @override
  CurrencyModel get currency => CurrencyModel.defaultCurrency;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BackupSyncService Schedule & Validation Unit Tests', () {
    test('isBackupDue handles off, elapsed intervals, and dirty check accurately',
        () {
      final now = DateTime(2026, 11, 26, 14, 0);

      // Off schedule -> never due
      expect(
        BackupSyncService.instance.isBackupDue(
          const BackupSyncConfig(
            schedule: BackupSchedule.off,
            wifiOnly: true,
            includeReceipts: true,
          ),
          now: now,
        ),
        isFalse,
      );

      // Daily schedule with no previous backup -> due immediately
      expect(
        BackupSyncService.instance.isBackupDue(
          const BackupSyncConfig(
            schedule: BackupSchedule.daily,
            wifiOnly: true,
            includeReceipts: true,
          ),
          now: now,
        ),
        isTrue,
      );

      // Daily schedule backed up 10 hours ago -> not due yet
      expect(
        BackupSyncService.instance.isBackupDue(
          BackupSyncConfig(
            schedule: BackupSchedule.daily,
            wifiOnly: true,
            includeReceipts: true,
            lastBackupAt: now.subtract(const Duration(hours: 10)),
            lastDataChangeAt: now.subtract(const Duration(hours: 1)),
          ),
          now: now,
        ),
        isFalse,
      );

      // Daily schedule backed up 25 hours ago WITH newer data change -> due
      expect(
        BackupSyncService.instance.isBackupDue(
          BackupSyncConfig(
            schedule: BackupSchedule.daily,
            wifiOnly: true,
            includeReceipts: true,
            lastBackupAt: now.subtract(const Duration(hours: 25)),
            lastDataChangeAt: now.subtract(const Duration(hours: 2)),
          ),
          now: now,
        ),
        isTrue,
      );

      // Daily schedule backed up 25 hours ago WITHOUT any changes since -> skip
      expect(
        BackupSyncService.instance.isBackupDue(
          BackupSyncConfig(
            schedule: BackupSchedule.daily,
            wifiOnly: true,
            includeReceipts: true,
            lastBackupAt: now.subtract(const Duration(hours: 25)),
            lastDataChangeAt: now.subtract(const Duration(hours: 30)),
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('restoreFromBackupBytes rejects unrecognized invalid bytes', () async {
      await expectLater(
        BackupSyncService.instance
            .restoreFromBackupBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6])),
        throwsFormatException,
      );
    });

    test(
        'findMissingReceiptNames only selects new photos not yet synced on Drive',
        () {
      final missing = BackupSyncService.instance.findMissingReceiptNames(
        localReceiptPaths: [
          '/data/user/0/app/receipt_1001.jpg',
          '/data/user/0/app/receipt_1002.jpg',
          '/data/user/0/app/receipt_1003.png',
          '/data/user/0/app/receipt_1003.png', // duplicate reference
          '',
        ],
        remoteSyncedReceipts: {
          'receipt_1001.jpg': 'drive_id_1',
          'receipt_1002.jpg': 'drive_id_2',
        },
      );

      expect(missing, ['receipt_1003.png']);
    });

    test('DriveBackupFile parses snapshot kind and newReceiptsUploaded', () {
      final file = DriveBackupFile.fromJson({
        'id': 'f_1',
        'name': 'smart_money_backup_2026.smbak',
        'size': '45000',
        'createdTime': '2026-11-26T12:00:00Z',
        'modifiedTime': '2026-11-26T12:00:00Z',
        'appProperties': {
          'kind': 'db_snapshot',
          'accountCount': '4',
          'transactionCount': '30',
          'receiptCount': '12',
          'newReceiptsUploaded': '2',
        },
      });

      expect(file.kind, 'db_snapshot');
      expect(file.accountCount, 4);
      expect(file.transactionCount, 30);
      expect(file.receiptCount, 12);
      expect(file.newReceiptsUploaded, 2);
    });
  });

  group('SettingsScreen Profile Banner & AccountInfoScreen UI Tests', () {
    const sampleProfile = GoogleAccountProfile(
      id: 'uid_1',
      email: 'yopa.dev@gmail.com',
      displayName: 'Yopa Pratama',
      photoUrl: null,
    );

    testWidgets(
        'SettingsScreen shows top Profile Banner with name and email when signed in',
        (tester) async {
      final mockBackup = MockBackupProvider(
        account: sampleProfile,
        schedule: BackupSchedule.daily,
      );
      final mockTx = MockSimpleTxProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(value: mockTx),
            ChangeNotifierProvider<BackupProvider>.value(value: mockBackup),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Top profile banner shows display name & email & schedule
      expect(find.text('Yopa Pratama'), findsOneWidget);
      expect(find.text('yopa.dev@gmail.com'), findsWidgets);
      expect(find.text('Auto-Backup: Harian'), findsOneWidget);

      // Tapping Account Information opens AccountInfoScreen
      await tester.tap(find.text('Account Information'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountInfoScreen), findsOneWidget);
      expect(find.text('Google Drive Terhubung'), findsOneWidget);
      expect(find.text('Keluar dari Akun Google'), findsOneWidget);
    });

    testWidgets(
        'AccountInfoScreen displays sign-in onboarding when signed out',
        (tester) async {
      final mockBackup = MockBackupProvider(account: null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<BackupProvider>.value(value: mockBackup),
          ],
          child: const MaterialApp(home: AccountInfoScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hubungkan Akun Google Anda'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.text('Web Client ID (OAuth)'), findsNothing);
    });

    testWidgets(
        'BackupRestoreScreen displays Google Drive section, schedule & local backup',
        (tester) async {
      final mockBackup = MockBackupProvider(
        account: sampleProfile,
        schedule: BackupSchedule.weekly,
        wifiOnly: true,
        includeReceipts: true,
        lastBackupAt: DateTime(2026, 11, 25, 10, 0),
        lastBackupSizeBytes: 512000,
      );
      final mockTx = MockSimpleTxProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(value: mockTx),
            ChangeNotifierProvider<BackupProvider>.value(value: mockBackup),
          ],
          child: const MaterialApp(home: BackupRestoreScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Google Drive Backup'), findsOneWidget);
      expect(find.text('Backup ke Google Drive'), findsOneWidget);
      expect(find.text('Restore Drive'), findsNothing);
      expect(find.text('Jadwal Backup Otomatis'), findsOneWidget);
      expect(find.text('Hanya Backup Saat Wi-Fi'), findsOneWidget);
      expect(find.text('Sertakan Foto Struk Transaksi'), findsOneWidget);
      expect(find.text('Backup Lokal (.smbak)'), findsOneWidget);
      expect(find.text('Restore dari File Lokal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'WelcomeScreen RESTORE DATA opens Google Drive & Local restore options',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockBackup = MockBackupProvider(
        account: sampleProfile,
      );
      final mockTx = MockSimpleTxProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(value: mockTx),
            ChangeNotifierProvider<BackupProvider>.value(value: mockBackup),
          ],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('RESTORE DATA'), findsOneWidget);
      await tester.tap(find.text('RESTORE DATA'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Sumber Restore'), findsOneWidget);
      expect(find.text('Restore dari Google Drive'), findsOneWidget);
      expect(find.text('Restore dari File Lokal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
