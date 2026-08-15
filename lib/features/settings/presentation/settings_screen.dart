import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../../ai_provider/presentation/provider_list_screen.dart';

import '../../../core/widgets/neumorphic_slider.dart';
import '../../../core/widgets/neumorphic_toggle.dart';
import '../../library/controllers/library_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final libraryState = ref.watch(libraryControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalBooks = libraryState.books.length;
    final totalPdfs = libraryState.books.where((b) => b.isPdf).length;
    final totalEpubs = libraryState.books.where((b) => b.isEpub).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Preferences & Sanctuary Customization',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Theme Mode Section
              _buildSectionHeader('Appearance & Theme', isDark),
              const SizedBox(height: 12),
              NeumorphicToggle<ThemeMode>(
                selectedValue: settings.themeMode,
                onSelected: (mode) => settingsController.setThemeMode(mode),
                items: const [
                  NeumorphicToggleItem(
                    value: ThemeMode.system,
                    label: 'System',
                    icon: Icons.brightness_auto_rounded,
                  ),
                  NeumorphicToggleItem(
                    value: ThemeMode.light,
                    label: 'Light',
                    icon: Icons.light_mode_rounded,
                  ),
                  NeumorphicToggleItem(
                    value: ThemeMode.dark,
                    label: 'Dark',
                    icon: Icons.dark_mode_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reader Default Typography
              _buildSectionHeader('Default Reader Typography', isDark),
              const SizedBox(height: 12),
              NeumorphicCard(
                borderRadius: 20,
                depth: 3.5,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Base Font Size',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        Text(
                          '${settings.defaultFontSize.toInt()} pt',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    NeumorphicSlider(
                      value: settings.defaultFontSize,
                      min: 12.0,
                      max: 32.0,
                      divisions: 10,
                      onChanged: (val) => settingsController.setFontSize(val),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preview Text:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The quick brown fox reads quietly in the tactile neomorphic sanctuary.',
                      style: TextStyle(
                        fontSize: settings.defaultFontSize,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Library Insights & Stats
              _buildSectionHeader('Library Insights', isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      label: 'Total Books',
                      value: '$totalBooks',
                      icon: Icons.menu_book_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      label: 'PDF Documents',
                      value: '$totalPdfs',
                      icon: Icons.picture_as_pdf_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      label: 'EPUB E-Books',
                      value: '$totalEpubs',
                      icon: Icons.auto_stories_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // AI Provider Configuration Entry
              _buildSectionHeader('AI Companion', isDark),
              const SizedBox(height: 12),
              NeumorphicCard(
                borderRadius: 20,
                depth: 3.5,
                padding: const EdgeInsets.all(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProviderListScreen()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.darkPrimary, AppColors.primary]
                              : [AppColors.lightPrimary, AppColors.primary],
                        ),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Provider Configuration',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Endpoint, models & usage intelligence',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    NeumorphicButton.icon(
                      icon: Icons.chevron_right_rounded,
                      size: 40,
                      iconSize: 18,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProviderListScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // About App Card
              NeumorphicCard(
                borderRadius: 20,
                depth: 3.5,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.darkPrimary, AppColors.primary]
                              : [AppColors.lightPrimary, AppColors.primary],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Neomorphic Reader v1.0',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Engineered with Clean Architecture, pdfrx & flutter_epub_viewer',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkInk : AppColors.lightInk,
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return NeumorphicCard(
      borderRadius: 18,
      depth: 3.0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
        ],
      ),
    );
  }
}
