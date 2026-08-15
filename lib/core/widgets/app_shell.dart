import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/bookmarks/presentation/bookmarks_screen.dart';
import '../../features/chat/controllers/chat_controller.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/library/controllers/library_controller.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/rag/controllers/rag_controller.dart';
import '../../features/rag/data/rag_models.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'floating_bottom_bar.dart';
import 'neumorphic_snackbar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LibraryScreen(),
    BookmarksScreen(),
    ChatScreen(),
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
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    FloatingBottomBarItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  String _bookTitle(String appBookId) {
    for (final book in ref.read(libraryControllerProvider).books) {
      if (book.id == appBookId) return book.title;
    }
    return appBookId;
  }

  void _showSnackbar(String message, NeoSnackbarType type) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NeumorphicSnackbar.show(context, message: message, type: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final notice = next.notice;
      if (notice != null && notice != previous?.notice) {
        _showSnackbar(notice, NeoSnackbarType.info);
        ref.read(chatControllerProvider.notifier).clearNotice();
        return;
      }
      final error = next.error;
      if (error != null && error != previous?.error) {
        _showSnackbar(error, NeoSnackbarType.error);
      }
    });

    ref.listen<RagState>(ragControllerProvider, (previous, next) {
      final prevBooks = previous?.books ?? const <String, RagBookIndex>{};
      for (final entry in next.books.entries) {
        final prevIndex = prevBooks[entry.key];
        final nextIndex = entry.value;
        if (nextIndex.status == RagBookStatus.failed &&
            prevIndex?.status != RagBookStatus.failed) {
          final title = _bookTitle(entry.key);
          final reason = (nextIndex.error?.isNotEmpty ?? false)
              ? ' — ${nextIndex.error}'
              : '';
          _showSnackbar('Indexing failed for “$title”.$reason', NeoSnackbarType.error);
        } else if (nextIndex.status == RagBookStatus.completed &&
            prevIndex?.status != RagBookStatus.completed) {
          final title = _bookTitle(entry.key);
          _showSnackbar('“$title” indexed — ready for RAG.', NeoSnackbarType.success);
        }
      }
    });

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
