import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../widgets/action_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _notificationsEnabled = false;
  List<ReminderTime> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final enabled = await NotificationService.instance.isNotificationsEnabled();
    final reminders = await NotificationService.instance.getReminders();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMasterNotification(bool value) async {
    setState(() => _notificationsEnabled = value);
    await NotificationService.instance.setNotificationsEnabled(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Notifikasi pengingat harian diaktifkan'
              : 'Notifikasi pengingat dinonaktifkan',
        ),
      ),
    );
  }

  Future<void> _toggleReminder(int index, bool value) async {
    setState(() {
      _reminders[index] = _reminders[index].copyWith(enabled: value);
    });
    await NotificationService.instance.saveReminders(_reminders);
  }

  Future<void> _editReminderTime(int index) async {
    final current = _reminders[index];
    final initialTime = TimeOfDay(hour: current.hour, minute: current.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _reminders[index] = _reminders[index].copyWith(
          hour: picked.hour,
          minute: picked.minute,
        );
      });
      await NotificationService.instance.saveReminders(_reminders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Waktu pengingat diubah ke ${_reminders[index].timeFormatted}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteReminder(int index) async {
    if (_reminders.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 jadwal pengingat.'),
        ),
      );
      return;
    }

    final toRemove = _reminders[index];
    setState(() {
      _reminders.removeAt(index);
    });
    await NotificationService.instance.cancelReminder(toRemove.id);
    await NotificationService.instance.saveReminders(_reminders);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal pengingat dihapus')),
      );
    }
  }

  Future<void> _addNewReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );

    if (picked != null && mounted) {
      final newId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final label = picked.hour < 12
          ? 'Pengingat Pagi'
          : (picked.hour < 17 ? 'Pengingat Siang' : 'Pengingat Malam');

      final newReminder = ReminderTime(
        id: newId,
        hour: picked.hour,
        minute: picked.minute,
        enabled: true,
        label: label,
      );

      setState(() {
        _reminders.add(newReminder);
      });
      await NotificationService.instance.saveReminders(_reminders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengingat baru ditambahkan: ${newReminder.timeFormatted}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Jadwal Pengingat?'),
        content: const Text(
          'Kembalikan jadwal ke setelan default: jam 3:00 PM (15:00) dan 8:00 PM (20:00)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _reminders =
            List<ReminderTime>.from(NotificationService.defaultReminders);
      });
      await NotificationService.instance.saveReminders(_reminders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal pengingat direset ke 3:00 PM dan 8:00 PM'),
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi tes berhasil dikirim!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim notifikasi tes: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? theme.cardColor : Colors.white;
    final dividerColor = isDark ? theme.dividerColor : const Color(0xFFF1F5F9);
    final sectionTitleColor = isDark ? Colors.white54 : const Color(0xFF777777);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor =
        isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset ke Default (3 PM & 8 PM)',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // SECTION 1: MASTER TOGGLE
                _buildSectionHeader('STATUS NOTIFIKASI', sectionTitleColor),
                Material(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: dividerColor),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      'Aktifkan Pengingat Harian',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Mengingatkan untuk mencatat pemasukan & pengeluaran',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    value: _notificationsEnabled,
                    activeColor: AppColors.primary,
                    onChanged: _toggleMasterNotification,
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: JADWAL PENGINGAT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildSectionHeader(
                        'JADWAL PENGINGAT HARIAN',
                        sectionTitleColor,
                      ),
                    ),
                    if (_notificationsEnabled)
                      TextButton.icon(
                        onPressed: _addNewReminder,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Tambah Waktu',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                Material(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: dividerColor),
                  ),
                  child: _reminders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              'Belum ada jadwal pengingat.',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reminders.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: dividerColor),
                          itemBuilder: (context, index) {
                            final reminder = _reminders[index];
                            final isAfternoon = reminder.hour >= 12 &&
                                reminder.hour < 18;
                            final isNight =
                                reminder.hour >= 18 || reminder.hour < 5;

                            final iconData = isNight
                                ? Icons.nightlight_round
                                : (isAfternoon
                                    ? Icons.wb_sunny_rounded
                                    : Icons.alarm_rounded);

                            final iconBg = isNight
                                ? Colors.indigo.withOpacity(0.12)
                                : (isAfternoon
                                    ? Colors.orange.withOpacity(0.12)
                                    : Colors.teal.withOpacity(0.12));

                            final iconColor = isNight
                                ? Colors.indigo
                                : (isAfternoon ? Colors.orange : Colors.teal);

                            return Opacity(
                              opacity: _notificationsEnabled ? 1.0 : 0.45,
                              child: InkWell(
                                onTap: _notificationsEnabled
                                    ? () => _editReminderTime(index)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: iconBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          iconData,
                                          color: iconColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    reminder.timeFormatted,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: primaryTextColor,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 14,
                                                  color: secondaryTextColor,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              reminder.label.isNotEmpty
                                                  ? reminder.label
                                                  : 'Setiap hari',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: secondaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.scale(
                                            scale: 0.85,
                                            child: Switch(
                                              value: reminder.enabled &&
                                                  _notificationsEnabled,
                                              activeColor: AppColors.primary,
                                              onChanged: _notificationsEnabled
                                                  ? (val) => _toggleReminder(
                                                      index, val)
                                                  : null,
                                            ),
                                          ),
                                          if (_reminders.length > 1) ...[
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              color:
                                                  Colors.red.withOpacity(0.7),
                                              tooltip: 'Hapus',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _notificationsEnabled
                                                  ? () =>
                                                      _deleteReminder(index)
                                                  : null,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Secara default, pengingat dikirim pada jam 3:00 PM (15:00) dan 8:00 PM (20:00). Anda dapat mengetuk ikon pensil untuk mengubah jam atau menambah jadwal baru.',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: TEST NOTIFIKASI
                _buildSectionHeader('UJI COBA', sectionTitleColor),
                Material(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uji Coba Notifikasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kirim notifikasi langsung ke perangkat untuk memastikan sistem notifikasi berfungsi.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ActionButton(
                          title: 'Kirim Notifikasi Tes',
                          icon: Icons.notifications_active_outlined,
                          onPress: _sendTestNotification,
                        ),
                      ],
                    ),
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
