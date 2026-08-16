import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/models/ai_model_info.dart';
import '../data/models/ai_provider.dart';
import '../data/models/usage_stats.dart';
import '../data/services/model_fetcher.dart';
import '../domain/notifiers/active_provider_notifier.dart';
import '../domain/notifiers/embedding_pool_notifier.dart';
import '../domain/notifiers/provider_list_notifier.dart';
import '../domain/providers.dart';
import 'add_edit_provider_screen.dart';
import 'embedding_pool_screen.dart';
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
  bool _retesting = false;
  String? _retestResult;
  bool _retestSucceeded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providerAsync = ref.watch(providerListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
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
          return _DetailBody(
            providerId: matches.first.id,
            retesting: _retesting,
            retestResult: _retestResult,
            retestSucceeded: _retestSucceeded,
            onRetest: _retest,
          );
        },
      ),
    );
  }

  Future<void> _retest() async {
    setState(() {
      _retesting = true;
      _retestResult = null;
    });
    try {
      final repo = ref.read(providerRepositoryProvider);
      final provider = repo.byId(widget.providerId);
      if (provider == null) {
        setState(() {
          _retestResult = 'Provider no longer exists.';
          _retestSucceeded = false;
        });
        return;
      }
      final key = await repo.apiKey(provider.id);
      final models = await ModelFetcher.fetch(baseUrl: provider.baseUrl, apiKey: key ?? '');
      final updated = provider.copyWith(
        lastStatusName: ConnectionStatus.connected.name,
        lastTestedAt: DateTime.now().toUtc(),
        cachedModelIds: models.models.isNotEmpty
            ? [for (final m in models.models) m.id]
            : provider.cachedModelIds,
      );
      await repo.save(updated);
      if (models.models.isNotEmpty) {
        await ref.read(modelRepositoryProvider).cache(provider.id, models.models);
      }
      ref.read(providerListProvider.notifier).refresh();
      setState(() {
        _retestSucceeded = true;
        _retestResult =
            'Connected in ${models.latencyMs}ms · ${models.models.length} models available.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retestSucceeded = false;
        _retestResult = _friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _retesting = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.toLowerCase().contains('unauthorized')) {
      return 'Authentication failed (401). Check the API key.';
    }
    if (s.contains('403')) return 'Access forbidden (403).';
    if (s.contains('404')) return 'Endpoint not found (404). Check the base URL.';
    if (s.contains('SocketException') || s.toLowerCase().contains('connection')) {
      return 'Could not connect. Is the endpoint reachable?';
    }
    if (s.contains('Timeout') || s.contains('timed out')) {
      return 'Connection timed out.';
    }
    return 'Connection failed: $e';
  }
}

class _DetailBody extends ConsumerWidget {
  final String providerId;
  final bool retesting;
  final String? retestResult;
  final bool retestSucceeded;
  final VoidCallback onRetest;

  const _DetailBody({
    required this.providerId,
    required this.retesting,
    required this.retestResult,
    required this.retestSucceeded,
    required this.onRetest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = ref
        .watch(providerListProvider)
        .value!
        .firstWhere((p) => p.id == providerId);
    final active = ref.watch(activeProviderProvider).value;
    final isActive = active?.provider?.id == providerId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HeaderCard(
          provider: provider,
          isActive: isActive,
          isDark: isDark,
          retesting: retesting,
          retestResult: retestResult,
          retestSucceeded: retestSucceeded,
          onRetest: onRetest,
        ),
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
  final bool retesting;
  final String? retestResult;
  final bool retestSucceeded;
  final VoidCallback onRetest;

  const _HeaderCard({
    required this.provider,
    required this.isActive,
    required this.isDark,
    required this.retesting,
    required this.retestResult,
    required this.retestSucceeded,
    required this.onRetest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = provider.type.accent(isDark);
    return SurfaceCard(
      borderRadius: 18,
      borderColor: isActive ? accent.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(provider.type.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        fontSize: 17,
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
              IconButton(
                onPressed: isActive
                    ? null
                    : () => ref.read(activeProviderProvider.notifier).setActiveProvider(provider.id),
                icon: Icon(
                  isActive ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isActive ? accent : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                  size: 24,
                ),
                tooltip: isActive ? 'Active provider' : 'Set as active',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.baseUrl,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusPillDetail(
                color: provider.lastStatus.color(isDark),
                label: provider.lastStatus.label,
              ),
              const SizedBox(width: 10),
              if (provider.lastTestedAt != null)
                Text(
                  'Tested ${provider.lastTestedAt!.toLocal().toString().substring(0, 16)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (retestResult != null) ...[
            StatusBanner(
              tone: retestSucceeded ? StatusTone.success : StatusTone.error,
              title: retestSucceeded ? 'Re-test successful' : 'Re-test failed',
              message: retestResult,
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: retesting ? null : onRetest,
            icon: retesting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 17),
            label: Text(retesting ? 'Re-testing…' : 'Test connection'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    final provider = ref
        .watch(providerListProvider)
        .value!
        .firstWhere((p) => p.id == providerId);
    final active = ref.watch(activeProviderProvider).value;
    final isActive = active?.provider?.id == providerId;

    final modelIds = provider.cachedModelIds;
    final cachedModels = ref.watch(modelRepositoryProvider).cached(providerId) ?? const [];
    final info = {for (final m in cachedModels) m.id: m};

    return SurfaceCard(
      borderRadius: 18,
      title: 'Models',
      subtitle: '${modelIds.length} cached from this endpoint',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _ModelSelectorRow(
            label: 'Chat model',
            icon: Icons.chat_bubble_rounded,
            modelId: isActive ? active?.chatModelId : null,
            isActive: isActive,
            isDark: isDark,
            modelIds: modelIds,
            info: info,
            initialModality: ModelModality.text,
            onPick: (id) => ref.read(activeProviderProvider.notifier).selectChatModel(id),
          ),
          const SizedBox(height: 10),
          _ModelSelectorRow(
            label: 'Embedding model',
            icon: Icons.grain_rounded,
            modelId: isActive ? active?.embeddingModelId : null,
            isActive: isActive,
            isDark: isDark,
            modelIds: modelIds,
            info: info,
            initialModality: ModelModality.embeddings,
            onPick: (id) => ref.read(activeProviderProvider.notifier).selectEmbeddingModel(id),
          ),
          const SizedBox(height: 10),
          _EmbeddingPoolEntry(isDark: isDark),
        ],
      ),
    );
  }
}

class _EmbeddingPoolEntry extends ConsumerWidget {
  final bool isDark;

  const _EmbeddingPoolEntry({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(embeddingPoolProvider);
    final providerCount = pool.map((e) => e.provider.id).toSet().length;
    final activeId = ref.watch(activeProviderProvider).value?.embeddingModelId;

    final subtitle = pool.isEmpty
        ? 'No embedding models across providers'
        : '${activeId ?? 'No active model'} · ${pool.length} in pool · '
            '$providerCount provider${providerCount == 1 ? '' : 's'}';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmbeddingPoolScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.darkCard : AppColors.secondary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.grain_rounded,
              size: 18,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Embedding Pool',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
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

class _ModelSelectorRow extends ConsumerWidget {
  final String label;
  final IconData icon;
  final String? modelId;
  final bool isActive;
  final bool isDark;
  final List<String> modelIds;
  final Map<String, AIModelInfo> info;
  final ModelModality? initialModality;
  final ValueChanged<String> onPick;

  const _ModelSelectorRow({
    required this.label,
    required this.icon,
    required this.modelId,
    required this.isActive,
    required this.isDark,
    required this.modelIds,
    required this.info,
    this.initialModality,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: isActive
          ? () async {
              final picked = await ModelPickerSheet.show(
                context,
                allModelIds: modelIds,
                selectedId: modelId,
                title: 'Select $label',
                info: info,
                initialModality: initialModality,
              );
              if (picked != null) onPick(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.darkCard : AppColors.secondary),
          borderRadius: BorderRadius.circular(12),
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
    final provider = ref
        .watch(providerListProvider)
        .value!
        .firstWhere((p) => p.id == providerId);
    final order = provider.fallbackOrder;

    final sortedIds = [...provider.cachedModelIds]..sort((a, b) {
        final pa = order[a] ?? 999;
        final pb = order[b] ?? 999;
        return pa.compareTo(pb);
      });

    return SurfaceCard(
      borderRadius: 18,
      title: 'Fallback Priority',
      subtitle: 'Reorder to control which models the auto-switch tries first.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    final dangerColor = isDark ? AppColors.darkDanger : AppColors.lightDanger;
    return SurfaceCard(
      borderRadius: 18,
      borderColor: dangerColor.withValues(alpha: 0.4),
      title: 'Danger Zone',
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: dangerColor,
            side: BorderSide(color: dangerColor.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete provider'),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
