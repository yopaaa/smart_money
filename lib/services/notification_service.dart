import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'database_helper.dart';

class ReminderTime {
  final int id;
  final int hour;
  final int minute;
  final bool enabled;
  final String label;

  const ReminderTime({
    required this.id,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.label = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'label': label,
      };

  factory ReminderTime.fromMap(Map<String, dynamic> map) => ReminderTime(
        id: map['id'] as int,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        enabled: map['enabled'] as bool? ?? true,
        label: map['label'] as String? ?? '',
      );

  ReminderTime copyWith({
    int? id,
    int? hour,
    int? minute,
    bool? enabled,
    String? label,
  }) =>
      ReminderTime(
        id: id ?? this.id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        label: label ?? this.label,
      );

  String get timeFormatted {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:$m (${h12.toString().padLeft(2, '0')}:$m $period)';
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String settingEnabledKey = '@notifications_enabled';
  static const String settingRemindersKey = '@notification_reminders';
  static const String channelId = 'smart_money_daily_reminders';
  static const String channelName = 'Pengingat Transaksi Harian';
  static const String channelDesc =
      'Notifikasi pengingat harian untuk mencatat pengeluaran dan pemasukan';

  static const List<ReminderTime> defaultReminders = [
    ReminderTime(
      id: 1,
      hour: 15,
      minute: 0,
      enabled: true,
      label: 'Pengingat Siang / Sore (3:00 PM)',
    ),
    ReminderTime(
      id: 2,
      hour: 20,
      minute: 0,
      enabled: true,
      label: 'Pengingat Malam (8:00 PM)',
    ),
  ];

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NotificationService: Gagal mendapatkan timezone lokal: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    bool granted = false;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final notifGranted =
          await androidImpl.requestNotificationsPermission() ?? false;
      await androidImpl.requestExactAlarmsPermission();
      granted = notifGranted;
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final iosGranted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      granted = granted || iosGranted;
    }

    return granted;
  }

  Future<bool> isNotificationsEnabled() async {
    try {
      final val = await DatabaseHelper.instance.getSetting(settingEnabledKey);
      if (val == null) return false;
      if (val is bool) return val;
      return val.toString().toLowerCase() == 'true';
    } catch (e) {
      debugPrint('NotificationService isNotificationsEnabled error: $e');
      return false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      await DatabaseHelper.instance.saveSetting(settingEnabledKey, enabled);
    } catch (e) {
      debugPrint('NotificationService setNotificationsEnabled error: $e');
    }
    if (enabled) {
      await requestPermissions();
      await syncSchedules();
    } else {
      await cancelAll();
    }
  }

  Future<List<ReminderTime>> getReminders() async {
    try {
      final raw = await DatabaseHelper.instance.getSetting(settingRemindersKey);
      if (raw == null) {
        return List<ReminderTime>.from(defaultReminders);
      }

      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        return decoded
            .map((e) =>
                ReminderTime.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('NotificationService: Gagal parse reminders: $e');
    }
    return List<ReminderTime>.from(defaultReminders);
  }

  Future<void> saveReminders(List<ReminderTime> reminders) async {
    try {
      final encoded = jsonEncode(reminders.map((r) => r.toMap()).toList());
      await DatabaseHelper.instance.saveSetting(settingRemindersKey, encoded);
    } catch (e) {
      debugPrint('NotificationService saveReminders error: $e');
    }
    final enabled = await isNotificationsEnabled();
    if (enabled) {
      await syncSchedules();
    }
  }

  Future<void> syncSchedules() async {
    await cancelAll();

    final enabled = await isNotificationsEnabled();
    if (!enabled) return;

    final reminders = await getReminders();
    for (final reminder in reminders) {
      if (reminder.enabled) {
        await _scheduleReminder(reminder);
      }
    }
  }

  Future<void> _scheduleReminder(ReminderTime reminder) async {
    final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final title = reminder.hour < 17
        ? 'Catat Keuangan Siangmu ☀️'
        : 'Catat Keuangan Malam Ini 🌙';
    final body = reminder.hour < 17
        ? 'Ada pengeluaran atau jajan tadi? Yuk catat di Smart Money sekarang.'
        : 'Sudah catat semua transaksi hari ini? Pastikan saldo dan catatanmu rapi!';

    await _plugin.zonedSchedule(
      id: reminder.id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: 999,
      title: 'Smart Money 💰',
      body: 'Pengingat aktif! Notifikasi Smart Money berhasil terhubung.',
      notificationDetails: details,
    );
  }
}
