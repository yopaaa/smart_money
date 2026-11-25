import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/currency_model.dart';
import '../models/transaction_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';

class AccountPeriodSummary {
  final AccountModel account;
  final String normalizedType;
  final bool isDebt;
  final int openingBalance;
  final int closingBalance;
  final int periodInflow;
  final int periodOutflow;
  final int netBalanceChange;

  const AccountPeriodSummary({
    required this.account,
    required this.normalizedType,
    required this.isDebt,
    required this.openingBalance,
    required this.closingBalance,
    required this.periodInflow,
    required this.periodOutflow,
    required this.netBalanceChange,
  });

  int get displayOpening => isDebt ? -openingBalance : openingBalance;
  int get displayClosing => isDebt ? -closingBalance : closingBalance;

  /// For assets: positive means balance increased.
  /// For liabilities (debt/credit card): positive means debt increased, negative means debt paid down.
  int get displayGrowth => isDebt ? -netBalanceChange : netBalanceChange;

  double? get growthPercent =>
      displayOpening != 0 ? (displayGrowth / displayOpening.abs()) * 100 : null;
}

class AccountTypeSummary {
  final String typeKey;
  final String label;
  final bool isLiability;
  final int openingTotal;
  final int closingTotal;
  final int inflow;
  final int outflow;
  final int growth;
  final int accountCount;

  const AccountTypeSummary({
    required this.typeKey,
    required this.label,
    required this.isLiability,
    required this.openingTotal,
    required this.closingTotal,
    required this.inflow,
    required this.outflow,
    required this.growth,
    required this.accountCount,
  });

  double? get growthPercent =>
      openingTotal != 0 ? (growth / openingTotal.abs()) * 100 : null;
}

class CategoryReportItem {
  final String categoryId;
  final String categoryName;
  final int amount;
  final int transactionCount;
  final double percent;

  const CategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.transactionCount,
    required this.percent,
  });
}

class MonthlyReportSummary {
  final String periodTitle;
  final ViewMode viewMode;
  final DateTime startDate;
  final DateTime endDate;
  final CurrencyModel currency;

  final int totalIncome;
  final int incomeCount;
  final int totalExpense;
  final int expenseCount;
  final int netCashFlow;
  final double savingRatePercent;

  final int totalTransfer;
  final int transferCount;
  final int totalTransferFee;

  final int savingOpening;
  final int savingClosing;
  final int savingGrowth;

  final int investOpening;
  final int investClosing;
  final int investGrowth;

  final int debtOpening;
  final int debtClosing;
  final int debtGrowth;

  final int otherAssetsOpening;
  final int otherAssetsClosing;
  final int otherAssetsGrowth;

  final int totalAssetsOpening;
  final int totalAssetsClosing;
  final int totalAssetsGrowth;

  final int netWorthOpening;
  final int netWorthClosing;
  final int netWorthGrowth;

  final List<AccountTypeSummary> typeSummaries;
  final List<AccountPeriodSummary> accountSummaries;
  final List<CategoryReportItem> expenseCategories;
  final List<CategoryReportItem> incomeCategories;

  const MonthlyReportSummary({
    required this.periodTitle,
    required this.viewMode,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.totalIncome,
    required this.incomeCount,
    required this.totalExpense,
    required this.expenseCount,
    required this.netCashFlow,
    required this.savingRatePercent,
    required this.totalTransfer,
    required this.transferCount,
    required this.totalTransferFee,
    required this.savingOpening,
    required this.savingClosing,
    required this.savingGrowth,
    required this.investOpening,
    required this.investClosing,
    required this.investGrowth,
    required this.debtOpening,
    required this.debtClosing,
    required this.debtGrowth,
    required this.otherAssetsOpening,
    required this.otherAssetsClosing,
    required this.otherAssetsGrowth,
    required this.totalAssetsOpening,
    required this.totalAssetsClosing,
    required this.totalAssetsGrowth,
    required this.netWorthOpening,
    required this.netWorthClosing,
    required this.netWorthGrowth,
    required this.typeSummaries,
    required this.accountSummaries,
    required this.expenseCategories,
    required this.incomeCategories,
  });
}

class MonthlyReportService {
  MonthlyReportService._();
  static final MonthlyReportService instance = MonthlyReportService._();

  static const Map<String, ({String name, bool isLiability})> _typeMetadata = {
    'cash': (name: 'Cash / Tunai', isLiability: false),
    'saving': (name: 'Saving Account', isLiability: false),
    'debit': (name: 'Debit Card', isLiability: false),
    'invest': (name: 'Investasi', isLiability: false),
    'expense-buffer': (name: 'Emergency Fund', isLiability: false),
    'receivable': (name: 'Piutang', isLiability: false),
    'card': (name: 'Credit Card', isLiability: true),
    'liability': (name: 'Liabilities', isLiability: true),
    'debt': (name: 'Hutang', isLiability: true),
    'other': (name: 'Lainnya', isLiability: false),
  };

  static const List<String> _typeOrder = [
    'cash',
    'saving',
    'debit',
    'invest',
    'expense-buffer',
    'receivable',
    'card',
    'liability',
    'debt',
    'other',
  ];

  /// Normalizes account type keys across casing and common aliases so all
  /// accounts (including legacy/imported saving, invest, and debt buckets)
  /// are detected consistently.
  static String normalizeAccountType(String rawType) {
    final t = rawType.trim().toLowerCase();
    if (t.isEmpty) return 'other';
    switch (t) {
      case 'invest':
      case 'investment':
      case 'investments':
      case 'investasi':
        return 'invest';
      case 'saving':
      case 'savings':
      case 'saving account':
      case 'saving_account':
      case 'saving-account':
      case 'tabungan':
      case 'bank':
        return 'saving';
      case 'debt':
      case 'hutang':
      case 'loan':
      case 'pinjaman':
        return 'debt';
      case 'liability':
      case 'liabilities':
      case 'kewajiban':
        return 'liability';
      case 'card':
      case 'credit card':
      case 'credit-card':
      case 'credit_card':
      case 'kartu kredit':
        return 'card';
      case 'cash':
      case 'tunai':
      case 'dompet':
        return 'cash';
      case 'debit':
      case 'debit card':
      case 'debit-card':
      case 'debit_card':
      case 'kartu debit':
        return 'debit';
      case 'receivable':
      case 'piutang':
        return 'receivable';
      case 'expense-buffer':
      case 'expense_buffer':
      case 'emergency fund':
      case 'emergency-fund':
      case 'emergency_fund':
      case 'dana darurat':
        return 'expense-buffer';
      default:
        return t;
    }
  }

  /// Computes complete cash-flow, category, account-type growth (saving,
  /// investment, debt/liabilities), and net-worth statistics for [selectedDate].
  MonthlyReportSummary calculateSummary({
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required List<TransactionModel> allTransactions,
    required CurrencyModel currency,
    required DateTime selectedDate,
    ViewMode viewMode = ViewMode.month,
  }) {
    final startDate = AppDateUtils.getStartOfPeriod(selectedDate, viewMode);
    final endDate = AppDateUtils.getEndOfPeriod(selectedDate, viewMode);
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    final categoryMap = {for (final c in categories) c.id: c};

    // Identify separate 'Biaya Admin' expense rows auto-generated alongside
    // transfers with fee > 0 in DatabaseHelper.addTransaction so we never
    // double-count the fee when reconstructing historical balances.
    final feeExpenseKeys = <String>{};
    for (final tx in allTransactions) {
      if (tx.type == 'expense' &&
          tx.category == 'Biaya Admin' &&
          tx.title == 'Biaya transfer') {
        final ts = int.tryParse(tx.createdAt) ?? 0;
        feeExpenseKeys.add('${tx.accountId}_${tx.amount}_$ts');
      }
    }

    bool hasPairedFeeExpense(TransactionModel transferTx) {
      if (transferTx.fee <= 0) return false;
      final ts = int.tryParse(transferTx.createdAt) ?? 0;
      return feeExpenseKeys
              .contains('${transferTx.accountId}_${transferTx.fee}_${ts + 1}') ||
          feeExpenseKeys
              .contains('${transferTx.accountId}_${transferTx.fee}_$ts');
    }

    final Map<String, int> afterPeriodDelta = {};
    final Map<String, int> inPeriodDelta = {};
    final Map<String, int> inPeriodInflow = {};
    final Map<String, int> inPeriodOutflow = {};

    int totalIncome = 0;
    int incomeCount = 0;
    int totalExpense = 0;
    int expenseCount = 0;
    int totalTransfer = 0;
    int transferCount = 0;
    int totalTransferFee = 0;

    final Map<String, ({int amount, int count})> expenseCatTotals = {};
    final Map<String, ({int amount, int count})> incomeCatTotals = {};

    for (final tx in allTransactions) {
      final ts = int.tryParse(tx.createdAt) ?? 0;
      final feeAlreadyInExpenseRow =
          tx.type == 'transfer' && hasPairedFeeExpense(tx);
      final effectiveTransferFee = feeAlreadyInExpenseRow ? 0 : tx.fee;

      if (ts > endMs) {
        if (tx.type == 'income') {
          afterPeriodDelta[tx.accountId] =
              (afterPeriodDelta[tx.accountId] ?? 0) + tx.amount;
        } else if (tx.type == 'expense') {
          afterPeriodDelta[tx.accountId] =
              (afterPeriodDelta[tx.accountId] ?? 0) - tx.amount;
        } else if (tx.type == 'transfer') {
          afterPeriodDelta[tx.accountId] =
              (afterPeriodDelta[tx.accountId] ?? 0) -
                  (tx.amount + effectiveTransferFee);
          if (tx.targetAccountId != null && tx.targetAccountId!.isNotEmpty) {
            afterPeriodDelta[tx.targetAccountId!] =
                (afterPeriodDelta[tx.targetAccountId!] ?? 0) + tx.amount;
          }
        }
        continue;
      }

      if (ts < startMs) {
        continue;
      }

      if (tx.type == 'income') {
        totalIncome += tx.amount;
        incomeCount++;

        inPeriodDelta[tx.accountId] =
            (inPeriodDelta[tx.accountId] ?? 0) + tx.amount;
        inPeriodInflow[tx.accountId] =
            (inPeriodInflow[tx.accountId] ?? 0) + tx.amount;

        final catKey = tx.category ?? 'uncategorized';
        final prev = incomeCatTotals[catKey];
        incomeCatTotals[catKey] = (
          amount: (prev?.amount ?? 0) + tx.amount,
          count: (prev?.count ?? 0) + 1,
        );
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
        expenseCount++;

        inPeriodDelta[tx.accountId] =
            (inPeriodDelta[tx.accountId] ?? 0) - tx.amount;
        inPeriodOutflow[tx.accountId] =
            (inPeriodOutflow[tx.accountId] ?? 0) + tx.amount;

        final catKey = tx.category ?? 'uncategorized';
        final prev = expenseCatTotals[catKey];
        expenseCatTotals[catKey] = (
          amount: (prev?.amount ?? 0) + tx.amount,
          count: (prev?.count ?? 0) + 1,
        );
      } else if (tx.type == 'transfer') {
        totalTransfer += tx.amount;
        transferCount++;
        totalTransferFee += tx.fee;

        inPeriodDelta[tx.accountId] = (inPeriodDelta[tx.accountId] ?? 0) -
            (tx.amount + effectiveTransferFee);
        inPeriodOutflow[tx.accountId] = (inPeriodOutflow[tx.accountId] ?? 0) +
            (tx.amount + effectiveTransferFee);

        if (tx.targetAccountId != null && tx.targetAccountId!.isNotEmpty) {
          inPeriodDelta[tx.targetAccountId!] =
              (inPeriodDelta[tx.targetAccountId!] ?? 0) + tx.amount;
          inPeriodInflow[tx.targetAccountId!] =
              (inPeriodInflow[tx.targetAccountId!] ?? 0) + tx.amount;
        }
      }
    }

    final netCashFlow = totalIncome - totalExpense;
    final savingRatePercent =
        totalIncome > 0 ? (netCashFlow / totalIncome) * 100.0 : 0.0;

    // Include ALL accounts (including hidden buckets) so every investment,
    // saving, and debt account is always read and summed accurately.
    final List<AccountPeriodSummary> accountSummaries = [];
    final Map<String, List<AccountPeriodSummary>> byType = {};

    int savingOpening = 0;
    int savingClosing = 0;
    int savingGrowth = 0;

    int investOpening = 0;
    int investClosing = 0;
    int investGrowth = 0;

    int debtOpening = 0;
    int debtClosing = 0;
    int debtGrowth = 0;

    int otherAssetsOpening = 0;
    int otherAssetsClosing = 0;
    int otherAssetsGrowth = 0;

    int totalAssetsOpening = 0;
    int totalAssetsClosing = 0;
    int totalAssetsGrowth = 0;

    for (final acc in accounts) {
      final periodDelta = inPeriodDelta[acc.id] ?? 0;
      final afterDelta = afterPeriodDelta[acc.id] ?? 0;
      final inflow = inPeriodInflow[acc.id] ?? 0;
      final outflow = inPeriodOutflow[acc.id] ?? 0;

      final closingRaw = acc.balance - afterDelta;
      final openingRaw = closingRaw - periodDelta;

      final typeKey = normalizeAccountType(acc.type);
      final meta = _typeMetadata[typeKey];
      final isLiability = acc.isLiability || (meta?.isLiability ?? false);

      final summary = AccountPeriodSummary(
        account: acc,
        normalizedType: typeKey,
        isDebt: isLiability,
        openingBalance: openingRaw,
        closingBalance: closingRaw,
        periodInflow: inflow,
        periodOutflow: outflow,
        netBalanceChange: periodDelta,
      );
      accountSummaries.add(summary);

      byType.putIfAbsent(typeKey, () => []).add(summary);

      if (isLiability) {
        debtOpening += summary.displayOpening;
        debtClosing += summary.displayClosing;
        debtGrowth += summary.displayGrowth;
      } else {
        totalAssetsOpening += summary.displayOpening;
        totalAssetsClosing += summary.displayClosing;
        totalAssetsGrowth += summary.displayGrowth;

        if (typeKey == 'saving') {
          savingOpening += summary.displayOpening;
          savingClosing += summary.displayClosing;
          savingGrowth += summary.displayGrowth;
        } else if (typeKey == 'invest') {
          investOpening += summary.displayOpening;
          investClosing += summary.displayClosing;
          investGrowth += summary.displayGrowth;
        } else {
          otherAssetsOpening += summary.displayOpening;
          otherAssetsClosing += summary.displayClosing;
          otherAssetsGrowth += summary.displayGrowth;
        }
      }
    }

    final netWorthOpening = totalAssetsOpening - debtOpening;
    final netWorthClosing = totalAssetsClosing - debtClosing;
    final netWorthGrowth = netWorthClosing - netWorthOpening;

    // Build sorted type summaries
    final List<AccountTypeSummary> typeSummaries = [];
    final allTypeKeys = {
      ..._typeOrder.where((k) => byType.containsKey(k)),
      ...byType.keys,
    };

    for (final key in allTypeKeys) {
      final list = byType[key];
      if (list == null || list.isEmpty) continue;

      final meta = _typeMetadata[key];
      final isLiability = meta?.isLiability ?? list.any((e) => e.isDebt);
      final label = meta?.name ?? key;

      int openSum = 0;
      int closeSum = 0;
      int inflowSum = 0;
      int outflowSum = 0;
      int growthSum = 0;

      for (final item in list) {
        openSum += item.displayOpening;
        closeSum += item.displayClosing;
        inflowSum += item.periodInflow;
        outflowSum += item.periodOutflow;
        growthSum += item.displayGrowth;
      }

      typeSummaries.add(
        AccountTypeSummary(
          typeKey: key,
          label: label,
          isLiability: isLiability,
          openingTotal: openSum,
          closingTotal: closeSum,
          inflow: inflowSum,
          outflow: outflowSum,
          growth: growthSum,
          accountCount: list.length,
        ),
      );
    }

    List<CategoryReportItem> buildCategoryList(
      Map<String, ({int amount, int count})> totalsMap,
      int grandTotal,
    ) {
      final items = totalsMap.entries.map((e) {
        final cat = categoryMap[e.key];
        final name = cat?.name ??
            (e.key == 'initial-balance'
                ? 'Saldo Awal'
                : e.key == 'Biaya Admin'
                    ? 'Biaya Admin'
                    : 'Lainnya');
        final pct =
            grandTotal > 0 ? (e.value.amount / grandTotal) * 100.0 : 0.0;
        return CategoryReportItem(
          categoryId: e.key,
          categoryName: name,
          amount: e.value.amount,
          transactionCount: e.value.count,
          percent: pct,
        );
      }).toList();
      items.sort((a, b) => b.amount.compareTo(a.amount));
      return items;
    }

    return MonthlyReportSummary(
      periodTitle: AppDateUtils.formatPeriodTitle(selectedDate, viewMode),
      viewMode: viewMode,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      totalIncome: totalIncome,
      incomeCount: incomeCount,
      totalExpense: totalExpense,
      expenseCount: expenseCount,
      netCashFlow: netCashFlow,
      savingRatePercent: savingRatePercent,
      totalTransfer: totalTransfer,
      transferCount: transferCount,
      totalTransferFee: totalTransferFee,
      savingOpening: savingOpening,
      savingClosing: savingClosing,
      savingGrowth: savingGrowth,
      investOpening: investOpening,
      investClosing: investClosing,
      investGrowth: investGrowth,
      debtOpening: debtOpening,
      debtClosing: debtClosing,
      debtGrowth: debtGrowth,
      otherAssetsOpening: otherAssetsOpening,
      otherAssetsClosing: otherAssetsClosing,
      otherAssetsGrowth: otherAssetsGrowth,
      totalAssetsOpening: totalAssetsOpening,
      totalAssetsClosing: totalAssetsClosing,
      totalAssetsGrowth: totalAssetsGrowth,
      netWorthOpening: netWorthOpening,
      netWorthClosing: netWorthClosing,
      netWorthGrowth: netWorthGrowth,
      typeSummaries: typeSummaries,
      accountSummaries: accountSummaries,
      expenseCategories: buildCategoryList(expenseCatTotals, totalExpense),
      incomeCategories: buildCategoryList(incomeCatTotals, totalIncome),
    );
  }

  /// Generates a clean formal Indonesian accounting statement PDF styled after
  /// classic 3-column financial cash-flow reports.
  Future<Uint8List> generatePdfBytes(
    MonthlyReportSummary summary, {
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
  }) async {
    final pdf = pw.Document(
      title: 'Laporan Keuangan - ${summary.periodTitle}',
      author: 'Smart Money',
    );

    const blackText = PdfColors.black;
    const mutedText = PdfColor.fromInt(0xFF4B5563);
    const borderColor = PdfColor.fromInt(0xFFCBD5E1);
    const softHeaderBg = PdfColor.fromInt(0xFFF1F5F9);

    final reportHeading = summary.viewMode == ViewMode.month
        ? 'Laporan Keuangan Bulanan'
        : 'Laporan Keuangan & Arus Kas';
    final rangeStr =
        '${DateFormat('dd MMM yyyy').format(summary.startDate)} - ${DateFormat('dd MMM yyyy').format(summary.endDate)}';
    final printedStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    String fmtAccounting(int amount, {bool zeroAsDash = true}) {
      if (amount == 0 && zeroAsDash) {
        return '${summary.currency.symbol} -';
      }
      final formatted = CurrencyFormatter.format(amount.abs(), summary.currency);
      if (amount < 0) {
        return '($formatted)';
      }
      return formatted;
    }

    String fmtPct(double? pct) {
      if (pct == null) return '-';
      final sign = pct > 0 ? '+' : '';
      return '$sign${pct.toStringAsFixed(1)}%';
    }

    final savingAccounts = summary.accountSummaries
        .where((a) => !a.isDebt && a.normalizedType == 'saving')
        .toList();
    final investAccounts = summary.accountSummaries
        .where((a) => !a.isDebt && a.normalizedType == 'invest')
        .toList();
    final debtAccounts =
        summary.accountSummaries.where((a) => a.isDebt).toList();
    final otherAssetTypes = summary.typeSummaries
        .where(
          (t) =>
              !t.isLiability && t.typeKey != 'saving' && t.typeKey != 'invest',
        )
        .toList();

    final statementRows = <pw.Widget>[
      // 1. Arus Kas dari Aktivitas Pemasukan & Pengeluaran
      _statementRow(
        label: 'Arus Kas dari Aktivitas Pemasukan & Pengeluaran',
        bold: true,
        indent: 0,
      ),
      _statementRow(
        label: 'Pemasukan (Income)',
        bold: true,
        indent: 12,
      ),
      if (summary.incomeCategories.isEmpty)
        _statementRow(
          label: 'Tidak ada pemasukan periode ini',
          indent: 24,
          col1: fmtAccounting(0),
          color: mutedText,
        )
      else
        ...List.generate(summary.incomeCategories.length, (i) {
          final c = summary.incomeCategories[i];
          final isLast = i == summary.incomeCategories.length - 1;
          return _statementRow(
            label:
                '${_sanitizePdfText(c.categoryName)} (${c.transactionCount}x, ${c.percent.toStringAsFixed(0)}%)',
            indent: 24,
            col1: fmtAccounting(c.amount, zeroAsDash: false),
            col1Underline: isLast,
          );
        }),
      _statementRow(
        label: 'Total Pemasukan (Income)',
        bold: true,
        indent: 12,
        col2: fmtAccounting(summary.totalIncome),
      ),

      pw.SizedBox(height: 4),
      _statementRow(
        label: 'Pengeluaran (Expense)',
        bold: true,
        indent: 12,
      ),
      if (summary.expenseCategories.isEmpty)
        _statementRow(
          label: 'Tidak ada pengeluaran periode ini',
          indent: 24,
          col1: fmtAccounting(0),
          color: mutedText,
        )
      else
        ...List.generate(summary.expenseCategories.length, (i) {
          final c = summary.expenseCategories[i];
          final isLast = i == summary.expenseCategories.length - 1;
          return _statementRow(
            label:
                '${_sanitizePdfText(c.categoryName)} (${c.transactionCount}x, ${c.percent.toStringAsFixed(0)}%)',
            indent: 24,
            col1: fmtAccounting(c.amount, zeroAsDash: false),
            col1Underline: isLast,
          );
        }),
      _statementRow(
        label: 'Total Pengeluaran (Expense)',
        bold: true,
        indent: 12,
        col2: fmtAccounting(-summary.totalExpense),
        col2Underline: true,
      ),
      _statementRow(
        label:
            'Arus Kas Bersih (${summary.netCashFlow >= 0 ? 'Surplus' : 'Defisit'} | Saving Rate: ${summary.savingRatePercent.toStringAsFixed(1)}%)',
        bold: true,
        indent: 12,
        col2: fmtAccounting(summary.netCashFlow),
      ),

      pw.SizedBox(height: 10),

      // 2. Aktivitas Tabungan (Saving)
      _statementRow(
        label:
            'Perubahan Tabungan / Saving Account (${savingAccounts.length} akun)',
        bold: true,
        indent: 0,
      ),
      if (savingAccounts.isEmpty)
        _statementRow(
          label: 'Belum ada akun Saving',
          indent: 14,
          col2: fmtAccounting(0),
          color: mutedText,
        )
      else ...[
        ...savingAccounts.map(
          (a) => _statementRow(
            label:
                '${_sanitizePdfText(a.account.name)} (${fmtAccounting(a.displayOpening, zeroAsDash: false)} -> ${fmtAccounting(a.displayClosing, zeroAsDash: false)})',
            indent: 14,
            col1: fmtAccounting(a.displayGrowth),
          ),
        ),
        _statementRow(
          label: 'Saldo Awal Saving',
          indent: 14,
          col1: fmtAccounting(summary.savingOpening),
        ),
        _statementRow(
          label: 'Saldo Akhir Saving',
          indent: 14,
          col1: fmtAccounting(summary.savingClosing),
          col1Underline: true,
        ),
        _statementRow(
          label: 'Kenaikan Bersih Saving',
          bold: true,
          indent: 14,
          col2: fmtAccounting(summary.savingGrowth),
        ),
      ],

      pw.SizedBox(height: 10),

      // 3. Aktivitas Investasi (Semua akun type invest)
      _statementRow(
        label:
            'Perubahan Investasi / Investment (${investAccounts.length} akun)',
        bold: true,
        indent: 0,
      ),
      if (investAccounts.isEmpty)
        _statementRow(
          label: 'Belum ada akun Investasi',
          indent: 14,
          col2: fmtAccounting(0),
          color: mutedText,
        )
      else ...[
        ...investAccounts.map(
          (a) => _statementRow(
            label:
                '${_sanitizePdfText(a.account.name)} (${fmtAccounting(a.displayOpening, zeroAsDash: false)} -> ${fmtAccounting(a.displayClosing, zeroAsDash: false)})',
            indent: 14,
            col1: fmtAccounting(a.displayGrowth),
          ),
        ),
        _statementRow(
          label: 'Saldo Awal Investasi',
          indent: 14,
          col1: fmtAccounting(summary.investOpening),
        ),
        _statementRow(
          label: 'Saldo Akhir Investasi',
          indent: 14,
          col1: fmtAccounting(summary.investClosing),
          col1Underline: true,
        ),
        _statementRow(
          label: 'Kenaikan Bersih Investasi',
          bold: true,
          indent: 14,
          col2: fmtAccounting(summary.investGrowth),
        ),
      ],

      pw.SizedBox(height: 10),

      // 4. Aktivitas Hutang & Kewajiban
      _statementRow(
        label:
            'Perubahan Hutang & Kewajiban (${debtAccounts.length} akun)',
        bold: true,
        indent: 0,
      ),
      if (debtAccounts.isEmpty)
        _statementRow(
          label: 'Tidak ada akun Hutang / Kewajiban',
          indent: 14,
          col2: fmtAccounting(0),
          color: mutedText,
        )
      else ...[
        ...debtAccounts.map(
          (a) => _statementRow(
            label:
                '${_sanitizePdfText(a.account.name)} (${fmtAccounting(a.displayOpening, zeroAsDash: false)} -> ${fmtAccounting(a.displayClosing, zeroAsDash: false)})',
            indent: 14,
            col1: fmtAccounting(a.displayGrowth),
          ),
        ),
        _statementRow(
          label: 'Total Hutang Awal Periode',
          indent: 14,
          col1: fmtAccounting(summary.debtOpening),
        ),
        _statementRow(
          label: 'Total Hutang Akhir Periode',
          indent: 14,
          col1: fmtAccounting(summary.debtClosing),
          col1Underline: true,
        ),
        _statementRow(
          label: 'Kenaikan / (Pelunasan) Jumlah Hutang',
          bold: true,
          indent: 14,
          col2: fmtAccounting(summary.debtGrowth),
        ),
      ],

      pw.SizedBox(height: 10),

      // 5. Aktivitas Aset Lainnya & Transfer
      _statementRow(
        label: 'Perubahan Aset Lainnya & Aktivitas Transfer',
        bold: true,
        indent: 0,
      ),
      ...otherAssetTypes.map(
        (t) => _statementRow(
          label:
              '${_sanitizePdfText(t.label)} (${t.accountCount} akun: ${fmtAccounting(t.openingTotal, zeroAsDash: false)} -> ${fmtAccounting(t.closingTotal, zeroAsDash: false)})',
          indent: 14,
          col1: fmtAccounting(t.growth),
        ),
      ),
      _statementRow(
        label:
            'Total Transfer Antar Akun (${summary.transferCount}x | Biaya Admin: ${fmtAccounting(summary.totalTransferFee)})',
        indent: 14,
        col1: fmtAccounting(summary.totalTransfer),
        col1Underline: true,
      ),
      _statementRow(
        label: 'Perubahan Bersih Aset Lainnya',
        bold: true,
        indent: 14,
        col2: fmtAccounting(summary.otherAssetsGrowth),
      ),

      pw.SizedBox(height: 12),

      // 6. Rekapitulasi Kekayaan Bersih (matching bottom block in reference image)
      _statementRow(
        label: 'Rekapitulasi Posisi & Kenaikan Kekayaan Bersih',
        bold: true,
        indent: 0,
      ),
      _statementRow(
        label: 'Kenaikan Total Aset (Saving + Investasi + Aset Lain)',
        indent: 14,
        col2: fmtAccounting(summary.totalAssetsGrowth),
      ),
      _statementRow(
        label: 'Pengaruh Perubahan Hutang terhadap Kekayaan Bersih',
        indent: 14,
        col2: fmtAccounting(-summary.debtGrowth),
        col2Underline: true,
      ),
      _statementRow(
        label: 'Kenaikan Bersih Kekayaan (Net Worth)',
        bold: true,
        indent: 14,
        col2: fmtAccounting(summary.netWorthGrowth),
      ),
      _statementRow(
        label: 'Kekayaan Bersih pada Awal Periode',
        indent: 14,
        col2: fmtAccounting(summary.netWorthOpening),
      ),
      _statementRow(
        label: 'Kekayaan Bersih pada Akhir Periode',
        bold: true,
        indent: 0,
        col2: fmtAccounting(summary.netWorthClosing, zeroAsDash: false),
        col2DoubleUnderline: true,
      ),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 34),
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Smart Money - ${_sanitizePdfText(reportHeading)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: mutedText,
                  ),
                ),
                pw.Text(
                  'Periode ${_sanitizePdfText(summary.periodTitle)}',
                  style: const pw.TextStyle(fontSize: 9, color: mutedText),
                ),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderColor, width: 0.7),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dicetak oleh Smart Money  |  $printedStr  |  Mata Uang: ${summary.currency.currency}',
                style: const pw.TextStyle(fontSize: 8, color: mutedText),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: mutedText),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Centered formal header block matching reference image
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Smart Money',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: blackText,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  reportHeading,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: blackText,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Periode ${_sanitizePdfText(summary.periodTitle)} ($rangeStr)',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: blackText,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1.5, color: blackText),
          pw.SizedBox(height: 14),

          // Main 3-column financial statement
          ...statementRows,

          pw.SizedBox(height: 22),

          // Lampiran: Ringkasan per Tipe Akun
          pw.Text(
            'Lampiran 1: Ringkasan Perubahan per Tipe Akun',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: blackText,
            ),
          ),
          pw.SizedBox(height: 6),
          if (summary.typeSummaries.isEmpty)
            pw.Text(
              'Belum ada akun yang tercatat.',
              style: const pw.TextStyle(fontSize: 9, color: mutedText),
            )
          else
            _buildStyledTable(
              headers: const [
                'Tipe Akun',
                'Status',
                'Posisi Awal',
                'Masuk',
                'Keluar',
                'Kenaikan / Perubahan',
                'Posisi Akhir',
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(0.9),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.4),
                5: const pw.FlexColumnWidth(2.0),
                6: const pw.FlexColumnWidth(1.5),
              },
              rows: summary.typeSummaries.map((t) {
                final pctStr = t.growthPercent != null
                    ? ' (${fmtPct(t.growthPercent)})'
                    : '';
                return _PdfTableRow(
                  cells: [
                    _PdfCell(
                      '${_sanitizePdfText(t.label)} (${t.accountCount} akun)',
                    ),
                    _PdfCell(t.isLiability ? 'Hutang' : 'Aset'),
                    _PdfCell(fmtAccounting(t.openingTotal), alignRight: true),
                    _PdfCell(fmtAccounting(t.inflow), alignRight: true),
                    _PdfCell(fmtAccounting(t.outflow), alignRight: true),
                    _PdfCell(
                      '${fmtAccounting(t.growth)}$pctStr',
                      alignRight: true,
                      bold: true,
                    ),
                    _PdfCell(
                      fmtAccounting(t.closingTotal),
                      alignRight: true,
                      bold: true,
                    ),
                  ],
                );
              }).toList(),
              borderColor: borderColor,
              headerBg: softHeaderBg,
              textColor: blackText,
            ),

          pw.SizedBox(height: 16),

          // Lampiran: Rincian Seluruh Akun
          pw.Text(
            'Lampiran 2: Rincian Seluruh Akun (${summary.accountSummaries.length} akun)',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: blackText,
            ),
          ),
          pw.SizedBox(height: 6),
          if (summary.accountSummaries.isEmpty)
            pw.Text(
              'Belum ada akun yang tercatat.',
              style: const pw.TextStyle(fontSize: 9, color: mutedText),
            )
          else
            _buildStyledTable(
              headers: const [
                'Nama Akun',
                'Tipe',
                'Awal',
                'Masuk',
                'Keluar',
                'Perubahan',
                'Akhir',
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.4),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.5),
              },
              rows: summary.accountSummaries.map((a) {
                final typeLabel =
                    _typeMetadata[a.normalizedType]?.name ?? a.account.type;
                return _PdfTableRow(
                  cells: [
                    _PdfCell(_sanitizePdfText(a.account.name)),
                    _PdfCell(_sanitizePdfText(typeLabel)),
                    _PdfCell(fmtAccounting(a.displayOpening), alignRight: true),
                    _PdfCell(fmtAccounting(a.periodInflow), alignRight: true),
                    _PdfCell(fmtAccounting(a.periodOutflow), alignRight: true),
                    _PdfCell(
                      fmtAccounting(a.displayGrowth),
                      alignRight: true,
                      bold: true,
                    ),
                    _PdfCell(
                      fmtAccounting(a.displayClosing),
                      alignRight: true,
                      bold: true,
                    ),
                  ],
                );
              }).toList(),
              borderColor: borderColor,
              headerBg: softHeaderBg,
              textColor: blackText,
            ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generates the PDF file in temporary storage and opens the OS share/save sheet.
  Future<File> exportAndShareReport({
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required List<TransactionModel> allTransactions,
    required CurrencyModel currency,
    required DateTime selectedDate,
    ViewMode viewMode = ViewMode.month,
    bool shareFile = true,
  }) async {
    final summary = calculateSummary(
      accounts: accounts,
      categories: categories,
      allTransactions: allTransactions,
      currency: currency,
      selectedDate: selectedDate,
      viewMode: viewMode,
    );

    final bytes = await generatePdfBytes(
      summary,
      accounts: accounts,
      categories: categories,
    );

    final tempDir = await getTemporaryDirectory();
    final safePeriod = summary.periodTitle
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = 'Laporan_Keuangan_$safePeriod.pdf';
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    if (shareFile) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Laporan Keuangan Smart Money - ${summary.periodTitle}',
      );
    }

    return file;
  }

  pw.Widget _statementRow({
    required String label,
    String col1 = '',
    String col2 = '',
    bool bold = false,
    double indent = 0,
    bool col1Underline = false,
    bool col2Underline = false,
    bool col2DoubleUnderline = false,
    PdfColor color = PdfColors.black,
  }) {
    final textStyle = pw.TextStyle(
      fontSize: 9.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );

    pw.Widget buildAmountCell(
      String text, {
      bool underline = false,
      bool doubleUnderline = false,
    }) {
      if (text.isEmpty) return pw.SizedBox.shrink();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            text,
            textAlign: pw.TextAlign.right,
            style: textStyle,
          ),
          if (underline || doubleUnderline) ...[
            pw.SizedBox(height: 2),
            pw.Container(height: 0.8, color: PdfColors.black),
          ],
          if (doubleUnderline) ...[
            pw.SizedBox(height: 1.5),
            pw.Container(height: 0.8, color: PdfColors.black),
          ],
        ],
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 54,
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: indent, right: 8),
              child: pw.Text(label, style: textStyle),
            ),
          ),
          pw.Expanded(
            flex: 23,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 8),
              child: buildAmountCell(col1, underline: col1Underline),
            ),
          ),
          pw.Expanded(
            flex: 23,
            child: buildAmountCell(
              col2,
              underline: col2Underline,
              doubleUnderline: col2DoubleUnderline,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStyledTable({
    required List<String> headers,
    required Map<int, pw.TableColumnWidth> columnWidths,
    required List<_PdfTableRow> rows,
    required PdfColor borderColor,
    required PdfColor headerBg,
    required PdfColor textColor,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.6),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          repeat: true,
          children: List.generate(headers.length, (i) {
            final isRight = rows.isNotEmpty &&
                i < rows.first.cells.length &&
                rows.first.cells[i].alignRight;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              child: pw.Text(
                headers[i],
                textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
            );
          }),
        ),
        ...rows.map((row) {
          return pw.TableRow(
            children: row.cells.map((cell) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                child: pw.Text(
                  cell.text,
                  textAlign:
                      cell.alignRight ? pw.TextAlign.right : pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontSize: 7.8,
                    fontWeight:
                        cell.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: textColor,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  /// Strips non-Latin1 characters (such as emojis) unsupported by PDF Type1 Helvetica.
  String _sanitizePdfText(String input) {
    final sanitized = input
        .replaceAll('\u2192', '->')
        .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'), '')
        .trim();
    return sanitized.isEmpty ? '-' : sanitized;
  }
}

class _PdfTableRow {
  final List<_PdfCell> cells;
  const _PdfTableRow({required this.cells});
}

class _PdfCell {
  final String text;
  final bool alignRight;
  final bool bold;

  const _PdfCell(
    this.text, {
    this.alignRight = false,
    this.bold = false,
  });
}
