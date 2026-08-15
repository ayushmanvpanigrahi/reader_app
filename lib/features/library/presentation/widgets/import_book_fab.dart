import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/widgets/neumorphic_button.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';

class ImportBookFab extends ConsumerWidget {
  final ValueChanged<BookModel>? onBookImported;

  const ImportBookFab({super.key, this.onBookImported});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NeumorphicButton(
      isCircle: false,
      isAccent: true,
      borderRadius: 26,
      depth: 4.5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      onPressed: () async {
        final importedBook =
            await ref.read(libraryControllerProvider.notifier).importFile();

        if (context.mounted && importedBook != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported "${importedBook.title}"',
                style: TextStyle(
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              action: SnackBarAction(
                label: 'Read Now',
                textColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                onPressed: () {
                  onBookImported?.call(importedBook);
                },
              ),
            ),
          );

          onBookImported?.call(importedBook);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_rounded,
            color: isDark ? AppColors.darkPrimaryForeground : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Import Book',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimaryForeground : Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
