import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../providers/backup_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/backup_sync_service.dart';
import '../../services/database_helper.dart';
import 'drive_restore_sheet.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBackingUpLocal = false;
  bool _isRestoringLocal = false;

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleLocalBackup(BackupProvider? backupProvider) async {
    setState(() => _isBackingUpLocal = true);
    try {
      final includeReceipts = backupProvider?.includeReceipts ?? true;
      final pkg = await BackupSyncService.instance.createBackupPackage(
        includeReceipts: includeReceipts,
      );

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupFileName = 'smart_money_backup_$dateStr.smbak';
      final backupFile = File(p.join(tempDir.path, backupFileName));
      await backupFile.writeAsBytes(pkg.bytes, flush: true);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Smart Money Backup ($dateStr)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup dibuat (${pkg.transactionCount} transaksi, ${pkg.receiptCount} foto struk)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUpLocal = false);
    }
  }

  Future<void> _handleLocalRestore(BackupProvider? backupProvider) async {
    setState(() => _isRestoringLocal = true);
    try {
      await restoreFromLocalBackupFile(
        context: context,
        txProvider: context.read<TransactionProvider>(),
        backupProvider: backupProvider,
        confirmOverwrite: true,
      );
    } finally {
      if (mounted) setState(() => _isRestoringLocal = false);
    }
  }

  Future<void> _handleGoogleBackupNow(BackupProvider backup) async {
    try {
      final res = await backup.backupToDriveNow();
      if (mounted) {
        final photoInfo = backup.includeReceipts
            ? ', ${res.newReceiptsUploaded} foto baru diunggah (${res.totalReceiptsSynced} tersinkron)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil backup DB (${_formatBytes(res.file.sizeBytes)}$photoInfo)',
            ),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _handleSyncBalances() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<TransactionProvider>();
    try {
      await DatabaseHelper.instance.recalculateAccountBalances();
      await provider.loadData();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Saldo akun berhasil disinkronkan dengan riwayat transaksi!',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal sinkronisasi saldo: $e')),
        );
      }
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will permanently delete all accounts, transactions, and categories. Continue?',
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
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.resetAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = Provider.of<BackupProvider?>(context);
    final profile = backup?.account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'sync') _handleSyncBalances();
              if (val == 'reset') _handleReset();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync',
                child: Text('Sinkronkan Saldo Akun'),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Text(
                  'Reset App Data',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Google Drive Backup & Auto-Sync Card
            if (backup != null) ...[
              Material(
                color: theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.add_to_drive_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Drive Backup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (profile == null) ...[
                      const Text(
                        'Hubungkan akun Google Anda untuk menyimpan backup otomatis ke Google Drive beserta foto struk transaksi.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: backup.isSigningIn
                              ? null
                              : () async {
                                  try {
                                    await backup.signIn();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Terhubung sebagai ${backup.account?.email ?? ''}',
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
                                          content: Text('$e'),
                                          backgroundColor: AppColors.expense,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: backup.isSigningIn
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            backup.isSigningIn
                                ? 'Menghubungkan...'
                                : 'Hubungkan Akun Google',
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.15),
                              backgroundImage: (profile.photoUrl != null &&
                                      profile.photoUrl!.isNotEmpty)
                                  ? NetworkImage(profile.photoUrl!)
                                  : null,
                              child: (profile.photoUrl == null ||
                                      profile.photoUrl!.isEmpty)
                                  ? Text(
                                      profile.displayName[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    backup.lastBackupAt != null
                                        ? 'Terakhir: ${DateFormat('dd MMM yyyy, HH:mm').format(backup.lastBackupAt!)} (${_formatBytes(backup.lastBackupSizeBytes)})'
                                        : 'Belum pernah backup ke Drive',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: (backup.isBackingUp || backup.isRestoring)
                              ? null
                              : () => _handleGoogleBackupNow(backup),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: backup.isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            backup.isBackingUp
                                ? 'Mengunggah...'
                                : 'Backup ke Google Drive',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Jadwal Backup Otomatis',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BackupSchedule>(
                        value: backup.schedule,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: BackupSchedule.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            backup.setSchedule(val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Hanya Backup Saat Wi-Fi',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        
                        value: backup.wifiOnly,
                        onChanged: (val) => backup.setWifiOnly(val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Sertakan Foto Struk Transaksi',
                          style: TextStyle(fontSize: 13.5),
                        ),
                       
                        value: backup.includeReceipts,
                        onChanged: (val) => backup.setIncludeReceipts(val),
                      ),
                    ],
                  ],
                ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Local Backup Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.folder_zip_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Backup Lokal (.smbak)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Simpan salinan database dan foto struk sebagai file .smbak untuk dibagikan atau disimpan offline.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isBackingUpLocal
                          ? null
                          : () => _handleLocalBackup(backup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isBackingUpLocal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _isBackingUpLocal
                            ? 'Creating Backup...'
                            : 'Create Backup',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Local Restore Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.restore_page_outlined,
                        color: Colors.deepOrange,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Restore dari File Lokal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pulihkan data dari file .smbak, .zip, .db, atau .sqlite. Seluruh data saat ini akan diganti.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isRestoringLocal
                          ? null
                          : () => _handleLocalRestore(backup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isRestoringLocal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        _isRestoringLocal
                            ? 'Restoring Data...'
                            : 'Restore from File',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
