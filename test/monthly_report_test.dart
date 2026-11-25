import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/models/account_model.dart';
import 'package:smart_money/models/category_model.dart';
import 'package:smart_money/models/currency_model.dart';
import 'package:smart_money/models/transaction_model.dart';
import 'package:smart_money/providers/theme_provider.dart';
import 'package:smart_money/providers/transaction_provider.dart';
import 'package:smart_money/screens/statistics/stats_screen.dart';
import 'package:smart_money/services/monthly_report_service.dart';
import 'package:smart_money/utils/date_utils.dart';

void main() {
  group('MonthlyReportService Calculations & PDF Generation', () {
    final targetMonth = DateTime(2026, 11, 15);

    final accounts = [
      AccountModel(
        id: 'acc_cash',
        name: 'Dompet Cash',
        type: 'cash',
        isLiability: false,
        // Final current balance (including Dec tx below):
        // Nov opening: 1,000,000
        // + Nov income salary: +10,000,000
        // - Nov expense food: -500,000
        // - Nov transfer to saving: -3,000,000
        // - Nov transfer to invest: -2,000,000
        // - Nov transfer fee: -2,500
        // - Nov transfer to pay debt: -400,000
        // = Nov closing: 5,097,500
        // + Dec 1 expense: -100,000 => Current balance: 4,997,500
        balance: 4997500,
      ),
      AccountModel(
        id: 'acc_saving',
        name: 'BCA Tabungan',
        type: 'saving',
        isLiability: false,
        // Nov opening: 5,000,000 + transfer in 3,000,000 = 8,000,000
        balance: 8000000,
      ),
      AccountModel(
        id: 'acc_invest',
        name: 'Bibit Reksadana',
        type: 'invest',
        isLiability: false,
        // Nov opening: 4,000,000 + transfer in 2,000,000 + dividend income 250,000 = 6,250,000
        balance: 6250000,
      ),
      AccountModel(
        id: 'acc_debt',
        name: 'Pinjaman KTA',
        type: 'debt',
        isLiability: true,
        // Debt accounts store negative balance in Smart Money:
        // Nov opening: -2,000,000 (Hutang awal = 2,000,000)
        // + Nov new borrowing (expense 1,000,000) => -3,000,000
        // + Nov repayment (transfer in 400,000) => -2,600,000 (Hutang akhir = 2,600,000)
        // Net debt increase = +600,000
        balance: -2600000,
      ),
    ];

    final categories = [
      CategoryModel(
        id: 'cat_salary',
        name: 'Gaji',
        icon: 'cash',
        color: '#4CAF50',
        type: 'income',
      ),
      CategoryModel(
        id: 'cat_div',
        name: 'Dividen',
        icon: 'chart-line',
        color: '#FFB74D',
        type: 'income',
      ),
      CategoryModel(
        id: 'cat_food',
        name: 'Makanan',
        icon: 'food',
        color: '#FF5722',
        type: 'expense',
      ),
      CategoryModel(
        id: 'cat_loan',
        name: 'Cicilan / Pinjaman',
        icon: 'bank',
        color: '#F06292',
        type: 'expense',
      ),
    ];

    final nov10 = DateTime(2026, 11, 10, 9, 0).millisecondsSinceEpoch;
    final nov12 = DateTime(2026, 11, 12, 12, 30).millisecondsSinceEpoch;
    final nov15 = DateTime(2026, 11, 15, 14, 0).millisecondsSinceEpoch;
    final nov18 = DateTime(2026, 11, 18, 16, 0).millisecondsSinceEpoch;
    final nov20 = DateTime(2026, 11, 20, 10, 0).millisecondsSinceEpoch;
    final dec02 = DateTime(2026, 12, 2, 10, 0).millisecondsSinceEpoch;

    final transactions = [
      TransactionModel(
        id: 'tx_salary',
        title: 'Gaji November',
        amount: 10000000,
        type: 'income',
        accountId: 'acc_cash',
        category: 'cat_salary',
        createdAt: nov10.toString(),
      ),
      TransactionModel(
        id: 'tx_food',
        title: 'Makan Siang',
        description: '🎙️ Transaksi Suara: Nasi Padang via Tunai',
        amount: 500000,
        type: 'expense',
        accountId: 'acc_cash',
        category: 'cat_food',
        createdAt: nov12.toString(),
      ),
      // Transfer with paired Biaya transfer expense row (like DatabaseHelper.addTransaction)
      TransactionModel(
        id: 'tx_tf_saving',
        title: 'Nabung BCA',
        amount: 3000000,
        fee: 2500,
        type: 'transfer',
        accountId: 'acc_cash',
        targetAccountId: 'acc_saving',
        createdAt: nov15.toString(),
      ),
      TransactionModel(
        id: 'tx_tf_fee',
        title: 'Biaya transfer',
        description: 'Biaya transfer ke BCA Tabungan',
        amount: 2500,
        type: 'expense',
        accountId: 'acc_cash',
        targetAccountId: 'acc_saving',
        category: 'Biaya Admin',
        createdAt: (nov15 + 1).toString(),
      ),
      TransactionModel(
        id: 'tx_tf_invest',
        title: 'Top Up Bibit',
        amount: 2000000,
        type: 'transfer',
        accountId: 'acc_cash',
        targetAccountId: 'acc_invest',
        createdAt: nov18.toString(),
      ),
      TransactionModel(
        id: 'tx_div',
        title: 'Imbal Hasil Reksadana',
        amount: 250000,
        type: 'income',
        accountId: 'acc_invest',
        category: 'cat_div',
        createdAt: nov18.toString(),
      ),
      TransactionModel(
        id: 'tx_borrow',
        title: 'Tarik Pinjaman Tambahan',
        amount: 1000000,
        type: 'expense',
        accountId: 'acc_debt',
        category: 'cat_loan',
        createdAt: nov20.toString(),
      ),
      TransactionModel(
        id: 'tx_repay',
        title: 'Bayar Cicilan Hutang',
        amount: 400000,
        type: 'transfer',
        accountId: 'acc_cash',
        targetAccountId: 'acc_debt',
        createdAt: nov20.toString(),
      ),
      // December transaction (outside November, must be excluded from Nov totals
      // and backed out from November closing balance!)
      TransactionModel(
        id: 'tx_dec',
        title: 'Kopi Desember',
        amount: 100000,
        type: 'expense',
        accountId: 'acc_cash',
        category: 'cat_food',
        createdAt: dec02.toString(),
      ),
    ];

    test('Accurately calculates income, expense, saving, invest, and debt growth',
        () {
      final summary = MonthlyReportService.instance.calculateSummary(
        accounts: accounts,
        categories: categories,
        allTransactions: transactions,
        currency: CurrencyModel.defaultCurrency,
        selectedDate: targetMonth,
        viewMode: ViewMode.month,
      );

      // Cash flow in November:
      // Income: 10,000,000 + 250,000 = 10,250,000
      // Expense: 500,000 + 2,500 + 1,000,000 = 1,502,500
      expect(summary.totalIncome, 10250000);
      expect(summary.totalExpense, 1502500);
      expect(summary.netCashFlow, 8747500);

      // Saving growth: +3,000,000 (5,000,000 -> 8,000,000)
      expect(summary.savingOpening, 5000000);
      expect(summary.savingClosing, 8000000);
      expect(summary.savingGrowth, 3000000);

      // Invest growth: +2,250,000 (4,000,000 -> 6,250,000)
      expect(summary.investOpening, 4000000);
      expect(summary.investClosing, 6250000);
      expect(summary.investGrowth, 2250000);

      // Debt growth: +600,000 (2,000,000 -> 2,600,000)
      expect(summary.debtOpening, 2000000);
      expect(summary.debtClosing, 2600000);
      expect(summary.debtGrowth, 600000);

      // Cash account backed out Dec -100,000 properly:
      // Opening = 1,000,000, Closing = 5,097,500
      final cashSummary = summary.accountSummaries
          .firstWhere((a) => a.account.id == 'acc_cash');
      expect(cashSummary.displayOpening, 1000000);
      expect(cashSummary.displayClosing, 5097500);

      // Assets: 1M + 5M + 4M = 10M opening; 5,097,500 + 8M + 6.25M = 19,347,500 closing
      expect(summary.totalAssetsOpening, 10000000);
      expect(summary.totalAssetsClosing, 19347500);

      // Net Worth: 10M - 2M = 8M opening -> 19,347,500 - 2.6M = 16,747,500 closing
      expect(summary.netWorthOpening, 8000000);
      expect(summary.netWorthClosing, 16747500);
      expect(summary.netWorthGrowth, 8747500);
    });

    test('Generates valid PDF bytes even with emoji in transaction description',
        () async {
      final summary = MonthlyReportService.instance.calculateSummary(
        accounts: accounts,
        categories: categories,
        allTransactions: transactions,
        currency: CurrencyModel.defaultCurrency,
        selectedDate: targetMonth,
        viewMode: ViewMode.month,
      );

      final bytes = await MonthlyReportService.instance.generatePdfBytes(
        summary,
        accounts: accounts,
        categories: categories,
      );

      expect(bytes.length, greaterThan(1000));
      // Check PDF magic header "%PDF-"
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test(
        'Detects all 5 investment accounts including hidden ones and type variants',
        () async {
      final fiveInvestAccounts = [
        AccountModel(
          id: 'inv_1',
          name: 'Bibit Reksadana',
          type: 'invest',
          balance: 1500000,
        ),
        AccountModel(
          id: 'inv_2',
          name: 'Ajaib Saham',
          type: 'invest',
          hidden: true,
          balance: 2000000,
        ),
        AccountModel(
          id: 'inv_3',
          name: 'Emas Antam',
          type: 'Investment',
          hidden: true,
          balance: 3000000,
        ),
        AccountModel(
          id: 'inv_4',
          name: 'Obligasi Negara',
          type: 'investasi',
          balance: 4000000,
        ),
        AccountModel(
          id: 'inv_5',
          name: 'Crypto Wallet',
          type: 'investments',
          hidden: true,
          balance: 1000000,
        ),
      ];

      final summary = MonthlyReportService.instance.calculateSummary(
        accounts: fiveInvestAccounts,
        categories: categories,
        allTransactions: [
          TransactionModel(
            id: 'tx_inv_1',
            title: 'Beli Reksadana',
            amount: 500000,
            type: 'income',
            accountId: 'inv_1',
            createdAt: nov15.toString(),
          ),
          TransactionModel(
            id: 'tx_inv_2',
            title: 'Dividen Saham',
            amount: 250000,
            type: 'income',
            accountId: 'inv_2',
            createdAt: nov18.toString(),
          ),
        ],
        currency: CurrencyModel.defaultCurrency,
        selectedDate: targetMonth,
        viewMode: ViewMode.month,
      );

      final investType = summary.typeSummaries
          .firstWhere((t) => t.typeKey == 'invest');
      expect(investType.accountCount, 5);
      expect(summary.investClosing, 11500000);
      expect(summary.investGrowth, 750000);
      expect(summary.investOpening, 10750000);

      final bytes = await MonthlyReportService.instance.generatePdfBytes(
        summary,
        accounts: fiveInvestAccounts,
        categories: categories,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  group('StatsScreen PDF Button UI Tests', () {
    testWidgets(
        'StatsScreen displays PDF download icon next to calendar icon on 360px screen without overflow',
        (tester) async {
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

      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
