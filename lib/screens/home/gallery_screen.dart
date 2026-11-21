import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
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
    if (widget.startDate != oldWidget.startDate || widget.endDate != oldWidget.endDate) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    final provider = context.read<TransactionProvider>();
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
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_images.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No transaction receipts found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      content = GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final tx = _images[index];
          final imagePath = tx.img ?? '';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: File(imagePath).existsSync()
                  ? Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.2),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
            ),
          );
        },
      );
    }

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gallery'),
        ),
        body: content,
      );
    }

    return content;
  }
}
