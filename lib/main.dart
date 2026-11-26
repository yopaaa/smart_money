import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/backup_provider.dart';
import 'providers/security_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/settings/pin_lock_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/backup_sync_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }
  try {
    await BackupSyncService.instance.initializeWorkmanager();
  } catch (e) {
    debugPrint('Workmanager init error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => BackupProvider()),
      ],
      child: const SmartMoneyApp(),
    ),
  );
}

class SmartMoneyApp extends StatefulWidget {
  const SmartMoneyApp({super.key});

  @override
  State<SmartMoneyApp> createState() => _SmartMoneyAppState();
}

class _SmartMoneyAppState extends State<SmartMoneyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backupProvider = Provider.of<BackupProvider?>(
        context,
        listen: false,
      );
      backupProvider?.syncIfDue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final securityProvider =
        Provider.of<SecurityProvider?>(context) ?? SecurityProvider.instance;

    return MaterialApp(
      title: 'Smart Money',
      debugShowCheckedModeBanner: false,
      theme: AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      themeMode: themeProvider.themeMode,
      home: !txProvider.isInitialized
          ? const SplashScreen()
          : txProvider.isNewUser
              ? const WelcomeScreen()
              : const MainNavigationScreen(),
      builder: (context, child) {
        final content = child ?? const SizedBox();
        if (!txProvider.isInitialized || txProvider.isNewUser) {
          return content;
        }

        return Stack(
          children: [
            content,
            if (securityProvider.isLocked)
              Positioned.fill(
                child: PinLockScreen(
                  mode: PinMode.verify,
                  canCancel: false,
                  onSuccess: () => securityProvider.unlockSession(),
                ),
              ),
          ],
        );
      },
    );
  }
}
