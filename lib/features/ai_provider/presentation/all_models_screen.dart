import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/ai_model_info.dart';
import '../data/models/ai_provider.dart';
import '../domain/notifiers/active_provider_notifier.dart';
import '../domain/notifiers/provider_list_notifier.dart';
import '../domain/providers.dart';
import 'extensions.dart';
import 'widgets/neo_text_field.dart';

/// Cross-provider model catalog. Every cached model from every configured
/// provider, filterable by category / family / text search, grouped by
/// category. Tapping an embedding model sets it as the active embedding model;
/// tapping a text model sets it as the active chat model (switching the active
/// provider when the model lives elsewhere).
class AllModelsScreen extends ConsumerStatefulWidget {
  const AllModelsScreen({super.key});

  @override
  ConsumerState<AllModelsScreen> createState() => _AllModelsScreenState();
}

class _AllModelsScreenState extends ConsumerState<AllModelsScreen> {
  ModelCategory? _category;
  ModelFamily? _family;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providers =
        ref.watch(providerListProvider).valueOrNull ?? const <AIProvider>[];
    final modelRepo = ref.watch(modelRepositoryProvider);
    final active = ref.watch(activeProviderProvider).value;

    final all = <({AIProvider provider, AIModelInfo model})>[];
    for (final p in providers) {
      for (final m in modelRepo.cached(p.id) ?? const <AIModelInfo>[]) {
        all.add((provider: p, model: m));
      }
    }

    final query = _query.trim().toLowerCase();
    final filtered = all.where((e) {
      if (_category != null && e.model.category != _category) return false;
      if (_family != null && e.model.family != _family) return false;
      if (query.isNotEmpty && !e.model.id.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    final rows = <_CatalogRow>[];
    for (final category in ModelCategory.values) {
      if (filtered.isEmpty) break;
      final inCategory =
          filtered.where((e) => e.model.category == category).toList();
      if (inCategory.isEmpty) continue;
      rows.add(_CatalogRow.header(category: category, count: inCategory.length));
      for (final e in inCategory) {
        rows.add(_CatalogRow.model(provider: e.provider, model: e.model));
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Models', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: NeoTextField(
              label: '',
              hint: 'Search models…',
              initialValue: '',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          _ChipRow(
            isDark: isDark,
            chips: [
              _FilterChipData(
                label: 'All',
                icon: Icons.apps_rounded,
                selected: _category == null,
                count: all.length,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in ModelCategory.values)
                _FilterChipData(
                  label: c.label,
                  icon: c.icon,
                  selected: _category == c,
                  count: all.where((e) => e.model.category == c).length,
                  onTap: () => setState(() => _category = _category == c ? null : c),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _ChipRow(
            isDark: isDark,
            chips: [
              for (final f in ModelFamily.values)
                if (all.any((e) => e.model.family == f))
                  _FilterChipData(
                    label: f.label,
                    icon: Icons.label_rounded,
                    selected: _family == f,
                    count: all.where((e) => e.model.family == f).length,
                    onTap: () => setState(() => _family = _family == f ? null : f),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty
                          ? 'No models cached yet.\nFetch a provider catalog first.'
                          : 'No models match the current filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return row.isHeader
                          ? _HeaderRow(
                              category: row.category!,
                              count: row.count!,
                              isDark: isDark,
                            )
                          : _ModelRow(
                              provider: row.provider!,
                              model: row.model!,
                              isDark: isDark,
                              isActiveChat: active?.chatModelId == row.model!.id,
                              isActiveEmbedding: active?.embeddingModelId == row.model!.id,
                              onTap: () => _activate(row.provider!, row.model!),
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _activate(AIProvider provider, AIModelInfo model) async {
    final isEmbedding = model.category == ModelCategory.embedding;
    final notifier = ref.read(activeProviderProvider.notifier);
    final active = ref.read(activeProviderProvider).value;
    if (active?.provider?.id != provider.id) {
      await notifier.setActiveProvider(provider.id);
    }
    if (isEmbedding) {
      await notifier.selectEmbeddingModel(model.id);
    } else {
      await notifier.selectChatModel(model.id);
    }
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
          content: Row(
            children: [
              Icon(
                isEmbedding ? Icons.grain_rounded : Icons.chat_bubble_rounded,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${isEmbedding ? 'Embedding' : 'Chat'} model set: ${model.id}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _FilterChipData {
  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _FilterChipData({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.onTap,
  });
}

class _ChipRow extends StatelessWidget {
  final bool isDark;
  final List<_FilterChipData> chips;

  const _ChipRow({required this.isDark, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PillChip(
                isDark: isDark,
                chip: chip,
              ),
            ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final bool isDark;
  final _FilterChipData chip;

  const _PillChip({required this.isDark, required this.chip});

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final Color bg;
    final Color fg;
    final Color border;
    final Color countColor;
    if (chip.selected) {
      bg = isDark ? AppColors.darkPrimaryTint : accent.withValues(alpha: 0.16);
      fg = isDark ? AppColors.darkPrimaryLight : accent;
      border = accent;
      countColor = fg;
    } else if (isDark) {
      bg = AppColors.darkFrost;
      fg = AppColors.darkFrostText;
      border = AppColors.darkFrost.withValues(alpha: 0.55);
      countColor = fg;
    } else {
      bg = AppColors.secondary.withValues(alpha: 0.7);
      fg = muted;
      border = AppColors.border;
      countColor = fg;
    }

    return InkWell(
      onTap: chip.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              chip.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: chip.selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${chip.count}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: countColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogRow {
  final bool isHeader;
  final ModelCategory? category;
  final int? count;
  final AIProvider? provider;
  final AIModelInfo? model;

  const _CatalogRow.header({required this.category, required this.count})
      : isHeader = true,
        provider = null,
        model = null;

  const _CatalogRow.model({required this.provider, required this.model})
      : isHeader = false,
        category = null,
        count = null;
}

class _HeaderRow extends StatelessWidget {
  final ModelCategory category;
  final int count;
  final bool isDark;

  const _HeaderRow({
    required this.category,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(
            category.icon,
            size: 15,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            '${category.label.toUpperCase()} ($count)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  final AIProvider provider;
  final AIModelInfo model;
  final bool isDark;
  final bool isActiveChat;
  final bool isActiveEmbedding;
  final VoidCallback onTap;

  const _ModelRow({
    required this.provider,
    required this.model,
    required this.isDark,
    required this.isActiveChat,
    required this.isActiveEmbedding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isActiveChat || isActiveEmbedding;
    final accent = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final spec = model.embeddingSpec;

    final meta = <String>[
      provider.displayName,
      model.family.label,
      if (model.isFree) 'free',
      if (spec != null) ...[
        if (spec.dimensions != null) '${spec.dimensions} dims',
        if (spec.maxInputTokens != null) '${formatCompact(spec.maxInputTokens!)} tokens',
      ],
      if (model.contextWindow > 0) formatContext(model.contextWindow),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? accent.withValues(alpha: 0.7)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(model.category.icon, size: 17, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
