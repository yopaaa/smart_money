import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../services/image_sync_service.dart';

class ImageSyncScreen extends StatefulWidget {
  final ImageSyncService? service;

  const ImageSyncScreen({super.key, this.service});

  @override
  State<ImageSyncScreen> createState() => _ImageSyncScreenState();
}

class _ImageSyncScreenState extends State<ImageSyncScreen> {
  ImageSyncService get _service => widget.service ?? ImageSyncService.instance;

  ImageSyncSummary? _summary;
  bool _isLoadingSummary = true;
  bool _isExporting = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary({bool requestPermission = false}) async {
    if (mounted) {
      setState(() => _isLoadingSummary = true);
    }
    try {
      final summary = await _service.getSummary(
        requestPermission: requestPermission,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _handleExportImages() async {
    setState(() => _isExporting = true);
    try {
      final res = await _service.exportToPublicFolder();
      await _loadSummary();
      if (!mounted) return;
      final msg =
          'Export selesai: ${res.copied} foto baru disalin, ${res.skipped} sudah sinkron'
          '${res.failed > 0 ? ', ${res.failed} gagal' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              res.failed > 0 ? Colors.orange.shade800 : AppColors.income,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export gambar: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleRestoreImages() async {
    setState(() => _isRestoring = true);
    try {
      final res = await _service.restoreFromPublicFolder();
      if (mounted) {
        await context.read<TransactionProvider>().loadData();
      }
      await _loadSummary();
      if (!mounted) return;
      final msg =
          'Restore selesai: ${res.copied} foto dipulihkan, ${res.skipped} sudah ada'
          '${res.remappedTransactions > 0 ? ', ${res.remappedTransactions} transaksi terhubung' : ''}'
          '${res.failed > 0 ? ', ${res.failed} gagal' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              res.failed > 0 ? Colors.orange.shade800 : AppColors.income,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal restore gambar: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleRestoreFromCustomFolder() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir == null || selectedDir.isEmpty) return;

    setState(() => _isRestoring = true);
    try {
      final res = await _service.restoreFromDirectory(selectedDir);
      if (mounted) {
        await context.read<TransactionProvider>().loadData();
      }
      await _loadSummary();
      if (!mounted) return;
      final msg =
          'Import folder selesai: ${res.copied} foto disalin, ${res.skipped} dilewati, '
          '${res.remappedTransactions} transaksi terhubung';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.income,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal import folder: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final borderColor = isDark ? theme.dividerColor : Colors.grey.shade200;
    final subtextColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final busy = _isExporting || _isRestoring;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export & Restore Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Periksa ulang folder',
            onPressed: busy
                ? null
                : () => _loadSummary(requestPermission: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Folder & Status Overview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_copy_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Folder Sinkronisasi Gambar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ImageSyncService.displayFolderPath,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingSummary)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _StatChip(
                            label: 'Di Aplikasi',
                            value: '${_summary?.localReceiptCount ?? 0} foto',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatChip(
                            label: 'Di Pictures/SmartMoney',
                            value: '${_summary?.publicFolderCount ?? 0} foto',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Export Card (Internal -> /sdcard/Pictures/SmartMoney)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Image',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sinkronkan foto struk dari penyimpanan internal aplikasi ke ${ImageSyncService.displayFolderPath}. Hanya foto yang belum ada di folder tujuan yang akan disalin.',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                      height: 1.4,
                    ),
                  ),
                  if (_summary != null && _summary!.pendingExportCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_summary!.pendingExportCount} foto baru siap diekspor',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : _handleExportImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 19),
                      label: Text(
                        _isExporting ? 'Mengekspor...' : 'Export Image',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Restore Card (/sdcard/Pictures/SmartMoney -> Internal)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Restore Image',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sinkronkan balik foto dari ${ImageSyncService.displayFolderPath} ke penyimpanan internal aplikasi dan hubungkan ulang ke riwayat transaksi lama.',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                      height: 1.4,
                    ),
                  ),
                  if (_summary != null &&
                      _summary!.pendingRestoreCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_summary!.pendingRestoreCount} foto di folder belum ada di aplikasi',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _handleRestoreImages,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 19),
                      label: Text(
                        _isRestoring ? 'Memulihkan...' : 'Restore Image',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: busy ? null : _handleRestoreFromCustomFolder,
                      icon: const Icon(Icons.folder_open_rounded, size: 17),
                      label: const Text(
                        'Atau pilih folder lain...',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
