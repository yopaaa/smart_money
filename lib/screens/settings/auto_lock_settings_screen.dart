import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/security_provider.dart';
import 'pin_lock_screen.dart';

class AutoLockSettingsScreen extends StatelessWidget {
  const AutoLockSettingsScreen({super.key});

  Future<void> _handleToggleLock(
    BuildContext context,
    SecurityProvider security,
    bool value,
  ) async {
    if (value) {
      if (!security.isPinSet) {
        // Must setup PIN first
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PinLockScreen(
              mode: PinMode.setup,
              canCancel: true,
            ),
          ),
        );
      } else {
        await security.setLockEnabled(true);
      }
    } else {
      // Confirm PIN before disabling
      if (security.isPinSet) {
        final confirmed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PinLockScreen(
              mode: PinMode.verify,
              canCancel: true,
              customTitle: 'Konfirmasi Matikan PIN',
              onSuccess: () => Navigator.pop(context, true),
            ),
          ),
        );

        if (confirmed == true) {
          await security.setLockEnabled(false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kunci PIN dinonaktifkan')),
            );
          }
        }
      } else {
        await security.setLockEnabled(false);
      }
    }
  }

  Future<void> _handleChangePin(
    BuildContext context,
    SecurityProvider security,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PinLockScreen(
          mode: PinMode.change,
          canCancel: true,
        ),
      ),
    );
  }

  void _handleLockNow(BuildContext context, SecurityProvider security) {
    security.lockSession();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aplikasi terkunci. Layar PIN aktif.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final security =
        Provider.of<SecurityProvider?>(context) ?? SecurityProvider.instance;

    final cardBg = isDark ? theme.cardColor : Colors.white;
    final dividerColor = isDark ? theme.dividerColor : const Color(0xFFF1F5F9);
    final sectionTitleColor = isDark ? Colors.white54 : const Color(0xFF777777);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor =
        isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunci Aplikasi (PIN)'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Section 1: STATUS KUNCI
          _buildSectionHeader('STATUS KEAMANAN', sectionTitleColor),
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: Text(
                'Kunci Aplikasi dengan PIN',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              subtitle: Text(
                security.isLockEnabled
                    ? (security.isPinSet
                        ? 'PIN aktif • Aplikasi terlindungi'
                        : 'PIN belum diatur')
                    : 'Aplikasi dapat dibuka tanpa PIN',
                style: TextStyle(
                  fontSize: 12.5,
                  color: secondaryTextColor,
                ),
              ),
              value: security.isLockEnabled && security.isPinSet,
              activeColor: AppColors.primary,
              onChanged: (val) => _handleToggleLock(context, security, val),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: PENGATURAN PIN (jika PIN sudah terpasang)
          if (security.isPinSet) ...[
            _buildSectionHeader('PENGATURAN PIN', sectionTitleColor),
            Material(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.pin_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    title: Text(
                      'Ubah PIN Keamanan',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Ganti 4 digit PIN aplikasi Anda',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: secondaryTextColor,
                    ),
                    onTap: () => _handleChangePin(context, security),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                    title: Text(
                      'Kunci Aplikasi Sekarang',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Kunci sesi sekarang untuk mencoba verifikasi PIN',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: secondaryTextColor,
                    ),
                    onTap: () => _handleLockNow(context, security),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Section 3: INFORMASI SESI
          _buildSectionHeader('INFORMASI SESI', sectionTitleColor),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Durasi Sesi: Panjang (4 Jam)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Selama sesi masih aktif dalam 4 jam, Anda dapat berpindah menu atau keluar masuk aplikasi tanpa harus memasukkan PIN berulang kali. Jika aplikasi ditinggalkan melebihi durasi sesi atau Anda memilih "Kunci Aplikasi Sekarang", layar PIN akan otomatis muncul.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
