import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../../constants/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../services/database_helper.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final dbPath = await getDatabasesPath();
      final currentDb = File(p.join(dbPath, 'smart_money.db'));

      if (!await currentDb.exists()) {
        throw Exception('Database file does not exist yet');
      }

      final db = await DatabaseHelper.instance.database;
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (_) {}

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final backupFileName = 'smart_money_backup_$dateStr.smbak';
      final backupFile = File(p.join(tempDir.path, backupFileName));

      await currentDb.copy(backupFile.path);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Smart Money Backup ($dateStr)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup file created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
          'Restoring will replace all current data with the backup file. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final pickedPath = files.first.path!;
      if (!pickedPath.endsWith('.smbak') && !pickedPath.endsWith('.db')) {
        throw Exception('File must be a .smbak or .db file');
      }

      final dbPath = await getDatabasesPath();
      final targetDbPath = p.join(dbPath, 'smart_money.db');

      // 1. Close current open database connection
      await DatabaseHelper.instance.closeAndReset();

      // 2. Delete WAL & SHM files to ensure no stale log cache remains
      final walFile = File('$targetDbPath-wal');
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      final shmFile = File('$targetDbPath-shm');
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      // 3. Overwrite database with restored file
      await File(pickedPath).copy(targetDbPath);

      // 4. Reopen database directly from restored file
      await DatabaseHelper.instance.database;

      if (!mounted) return;
      final provider = context.read<TransactionProvider>();
      final messenger = ScaffoldMessenger.of(context);
      await provider.loadData();

      messenger.showSnackBar(
        const SnackBar(content: Text('Database restored successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleSyncBalances() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<TransactionProvider>();
    try {
      await DatabaseHelper.instance.recalculateAccountBalances();
      await provider.loadData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Saldo akun berhasil disinkronkan dengan riwayat transaksi!')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                child: Text('Reset App Data', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Backup Card
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
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Backup Database',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save a copy of your accounts and transactions as a .smbak file. You can share or upload it to Google Drive, Telegram, etc.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isBackingUp ? null : _handleBackup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isBackingUp
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(_isBackingUp ? 'Creating Backup...' : 'Create Backup'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Restore Card
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
                  Row(
                    children: [
                      const Icon(Icons.cloud_download_outlined, color: Colors.deepOrange, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Restore Database',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Restore data from an existing .smbak file. This will replace all current financial records.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isRestoring ? null : _handleRestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isRestoring
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download),
                      label: Text(_isRestoring ? 'Restoring Data...' : 'Restore from File'),
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
