import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/security_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/settings/pin_lock_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
      ],
      child: const SmartMoneyApp(),
    ),
  );
}

class SmartMoneyApp extends StatelessWidget {
  const SmartMoneyApp({super.key});

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
