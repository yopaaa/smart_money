import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class SecurityProvider extends ChangeNotifier with WidgetsBindingObserver {
  static final SecurityProvider instance = SecurityProvider._init();

  static const String settingLockEnabledKey = '@app_lock_enabled';
  static const String settingPinKey = '@app_pin';
  static const String settingSessionDurationKey = '@app_session_duration_minutes';

  bool _isInitialized = false;
  bool _isLockEnabled = false;
  String? _savedPin;
  bool _isSessionUnlocked = false;
  DateTime? _sessionExpiry;

  // Default long session (240 minutes = 4 hours) as requested
  Duration _sessionDuration = const Duration(minutes: 240);

  SecurityProvider._init() {
    WidgetsBinding.instance.addObserver(this);
    loadSecuritySettings();
  }

  factory SecurityProvider() => instance;

  bool get isInitialized => _isInitialized;
  bool get isLockEnabled => _isLockEnabled;
  bool get isPinSet => _savedPin != null && _savedPin!.isNotEmpty;
  bool get isSessionUnlocked => _isSessionUnlocked;
  Duration get sessionDuration => _sessionDuration;

  /// Returns true if app lock is active, a PIN is set, and the current session is invalid/expired.
  bool get isLocked {
    if (!_isInitialized || !_isLockEnabled || !isPinSet) {
      return false;
    }
    return !_isSessionValid();
  }

  bool _isSessionValid() {
    if (!_isSessionUnlocked) return false;
    if (_sessionExpiry == null) return false;
    return DateTime.now().isBefore(_sessionExpiry!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLockEnabled || !isPinSet) return;

    if (state == AppLifecycleState.resumed) {
      if (_sessionExpiry != null && DateTime.now().isAfter(_sessionExpiry!)) {
        // Session expired while in background
        _isSessionUnlocked = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadSecuritySettings() async {
    try {
      final enabledVal =
          await DatabaseHelper.instance.getSetting(settingLockEnabledKey);
      final pinVal = await DatabaseHelper.instance.getSetting(settingPinKey);
      final durationVal =
          await DatabaseHelper.instance.getSetting(settingSessionDurationKey);

      if (enabledVal != null) {
        _isLockEnabled = enabledVal is bool
            ? enabledVal
            : enabledVal.toString().toLowerCase() == 'true';
      }

      if (pinVal != null && pinVal.toString().isNotEmpty) {
        _savedPin = pinVal.toString();
      }

      if (durationVal != null) {
        final minutes = int.tryParse(durationVal.toString());
        if (minutes != null && minutes > 0) {
          _sessionDuration = Duration(minutes: minutes);
        }
      }
    } catch (e) {
      debugPrint('SecurityProvider loadSettings error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Verifies input PIN against the saved PIN.
  bool verifyPin(String inputPin) {
    if (_savedPin == null) return false;
    return _savedPin == inputPin;
  }

  /// Unlocks the session if PIN matches.
  bool unlock(String inputPin) {
    if (verifyPin(inputPin)) {
      unlockSession();
      return true;
    }
    return false;
  }

  /// Marks session as unlocked and extends session expiry.
  void unlockSession() {
    _isSessionUnlocked = true;
    _sessionExpiry = DateTime.now().add(_sessionDuration);
    notifyListeners();
  }

  /// Manually locks the session immediately.
  void lockSession() {
    _isSessionUnlocked = false;
    _sessionExpiry = null;
    notifyListeners();
  }

  /// Saves a new PIN and activates app lock.
  Future<void> setPin(String newPin) async {
    _savedPin = newPin;
    _isLockEnabled = true;
    unlockSession();

    try {
      await DatabaseHelper.instance.saveSetting(settingPinKey, newPin);
      await DatabaseHelper.instance.saveSetting(settingLockEnabledKey, true);
    } catch (e) {
      debugPrint('SecurityProvider savePin error: $e');
    }
    notifyListeners();
  }

  /// Removes the PIN and disables app lock.
  Future<void> removePin() async {
    _savedPin = null;
    _isLockEnabled = false;
    _isSessionUnlocked = true;
    _sessionExpiry = null;

    try {
      await DatabaseHelper.instance.saveSetting(settingPinKey, '');
      await DatabaseHelper.instance.saveSetting(settingLockEnabledKey, false);
    } catch (e) {
      debugPrint('SecurityProvider removePin error: $e');
    }
    notifyListeners();
  }

  /// Toggles lock enabled flag.
  Future<void> setLockEnabled(bool enabled) async {
    _isLockEnabled = enabled;
    if (enabled) {
      if (isPinSet) {
        unlockSession();
      }
    } else {
      _isSessionUnlocked = true;
    }

    try {
      await DatabaseHelper.instance.saveSetting(settingLockEnabledKey, enabled);
    } catch (e) {
      debugPrint('SecurityProvider setLockEnabled error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
