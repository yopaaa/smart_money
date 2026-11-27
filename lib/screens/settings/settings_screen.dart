import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/backup_sync_service.dart';
import '../home/gallery_screen.dart';
import 'account_info_screen.dart';
import 'app_info_screen.dart';
import 'auto_lock_settings_screen.dart';
import 'backup_restore_screen.dart';
import 'category_management_screen.dart';
import 'currency_setting_screen.dart';
import 'deleted_history_screen.dart';
import 'file_export_screen.dart';
import 'gemini_api_key_dialog.dart';
import 'image_sync_screen.dart';
import 'notification_settings_screen.dart';
import 'report_screen.dart';
import '../../providers/security_provider.dart';
import '../../services/gemini_voice_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = false;
  bool _autoBackupEnabled = true;
  bool _hasGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
    _checkGeminiApiKey();
  }

  Future<void> _checkGeminiApiKey() async {
    try {
      final hasKey = await GeminiVoiceService.instance.hasApiKey();
      if (mounted) {
        setState(() => _hasGeminiApiKey = hasKey);
      }
    } catch (_) {}
  }

  Future<void> _loadNotificationState() async {
    try {
      final enabled =
          await NotificationService.instance.isNotificationsEnabled();
      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final security =
        Provider.of<SecurityProvider?>(context) ?? SecurityProvider.instance;
    final backupProvider = Provider.of<BackupProvider?>(context);
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final currentCurrency = txProvider.currency;

    final bgColor = theme.scaffoldBackgroundColor;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final itemTitleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final dividerColor = isDark ? theme.dividerColor : const Color(0xFFF1F5F9);
    final sectionTitleColor = isDark ? Colors.white54 : const Color(0xFF777777);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header: Settings
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? theme.dividerColor : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Logged-in Google Profile Banner
                  if (backupProvider != null && backupProvider.isSignedIn) ...[
                    _buildProfileBanner(
                      context: context,
                      backupProvider: backupProvider,
                      cardBg: cardBg,
                      titleColor: itemTitleColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 18),
                  ],

                  // PROFILE Section
                  _buildSectionHeader('PROFILE', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildNavigationItem(
                        title: 'Account Information',
                        subtitle: backupProvider?.isSignedIn == true
                            ? backupProvider!.account!.email
                            : 'Hubungkan akun Google & info profil',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountInfoScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Backup & Restore',
                        subtitle: backupProvider?.lastBackupAt != null
                            ? 'Terakhir: ${DateFormat('dd MMM, HH:mm').format(backupProvider!.lastBackupAt!)}'
                            : 'Google Drive & cadangan lokal',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupRestoreScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // SECURITY Section
                  _buildSectionHeader('SECURITY', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildSwitchItem(
                        title: 'Biometric Authentication',
                        subtitle: 'Use fingerprint or face unlock',
                        value: _biometricEnabled,
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) {
                          setState(() {
                            _biometricEnabled = val;
                          });
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Auto Lock',
                        subtitle: security.isLockEnabled && security.isPinSet
                            ? 'PIN Aktif (Sesi 4 Jam)'
                            : 'Kunci aplikasi dengan PIN',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AutoLockSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Privacy Settings',
                        subtitle: 'Manage your privacy preferences',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Privacy settings: Local storage enabled')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // PREFERENCES Section
                  _buildSectionHeader('PREFERENCES', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildNavigationItem(
                        title: 'Gemini AI (Transaksi Suara)',
                        subtitle: _hasGeminiApiKey
                            ? 'API Key terpasang • Transaksi suara aktif'
                            : 'Atur Google Gemini API Key',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () async {
                          await GeminiApiKeyDialog.show(context);
                          _checkGeminiApiKey();
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Notifications',
                        subtitle: _notificationsEnabled
                            ? 'Aktif (Default: 3 PM & 8 PM)'
                            : 'Kelola jadwal pengingat transaksi',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          );
                          _loadNotificationState();
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildSwitchItem(
                        title: 'Dark Mode',
                        subtitle: 'Switch between light and dark theme',
                        value: isDark,
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) => themeProvider.toggleTheme(),
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Currency',
                        subtitle: '${currentCurrency.name} (${currentCurrency.symbol})',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CurrencySettingScreen()),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Categories',
                        subtitle: 'Set your income and expense categories',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // DATA Section
                  _buildSectionHeader('DATA', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildSwitchItem(
                        title: 'Auto Backup',
                        subtitle: backupProvider != null &&
                                backupProvider.schedule != BackupSchedule.off
                            ? 'Terjadwal ${backupProvider.schedule.label} ke Google Drive'
                            : 'Aktifkan jadwal backup otomatis',
                        value: backupProvider != null
                            ? backupProvider.schedule != BackupSchedule.off
                            : _autoBackupEnabled,
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) async {
                          if (backupProvider != null) {
                            await backupProvider.setSchedule(
                              val
                                  ? BackupSchedule.daily
                                  : BackupSchedule.off,
                            );
                          } else {
                            setState(() {
                              _autoBackupEnabled = val;
                            });
                          }
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Export Data',
                        subtitle: 'Export transactions to CSV or Excel',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FileExportScreen()),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Export Image',
                        subtitle: 'Sinkron & restore foto (/sdcard/Pictures/SmartMoney)',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ImageSyncScreen()),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Gallery',
                        subtitle: 'Transactions receipt images',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GalleryScreen(isStandalone: true),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Recycle Bin',
                        subtitle: 'View and restore deleted transactions',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeletedHistoryScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ABOUT & SUPPORT Section
                  _buildSectionHeader('SUPPORT & ABOUT', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildNavigationItem(
                        title: 'Contact & Feedback',
                        subtitle: 'Send feedback or report issues',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportScreen()),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'About Smart Money',
                        subtitle: 'Version 1.0.0',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AppInfoScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  // Space for bottom curved navigation bar
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBanner({
    required BuildContext context,
    required BackupProvider backupProvider,
    required Color cardBg,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final profile = backupProvider.account!;
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : 'G';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
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
                            fontSize: 20,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.email,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          backupProvider.schedule == BackupSchedule.off
                              ? 'Google Drive Terhubung'
                              : 'Auto-Backup: ${backupProvider.schedule.label}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required Color titleColor,
    required Color subtitleColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF2563EB),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
