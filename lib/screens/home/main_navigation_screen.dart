import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../constants/app_colors.dart';
import '../accounts/accounts_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/stats_screen.dart';
import '../transactions/transaction_form_screen.dart';
import 'history_screen.dart';

// Custom location untuk mengatur kedalaman posisi tombol tengah
class CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final double offsetY;

  const CustomFloatingActionButtonLocation({this.offsetY = 16.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2.0;
    final double fabY =
        scaffoldGeometry.contentBottom -
        (scaffoldGeometry.floatingActionButtonSize.height / 2.0) +
        offsetY;

    return Offset(fabX, fabY);
  }
}

// Custom Notched Shape untuk kehalusan sudut lekukan bar
class CustomNotchedShape extends NotchedShape {
  final double cornerRadius; // Menentukan kehalusan sudut lekukan dalam

  const CustomNotchedShape({this.cornerRadius = 15.0});

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }

    final double notchRadius = guest.width / 2.0;
    final double s1 = cornerRadius;
    final double s2 = notchRadius;

    final double r = s2;
    final double a = -1.0 * r - s1;
    final double b = host.top - guest.center.dy;
    final double n2 = (a * a + b * b);
    final double p = (a * a - b * b + (r + s1) * (r + s1)) / (2.0 * n2);

    // Jika guest keluar jalur perhitungan, kembalikan kotak biasa
    if (p < 0.0 || p > 1.0) {
      return Path()..addRect(host);
    }

    final double cx = guest.center.dx;
    final double cy = guest.center.dy;

    return Path()
      ..moveTo(host.left, host.top)
      ..lineTo(cx - notchRadius - cornerRadius, host.top)
      // Lekukan transisi masuk
      ..quadraticBezierTo(
        cx - notchRadius,
        host.top,
        cx - notchRadius,
        host.top + (cy - host.top > 0 ? (cy - host.top) * 0.5 : cornerRadius),
      )
      // Lekukan melingkari tombol
      ..arcToPoint(
        Offset(
          cx + notchRadius,
          host.top + (cy - host.top > 0 ? (cy - host.top) * 0.5 : cornerRadius),
        ),
        radius: Radius.circular(notchRadius),
        clockwise: false,
      )
      // Lekukan transisi keluar
      ..quadraticBezierTo(
        cx + notchRadius,
        host.top,
        cx + notchRadius + cornerRadius,
        host.top,
      )
      ..lineTo(host.right, host.top)
      ..lineTo(host.right, host.bottom)
      ..lineTo(host.left, host.bottom)
      ..close();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HistoryScreen(),
    StatsScreen(),
    AccountsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF0A1A24) : const Color(0xFFE5E7EB);
    final unselectedColor = isDark ? const Color(0xFF808080) : const Color(0xFF71717A);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: AppColors.primary,
          elevation: 4,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TransactionFormScreen(),
              ),
            );
          },
          child: const Icon(
            Ionicons.add,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),

      // Atur nilai offsetY di sini untuk kedalaman posisi tombol tengah
      floatingActionButtonLocation: const CustomFloatingActionButtonLocation(
        offsetY: 0,
      ),

      bottomNavigationBar: BottomAppBar(
        height: 90,
        padding: EdgeInsets.zero,
        shape: const CustomNotchedShape(cornerRadius: 15.0),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        color: navBgColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Ionicons.home,
                size: 28,
                color: _currentIndex == 0 ? AppColors.primary : unselectedColor,
              ),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              icon: Icon(
                Ionicons.analytics,
                size: 28,
                color: _currentIndex == 1 ? AppColors.primary : unselectedColor,
              ),
              onPressed: () => setState(() => _currentIndex = 1),
            ),

            const SizedBox(width: 40),

            IconButton(
              icon: Icon(
                Ionicons.albums,
                size: 28,
                color: _currentIndex == 2 ? AppColors.primary : unselectedColor,
              ),
              onPressed: () => setState(() => _currentIndex = 2),
            ),
            IconButton(
              icon: Icon(
                Ionicons.settings,
                size: 28,
                color: _currentIndex == 3 ? AppColors.primary : unselectedColor,
              ),
              onPressed: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}
