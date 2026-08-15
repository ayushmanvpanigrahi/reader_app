import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/surface_card.dart';
import '../data/models/ai_provider.dart';
import '../domain/notifiers/active_provider_notifier.dart';
import '../domain/notifiers/model_switcher_notifier.dart';
import '../domain/notifiers/provider_list_notifier.dart';
import '../domain/providers.dart';
import 'add_edit_provider_screen.dart';
import 'extensions.dart';
import 'provider_detail_screen.dart';
import 'widgets/model_picker_sheet.dart';
import 'widgets/provider_card.dart';
import 'widgets/rag_setup_card.dart';

class ProviderListScreen extends ConsumerStatefulWidget {
  const ProviderListScreen({super.key});

  @override
  ConsumerState<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends ConsumerState<ProviderListScreen> {
  String? _lastAutoSwitchMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providersAsync = ref.watch(providerListProvider);
    final active = ref.watch(activeProviderProvider).value;

    ref.listen<String?>(autoSwitchMessageProvider, (prev, next) {
      if (next == null || next == _lastAutoSwitchMessage) return;
      _lastAutoSwitchMessage = next;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(next)),
              ],
            ),
          ),
        );
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Providers', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            tooltip: 'Fallback settings',
            onPressed: () => _openFallbackSettings(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProvider,
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        foregroundColor: isDark ? AppColors.darkPrimaryForeground : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Provider', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatusBanner(
              tone: StatusTone.error,
              title: 'Failed to load providers',
              message: '$e',
              actionLabel: 'Retry',
              onAction: () => ref.read(providerListProvider.notifier).refresh(),
            ),
          ),
        ),
        data: (providers) {
          final activeProvider = active?.provider;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (activeProvider != null) ...[
                _ActiveSummary(
                  provider: activeProvider,
                  chatModelId: active?.chatModelId,
                  embeddingModelId: active?.embeddingModelId,
                  isDark: isDark,
                  onTap: () => _openDetail(activeProvider),
                ),
                const SizedBox(height: 16),
              ],
              const RagSetupCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Your providers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${providers.length} configured',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (providers.isEmpty)
                _EmptyState(isDark: isDark, onAdd: _openAddProvider)
              else
                for (final provider in providers) ...[
                  ProviderCard(
                    provider: provider,
                    isActive: provider.isActive,
                    modelCount: provider.cachedModelIds.length,
                    onTap: () => _openDetail(provider),
                    onToggle: () => _toggleActive(provider),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  void _openAddProvider() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditProviderScreen()),
    );
  }

  void _openDetail(AIProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProviderDetailScreen(providerId: provider.id)),
    );
  }

  void _toggleActive(AIProvider provider) {
    if (provider.isActive) return;
    ref.read(activeProviderProvider.notifier).setActiveProvider(provider.id);
  }

  void _openFallbackSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FallbackPoolSheet(),
    );
  }
}

class _ActiveSummary extends StatelessWidget {
  final AIProvider provider;
  final String? chatModelId;
  final String? embeddingModelId;
  final bool isDark;
  final VoidCallback onTap;

  const _ActiveSummary({
    required this.provider,
    required this.chatModelId,
    required this.embeddingModelId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = provider.type.accent(isDark);
    return SurfaceCard(
      borderRadius: 18,
      onTap: onTap,
      borderColor: accent.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(provider.type.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chat: ${chatModelId ?? '—'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
                Text(
                  'Embedding: ${embeddingModelId ?? '—'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;

  const _EmptyState({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 52,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'No AI providers yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect Groq, OpenRouter, NVIDIA, OpenAI or any OpenAI-compatible endpoint to enable in-app AI chat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add your first provider'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackPoolSheet extends ConsumerWidget {
  const _FallbackPoolSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(modelSwitcherProvider).value;
    final chatPool = state?.chatFallbackPool ?? const <String>[];
    final embedPool = state?.embeddingFallbackPool ?? const <String>[];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkStage : AppColors.lightStage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-Switch Fallback Pools',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When the active model is rate-exhausted, the app automatically switches to the next available model in the pool — even from another provider.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
              const SizedBox(height: 16),
              _PoolSection(
                title: 'Chat models',
                pool: chatPool,
                isDark: isDark,
                onPick: (ids) =>
                    ref.read(modelSwitcherProvider.notifier).setChatFallbackPool(ids),
              ),
              const SizedBox(height: 16),
              _PoolSection(
                title: 'Embedding models',
                pool: embedPool,
                isDark: isDark,
                onPick: (ids) =>
                    ref.read(modelSwitcherProvider.notifier).setEmbeddingFallbackPool(ids),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoolSection extends ConsumerWidget {
  final String title;
  final List<String> pool;
  final bool isDark;
  final ValueChanged<List<String>> onPick;

  const _PoolSection({
    required this.title,
    required this.pool,
    required this.isDark,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(providerListProvider).value ?? const <AIProvider>[];
    final allModels = <String>[
      for (final p in providers)
        for (final m in p.cachedModelIds) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            Text(
              '${pool.length} selected',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in pool)
              Chip(
                label: Text(id),
                backgroundColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
                deleteIconColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                onDeleted: () => onPick([...pool]..remove(id)),
              ),
            ActionChip(
              avatar: Icon(
                Icons.add_rounded,
                size: 18,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              label: const Text('Add'),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              onPressed: () async {
                if (allModels.isEmpty) return;
                final picked = await ModelPickerSheet.show(
                  context,
                  allModelIds: allModels,
                  selectedId: null,
                  title: 'Add to $title',
                );
                if (picked != null && !pool.contains(picked)) {
                  onPick([...pool, picked]);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
