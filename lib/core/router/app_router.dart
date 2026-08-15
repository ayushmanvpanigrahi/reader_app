import 'package:flutter/material.dart';
import '../../features/epub_reader/presentation/epub_reader_screen.dart';
import '../../features/library/data/models/book_model.dart';
import '../../features/pdf_reader/presentation/pdf_reader_screen.dart';
import '../widgets/app_shell.dart';

class AppRouter {
  static const String home = '/';
  static const String pdfReader = '/pdf-reader';
  static const String epubReader = '/epub-reader';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const AppShell(),
          settings: settings,
        );

      case pdfReader:
        final book = settings.arguments as BookModel;
        return _buildFadeThroughRoute(
          page: PdfReaderScreen(book: book),
          settings: settings,
        );

      case epubReader:
        final book = settings.arguments as BookModel;
        return _buildFadeThroughRoute(
          page: EpubReaderScreen(book: book),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const AppShell(),
          settings: settings,
        );
    }
  }

  static PageRouteBuilder _buildFadeThroughRoute({
    required Widget page,
    required RouteSettings settings,
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: end).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}
