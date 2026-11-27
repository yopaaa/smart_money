import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import 'backup_sync_service.dart';
import 'database_helper.dart';

class PublicImageEntry {
  final String name;
  final String uri;
  final String path;

  const PublicImageEntry({
    required this.name,
    this.uri = '',
    this.path = '',
  });
}

class ImageSyncSummary {
  final int localReceiptCount;
  final int publicFolderCount;
  final int pendingExportCount;
  final int pendingRestoreCount;

  const ImageSyncSummary({
    required this.localReceiptCount,
    required this.publicFolderCount,
    required this.pendingExportCount,
    required this.pendingRestoreCount,
  });
}

class ImageSyncResult {
  final int copied;
  final int skipped;
  final int failed;
  final int remappedTransactions;

  const ImageSyncResult({
    required this.copied,
    required this.skipped,
    required this.failed,
    this.remappedTransactions = 0,
  });
}

/// Abstracts platform folder access so unit tests can run without Android MediaStore.
abstract class ImageFolderBridge {
  Future<bool> ensurePermission();
  Future<List<PublicImageEntry>> listPublicImages(String relativePath);
  Future<String> exportToPublicFolder({
    required String sourcePath,
    required String fileName,
    required String relativePath,
  });
  Future<bool> copyPublicImageToLocal({
    required PublicImageEntry entry,
    required String destPath,
  });
}

class _MethodChannelImageFolderBridge implements ImageFolderBridge {
  static const MethodChannel _channel =
      MethodChannel('com.nlabs.smartmoney/image_sync');

  @override
  Future<bool> ensurePermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final granted =
        await _channel.invokeMethod<bool>('ensureStoragePermission');
    return granted ?? false;
  }

  @override
  Future<List<PublicImageEntry>> listPublicImages(String relativePath) async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'listFolderImages',
      {'relativePath': relativePath},
    );
    if (raw == null) return const [];
    final entries = <PublicImageEntry>[];
    for (final item in raw) {
      if (item is Map) {
        final name = item['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        entries.add(
          PublicImageEntry(
            name: name,
            uri: item['uri']?.toString() ?? '',
            path: item['path']?.toString() ?? '',
          ),
        );
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
    if (kIsWeb || !Platform.isAndroid) return 'failed';
    final status = await _channel.invokeMethod<String>(
      'exportImageToPublicFolder',
      {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'relativePath': relativePath,
      },
    );
    return status ?? 'failed';
  }

  @override
  Future<bool> copyPublicImageToLocal({
    required PublicImageEntry entry,
    required String destPath,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>(
      'copyPublicImageToLocal',
      {
        'uri': entry.uri,
        'path': entry.path,
        'destPath': destPath,
      },
    );
    return ok ?? false;
  }
}

class ImageSyncService {
  ImageSyncService._({
    ImageFolderBridge? bridge,
    Directory? appDirOverride,
    Future<List<TransactionModel>> Function()? transactionsLoader,
  }) : _bridge = bridge ?? _MethodChannelImageFolderBridge(),
       _defaultAppDirOverride = appDirOverride,
       _transactionsLoader = transactionsLoader;

  static final ImageSyncService instance = ImageSyncService._();

  @visibleForTesting
  factory ImageSyncService.forTest({
    required ImageFolderBridge bridge,
    Directory? appDirOverride,
    Future<List<TransactionModel>> Function()? transactionsLoader,
  }) {
    return ImageSyncService._(
      bridge: bridge,
      appDirOverride: appDirOverride,
      transactionsLoader: transactionsLoader,
    );
  }

  static const String publicRelativePath = 'Pictures/SmartMoney';
  static const String displayFolderPath = '/sdcard/Pictures/SmartMoney';

  final ImageFolderBridge _bridge;
  final Directory? _defaultAppDirOverride;
  final Future<List<TransactionModel>> Function()? _transactionsLoader;

  /// Extracts a clean filename from local paths, legacy paths, or `file://` URIs.
  static String extractFileName(String? rawPath) {
    final trimmed = rawPath?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('file://')) {
      final parsed = Uri.tryParse(trimmed);
      if (parsed != null && parsed.path.isNotEmpty) {
        return p.basename(Uri.decodeFull(parsed.path));
      }
    }
    return p.basename(trimmed);
  }

  static bool isSupportedImageFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.webp' ||
        ext == '.heic';
  }

  Future<Directory> _resolveAppDir({Directory? overrideDir}) async {
    if (overrideDir != null) return overrideDir;
    if (_defaultAppDirOverride != null) return _defaultAppDirOverride;
    return getApplicationDocumentsDirectory();
  }

  Future<List<TransactionModel>> _loadTransactions(
    List<TransactionModel>? overrideTxs,
  ) async {
    if (overrideTxs != null) return overrideTxs;
    if (_transactionsLoader != null) return _transactionsLoader();
    return DatabaseHelper.instance.getTransactions();
  }

  /// Collects unique receipt files present locally (referenced by transactions
  /// or already stored in appDir).
  Future<Map<String, File>> collectLocalReceipts({
    required List<TransactionModel> transactions,
    required Directory appDir,
  }) async {
    final map = <String, File>{};

    for (final tx in transactions) {
      final raw = tx.img?.trim() ?? '';
      if (raw.isEmpty) continue;
      final name = extractFileName(raw);
      if (name.isEmpty || map.containsKey(name)) continue;

      final directFile = File(raw);
      if (await directFile.exists()) {
        map[name] = directFile;
        continue;
      }

      final appFile = File(p.join(appDir.path, name));
      if (await appFile.exists()) {
        map[name] = appFile;
      }
    }

    if (await appDir.exists()) {
      await for (final entity in appDir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (isSupportedImageFile(name) && !map.containsKey(name)) {
            map[name] = entity;
          }
        }
      }
    }

    return map;
  }

  Future<ImageSyncSummary> getSummary({
    List<TransactionModel>? transactionsOverride,
    Directory? appDirOverride,
    bool requestPermission = false,
  }) async {
    final appDir = await _resolveAppDir(overrideDir: appDirOverride);
    final transactions = await _loadTransactions(transactionsOverride);

    final localReceipts = await collectLocalReceipts(
      transactions: transactions,
      appDir: appDir,
    );

    List<PublicImageEntry> publicImages = const [];
    if (requestPermission) {
      final granted = await _bridge.ensurePermission();
      if (granted) {
        publicImages = await _bridge.listPublicImages(publicRelativePath);
      }
    } else {
      try {
        publicImages = await _bridge.listPublicImages(publicRelativePath);
      } catch (_) {}
    }

    final localNames = localReceipts.keys.toSet();
    final publicNames = publicImages.map((e) => e.name).toSet();

    final pendingExport = localNames.difference(publicNames).length;
    final pendingRestore = publicNames.difference(localNames).length;

    return ImageSyncSummary(
      localReceiptCount: localNames.length,
      publicFolderCount: publicNames.length,
      pendingExportCount: pendingExport,
      pendingRestoreCount: pendingRestore,
    );
  }

  /// Incrementally exports local receipt images to `/sdcard/Pictures/SmartMoney`.
  Future<ImageSyncResult> exportToPublicFolder({
    List<TransactionModel>? transactionsOverride,
    Directory? appDirOverride,
  }) async {
    final granted = await _bridge.ensurePermission();
    if (!granted) {
      throw Exception(
        'Izin akses foto/penyimpanan ditolak. Aktifkan izin Media/Photos terlebih dahulu.',
      );
    }

    final appDir = await _resolveAppDir(overrideDir: appDirOverride);
    final transactions = await _loadTransactions(transactionsOverride);

    final localReceipts = await collectLocalReceipts(
      transactions: transactions,
      appDir: appDir,
    );

    final publicImages = await _bridge.listPublicImages(publicRelativePath);
    final existingPublicNames = publicImages.map((e) => e.name).toSet();

    int copied = 0;
    int skipped = 0;
    int failed = 0;

    for (final entry in localReceipts.entries) {
      if (existingPublicNames.contains(entry.key)) {
        skipped++;
        continue;
      }
      try {
        final status = await _bridge.exportToPublicFolder(
          sourcePath: entry.value.path,
          fileName: entry.key,
          relativePath: publicRelativePath,
        );
        if (status == 'exported') {
          copied++;
          existingPublicNames.add(entry.key);
        } else if (status == 'skipped') {
          skipped++;
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint('ImageSyncService export error (${entry.key}): $e');
        failed++;
      }
    }

    return ImageSyncResult(
      copied: copied,
      skipped: skipped,
      failed: failed,
    );
  }

  /// Incrementally restores images from `/sdcard/Pictures/SmartMoney` into
  /// the app's internal directory and remaps `transactions.img` paths.
  Future<ImageSyncResult> restoreFromPublicFolder({
    Directory? appDirOverride,
  }) async {
    final granted = await _bridge.ensurePermission();
    if (!granted) {
      throw Exception(
        'Izin akses foto/penyimpanan ditolak. Aktifkan izin Media/Photos terlebih dahulu.',
      );
    }

    final publicImages = await _bridge.listPublicImages(publicRelativePath);
    return _restoreEntriesToInternal(
      entries: publicImages,
      appDirOverride: appDirOverride,
    );
  }

  /// Restores receipt images from any user-picked local directory into internal
  /// app storage and remaps `transactions.img` paths.
  Future<ImageSyncResult> restoreFromDirectory(
    String directoryPath, {
    Directory? appDirOverride,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception('Folder tidak ditemukan: $directoryPath');
    }

    final entries = <PublicImageEntry>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (isSupportedImageFile(name)) {
          entries.add(PublicImageEntry(name: name, path: entity.path));
        }
      }
    }

    return _restoreEntriesToInternal(
      entries: entries,
      appDirOverride: appDirOverride,
      directFileCopy: true,
    );
  }

  Future<ImageSyncResult> _restoreEntriesToInternal({
    required List<PublicImageEntry> entries,
    Directory? appDirOverride,
    bool directFileCopy = false,
  }) async {
    final appDir = await _resolveAppDir(overrideDir: appDirOverride);
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    int copied = 0;
    int skipped = 0;
    int failed = 0;

    for (final entry in entries) {
      if (entry.name.isEmpty || !isSupportedImageFile(entry.name)) continue;
      final destPath = p.join(appDir.path, entry.name);
      final destFile = File(destPath);
      if (await destFile.exists()) {
        skipped++;
        continue;
      }

      try {
        bool ok = false;
        if (directFileCopy && entry.path.isNotEmpty) {
          final srcFile = File(entry.path);
          if (await srcFile.exists()) {
            await srcFile.copy(destPath);
            ok = true;
          }
        } else {
          ok = await _bridge.copyPublicImageToLocal(
            entry: entry,
            destPath: destPath,
          );
        }

        if (ok) {
          copied++;
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint('ImageSyncService restore error (${entry.name}): $e');
        failed++;
      }
    }

    final remapped = await remapTransactionImagesToAppDir(appDir: appDir);

    if (copied > 0 || remapped > 0) {
      await BackupSyncService.instance.markDataChanged();
    }

    return ImageSyncResult(
      copied: copied,
      skipped: skipped,
      failed: failed,
      remappedTransactions: remapped,
    );
  }

  /// Updates `transactions.img` rows whose filename exists inside [appDir] so
  /// migrated databases from old apps (`com.koucheng.smartmoney` / `.smbak`)
  /// immediately link to the restored internal image files.
  Future<int> remapTransactionImagesToAppDir({
    required Directory appDir,
  }) async {
    if (!await appDir.exists()) return 0;

    final availableByName = <String, String>{};
    await for (final entity in appDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        availableByName[name] = entity.path;
      }
    }

    if (availableByName.isEmpty) return 0;

    final db = await DatabaseHelper.instance.database;
    final transactions = await DatabaseHelper.instance.getTransactions();
    final batch = db.batch();
    int remapped = 0;

    for (final tx in transactions) {
      final oldImg = tx.img?.trim() ?? '';
      if (oldImg.isEmpty) continue;
      final baseName = extractFileName(oldImg);
      final targetPath = availableByName[baseName];
      if (targetPath != null && targetPath != oldImg) {
        batch.update(
          DatabaseHelper.transactionTableName,
          {'img': targetPath},
          where: 'id = ?',
          whereArgs: [tx.id],
        );
        remapped++;
      }
    }

    if (remapped > 0) {
      await batch.commit(noResult: true);
    }

    return remapped;
  }
}
