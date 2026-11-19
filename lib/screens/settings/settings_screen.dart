import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import 'app_info_screen.dart';
import 'backup_restore_screen.dart';
import 'category_management_screen.dart';
import 'currency_setting_screen.dart';
import 'deleted_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  bool _autoBackupEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final txProvider = context.watch<TransactionProvider>();
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
                  // PROFILE Section
                  _buildSectionHeader('PROFILE', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
                      _buildNavigationItem(
                        title: 'Account Information',
                        subtitle: 'Update your personal details',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account Information feature')),
                          );
                        },
                      ),
                      Divider(height: 1, color: dividerColor),
                      _buildNavigationItem(
                        title: 'Backup & Restore',
                        subtitle: 'Manage your data backup',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
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
                        subtitle: 'Lock app after inactivity',
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Auto Lock configured to immediate')),
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
                      _buildSwitchItem(
                        title: 'Notifications',
                        subtitle: 'Manage notification settings',
                        value: _notificationsEnabled,
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) {
                          setState(() {
                            _notificationsEnabled = val;
                          });
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
                        subtitle: 'Automatically backup your data',
                        value: _autoBackupEnabled,
                        titleColor: itemTitleColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) {
                          setState(() {
                            _autoBackupEnabled = val;
                          });
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

                  // ABOUT Section
                  _buildSectionHeader('ABOUT', sectionTitleColor),
                  _buildCard(
                    cardBg: cardBg,
                    children: [
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
