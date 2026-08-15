import 'package:flutter/material.dart';
import '../../features/bookmarks/presentation/bookmarks_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'floating_bottom_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LibraryScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  final List<FloatingBottomBarItem> _navItems = const [
    FloatingBottomBarItem(
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
      label: 'Library',
    ),
    FloatingBottomBarItem(
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_rounded,
      label: 'Bookmarks',
    ),
    FloatingBottomBarItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: FloatingBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _navItems,
      ),
    );
  }
}
