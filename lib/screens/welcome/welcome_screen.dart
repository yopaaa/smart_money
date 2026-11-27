import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/backup_provider.dart';
import '../../providers/transaction_provider.dart';
import '../settings/drive_restore_sheet.dart';
import 'add_bucket_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Financial monitoring',
      'description': 'Keep your incomes and expenses on track',
      'image': 'assets/illustrations/financial.jpg',
    },
    {
      'title': 'Smart Analytics',
      'description': 'Get insights from your spending patterns',
      'image': 'assets/illustrations/Analytics.jpg',
    },
    {
      'title': 'Your Data is Safe',
      'description':
          'You store your own data locally. You can backup and restore anytime.',
      'image': 'assets/illustrations/security.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn(BackupProvider? backupProvider) async {
    _timer?.cancel();
    if (backupProvider == null) return;

    try {
      await backupProvider.signIn();
      if (!mounted) return;
      final txProvider = Provider.of<TransactionProvider?>(
        context,
        listen: false,
      );
      if (txProvider != null && backupProvider.driveBackups.isNotEmpty) {
        await showGoogleDriveRestoreSheet(
          context: context,
          backup: backupProvider,
          txProvider: txProvider,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Berhasil masuk dengan Google. Belum ada backup di Drive atau tap Restore dari Google Drive.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _openDriveRestore(BackupProvider backupProvider) async {
    _timer?.cancel();
    final txProvider = Provider.of<TransactionProvider?>(
      context,
      listen: false,
    );
    if (txProvider == null) return;
    await showGoogleDriveRestoreSheet(
      context: context,
      backup: backupProvider,
      txProvider: txProvider,
    );
  }

  Future<void> _showOnboardingRestoreOptions() async {
    _timer?.cancel();

    final backupProvider =
        Provider.of<BackupProvider?>(context, listen: false);
    final txProvider =
        Provider.of<TransactionProvider?>(context, listen: false);
    final isSignedIn = backupProvider?.isSignedIn == true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isSignedIn
                      ? 'Pilih Sumber Restore'
                      : 'Restore dari File Lokal',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSignedIn
                      ? 'Pulihkan data keuangan Anda dari Google Drive atau file backup lokal (.smbak).'
                      : 'Pilih file backup lokal (.smbak) atau masuk dengan Google terlebih dahulu untuk memulihkan dari Drive.',
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Theme.of(sheetCtx).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(sheetCtx).dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSignedIn) ...[
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.cloud_download_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Restore dari Google Drive',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Ambil snapshot & foto struk dari App Data Folder',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            if (!mounted ||
                                backupProvider == null ||
                                txProvider == null) {
                              return;
                            }
                            await showGoogleDriveRestoreSheet(
                              context: context,
                              backup: backupProvider,
                              txProvider: txProvider,
                            );
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.folder_open_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Restore dari File Lokal',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Pilih file .smbak, .zip, atau .db dari perangkat',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          if (!mounted) return;
                          await restoreFromLocalBackupFile(
                            context: context,
                            txProvider: txProvider,
                            backupProvider: backupProvider,
                            confirmOverwrite: false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupProvider = Provider.of<BackupProvider?>(context);
    final isSignedIn = backupProvider?.isSignedIn == true;
    final profile = backupProvider?.account;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Herzlich willkommen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 240),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                slide['image']!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          slide['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          slide['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Google Sign-In / Connected Drive Restore Card above GET STARTED
              if (!isSignedIn)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: (backupProvider?.isSigningIn ?? false)
                        ? null
                        : () => _handleGoogleSignIn(backupProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF1E293B),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: (backupProvider?.isSigningIn ?? false)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.login_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                    label: Text(
                      (backupProvider?.isSigningIn ?? false)
                          ? 'Menghubungkan ke Google...'
                          : 'Masuk dengan Google',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.14)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          (profile?.displayName ?? 'G')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Akun Google',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              profile?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: (backupProvider?.isRestoring ?? false)
                            ? null
                            : () => _openDriveRestore(backupProvider!),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text(
                          'Restore Drive',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Keluar akun Google',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        onPressed: () => backupProvider?.signOut(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddBucketScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'GET STARTED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showOnboardingRestoreOptions,
                child: const Text(
                  'RESTORE DATA',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
