import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/transaction_provider.dart';

class FileExportScreen extends StatefulWidget {
  const FileExportScreen({super.key});

  @override
  State<FileExportScreen> createState() => _FileExportScreenState();
}

class _FileExportScreenState extends State<FileExportScreen> {
  bool _isExportingCsv = false;
  bool _isExportingExcel = false;

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final provider = context.read<TransactionProvider>();
      final txs = await provider.filterTransactions();

      final buffer = StringBuffer();
      buffer.writeln('Date,Type,Category,Amount,Account,Note');

      for (var tx in txs) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.dateTime);
        final category = provider.getCategoryById(tx.category)?.name ?? tx.category ?? '';
        final account = provider.findAccount(tx.accountId)?.name ?? tx.accountId;
        final title = tx.title.replaceAll(',', ' ');
        final note = (tx.description ?? '').replaceAll(',', ' ');

        buffer.writeln('$dateStr,${tx.type},$category,${tx.amount},$account,$title - $note');
      }

      final tempDir = await getTemporaryDirectory();
      final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'smart_money_export_$dateSlug.csv'));
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Smart Money CSV Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExportingExcel = true);
    try {
      final provider = context.read<TransactionProvider>();
      final txs = await provider.filterTransactions();

      final buffer = StringBuffer();
      buffer.writeln('Tanggal\tTipe\tKategori\tJumlah\tAkun\tCatatan');

      for (var tx in txs) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.dateTime);
        final category = provider.getCategoryById(tx.category)?.name ?? tx.category ?? '';
        final account = provider.findAccount(tx.accountId)?.name ?? tx.accountId;
        final title = tx.title.replaceAll('\t', ' ');
        final note = (tx.description ?? '').replaceAll('\t', ' ');

        buffer.writeln('$dateStr\t${tx.type}\t$category\t${tx.amount}\t$account\t$title - $note');
      }

      final tempDir = await getTemporaryDirectory();
      final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'smart_money_export_$dateSlug.xls'));
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.ms-excel')],
        subject: 'Smart Money Excel Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CSV Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Ionicons.documentTextOutline, color: const Color(0xFF27AE60), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Export CSV',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export all transactions as a CSV spreadsheet file compatible with Google Sheets, Excel, and other tools.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27AE60),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isExportingCsv ? null : _exportCsv,
                    icon: _isExportingCsv
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Ionicons.downloadOutline, size: 20),
                    label: Text(_isExportingCsv ? 'Exporting...' : 'Export CSV'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Excel Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Ionicons.gridOutline, color: const Color(0xFF2980B9), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Export Excel (XLS)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export all transactions formatted for Microsoft Excel with Indonesian column headers.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2980B9),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isExportingExcel ? null : _exportExcel,
                    icon: _isExportingExcel
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Ionicons.downloadOutline, size: 20),
                    label: Text(_isExportingExcel ? 'Exporting...' : 'Export Excel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
