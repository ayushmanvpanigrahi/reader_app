import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/neumorphic_decorations.dart';
import '../../../../core/widgets/neumorphic_card.dart';
import '../../data/models/book_model.dart';

class BookGridCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const BookGridCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  static const List<List<Color>> _coverGradients = [
    [Color(0xFFC2703D), Color(0xFF8E481D)], // Muted Amber / Terra Cotta
    [Color(0xFF2C5E7A), Color(0xFF183B4E)], // Deep Ocean Blue
    [Color(0xFF4A6B53), Color(0xFF2B4733)], // Sage / Forest Green
    [Color(0xFF7A4A75), Color(0xFF4B2347)], // Plum / Vintage Wine
    [Color(0xFF8A6D3B), Color(0xFF5A431F)], // Antique Gold
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = _coverGradients[book.coverColorIndex % _coverGradients.length];

    return RepaintBoundary(
      child: NeumorphicCard(
        borderRadius: 20,
        depth: 4.0,
        padding: const EdgeInsets.all(10.0),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover View
            Expanded(
              child: Stack(
                children: [
                  // Stylized Book Cover with 3D spine and texture
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          offset: const Offset(2, 4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Left Spine Highlight
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Spine Crease line
                        Positioned(
                          left: 14,
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),

                        // Decorative Geometric Overlay
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Format Badge
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      book.isPdf ? 'PDF' : 'EPUB',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),

                                // Book Title & Author inside cover
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      book.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Favorite Button
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: Icon(
                          book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: book.isFavorite ? AppColors.lightDanger : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Title & Author below cover
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),

            const SizedBox(height: 8),

            // Reading Progress Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 5,
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [AppColors.darkPrimary, const Color(0xFFC2703D)]
                                  : [AppColors.lightPrimary, const Color(0xFFE57C20)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${book.progressPercentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
