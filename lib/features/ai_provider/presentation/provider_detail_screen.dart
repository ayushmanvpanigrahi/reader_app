import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../data/models/ai_model_info.dart';
import '../data/models/ai_provider.dart';
import '../data/models/usage_stats.dart';
import '../domain/notifiers/active_provider_notifier.dart';
import '../domain/notifiers/provider_list_notifier.dart';
import '../domain/providers.dart';
import 'add_edit_provider_screen.dart';
import 'extensions.dart';
import 'widgets/model_picker_sheet.dart';
import 'widgets/rate_limit_ring.dart';
import 'widgets/usage_sparkline.dart';

class ProviderDetailScreen extends ConsumerStatefulWidget {
  final String providerId;

  const ProviderDetailScreen({super.key, required this.providerId});

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providerAsync = ref.watch(providerListProvider);

    return Scaffold(
      backgroundColor: AppColors.getStage(context),
      appBar: AppBar(
        backgroundColor: AppColors.getStage(context),
        elevation: 0,
        title: const Text('Provider', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            tooltip: 'Edit provider',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditProviderScreen(providerId: widget.providerId),
                ),
              );
            },
          ),
        ],
      ),
      body: providerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (providers) {
          final matches = providers.where((p) => p.id == widget.providerId).toList();
          if (matches.isEmpty) return const _MissingProvider();
          return _DetailBody(providerId: matches.first.id);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final String providerId;

  const _DetailBody({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = ref.watch(providerListProvider).value!
        .firstWhere((p) => p.id == providerId);
    final active = ref.watch(activeProviderProvider).value;
    final isActive = active?.provider?.id == providerId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HeaderCard(provider: provider, isActive: isActive, isDark: isDark),
        const SizedBox(height: 16),
        _ModelsSection(providerId: providerId, isDark: isDark),
        const SizedBox(height: 16),
        _UsageSection(providerId: providerId, isDark: isDark),
        const SizedBox(height: 16),
        _FallbackSection(providerId: providerId, isDark: isDark),
        const SizedBox(height: 16),
        _DangerZone(provider: provider, isActive: isActive, isDark: isDark),
      ],
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  final AIProvider provider;
  final bool isActive;
  final bool isDark;

  const _HeaderCard({required this.provider, required this.isActive, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = provider.type.accent(isDark);
    return NeumorphicCard(
      borderRadius: 22,
      depth: 4.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(provider.type.icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
              NeumorphicButton.icon(
                icon: isActive ? Icons.star_rounded : Icons.star_border_rounded,
                onPressed: isActive
                    ? null
                    : () => ref.read(activeProviderProvider.notifier).setActiveProvider(provider.id),
                isSelected: isActive,
                size: 44,
                tooltip: isActive ? 'Active provider' : 'Set as active',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            provider.baseUrl,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusPillDetail(
                color: provider.lastStatus.color(isDark),
                label: 'Status: ${provider.lastStatus.label}',
              ),
              const SizedBox(width: 10),
              if (provider.lastTestedAt != null)
                Text(
                  'Tested ${provider.lastTestedAt!.toLocal()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPillDetail extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPillDetail({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ModelsSection extends ConsumerWidget {
  final String providerId;
  final bool isDark;

  const _ModelsSection({required this.providerId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(providerListProvider).value!
        .firstWhere((p) => p.id == providerId);
    final active = ref.watch(activeProviderProvider).value;
    final isActive = active?.provider?.id == providerId;

    final modelIds = provider.cachedModelIds;
    final cachedModels = ref.watch(modelRepositoryProvider).cached(providerId) ?? const [];
    final info = {for (final m in cachedModels) m.id: m};

    return NeumorphicCard(
      borderRadius: 20,
      depth: 3.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Models',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${modelIds.length} cached from this endpoint',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 14),
          _ModelSelectorRow(
            label: 'Chat model',
            icon: Icons.chat_bubble_rounded,
            modelId: isActive ? active?.chatModelId : null,
            isActive: isActive,
            isDark: isDark,
            modelIds: modelIds,
            info: info,
            onPick: (id) => ref.read(activeProviderProvider.notifier).selectChatModel(id),
          ),
          const SizedBox(height: 12),
          _ModelSelectorRow(
            label: 'Embedding model',
            icon: Icons.grain_rounded,
            modelId: isActive ? active?.embeddingModelId : null,
            isActive: isActive,
            isDark: isDark,
            modelIds: modelIds,
            info: info,
            onPick: (id) => ref.read(activeProviderProvider.notifier).selectEmbeddingModel(id),
          ),
        ],
      ),
    );
  }
}

class _ModelSelectorRow extends ConsumerWidget {
  final String label;
  final IconData icon;
  final String? modelId;
  final bool isActive;
  final bool isDark;
  final List<String> modelIds;
  final Map<String, AIModelInfo> info;
  final ValueChanged<String> onPick;

  const _ModelSelectorRow({
    required this.label,
    required this.icon,
    required this.modelId,
    required this.isActive,
    required this.isDark,
    required this.modelIds,
    required this.info,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isActive
          ? () async {
              final picked = await ModelPickerSheet.show(
                context,
                allModelIds: modelIds,
                selectedId: modelId,
                title: 'Select $label',
                info: info,
              );
              if (picked != null) onPick(picked);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.darkInput : AppColors.secondary).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                  Text(
                    modelId ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                ],
              ),
            ),
            if (!isActive)
              Text(
                'Activate provider first',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _UsageSection extends ConsumerWidget {
  final String providerId;
  final bool isDark;

  const _UsageSection({required this.providerId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateLimit = ref.watch(currentRateLimitProvider).value;
    final allUsage = ref.watch(allUsageStatsProvider).value ?? const <UsageStats>[];
    final providerUsage = allUsage.where((u) => u.providerId == providerId).toList();

    return Column(
      children: [
        RateLimitRing(snapshot: rateLimit),
        const SizedBox(height: 12),
        UsageSparkline(
          buckets: [
            for (final u in providerUsage)
              ...u.dailyHistory,
          ],
        ),
      ],
    );
  }
}

class _FallbackSection extends ConsumerWidget {
  final String providerId;
  final bool isDark;

  const _FallbackSection({required this.providerId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(providerListProvider).value!
        .firstWhere((p) => p.id == providerId);
    final order = provider.fallbackOrder;

    final sortedIds = [...provider.cachedModelIds]..sort((a, b) {
        final pa = order[a] ?? 999;
        final pb = order[b] ?? 999;
        return pa.compareTo(pb);
      });

    return NeumorphicCard(
      borderRadius: 20,
      depth: 3.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fallback Priority',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const Spacer(),
              Text(
                '${order.length} ranked',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reorder to control which models the auto-switch tries first.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (sortedIds.isEmpty)
            Text(
              'No cached models yet. Fetch the catalog from the edit screen first.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            )
          else
            _ReorderableModelList(
              modelIds: sortedIds,
              order: order,
              isDark: isDark,
              onChanged: (newOrder) {
                final updated = Map<String, int>.fromEntries(
                  newOrder.asMap().entries.map((e) => MapEntry(e.value, e.key)),
                );
                ref.read(providerListProvider.notifier).save(
                      provider.copyWith(fallbackOrder: updated),
                    );
              },
            ),
        ],
      ),
    );
  }
}

class _ReorderableModelList extends StatefulWidget {
  final List<String> modelIds;
  final Map<String, int> order;
  final bool isDark;
  final ValueChanged<List<String>> onChanged;

  const _ReorderableModelList({
    required this.modelIds,
    required this.order,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_ReorderableModelList> createState() => _ReorderableModelListState();
}

class _ReorderableModelListState extends State<_ReorderableModelList> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.modelIds];
  }

  @override
  void didUpdateWidget(covariant _ReorderableModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = [...widget.modelIds];
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
        widget.onChanged(_items);
      },
      itemBuilder: (context, index) {
        final id = _items[index];
        return ListTile(
          key: ValueKey(id),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.drag_indicator_rounded,
            color: widget.isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
          title: Text(
            id,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          trailing: Text(
            '#${(widget.order[id] ?? 999) + 1}',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
        );
      },
    );
  }
}

class _DangerZone extends ConsumerWidget {
  final AIProvider provider;
  final bool isActive;
  final bool isDark;

  const _DangerZone({required this.provider, required this.isActive, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeumorphicCard(
      borderRadius: 20,
      depth: 3,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkDanger : AppColors.lightDanger,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkDanger : AppColors.lightDanger,
                    side: BorderSide(
                      color: (isDark ? AppColors.darkDanger : AppColors.lightDanger)
                          .withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Delete provider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.getCard(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete provider?'),
        content: Text(
          'Remove "${provider.displayName}" and its saved API key?',
          style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.lightMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(providerListProvider.notifier).remove(provider.id);
              Navigator.of(context).pop();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: isDark ? AppColors.darkDanger : AppColors.lightDanger),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingProvider extends StatelessWidget {
  const _MissingProvider();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Provider not found.'));
  }
}
