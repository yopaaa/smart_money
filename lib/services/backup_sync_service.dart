import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'database_helper.dart';
import 'google_drive_service.dart';

enum BackupSchedule {
  off('off', 'Mati (Manual)', Duration.zero),
  daily('daily', 'Harian', Duration(hours: 24)),
  weekly('weekly', 'Mingguan', Duration(days: 7)),
  monthly('monthly', 'Bulanan', Duration(days: 30));

  final String key;
  final String label;
  final Duration interval;

  const BackupSchedule(this.key, this.label, this.interval);

  static BackupSchedule fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return BackupSchedule.off;
  }
}

class BackupPackageResult {
  final Uint8List bytes;
  final int accountCount;
  final int transactionCount;
  final int receiptCount;

  const BackupPackageResult({
    required this.bytes,
    required this.accountCount,
    required this.transactionCount,
    required this.receiptCount,
  });
}

class DriveSyncResult {
  final DriveBackupFile file;
  final int newReceiptsUploaded;
  final int totalReceiptsSynced;

  const DriveSyncResult({
    required this.file,
    required this.newReceiptsUploaded,
    required this.totalReceiptsSynced,
  });
}

class BackupSyncConfig {
  final BackupSchedule schedule;
  final bool wifiOnly;
  final bool includeReceipts;
  final DateTime? lastBackupAt;
  final int? lastBackupSizeBytes;
  final DateTime? lastDataChangeAt;

  const BackupSyncConfig({
    required this.schedule,
    required this.wifiOnly,
    required this.includeReceipts,
    this.lastBackupAt,
    this.lastBackupSizeBytes,
    this.lastDataChangeAt,
  });
}

@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await BackupSyncService.instance.performBackgroundSyncTask();
    } catch (e) {
      debugPrint('Background backup task error: $e');
    }
    return true;
  });
}

class BackupSyncService {
  BackupSyncService._();
  static final BackupSyncService instance = BackupSyncService._();

  static const String uniqueWorkName = 'smart_money_gdrive_auto_backup';
  static const String workTaskName = 'gdrive_auto_backup';

  static const String settingScheduleKey = '@backup_schedule';
  static const String settingWifiOnlyKey = '@backup_wifi_only';
  static const String settingIncludeReceiptsKey = '@backup_include_receipts';
  static const String settingLastBackupAtKey = '@gdrive_last_backup_at';
  static const String settingLastBackupSizeKey = '@gdrive_last_backup_size';
  static const String settingLastDataChangeKey = '@backup_last_data_change_at';

  bool _workmanagerInitialized = false;
  bool _isSyncInProgress = false;

  Future<void> initializeWorkmanager() async {
    if (_workmanagerInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await Workmanager().initialize(backupCallbackDispatcher);
      _workmanagerInitialized = true;
    } catch (e) {
      debugPrint('BackupSyncService initializeWorkmanager error: $e');
    }
  }

  Future<BackupSyncConfig> loadConfig() async {
    try {
      final db = DatabaseHelper.instance;
      final scheduleRaw = await db.getSetting(settingScheduleKey);
      final wifiRaw = await db.getSetting(settingWifiOnlyKey);
      final receiptsRaw = await db.getSetting(settingIncludeReceiptsKey);
      final lastBackupRaw = await db.getSetting(settingLastBackupAtKey);
      final lastSizeRaw = await db.getSetting(settingLastBackupSizeKey);
      final lastChangeRaw = await db.getSetting(settingLastDataChangeKey);

      final lastBackupMs = int.tryParse(lastBackupRaw?.toString() ?? '');
      final lastChangeMs = int.tryParse(lastChangeRaw?.toString() ?? '');

      return BackupSyncConfig(
        schedule: BackupSchedule.fromKey(scheduleRaw?.toString()),
        wifiOnly: wifiRaw == null ? true : (wifiRaw == true || wifiRaw == 1),
        includeReceipts:
            receiptsRaw == null ? true : (receiptsRaw == true || receiptsRaw == 1),
        lastBackupAt: lastBackupMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs)
            : null,
        lastBackupSizeBytes: int.tryParse(lastSizeRaw?.toString() ?? ''),
        lastDataChangeAt: lastChangeMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastChangeMs)
            : null,
      );
    } catch (e) {
      debugPrint('BackupSyncService loadConfig error: $e');
      return const BackupSyncConfig(
        schedule: BackupSchedule.off,
        wifiOnly: true,
        includeReceipts: true,
      );
    }
  }

  Future<void> saveSchedule(
    BackupSchedule schedule, {
    required bool wifiOnly,
  }) async {
    await DatabaseHelper.instance.saveSetting(settingScheduleKey, schedule.key);
    await DatabaseHelper.instance.saveSetting(settingWifiOnlyKey, wifiOnly);
    await applyScheduleToWorkmanager(schedule, wifiOnly: wifiOnly);
  }

  Future<void> saveWifiOnly(
    bool wifiOnly, {
    required BackupSchedule currentSchedule,
  }) async {
    await DatabaseHelper.instance.saveSetting(settingWifiOnlyKey, wifiOnly);
    await applyScheduleToWorkmanager(currentSchedule, wifiOnly: wifiOnly);
  }

  Future<void> saveIncludeReceipts(bool includeReceipts) async {
    await DatabaseHelper.instance
        .saveSetting(settingIncludeReceiptsKey, includeReceipts);
  }

  Future<void> markDataChanged() async {
    try {
      await DatabaseHelper.instance.saveSetting(
        settingLastDataChangeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('BackupSyncService markDataChanged error: $e');
    }
  }

  Future<void> applyScheduleToWorkmanager(
    BackupSchedule schedule, {
    required bool wifiOnly,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await initializeWorkmanager();
      if (schedule == BackupSchedule.off) {
        await Workmanager().cancelByUniqueName(uniqueWorkName);
        return;
      }

      await Workmanager().registerPeriodicTask(
        uniqueWorkName,
        workTaskName,
        frequency: schedule.interval,
        initialDelay: const Duration(minutes: 15),
        constraints: Constraints(
          networkType:
              wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
    } catch (e) {
      debugPrint('BackupSyncService applyScheduleToWorkmanager error: $e');
    }
  }

  /// Packs SQLite DB + metadata.json (plus optional embedded receipt photos
  /// for portable local .smbak sharing).
  Future<BackupPackageResult> createBackupPackage({
    bool includeReceipts = true,
    bool embedReceiptsInZip = true,
  }) async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'smart_money.db'));
    if (!await dbFile.exists()) {
      throw Exception('Database file belum tersedia.');
    }

    final db = await DatabaseHelper.instance.database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    final dbBytes = await dbFile.readAsBytes();
    final accounts = await DatabaseHelper.instance.getAccounts();
    final transactions = await DatabaseHelper.instance.getTransactions();

    final archive = Archive();
    archive.addFile(ArchiveFile('smart_money.db', dbBytes.length, dbBytes));

    int receiptCount = 0;
    final addedNames = <String>{};

    if (includeReceipts) {
      for (final tx in transactions) {
        final imgPath = tx.img?.trim() ?? '';
        if (imgPath.isEmpty) continue;
        final file = File(imgPath);
        if (!await file.exists()) continue;

        final fileName = p.basename(imgPath);
        if (addedNames.contains(fileName)) continue;

        if (embedReceiptsInZip) {
          final imgBytes = await file.readAsBytes();
          archive.addFile(
            ArchiveFile('receipts/$fileName', imgBytes.length, imgBytes),
          );
        }
        addedNames.add(fileName);
        receiptCount++;
      }
    }

    final metadataJson = utf8.encode(
      jsonEncode({
        'formatVersion': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'accountCount': accounts.length,
        'transactionCount': transactions.length,
        'receiptCount': receiptCount,
        'includeReceipts': includeReceipts,
        'incrementalReceipts': !embedReceiptsInZip,
      }),
    );
    archive.addFile(
      ArchiveFile('metadata.json', metadataJson.length, metadataJson),
    );

    final encoded = ZipEncoder().encode(archive);
    return BackupPackageResult(
      bytes: Uint8List.fromList(encoded),
      accountCount: accounts.length,
      transactionCount: transactions.length,
      receiptCount: receiptCount,
    );
  }

  /// Restores from either a v2 ZIP backup bundle (.smbak/.zip) or a legacy raw
  /// SQLite backup file (.smbak/.db/.sqlite).
  Future<void> restoreFromBackupBytes(Uint8List bytes) async {
    if (bytes.length < 4) {
      throw const FormatException('File backup rusak atau terlalu kecil.');
    }

    final isZip = bytes[0] == 0x50 && bytes[1] == 0x4B; // 'PK'
    final isSqlite = bytes.length >= 15 &&
        ascii.decode(bytes.sublist(0, 15), allowInvalid: true) ==
            'SQLite format 3';

    if (!isZip && !isSqlite) {
      throw const FormatException(
        'Format file backup tidak dikenali (harus .smbak, .zip, .db, atau .sqlite).',
      );
    }

    final dbPath = await getDatabasesPath();
    final targetDbPath = p.join(dbPath, 'smart_money.db');

    if (isSqlite) {
      await _replaceDatabaseFile(targetDbPath, bytes);
      await DatabaseHelper.instance.database;
      return;
    }

    // ZIP Archive v2 restore
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? dbEntry;
    final receiptEntries = <ArchiveFile>[];

    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.name == 'smart_money.db' ||
          p.basename(file.name) == 'smart_money.db') {
        dbEntry = file;
      } else if (file.name.startsWith('receipts/')) {
        receiptEntries.add(file);
      }
    }

    if (dbEntry == null) {
      throw const FormatException(
        'Arsip backup tidak berisi file smart_money.db.',
      );
    }

    final dbContent = dbEntry.content as List<int>;
    await _replaceDatabaseFile(targetDbPath, Uint8List.fromList(dbContent));

    // Restore receipt photos into new device's ApplicationDocumentsDirectory
    if (receiptEntries.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final restoredReceiptPaths = <String, String>{};

      for (final entry in receiptEntries) {
        final baseName = p.basename(entry.name);
        if (baseName.isEmpty) continue;
        final targetImgFile = File(p.join(appDir.path, baseName));
        await targetImgFile.writeAsBytes(
          entry.content as List<int>,
          flush: true,
        );
        restoredReceiptPaths[baseName] = targetImgFile.path;
      }

      // Remap transaction img paths in restored SQLite DB
      final db = await DatabaseHelper.instance.database;
      final txs = await DatabaseHelper.instance.getTransactions();
      final batch = db.batch();
      for (final tx in txs) {
        final oldImg = tx.img?.trim() ?? '';
        if (oldImg.isEmpty) continue;
        final baseName = p.basename(oldImg);
        final newPath = restoredReceiptPaths[baseName];
        if (newPath != null && newPath != oldImg) {
          batch.update(
            DatabaseHelper.transactionTableName,
            {'img': newPath},
            where: 'id = ?',
            whereArgs: [tx.id],
          );
        }
      }
      await batch.commit(noResult: true);
    } else {
      await DatabaseHelper.instance.database;
    }
  }

  Future<void> _replaceDatabaseFile(String targetDbPath, Uint8List bytes) async {
    await DatabaseHelper.instance.closeAndReset();

    final walFile = File('$targetDbPath-wal');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
    final shmFile = File('$targetDbPath-shm');
    if (await shmFile.exists()) {
      try {
        await shmFile.delete();
      } catch (_) {}
    }

    await File(targetDbPath).writeAsBytes(bytes, flush: true);
  }

  /// Computes which unique local receipt filenames are missing from Drive.
  List<String> findMissingReceiptNames({
    required Iterable<String> localReceiptPaths,
    required Map<String, String> remoteSyncedReceipts,
  }) {
    final missing = <String>[];
    final seen = <String>{};
    for (final path in localReceiptPaths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      final baseName = p.basename(trimmed);
      if (baseName.isEmpty || seen.contains(baseName)) continue;
      seen.add(baseName);
      if (!remoteSyncedReceipts.containsKey(baseName)) {
        missing.add(baseName);
      }
    }
    return missing;
  }

  String _imageMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Incrementally uploads only NEW receipt photos that do not exist in Drive yet.
  Future<({int newUploaded, int totalLocal})> syncReceiptsIncrementally({
    required bool interactive,
  }) async {
    final transactions = await DatabaseHelper.instance.getTransactions();
    final Map<String, File> localFilesByName = {};

    for (final tx in transactions) {
      final imgPath = tx.img?.trim() ?? '';
      if (imgPath.isEmpty) continue;
      final fileName = p.basename(imgPath);
      if (fileName.isEmpty || localFilesByName.containsKey(fileName)) continue;
      final file = File(imgPath);
      if (await file.exists()) {
        localFilesByName[fileName] = file;
      }
    }

    if (localFilesByName.isEmpty) {
      return (newUploaded: 0, totalLocal: 0);
    }

    final remoteReceipts = await GoogleDriveService.instance
        .listSyncedReceipts(interactive: interactive);
    final missingNames = findMissingReceiptNames(
      localReceiptPaths: localFilesByName.keys,
      remoteSyncedReceipts: remoteReceipts,
    );

    int uploadedCount = 0;
    for (final baseName in missingNames) {
      final file = localFilesByName[baseName];
      if (file == null) continue;
      final imgBytes = await file.readAsBytes();
      await GoogleDriveService.instance.uploadBackupBytes(
        bytes: imgBytes,
        fileName: 'receipt_sync_$baseName',
        mimeType: _imageMimeType(baseName),
        pruneOldSnapshots: false,
        interactive: interactive,
        appProperties: {
          'kind': 'receipt',
          'receiptName': baseName,
        },
      );
      uploadedCount++;
    }

    return (newUploaded: uploadedCount, totalLocal: localFilesByName.length);
  }

  /// Syncs only new receipt photos incrementally, then uploads a lightweight
  /// DB snapshot to Google Drive appDataFolder.
  Future<DriveSyncResult> backupToGoogleDrive({
    bool includeReceipts = true,
    bool interactive = true,
  }) async {
    int newReceiptsUploaded = 0;
    int totalReceiptsSynced = 0;

    if (includeReceipts) {
      final syncRes =
          await syncReceiptsIncrementally(interactive: interactive);
      newReceiptsUploaded = syncRes.newUploaded;
      totalReceiptsSynced = syncRes.totalLocal;
    }

    // Only package DB + metadata for Drive (photos are already synced separately!)
    final package = await createBackupPackage(
      includeReceipts: includeReceipts,
      embedReceiptsInZip: false,
    );
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = 'smart_money_backup_$dateStr.smbak';

    final uploaded = await GoogleDriveService.instance.uploadBackupBytes(
      bytes: package.bytes,
      fileName: fileName,
      mimeType: 'application/zip',
      pruneOldSnapshots: true,
      interactive: interactive,
      appProperties: {
        'kind': 'db_snapshot',
        'accountCount': package.accountCount.toString(),
        'transactionCount': package.transactionCount.toString(),
        'receiptCount': package.receiptCount.toString(),
        'newReceiptsUploaded': newReceiptsUploaded.toString(),
      },
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await DatabaseHelper.instance.saveSetting(settingLastBackupAtKey, nowMs);
    await DatabaseHelper.instance
        .saveSetting(settingLastBackupSizeKey, package.bytes.length);

    return DriveSyncResult(
      file: uploaded,
      newReceiptsUploaded: newReceiptsUploaded,
      totalReceiptsSynced: totalReceiptsSynced,
    );
  }

  /// Downloads a DB snapshot from Google Drive, restores SQLite, and downloads
  /// any missing receipt photos referenced by the restored transactions.
  Future<void> restoreFromGoogleDriveSnapshot(
    String fileId, {
    bool interactive = true,
  }) async {
    final bytes = await GoogleDriveService.instance.downloadBackup(
      fileId,
      interactive: interactive,
    );
    await restoreFromBackupBytes(bytes);

    final txs = await DatabaseHelper.instance.getTransactions();
    final neededByBasename = <String, List<String>>{};
    for (final tx in txs) {
      final img = tx.img?.trim() ?? '';
      if (img.isEmpty) continue;
      if (File(img).existsSync()) continue;
      final base = p.basename(img);
      if (base.isEmpty) continue;
      neededByBasename.putIfAbsent(base, () => []).add(tx.id);
    }

    if (neededByBasename.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final remoteReceipts = await GoogleDriveService.instance
        .listSyncedReceipts(interactive: interactive);

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    bool hasPathUpdates = false;

    for (final entry in neededByBasename.entries) {
      final baseName = entry.key;
      final localTarget = File(p.join(appDir.path, baseName));

      if (!await localTarget.exists()) {
        final remoteFileId = remoteReceipts[baseName];
        if (remoteFileId == null) continue;
        try {
          final imgBytes = await GoogleDriveService.instance.downloadBackup(
            remoteFileId,
            interactive: interactive,
          );
          await localTarget.writeAsBytes(imgBytes, flush: true);
        } catch (e) {
          debugPrint('Failed downloading synced receipt $baseName: $e');
          continue;
        }
      }

      for (final txId in entry.value) {
        batch.update(
          DatabaseHelper.transactionTableName,
          {'img': localTarget.path},
          where: 'id = ?',
          whereArgs: [txId],
        );
        hasPathUpdates = true;
      }
    }

    if (hasPathUpdates) {
      await batch.commit(noResult: true);
    }
  }

  /// Returns true when a scheduled backup interval has elapsed since the last
  /// successful backup AND (if known) data changed after that backup.
  bool isBackupDue(BackupSyncConfig config, {DateTime? now}) {
    if (config.schedule == BackupSchedule.off) return false;
    final current = now ?? DateTime.now();
    final lastBackup = config.lastBackupAt;
    if (lastBackup == null) return true;

    final elapsed = current.difference(lastBackup);
    if (elapsed < config.schedule.interval) return false;

    final lastChange = config.lastDataChangeAt;
    if (lastChange != null && !lastChange.isAfter(lastBackup)) {
      // No local data changed since the last backup
      return false;
    }

    return true;
  }

  /// Runs silently in foreground on app launch/resume or after data mutations
  /// when a scheduled backup is due and user is connected to Google.
  Future<bool> syncIfDue({bool interactive = false}) async {
    if (_isSyncInProgress) return false;
    _isSyncInProgress = true;
    try {
      final profile = await GoogleDriveService.instance.getSavedProfile();
      if (profile == null) return false;

      final config = await loadConfig();
      if (!isBackupDue(config)) return false;

      await backupToGoogleDrive(
        includeReceipts: config.includeReceipts,
        interactive: interactive,
      );
      return true;
    } catch (e) {
      debugPrint('BackupSyncService syncIfDue skipped/failed: $e');
      return false;
    } finally {
      _isSyncInProgress = false;
    }
  }

  /// Executed by Android WorkManager in a background isolate.
  Future<void> performBackgroundSyncTask() async {
    final profile = await GoogleDriveService.instance.trySilentSignIn();
    if (profile == null) return;

    final config = await loadConfig();
    if (!isBackupDue(config)) return;

    await backupToGoogleDrive(
      includeReceipts: config.includeReceipts,
      interactive: false,
    );
  }
}
