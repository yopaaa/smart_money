import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../../widgets/transaction_item.dart';
import '../transactions/transaction_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  final int? startDate;
  final int? endDate;
  final bool isStandalone;

  const GalleryScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.isStandalone = false,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<TransactionModel> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    final provider = context.read<TransactionProvider>();
    try {
      final txs = await provider.filterTransactions(
        startDate: widget.startDate,
        endDate: widget.endDate,
        hasImage: true,
      );
      if (mounted) {
        setState(() {
          _images = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_images.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 60,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada foto struk transaksi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Foto struk yang ditambahkan pada transaksi akan muncul di sini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final groupedList = AppDateUtils.groupTransactionsByDate(_images);
      final horizontalPadding = widget.isStandalone ? 16.0 : 0.0;

      content = ListView.builder(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          4.0,
          horizontalPadding,
          100.0,
        ),
        itemCount: groupedList.length,
        itemBuilder: (context, groupIndex) {
          final group = groupedList[groupIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header matching HistoryScreen
              TransactionDateHeader(
                group: group,
                currency: currency,
              ),
              const SizedBox(height: 8),

              // Grid of Photos for this date
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: group.transactions.length,
                itemBuilder: (context, itemIndex) {
                  final tx = group.transactions[itemIndex];
                  return _buildPhotoTile(context, tx, currency, isDark);
                },
              ),
              const SizedBox(height: 14),
            ],
          );
        },
      );
    }

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Galeri Foto Transaksi'),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildPhotoTile(
    BuildContext context,
    TransactionModel tx,
    dynamic currency,
    bool isDark,
  ) {
    final imagePath = tx.img ?? '';
    final file = File(imagePath);
    final fileExists = imagePath.isNotEmpty && file.existsSync();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13222D) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                ),
              ).then((_) => _loadImages());
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Photo Image or Placeholder
                fileExists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildBrokenImagePlaceholder(isDark),
                      )
                    : _buildBrokenImagePlaceholder(isDark),

                // 2. Bottom Gradient with Time (Jam) & Amount Overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(9),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.black.withOpacity(0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Jam (Time) formatted matching app standard
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat('HH:mm').format(tx.dateTime),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 3,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Amount with income/expense color
                        Text(
                          CurrencyFormatter.format(tx.amount, currency),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: tx.type == 'income'
                                ? const Color(0xFF4ADE80)
                                : Colors.white,
                            shadows: const [
                              Shadow(
                                blurRadius: 3,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrokenImagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
      ),
    );
  }
}
