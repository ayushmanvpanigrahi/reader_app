import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/ai_model_info.dart';
import '../extensions.dart';

/// Model selection sheet: modal bottom sheet with live filtering.
/// Returns the selected model id, or null if dismissed.
///
/// The sheet lets the user scope the list by modality (Chat / Embeddings /
/// Vision) using filter chips, and shows family + pricing badges per model.
/// Pass [initialModality] to open on a specific scope (e.g. embeddings when
/// picking the embedding model); the user can still switch to "All".
class ModelPickerSheet {
  static Future<String?> show(
    BuildContext context, {
    required List<String> allModelIds,
    required String? selectedId,
    String title = 'Select a model',
    Map<String, AIModelInfo>? info,
    ModelModality? initialModality,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModelPickerSheet(
        allModelIds: allModelIds,
        selectedId: selectedId,
        title: title,
        info: info,
        initialModality: initialModality,
      ),
    );
  }
}

class _ModelPickerSheet extends HookWidget {
  final List<String> allModelIds;
  final String? selectedId;
  final String title;
  final Map<String, AIModelInfo>? info;
  final ModelModality? initialModality;

  const _ModelPickerSheet({
    required this.allModelIds,
    required this.selectedId,
    required this.title,
    this.info,
    this.initialModality,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final search = useTextEditingController();
    final query = useValueListenable(search);
    final modality = useState<ModelModality?>(initialModality);

    final filtered = useMemoized(
      () {
        final q = query.text.trim().toLowerCase();
        return allModelIds.where((id) {
          if (q.isNotEmpty && !id.toLowerCase().contains(q)) return false;
          final model = info?[id];
          if (modality.value == null || model == null) return true;
          return model.modality == modality.value;
        }).toList();
      },
      [query.text, modality.value, allModelIds, info],
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkStage : AppColors.lightStage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMuted.withValues(alpha: 0.5) : AppColors.lightMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} models',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.secondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: TextField(
                controller: search,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Search models…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkMuted.withValues(alpha: 0.6)
                        : AppColors.lightMuted.withValues(alpha: 0.6),
                  ),
                  icon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ModalityFilter(
            selected: modality.value,
            isDark: isDark,
            onChanged: (m) => modality.value = m,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No models match',
                      style: TextStyle(
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final id = filtered[index];
                      final isSelected = id == selectedId;
                      return _ModelTile(
                        id: id,
                        info: info?[id],
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).pop(id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModalityFilter extends StatelessWidget {
  final ModelModality? selected;
  final bool isDark;
  final ValueChanged<ModelModality?> onChanged;

  const _ModalityFilter({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  static const _tabs = <ModelModality?>[
    null,
    ModelModality.text,
    ModelModality.embeddings,
    ModelModality.vision,
  ];

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final tab in _tabs) ...[
            _FilterChip(
              label: tab?.label ?? 'All',
              selected: selected == tab,
              color: primary,
              isDark: isDark,
              onTap: () => onChanged(tab),
            ),
            if (tab != _tabs.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.28 : 0.14)
              : (isDark ? AppColors.darkCard : AppColors.lightPaper),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? color
                : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
          ),
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String id;
  final AIModelInfo? info;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModelTile({
    required this.id,
    required this.info,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : AppColors.lightPaper),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  if (info != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(info!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: info!.family.label,
                          color: accent,
                          isDark: isDark,
                        ),
                        _Badge(
                          label: info!.modality.label,
                          color: info!.isEmbedding
                              ? const Color(0xFF42A5F5)
                              : accent,
                          isDark: isDark,
                        ),
                        _Badge(
                          label: info!.isFree ? 'Free' : 'Paid',
                          color: info!.isFree
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFFE57373),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }

  String _subtitle(AIModelInfo m) {
    final ctx = formatContext(m.contextWindow);
    return ctx == '—' ? 'OpenAI-compatible endpoint' : '$ctx window';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _Badge({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
