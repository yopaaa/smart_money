import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/backup_provider.dart';
import '../../services/backup_sync_service.dart';
import '../../services/google_drive_service.dart';
import 'backup_restore_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {

  Future<void> _handleSignIn(BackupProvider backupProvider) async {
    try {
      await backupProvider.signIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil terhubung sebagai ${backupProvider.account?.email ?? ''}',
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

  Future<void> _handleSignOut(BackupProvider backupProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Putuskan Akun Google?'),
        content: const Text(
          'Sinkronisasi dan backup otomatis ke Google Drive akan berhenti sampai Anda login kembali. Data lokal di perangkat tidak akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await backupProvider.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun Google telah diputuskan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final dividerColor = isDark ? theme.dividerColor : const Color(0xFFF1F5F9);
    final profile = backup.account;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile != null) ...[
            _buildConnectedProfileBanner(
              profile: profile,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.person_outline,
                    label: 'Nama Lengkap',
                    value: profile.displayName,
                    titleColor: titleColor,
                    subtextColor: subtextColor,
                  ),
                  Divider(height: 1, color: dividerColor),
                  _infoTile(
                    icon: Icons.email_outlined,
                    label: 'Email Google',
                    value: profile.email,
                    titleColor: titleColor,
                    subtextColor: subtextColor,
                  ),
                  Divider(height: 1, color: dividerColor),
                  _infoTile(
                    icon: Icons.cloud_done_outlined,
                    label: 'Ruang Penyimpanan Drive',
                    value: 'App Data Folder',
                    titleColor: titleColor,
                    subtextColor: subtextColor,
                  ),
                  Divider(height: 1, color: dividerColor),
                  _infoTile(
                    icon: Icons.schedule_rounded,
                    label: 'Jadwal Auto-Backup',
                    value: backup.schedule == BackupSchedule.off
                        ? 'Mati (Manual)'
                        : '${backup.schedule.label}${backup.wifiOnly ? ' (Wi-Fi)' : ''}',
                    titleColor: titleColor,
                    subtextColor: subtextColor,
                  ),
                  Divider(height: 1, color: dividerColor),
                  _infoTile(
                    icon: Icons.history_rounded,
                    label: 'Backup Drive Terakhir',
                    value: backup.lastBackupAt != null
                        ? DateFormat('dd MMM yyyy, HH:mm')
                            .format(backup.lastBackupAt!)
                        : 'Belum pernah backup',
                    titleColor: titleColor,
                    subtextColor: subtextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupRestoreScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text(
                'Kelola Backup & Jadwal Sinkronisasi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expense,
                side: const BorderSide(color: AppColors.expense),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _handleSignOut(backup),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Keluar dari Akun Google',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Hubungkan Akun Google Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login dengan Google untuk menampilkan profil akun, menyimpan backup transaksi beserta foto struk secara aman di Google Drive (App Data Folder), dan mengaktifkan jadwal sinkronisasi otomatis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        backup.isSigningIn ? null : () => _handleSignIn(backup),
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
                          : 'Masuk dengan Google',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedProfileBanner({
    required GoogleAccountProfile profile,
    required bool isDark,
  }) {
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : 'G';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.22),
            backgroundImage: (profile.photoUrl != null &&
                    profile.photoUrl!.trim().isNotEmpty)
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: (profile.photoUrl == null ||
                    profile.photoUrl!.trim().isEmpty)
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Google Drive Terhubung',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color titleColor,
    required Color subtextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
