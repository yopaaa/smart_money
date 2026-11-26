import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/currency_model.dart';
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

class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin {
  static final DateFormat _timeFmt = DateFormat('HH:mm');

  List<GroupedTransaction> _groupedImages = const [];
  bool _isLoading = true;
  int _loadRequestId = 0;
  TransactionProvider? _provider;

  @override
  bool get wantKeepAlive => !widget.isStandalone;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TransactionProvider>();
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider?.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
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
    final requestId = ++_loadRequestId;
    final provider = _provider ?? context.read<TransactionProvider>();
    try {
      final txs = await provider.filterTransactions(
        startDate: widget.startDate,
        endDate: widget.endDate,
        hasImage: true,
      );
      final grouped = txs.isEmpty
          ? const <GroupedTransaction>[]
          : AppDateUtils.groupTransactionsByDate(txs);

      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _groupedImages = grouped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _computeThumbnailCacheWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ((screenWidth / 3.0) * dpr).round().clamp(180, 480);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currency = context.select<TransactionProvider, CurrencyModel>(
      (p) => p.currency,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_groupedImages.isEmpty) {
      content = RefreshIndicator(
        onRefresh: _loadImages,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48.0,
                    horizontal: 32.0,
                  ),
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
              ),
            ),
          ],
        ),
      );
    } else {
      final horizontalPadding = widget.isStandalone ? 16.0 : 0.0;
      final thumbCacheWidth = _computeThumbnailCacheWidth(context);

      content = RefreshIndicator(
        onRefresh: _loadImages,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            for (final group in _groupedImages) ...[
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TransactionDateHeader(
                      group: group,
                      currency: currency,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: 14.0,
                ),
                sliver: SliverGrid.builder(
                  addAutomaticKeepAlives: false,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: group.transactions.length,
                  itemBuilder: (context, itemIndex) {
                    final tx = group.transactions[itemIndex];
                    return RepaintBoundary(
                      child: _PhotoTile(
                        key: ValueKey(tx.id),
                        tx: tx,
                        currency: currency,
                        isDark: isDark,
                        thumbCacheWidth: thumbCacheWidth,
                        timeText: _timeFmt.format(tx.dateTime),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailScreen(transactionId: tx.id),
                            ),
                          ).then((_) => _loadImages());
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    }

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Galeri Foto Transaksi')),
        body: content,
      );
    }

    return content;
  }
}

class _PhotoTile extends StatelessWidget {
  final TransactionModel tx;
  final CurrencyModel currency;
  final bool isDark;
  final int thumbCacheWidth;
  final String timeText;
  final VoidCallback onTap;

  const _PhotoTile({
    super.key,
    required this.tx,
    required this.currency,
    required this.isDark,
    required this.thumbCacheWidth,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = tx.img ?? '';

    return Material(
      color: isDark ? const Color(0xFF13222D) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath.isNotEmpty)
              Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                cacheWidth: thumbCacheWidth,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _BrokenImagePlaceholder(isDark),
              )
            else
              _BrokenImagePlaceholder(isDark),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            timeText,
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
                      Text(
                        CurrencyFormatter.format(tx.amount, currency),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: tx.type == 'income'
                              ? const Color(0xFF4ADE80)
                              : Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.black87),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrokenImagePlaceholder extends StatelessWidget {
  final bool isDark;
  const _BrokenImagePlaceholder(this.isDark);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
