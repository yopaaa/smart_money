import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/constants/app_icons.dart';
import 'package:smart_money/screens/accounts/create_account_screen.dart';
import 'package:smart_money/screens/home/history_screen.dart';
import 'package:smart_money/screens/settings/settings_screen.dart';
import 'package:smart_money/screens/splash/splash_screen.dart';
import 'package:smart_money/screens/statistics/stats_screen.dart';
import 'package:smart_money/widgets/animated_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        return '/mock/databases';
      }
      if (methodCall.method == 'openDatabase') {
        return 1;
      }
      return <Map<String, dynamic>>[];
    });
  });

  testWidgets('CreateAccountScreen renders all required fields matching design', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(
          home: CreateAccountScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Buat Akun'), findsOneWidget);
    expect(find.text('Nama Akun'), findsOneWidget);
    expect(find.text('Jumlah'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pilih Ikon'), findsOneWidget);
    expect(find.text('Pilih Warna'), findsOneWidget);
    expect(find.text('Tampilkan Saldo Akun Ini ke Total'), findsOneWidget);
    expect(find.text('Deskripsi'), findsOneWidget);
    expect(find.text('TAMBAH TRANSAKSI'), findsOneWidget);

    // Tap icon picker container to verify modal dialog
    await tester.tap(find.byIcon(AppIcons.getIcon('cash')).first);
    await tester.pumpAndSettle();

    expect(find.text('Tutup'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup'), findsNothing);
  });

  testWidgets('SettingsScreen renders sections matching design', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Account Information'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Biometric Authentication'), findsOneWidget);
  });

  testWidgets('StatsScreen renders without overflow on 360px width screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(
          home: StatsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  });

  testWidgets('HistoryScreen renders AnimatedTabBar and PageView correctly', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(
          home: HistoryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AnimatedTabBar), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Ionicons.list), findsOneWidget);
    expect(find.byIcon(Ionicons.images), findsOneWidget);
  });

  testWidgets('SplashScreen renders logo and title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    expect(find.text('Smart Money'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
