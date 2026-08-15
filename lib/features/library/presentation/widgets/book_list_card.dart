import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/neumorphic_decorations.dart';
import '../../../../core/widgets/neumorphic_card.dart';
import '../../data/models/book_model.dart';


class BookListCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const BookListCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  static const List<List<Color>> _coverGradients = [
    [Color(0xFFC2703D), Color(0xFF8E481D)],
    [Color(0xFF2C5E7A), Color(0xFF183B4E)],
    [Color(0xFF4A6B53), Color(0xFF2B4733)],
    [Color(0xFF7A4A75), Color(0xFF4B2347)],
    [Color(0xFF8A6D3B), Color(0xFF5A431F)],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = _coverGradients[book.coverColorIndex % _coverGradients.length];

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: NeumorphicCard(
          borderRadius: 18,
          depth: 3.5,
          padding: const EdgeInsets.all(12.0),
          onTap: onTap,
          child: Row(
            children: [
              // Mini 3D Book Cover
              Container(
                width: 58,
                height: 82,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(2, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.isPdf ? 'PDF' : 'EPUB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Details & Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: NeumorphicDecorations.boxDecoration(
                              context: context,
                              shape: NeumorphicShape.debossed,
                              borderRadius: 3,
                              depth: 1.5,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: book.progress.clamp(0.0, 1.0),
                                child: Container(
                                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${book.progressPercentage.toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Favorite & Menu
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: book.isFavorite ? AppColors.lightDanger : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                      size: 20,
                    ),
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                    color: isDark ? AppColors.darkPopover : AppColors.lightPaper,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppColors.lightDanger, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.lightDanger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
