import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// App-wide bottom navigation bar.
///
/// Add new tabs here as the app grows (Tutor search, Schedule, etc.).
/// Each screen that uses a bottom nav simply renders this widget and
/// passes its own [selectedIndex] + [onTap] handler.
///
/// Usage:
///   AppBottomNav(
///     selectedIndex: _selectedTab,
///     onTap: (i) => setState(() => _selectedTab = i),
///   )
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.brown,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:
          GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle:
          GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w400),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
