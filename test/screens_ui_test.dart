import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/constants/app_icons.dart';
import 'package:smart_money/screens/accounts/create_account_screen.dart';
import 'package:smart_money/screens/home/history_screen.dart';
import 'package:smart_money/screens/settings/file_export_screen.dart';
import 'package:smart_money/screens/settings/report_screen.dart';
import 'package:smart_money/screens/settings/settings_screen.dart';
import 'package:smart_money/screens/splash/splash_screen.dart';
import 'package:smart_money/screens/statistics/stats_screen.dart';
import 'package:smart_money/screens/transactions/transaction_detail_screen.dart';
import 'package:smart_money/screens/transactions/transaction_form_screen.dart';
import 'package:smart_money/widgets/animated_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getDatabasesPath') {
            return '/mock/databases';
          }
          if (methodCall.method == 'openDatabase') {
            return 1;
          }
          return <Map<String, dynamic>>[];
        });
  });

  testWidgets(
    'CreateAccountScreen renders all required fields matching design',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ],
          child: const MaterialApp(home: CreateAccountScreen()),
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
    },
  );

  testWidgets('SettingsScreen renders sections matching design', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
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

  testWidgets('StatsScreen renders without overflow on 360px width screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  });

  testWidgets('HistoryScreen renders AnimatedTabBar and PageView correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(home: HistoryScreen()),
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
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Smart Money'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('FileExportScreen renders CSV and Excel export options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(home: FileExportScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('Export CSV'), findsWidgets);
    expect(find.text('Export Excel (XLS)'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
  });

  testWidgets('ReportScreen renders fields and sends report dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: const MaterialApp(home: ReportScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Contact & Report'), findsOneWidget);
    expect(find.text('Judul / Subjek'), findsOneWidget);
    expect(find.text('Email Anda'), findsOneWidget);
    expect(find.text('Deskripsi Masalah / Masukan'), findsOneWidget);
    expect(find.text('KIRIM LAPORAN'), findsOneWidget);
  });

  testWidgets(
    'TransactionFormScreen renders vertical clean and compact fields',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check title labels on top of input areas
      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('Waktu'), findsOneWidget);
      expect(find.text('Judul Transaksi'), findsOneWidget);
      expect(find.textContaining('Jumlah'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Deskripsi & Foto (Opsional)'), findsOneWidget);
      expect(find.text('Tambah Transaksi'), findsOneWidget);

      // Switch tab to Transfer
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Akun Sumber'), findsOneWidget);
      expect(find.text('Akun Tujuan'), findsOneWidget);
      expect(find.textContaining('Biaya Admin'), findsOneWidget);

      // Simulate keyboard opening and verify button stays above keyboard
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pump();
      expect(find.text('Tambah Transaksi'), findsOneWidget);
      final buttonRect = tester.getRect(find.text('Tambah Transaksi'));
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(buttonRect.bottom, lessThanOrEqualTo(screenHeight - 250));
    },
  );

  testWidgets(
    'TransactionDetailScreen renders form structure and action buttons matching old app',
    (tester) async {
      final sampleTx = TransactionModel(
        id: 'tx-123',
        title: 'Makan Siang',
        amount: 35000,
        type: 'expense',
        accountId: 'acc-1',
        createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ],
          child: MaterialApp(
            home: TransactionDetailScreen(
              transactionId: 'tx-123',
              initialTransaction: sampleTx,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header title
      expect(find.text('Expense Details'), findsOneWidget);

      // Form field labels
      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('Waktu'), findsOneWidget);
      expect(find.text('Judul Transaksi'), findsOneWidget);
      expect(find.textContaining('Jumlah'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Deskripsi'), findsOneWidget);

      // Pre-filled value
      expect(find.text('Makan Siang'), findsOneWidget);

      // Slider tabs removed as requested
      expect(find.byType(AnimatedTabBar), findsNothing);

      // Bottom 3 action buttons matching old app
      expect(find.text('Hapus'), findsOneWidget);
      expect(find.text('Salin'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  testWidgets(
    'TransactionFormScreen opens compact category & account modals matching design',
    (tester) async {
      final mockTx = _PickerMockTransactionProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<TransactionProvider>.value(value: mockTx),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Kategori modal
      await tester.tap(find.text('Makanan').first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      await tester.tap(find.text('Minuman'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Minuman'), findsOneWidget);

      // Open Akun modal: compact single-line name only (no balance subtitle)
      await tester.tap(find.text('Cash On Hand').first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Cash On Gopay'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('Rp'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Cash On Gopay'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Cash On Gopay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PickerMockTransactionProvider extends TransactionProvider {
  @override
  Future<void> loadData() async {}

  @override
  List<AccountModel> get accounts => [
    AccountModel(
      id: 'acc-1',
      name: 'Cash On Hand',
      balance: 250000,
      type: 'cash',
      icon: 'cash',
      iconColor: '#4CAF50',
    ),
    AccountModel(
      id: 'acc-2',
      name: 'Cash On Gopay',
      balance: 150000,
      type: 'ewallet',
      icon: 'cash',
      iconColor: '#66BB6A',
    ),
  ];

  @override
  List<CategoryModel> getCategoriesByType(String type) => [
    CategoryModel(
      id: 'cat-1',
      name: 'Makanan',
      icon: 'restaurant',
      color: '#E57373',
      type: 'expense',
    ),
    CategoryModel(
      id: 'cat-2',
      name: 'Minuman',
      icon: 'local_drink',
      color: '#42A5F5',
      type: 'expense',
    ),
  ];
}
