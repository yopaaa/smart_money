import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../providers/backup_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/backup_sync_service.dart';
import '../../services/google_drive_service.dart';

String _formatSnapshotBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '-';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Shared local `.smbak` / `.zip` / `.db` / `.sqlite` file picker and restore helper.
Future<bool> restoreFromLocalBackupFile({
  required BuildContext context,
  required TransactionProvider? txProvider,
  BackupProvider? backupProvider,
  bool confirmOverwrite = true,
}) async {
  if (confirmOverwrite) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
          'Restoring will replace all current data with the backup file. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  try {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty || files.first.path == null) {
      return false;
    }

    final pickedPath = files.first.path!;
    final lowerPath = pickedPath.toLowerCase();
    if (!lowerPath.endsWith('.smbak') &&
        !lowerPath.endsWith('.zip') &&
        !lowerPath.endsWith('.db') &&
        !lowerPath.endsWith('.sqlite')) {
      throw Exception('File harus berformat .smbak, .zip, .db, atau .sqlite');
    }

    final bytes = await File(pickedPath).readAsBytes();
    await BackupSyncService.instance.restoreFromBackupBytes(bytes);

    await txProvider?.loadData();
    await backupProvider?.loadSettings();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully!'),
          backgroundColor: AppColors.income,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
    return false;
  }
}

/// Shows the Google Drive `appDataFolder` snapshot picker and handles restore.
/// Intended for initial onboarding / fresh installs so existing live data is
/// not accidentally overwritten from Settings.
Future<bool> showGoogleDriveRestoreSheet({
  required BuildContext context,
  required BackupProvider backup,
  required TransactionProvider txProvider,
}) async {
  try {
    await backup.refreshDriveBackups(interactive: true);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  var restored = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final backups = backup.driveBackups;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Riwayat Backup di Google Drive',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Disimpan aman di App Data Folder (${backups.length}/${GoogleDriveService.maxRetainedBackups} snapshot)',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  if (backups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Belum ada file backup di Google Drive.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: backups.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final item = backups[idx];
                          final dateText = DateFormat('dd MMM yyyy, HH:mm')
                              .format(item.createdTime);
                          final metaParts = <String>[
                            _formatSnapshotBytes(item.sizeBytes),
                            if (item.transactionCount > 0)
                              '${item.transactionCount} tx',
                            if (item.receiptCount > 0)
                              '${item.receiptCount} foto',
                          ];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(
                                Icons.cloud_done_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              dateText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              metaParts.join(' • '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await backup.deleteDriveBackup(item.id);
                                    setSheetState(() {});
                                  },
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(sheetCtx);
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text(
                                          'Restore dari Google Drive?',
                                        ),
                                        content: Text(
                                          'Semua data lokal saat ini akan diganti dengan backup tanggal $dateText.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, false),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(dCtx, true),
                                            child: const Text('Restore'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true && context.mounted) {
                                      try {
                                        await backup.restoreFromDrive(
                                          item.id,
                                          txProvider,
                                        );
                                        restored = true;
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Data berhasil dipulihkan dari Google Drive!',
                                              ),
                                              backgroundColor: AppColors.income,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Gagal restore: $e',
                                              ),
                                              backgroundColor:
                                                  AppColors.expense,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Restore',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return restored;
}
