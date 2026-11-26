import 'package:flutter/material.dart';
import '../services/backup_sync_service.dart';
import '../services/google_drive_service.dart';
import 'transaction_provider.dart';

class BackupProvider extends ChangeNotifier {
  GoogleAccountProfile? _account;
  String? _serverClientId;
  BackupSchedule _schedule = BackupSchedule.off;
  bool _wifiOnly = true;
  bool _includeReceipts = true;
  DateTime? _lastBackupAt;
  int? _lastBackupSizeBytes;
  List<DriveBackupFile> _driveBackups = [];

  bool _isInitialized = false;
  bool _isSigningIn = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingDriveList = false;

  GoogleAccountProfile? get account => _account;
  bool get isSignedIn => _account != null;
  String? get serverClientId => _serverClientId;
  BackupSchedule get schedule => _schedule;
  bool get wifiOnly => _wifiOnly;
  bool get includeReceipts => _includeReceipts;
  DateTime? get lastBackupAt => _lastBackupAt;
  int? get lastBackupSizeBytes => _lastBackupSizeBytes;
  List<DriveBackupFile> get driveBackups => _driveBackups;

  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get isLoadingDriveList => _isLoadingDriveList;

  BackupProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadSettings();
    }
  }

  Future<void> loadSettings() async {
    try {
      final config = await BackupSyncService.instance.loadConfig();
      _schedule = config.schedule;
      _wifiOnly = config.wifiOnly;
      _includeReceipts = config.includeReceipts;
      _lastBackupAt = config.lastBackupAt;
      _lastBackupSizeBytes = config.lastBackupSizeBytes;

      _serverClientId = await GoogleDriveService.instance.getServerClientId();
      _account = await GoogleDriveService.instance.getSavedProfile();

      if (_account != null) {
        // Attempt silent refresh of profile & schedule WorkManager
        _account = await GoogleDriveService.instance.trySilentSignIn() ??
            _account;
        if (_schedule != BackupSchedule.off) {
          await BackupSyncService.instance.applyScheduleToWorkmanager(
            _schedule,
            wifiOnly: _wifiOnly,
          );
          await syncIfDue();
        }
      }
    } catch (e) {
      debugPrint('BackupProvider loadSettings error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> saveServerClientId(String clientId) async {
    await GoogleDriveService.instance.saveServerClientId(clientId);
    _serverClientId = await GoogleDriveService.instance.getServerClientId();
    notifyListeners();
  }

  Future<GoogleAccountProfile> signIn() async {
    _isSigningIn = true;
    notifyListeners();
    try {
      final profile = await GoogleDriveService.instance.signInInteractive();
      _account = profile;
      notifyListeners();
      await refreshDriveBackups(interactive: false);
      return profile;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await GoogleDriveService.instance.signOut();
    _account = null;
    _driveBackups = [];
    notifyListeners();
  }

  Future<void> setSchedule(BackupSchedule newSchedule) async {
    _schedule = newSchedule;
    notifyListeners();
    await BackupSyncService.instance.saveSchedule(
      newSchedule,
      wifiOnly: _wifiOnly,
    );
    if (newSchedule != BackupSchedule.off && _account != null) {
      await syncIfDue();
    }
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    notifyListeners();
    await BackupSyncService.instance.saveWifiOnly(
      value,
      currentSchedule: _schedule,
    );
  }

  Future<void> setIncludeReceipts(bool value) async {
    _includeReceipts = value;
    notifyListeners();
    await BackupSyncService.instance.saveIncludeReceipts(value);
  }

  Future<DriveSyncResult> backupToDriveNow() async {
    if (_isBackingUp) {
      throw Exception('Proses backup sedang berjalan.');
    }
    _isBackingUp = true;
    notifyListeners();

    try {
      _account ??= await GoogleDriveService.instance.signInInteractive();
      final result = await BackupSyncService.instance.backupToGoogleDrive(
        includeReceipts: _includeReceipts,
        interactive: true,
      );
      final config = await BackupSyncService.instance.loadConfig();
      _lastBackupAt = config.lastBackupAt ?? DateTime.now();
      _lastBackupSizeBytes =
          config.lastBackupSizeBytes ?? result.file.sizeBytes;

      await refreshDriveBackups(interactive: false);
      return result;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  Future<void> refreshDriveBackups({bool interactive = true}) async {
    if (_account == null) return;
    _isLoadingDriveList = true;
    notifyListeners();
    try {
      _driveBackups = await GoogleDriveService.instance.listBackups(
        interactive: interactive,
      );
    } catch (e) {
      debugPrint('BackupProvider refreshDriveBackups error: $e');
      if (interactive) rethrow;
    } finally {
      _isLoadingDriveList = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromDrive(
    String fileId,
    TransactionProvider txProvider,
  ) async {
    _isRestoring = true;
    notifyListeners();
    try {
      await BackupSyncService.instance.restoreFromGoogleDriveSnapshot(
        fileId,
        interactive: true,
      );
      await txProvider.loadData();
      await loadSettings();
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> deleteDriveBackup(String fileId) async {
    await GoogleDriveService.instance.deleteBackup(fileId, interactive: true);
    _driveBackups.removeWhere((b) => b.id == fileId);
    notifyListeners();
  }

  Future<bool> syncIfDue() async {
    final synced = await BackupSyncService.instance.syncIfDue();
    if (synced) {
      final config = await BackupSyncService.instance.loadConfig();
      _lastBackupAt = config.lastBackupAt;
      _lastBackupSizeBytes = config.lastBackupSizeBytes;
      notifyListeners();
    }
    return synced;
  }
}
