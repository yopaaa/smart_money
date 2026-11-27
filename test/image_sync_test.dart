import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/settings/image_sync_screen.dart';
import 'package:smart_money/screens/settings/settings_screen.dart';
import 'package:smart_money/services/image_sync_service.dart';

class _FakeImageFolderBridge implements ImageFolderBridge {
  final Directory publicDir;
  bool grantPermission = true;
  int exportCalls = 0;
  int restoreCalls = 0;

  _FakeImageFolderBridge(this.publicDir);

  @override
  Future<bool> ensurePermission() async => grantPermission;

  @override
  Future<List<PublicImageEntry>> listPublicImages(String relativePath) async {
    if (!publicDir.existsSync()) return const [];
    final entries = <PublicImageEntry>[];
    for (final entity in publicDir.listSync()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (ImageSyncService.isSupportedImageFile(name)) {
          entries.add(PublicImageEntry(name: name, path: entity.path));
        }
      }
    }
    return entries;
  }

  @override
  Future<String> exportToPublicFolder({
    required String sourcePath,
    required String fileName,
    required String relativePath,
  }) async {
    exportCalls++;
    if (!await publicDir.exists()) {
      await publicDir.create(recursive: true);
    }
    final target = File(p.join(publicDir.path, fileName));
    if (await target.exists()) return 'skipped';
    await File(sourcePath).copy(target.path);
    return 'exported';
  }

  @override
  Future<bool> copyPublicImageToLocal({
    required PublicImageEntry entry,
    required String destPath,
  }) async {
    restoreCalls++;
    final src = File(entry.path);
    if (!await src.exists()) return false;
    await File(destPath).parent.create(recursive: true);
    await src.copy(destPath);
    return true;
  }
}

class _StubTxProvider extends ChangeNotifier implements TransactionProvider {
  @override
  CurrencyModel get currency => CurrencyModel.defaultCurrency;

  @override
  Future<void> loadData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ImageSyncService Unit Tests', () {
    test('extractFileName handles local path and legacy file:// URI', () {
      expect(
        ImageSyncService.extractFileName(
          'file:///data/user/0/com.koucheng.smartmoney/files/receipt_1.jpg',
        ),
        'receipt_1.jpg',
      );
      expect(
        ImageSyncService.extractFileName('/data/user/0/app/receipt_2.png'),
        'receipt_2.png',
      );
      expect(ImageSyncService.extractFileName('   '), isEmpty);
    });

    test('exportToPublicFolder copies only missing receipts incrementally', () async {
      final tempRoot = await Directory.systemTemp.createTemp('img_sync_exp_');
      addTearDown(() => tempRoot.delete(recursive: true));

      final appDir = Directory(p.join(tempRoot.path, 'app'))..createSync();
      final publicDir = Directory(p.join(tempRoot.path, 'public'))..createSync();

      final photoA = File(p.join(appDir.path, 'receipt_a.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final photoB = File(p.join(appDir.path, 'receipt_b.jpg'))
        ..writeAsBytesSync([4, 5, 6]);
      // photoA already synced in public folder
      File(p.join(publicDir.path, 'receipt_a.jpg')).writeAsBytesSync([1, 2, 3]);

      final bridge = _FakeImageFolderBridge(publicDir);
      final service = ImageSyncService.forTest(bridge: bridge);

      final txs = [
        TransactionModel(
          id: 'tx1',
          title: 'Lunch',
          amount: 10000,
          type: 'expense',
          accountId: 'a1',
          createdAt: '1700000000000',
          img: photoA.path,
        ),
        TransactionModel(
          id: 'tx2',
          title: 'Dinner',
          amount: 20000,
          type: 'expense',
          accountId: 'a1',
          createdAt: '1700000001000',
          img: photoB.path,
        ),
      ];

      final summaryBefore = await service.getSummary(
        transactionsOverride: txs,
        appDirOverride: appDir,
      );
      expect(summaryBefore.localReceiptCount, 2);
      expect(summaryBefore.publicFolderCount, 1);
      expect(summaryBefore.pendingExportCount, 1);
      expect(summaryBefore.pendingRestoreCount, 0);

      final result = await service.exportToPublicFolder(
        transactionsOverride: txs,
        appDirOverride: appDir,
      );
      expect(result.copied, 1);
      expect(result.skipped, 1);
      expect(result.failed, 0);
      expect(bridge.exportCalls, 1);
      expect(
        File(p.join(publicDir.path, 'receipt_b.jpg')).existsSync(),
        isTrue,
      );
    });
  });

  group('ImageSyncScreen & SettingsScreen UI Tests', () {
    testWidgets('SettingsScreen exposes Export Image navigation item', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(
              value: _StubTxProvider(),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Export Image'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Export Image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ImageSyncScreen displays summary counts, Export Image & Restore Image', (
      tester,
    ) async {
      final tempRoot = Directory.systemTemp.createTempSync('img_sync_ui_');
      addTearDown(() => tempRoot.deleteSync(recursive: true));
      final appDir = Directory(p.join(tempRoot.path, 'app'))..createSync();
      final publicDir = Directory(p.join(tempRoot.path, 'public'))..createSync();
      File(p.join(publicDir.path, 'old_receipt.jpg')).writeAsBytesSync([9, 8]);

      final bridge = _FakeImageFolderBridge(publicDir);
      final service = ImageSyncService.forTest(
        bridge: bridge,
        appDirOverride: appDir,
        transactionsLoader: () async => const [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(
              value: _StubTxProvider(),
            ),
          ],
          child: MaterialApp(home: ImageSyncScreen(service: service)),
        ),
      );
      for (var i = 0;
          i < 20 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
          i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        });
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Export & Restore Image'), findsOneWidget);
      expect(find.text('/sdcard/Pictures/SmartMoney'), findsOneWidget);
      expect(find.text('1 foto'), findsOneWidget);
      expect(find.text('Export Image'), findsNWidgets(2)); // Title + button
      expect(find.text('Restore Image'), findsNWidgets(2)); // Title + button
      expect(tester.takeException(), isNull);
    });
  });
}
