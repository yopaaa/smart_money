import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../constants/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../services/gemini_voice_service.dart';
import '../settings/gemini_api_key_dialog.dart';
import 'voice_transaction_review_sheet.dart';

/// Modal dialog with wave listening animation for recording transactions by voice.
class VoiceTransactionDialog extends StatefulWidget {
  final ValueChanged<String>? onSubmit;
  final VoidCallback? onCancel;

  const VoiceTransactionDialog({
    super.key,
    this.onSubmit,
    this.onCancel,
  });

  /// Helper static method to open the dialog with a smooth fade & scale transition.
  static Future<void> show({
    required BuildContext context,
    ValueChanged<String>? onSubmit,
    VoidCallback? onCancel,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VoiceTransactionDialog',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return VoiceTransactionDialog(
          onSubmit: onSubmit,
          onCancel: onCancel,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * anim1.value,
            sigmaY: 6 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<VoiceTransactionDialog> createState() => _VoiceTransactionDialogState();
}

class _VoiceTransactionDialogState extends State<VoiceTransactionDialog>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _barsController;
  late final AnimationController _pulseController;
  late final AnimationController _aiSpinController;

  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordedFilePath;
  String? _errorMessage;
  bool _isApiKeyMissing = false;

  Timer? _hintTimer;
  Timer? _amplitudeTimer;
  double _currentAmplitudeLevel = 0.5;
  int _hintIndex = 0;

  final List<String> _hintPrompts = [
    'Beli kopi 25 ribu dari BCA',
    'Makan siang 35 ribu pakai Gopay',
    'Gaji bulanan masuk 8 juta ke Mandiri',
    'Beli bensin 50 ribu tunai',
    'Bayar tagihan listrik 150 ribu dari BCA',
  ];

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _aiSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _hintIndex = (_hintIndex + 1) % _hintPrompts.length;
        });
      }
    });

    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Izin mikrofon tidak diberikan.';
          });
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 24000,
      );

      await _audioRecorder.start(config, path: filePath);
      _recordedFilePath = filePath;
      if (mounted) {
        setState(() {
          _isRecording = true;
          _errorMessage = null;
        });
      }

      // Periodically check amplitude to animate soundwaves dynamically
      _amplitudeTimer =
          Timer.periodic(const Duration(milliseconds: 120), (_) async {
        try {
          if (_isRecording) {
            final amp = await _audioRecorder.getAmplitude();
            if (mounted && amp.current > -80.0) {
              // Normalize -60dB to 0dB into 0.1 .. 1.0
              final normalized = ((amp.current + 60) / 60).clamp(0.15, 1.0);
              setState(() => _currentAmplitudeLevel = normalized);
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Voice recording start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _amplitudeTimer?.cancel();
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null && path.isNotEmpty) {
          _recordedFilePath = path;
        }
      } catch (e) {
        debugPrint('Voice recording stop error: $e');
      } finally {
        if (mounted) {
          setState(() => _isRecording = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _hintTimer?.cancel();
    _waveController.dispose();
    _barsController.dispose();
    _pulseController.dispose();
    _aiSpinController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    HapticFeedback.mediumImpact();

    // If caller provided custom onSubmit (e.g. widget test), call it directly
    if (widget.onSubmit != null) {
      final sampleTranscript = _hintPrompts[_hintIndex];
      widget.onSubmit!(sampleTranscript);
      return;
    }

    // Stop recording first
    await _stopRecording();

    // Check Gemini API key
    final hasKey = await GeminiVoiceService.instance.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        setState(() {
          _isApiKeyMissing = true;
          _errorMessage =
              'API Key Gemini belum diatur. Silakan atur API Key terlebih dahulu.';
        });
      }
      return;
    }

    final filePath = _recordedFilePath;
    final file = filePath != null ? File(filePath) : null;
    if (file == null || !file.existsSync() || file.lengthSync() == 0) {
      // Fallback: If no audio file was recorded, notify user
      if (mounted) {
        setState(() {
          _errorMessage =
              'Tidak ada rekaman audio terdeteksi. Silakan coba rekam lagi.';
        });
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _isApiKeyMissing = false;
    });

    if (!mounted) return;

    try {
      final txProvider = context.read<TransactionProvider>();
      final parsedTransactions =
          await GeminiVoiceService.instance.parseAudioToTransactions(
        audioFile: file,
        accounts: txProvider.accounts,
        categories: txProvider.categories,
        currency: txProvider.currency,
      );

      if (!mounted) return;

      // Close this voice dialog
      Navigator.of(context).pop();

      // Open the Review Bottom Sheet with all parsed transactions
      VoiceTransactionReviewSheet.show(
        context: context,
        transactions: parsedTransactions,
        transcript: GeminiVoiceService.instance.lastTranscript,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _handleCancel() {
    _stopRecording();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openApiKeySetting() async {
    final saved = await GeminiApiKeyDialog.show(context);
    if (saved == true && mounted) {
      setState(() {
        _isApiKeyMissing = false;
        _errorMessage = null;
      });
      _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title & Subtitle
                Text(
                  _isProcessing ? 'Menganalisis Suara...' : 'Mendengarkan...',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isProcessing
                      ? 'Gemini AI sedang mengekstrak transaksi Anda'
                      : 'Ucapkan transaksi Anda secara jelas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 28),

                // Center Wave Animation / AI Processing Orb
                SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric Ripple Waves (while recording)
                      if (!_isProcessing)
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(150, 150),
                              painter: _RippleWavePainter(
                                progress: _waveController.value,
                                waveColor: AppColors.primary,
                              ),
                            );
                          },
                        ),

                      // Rotating gradient ring when processing
                      if (_isProcessing)
                        RotationTransition(
                          turns: _aiSpinController,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.0),
                                  AppColors.primary,
                                  const Color(0xFF38BDF8),
                                  AppColors.primary.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Central Glowing Mic Orb with Pulse
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF0284C7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.55),
                                blurRadius: 22,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _isProcessing
                                  ? Icons.auto_awesome_rounded
                                  : Ionicons.mic,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Animated Live Soundwave Bars
                SizedBox(
                  height: 32,
                  child: AnimatedBuilder(
                    animation: _barsController,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(9, (index) {
                          final phase = index * 0.45;
                          final value = math.sin(
                            (_barsController.value * 2 * math.pi) + phase,
                          );
                          final normalized =
                              ((value + 1) / 2).clamp(0.15, 1.0) *
                                  (_isProcessing ? 0.3 : _currentAmplitudeLevel);
                          final height = 6.0 + (normalized * 22.0);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: 3.5,
                            height: height,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.35 + (normalized * 0.65),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Error Message Box (if any)
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.expense.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_isApiKeyMissing) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _openApiKeySetting,
                            icon: const Icon(Icons.key_rounded, size: 16),
                            label: const Text(
                              'Atur API Key',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              setState(() => _errorMessage = null);
                              _startRecording();
                            },
                            child: const Text(
                              'Coba Rekam Lagi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Hint Prompt Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Contoh yang bisa diucapkan:',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            '"${_hintPrompts[_hintIndex]}"',
                            key: ValueKey<int>(_hintIndex),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _handleSubmit,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Ionicons.checkmarkCircle, size: 20),
                    label: Text(
                      _isProcessing ? 'Menganalisis...' : 'Selesai / Submit',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Cancel Text Button
                TextButton(
                  onPressed: _isProcessing ? null : _handleCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
}

/// Custom painter for rendering concentric ripples radiating outwards.
class _RippleWavePainter extends CustomPainter {
  final double progress;
  final Color waveColor;

  _RippleWavePainter({
    required this.progress,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const int waveCount = 3;
    const double minRadius = 40.0;
    final double maxRadius = size.width / 2;

    for (int i = 0; i < waveCount; i++) {
      final double waveProgress = (progress + (i / waveCount)) % 1.0;
      final double currentRadius =
          minRadius + (waveProgress * (maxRadius - minRadius));
      final double opacity = (1.0 - waveProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = waveColor.withOpacity(opacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1.0 - waveProgress * 0.5);

      canvas.drawCircle(center, currentRadius, paint);

      final fillPaint = Paint()
        ..color = waveColor.withOpacity(opacity * 0.08)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, currentRadius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveColor != waveColor;
  }
}
