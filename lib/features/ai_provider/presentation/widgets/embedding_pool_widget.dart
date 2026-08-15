import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/notifiers/active_provider_notifier.dart';
import '../../domain/notifiers/embedding_pool_notifier.dart';
import '../extensions.dart';

/// Reorderable, live-status view of the unified cross-provider embedding pool.
/// Drag rows to change priority; status dots + countdown timers reflect the
/// latest rate-limit snapshots and the auto-switcher's exhaustion map.
class EmbeddingPoolWidget extends ConsumerStatefulWidget {
  final bool shrinkWrap;

  const EmbeddingPoolWidget({super.key, this.shrinkWrap = false});

  @override
  ConsumerState<EmbeddingPoolWidget> createState() => _EmbeddingPoolWidgetState();
}

class _EmbeddingPoolWidgetState extends ConsumerState<EmbeddingPoolWidget> {
  Timer? _ticker;
  bool _hasLiveCountdown = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool needsLive) {
    if (needsLive && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _hasLiveCountdown) setState(() {});
      });
    } else if (!needsLive && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pool = ref.watch(embeddingPoolProvider);
    final active = ref.watch(activeProviderProvider).value;
    final activeId = active?.embeddingModelId;

    _hasLiveCountdown = pool.any(
      (e) => e.resetsAt != null && e.resetsAt!.isAfter(DateTime.now()),
    );
    _syncTicker(_hasLiveCountdown);

    if (pool.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No embedding models found.\nAdd a provider and fetch its model catalog.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final providerCount = pool.map((e) => e.provider.id).toSet().length;
    final available = pool.where((e) => e.status == EmbeddingModelStatus.available).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Text(
                '${pool.length} models · $providerCount providers',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
              const Spacer(),
              Text(
                '$available/${pool.length} available',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
                ),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: pool.length,
          onReorderItem: _onReorder,
          itemBuilder: (context, index) {
            final entry = pool[index];
            final spec = entry.model.embeddingSpec;
            return _PoolTile(
              key: ValueKey(entry.model.id),
              entry: entry,
              index: index,
              isActive: entry.model.id == activeId,
              isDark: isDark,
              dimsLabel: spec != null && spec.dimensions != null
                  ? '${spec.dimensions} dims'
                  : null,
            );
          },
        ),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final pool = ref.read(embeddingPoolProvider);
    final next = pool.map((e) => e.model.id).toList();
    final id = next.removeAt(oldIndex);
    next.insert(newIndex, id);
    ref.read(embeddingPoolOrderProvider.notifier).reorder(next);
  }
}

class _PoolTile extends StatelessWidget {
  final EmbeddingPoolEntry entry;
  final int index;
  final bool isActive;
  final bool isDark;
  final String? dimsLabel;

  const _PoolTile({
    super.key,
    required this.entry,
    required this.index,
    required this.isActive,
    required this.isDark,
    required this.dimsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.status.color(isDark);
    final subtitleParts = <String>[
      entry.provider.displayName,
      entry.model.family.label,
      if (entry.model.isFree) 'free',
      ...dimsLabel == null ? const <String>[] : <String>[dimsLabel!],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        borderColor: isActive
            ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
            : null,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              entry.status.icon,
              size: 20,
              color: statusColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.model.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
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
            const SizedBox(width: 8),
            if (entry.status == EmbeddingModelStatus.exhausted &&
                entry.resetsAt != null)
              Text(
                _resetLabel(entry.resetsAt!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              )
            else
              Text(
                entry.status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resetLabel(DateTime reset) {
    final diff = reset.difference(DateTime.now());
    if (diff.isNegative) return '…';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return 'resets in ${h}h ${m}m';
    if (m > 0) return 'resets in ${m}m ${s}s';
    return 'resets in ${s}s';
  }
}
