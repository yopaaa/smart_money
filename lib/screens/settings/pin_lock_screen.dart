import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/security_provider.dart';

enum PinMode {
  verify,
  setup,
  change,
}

class PinLockScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;
  final bool canCancel;
  final String? customTitle;

  const PinLockScreen({
    super.key,
    this.mode = PinMode.verify,
    this.onSuccess,
    this.onCancel,
    this.canCancel = false,
    this.customTitle,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _enteredPin = '';
  String? _firstEnteredPin; // Used in setup/change mode
  String? _errorMessage;
  int _currentStep = 1; // For setup/change mode steps

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String digit) {
    if (_enteredPin.length >= _pinLength) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == _pinLength) {
      _processCompletePin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onBackspaceLongPress() {
    if (_enteredPin.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  Future<void> _processCompletePin() async {
    final security =
        Provider.of<SecurityProvider?>(context, listen: false) ??
            SecurityProvider.instance;

    if (widget.mode == PinMode.verify) {
      if (security.verifyPin(_enteredPin)) {
        HapticFeedback.mediumImpact();
        security.unlockSession();
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        _triggerError('PIN salah, silakan coba lagi');
      }
    } else if (widget.mode == PinMode.setup) {
      if (_currentStep == 1) {
        // Step 1: Save first entry and move to confirm
        _firstEnteredPin = _enteredPin;
        setState(() {
          _enteredPin = '';
          _currentStep = 2;
        });
      } else {
        // Step 2: Confirm
        if (_enteredPin == _firstEnteredPin) {
          HapticFeedback.mediumImpact();
          await security.setPin(_enteredPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN keamanan berhasil dibuat!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          }
        } else {
          _triggerError('PIN konfirmasi tidak cocok. Silakan ulangi.');
          setState(() {
            _currentStep = 1;
            _firstEnteredPin = null;
          });
        }
      }
    } else if (widget.mode == PinMode.change) {
      if (_currentStep == 1) {
        // Verify old PIN
        if (security.verifyPin(_enteredPin)) {
          setState(() {
            _enteredPin = '';
            _currentStep = 2;
          });
        } else {
          _triggerError('PIN lama salah, silakan coba lagi');
        }
      } else if (_currentStep == 2) {
        // Enter new PIN
        _firstEnteredPin = _enteredPin;
        setState(() {
          _enteredPin = '';
          _currentStep = 3;
        });
      } else {
        // Confirm new PIN
        if (_enteredPin == _firstEnteredPin) {
          HapticFeedback.mediumImpact();
          await security.setPin(_enteredPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN berhasil diperbarui!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          }
        } else {
          _triggerError('PIN konfirmasi tidak cocok. Silakan ulangi.');
          setState(() {
            _currentStep = 2;
            _firstEnteredPin = null;
          });
        }
      }
    }
  }

  void _triggerError(String message) {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0.0);
    setState(() {
      _errorMessage = message;
      _enteredPin = '';
    });
  }

  String _getTitle() {
    if (widget.customTitle != null) return widget.customTitle!;
    if (widget.mode == PinMode.verify) return 'Masukkan PIN';
    if (widget.mode == PinMode.setup) {
      return _currentStep == 1 ? 'Buat PIN Baru' : 'Konfirmasi PIN';
    }
    // Change mode
    if (_currentStep == 1) return 'Masukkan PIN Lama';
    if (_currentStep == 2) return 'Buat PIN Baru';
    return 'Konfirmasi PIN Baru';
  }

  String _getSubtitle() {
    if (widget.mode == PinMode.verify) {
      return 'Masukkan 4 digit PIN untuk membuka Smart Money';
    }
    if (widget.mode == PinMode.setup) {
      return _currentStep == 1
          ? 'Tentukan 4 digit PIN keamanan aplikasi Anda'
          : 'Masukkan ulang 4 digit PIN yang sama';
    }
    if (_currentStep == 1) return 'Verifikasi PIN Anda saat ini';
    if (_currentStep == 2) return 'Masukkan 4 digit PIN baru yang Anda inginkan';
    return 'Masukkan ulang 4 digit PIN baru untuk konfirmasi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor =
        isDark ? Colors.white60 : const Color(0xFF64748B);
    final keyButtonBg =
        isDark ? const Color(0xFF13222D) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top Bar with optional Cancel button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            if (widget.canCancel)
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                color: primaryTextColor,
                                onPressed: () {
                                  if (widget.onCancel != null) {
                                    widget.onCancel!();
                                  } else {
                                    Navigator.of(context).pop(false);
                                  }
                                },
                              )
                            else
                              const SizedBox(height: 40),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Lock / Shield Icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        _getTitle(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _getSubtitle(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // PIN Indicator Dots with Animated Shake
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final offset = _shakeAnimation.value *
                              math.sin(_shakeController.value * math.pi * 4);
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pinLength, (index) {
                            final isFilled = index < _enteredPin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: isFilled ? 18 : 16,
                              height: isFilled ? 18 : 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white12
                                        : const Color(0xFFCBD5E1)),
                                border: Border.all(
                                  color: isFilled
                                      ? AppColors.primary
                                      : (isDark
                                          ? Colors.white24
                                          : const Color(0xFF94A3B8)),
                                  width: 1.5,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),

                      // Error Message (if any)
                      SizedBox(
                        height: 28,
                        child: Center(
                          child: _errorMessage != null
                              ? Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.expense,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // const Spacer(),

                      // Keypad (3x4 grid)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          children: [
                            _buildKeypadRow(['1', '2', '3'], keyButtonBg, primaryTextColor),
                            const SizedBox(height: 10),
                            _buildKeypadRow(['4', '5', '6'], keyButtonBg, primaryTextColor),
                            const SizedBox(height: 10),
                            _buildKeypadRow(['7', '8', '9'], keyButtonBg, primaryTextColor),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Empty or Cancel Button
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: widget.canCancel
                                      ? InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            if (widget.onCancel != null) {
                                              widget.onCancel!();
                                            } else {
                                              Navigator.of(context).pop(false);
                                            }
                                          },
                                          child: Center(
                                            child: Text(
                                              'Batal',
                                              style: TextStyle(
                                                color: secondaryTextColor,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),

                                // Digit 0
                                _buildKeyButton('0', keyButtonBg, primaryTextColor),

                                // Backspace Button
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _onBackspacePressed,
                                    onLongPress: _onBackspaceLongPress,
                                    child: Center(
                                      child: Icon(
                                        Icons.backspace_outlined,
                                        size: 24,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypadRow(
    List<String> keys,
    Color bg,
    Color textCol,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeyButton(key, bg, textCol)).toList(),
    );
  }

  Widget _buildKeyButton(String digit, Color bg, Color textCol) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onKeyPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
