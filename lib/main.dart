import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
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

    return MaterialApp(
      title: 'Smart Money',
      debugShowCheckedModeBanner: false,
      theme: AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      themeMode: themeProvider.themeMode,
      home: txProvider.isLoading
          ? const SplashScreen()
          : txProvider.isNewUser
              ? const WelcomeScreen()
              : const MainNavigationScreen(),
    );
  }
}
