import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/gemini_voice_service.dart';

class GeminiApiKeyDialog extends StatefulWidget {
  const GeminiApiKeyDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const GeminiApiKeyDialog(),
    );
  }

  @override
  State<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends State<GeminiApiKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  bool _isTesting = false;
  String? _testStatusMessage;
  bool? _isTestSuccess;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await GeminiVoiceService.instance.getApiKey();
    if (key != null && key.isNotEmpty && mounted) {
      _controller.text = key;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testStatusMessage = 'Silakan masukkan API key terlebih dahulu.';
        _isTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatusMessage = null;
      _isTestSuccess = null;
    });

    try {
      final success = await GeminiVoiceService.instance.testApiKey(key);
      if (mounted) {
        setState(() {
          _isTesting = false;
          _isTestSuccess = success;
          _testStatusMessage = success
              ? 'Koneksi Gemini API berhasil!'
              : 'Gagal terhubung. Pastikan API key valid.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _isTestSuccess = false;
          _testStatusMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final key = _controller.text.trim();
    await GeminiVoiceService.instance.saveApiKey(key);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key Gemini berhasil disimpan!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    await GeminiVoiceService.instance.removeApiKey();
    _controller.clear();
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key Gemini dihapus'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? theme.cardColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pengaturan Gemini AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan Google Gemini API Key Anda untuk mengaktifkan fitur pencatatan transaksi cerdas via suara.',
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Input Field
            TextField(
              controller: _controller,
              obscureText: _obscureText,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                labelText: 'API Key',
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureText = !_obscureText),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Test Connection Button & Status
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable_rounded, size: 16),
                  label: const Text('Tes Koneksi', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_controller.text.isNotEmpty)
                  TextButton(
                    onPressed: _handleDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Hapus Key', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            if (_testStatusMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_isTestSuccess == true
                          ? AppColors.income
                          : AppColors.expense)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testStatusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isTestSuccess == true
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'Tips: Dapatkan API Key gratis di aistudio.google.com (Google AI Studio).',
              style: TextStyle(
                fontSize: 11.5,
                color: subtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _handleSave,
          child: const Text('Simpan Key', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
