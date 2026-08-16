import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../library/controllers/library_controller.dart';
import '../../../library/data/models/book_model.dart';
import '../../../rag/controllers/rag_controller.dart';
import '../../../rag/data/rag_models.dart';

/// RAG & Backend status card shown on the provider list screen.
///
/// Confirms whether the Render backend is reachable, whether RAG is enabled,
/// exactly which books are indexed, and offers re-test / retry actions.
class RagSetupCard extends ConsumerStatefulWidget {
  const RagSetupCard({super.key});

  @override
  ConsumerState<RagSetupCard> createState() => _RagSetupCardState();
}

class _RagSetupCardState extends ConsumerState<RagSetupCard> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(ragControllerProvider).baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rag = ref.watch(ragControllerProvider);
    final library = ref.watch(libraryControllerProvider).books;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = ref.read(ragControllerProvider.notifier);

    final titleByAppId = {for (final b in library) b.id: b};
    final titleByBackendId = {
      for (final b in library)
        if (rag.backendBookIdFor(b.id) != null) rag.backendBookIdFor(b.id)!: b,
    };

    final items = _buildIndexItems(rag, titleByAppId, titleByBackendId);

    return SurfaceCard(
      borderRadius: 18,
      title: 'RAG & Backend',
      subtitle: 'Powers grounded answers over your library.',
      trailing: Switch(
        value: rag.enabled,
        onChanged: rag.checking ? null : (v) => controller.setRagEnabled(v),
        activeThumbColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _buildBackendStatus(rag, isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  enabled: !rag.checking,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    hintText: 'https://your-service.onrender.com',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (v) => _saveAndTest(controller),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: rag.checking ? null : () => _saveAndTest(controller),
                  icon: rag.checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 18),
                  label: Text(rag.checking ? 'Testing' : 'Test'),
                ),
              ),
            ],
          ),
          if (rag.error != null) ...[
            const SizedBox(height: 12),
            StatusBanner(
              tone: StatusTone.error,
              title: 'Backend unreachable',
              message: rag.error,
              actionLabel: 'Retry',
              onAction: rag.checking ? null : () => controller.testConnection(),
            ),
          ],
          const SizedBox(height: 16),
          _buildIndexedBooksHeader(rag, isDark),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkInput : AppColors.secondary).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rag.enabled
                    ? 'No books indexed yet. Open a book in the Chat tab and pick it as context — it will be indexed automatically.'
                    : 'Enable RAG to index your books for grounded answers.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            )
          else
            for (final item in items) ...[
              _IndexedBookTile(item: item, library: library, isDark: isDark),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Future<void> _saveAndTest(RagController controller) async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a backend URL first.')),
      );
      return;
    }
    await controller.updateConfig(baseUrl: url);
    await controller.setRagEnabled(true);
  }

  Widget _buildBackendStatus(RagState rag, bool isDark) {
    if (rag.checking) {
      return const StatusBanner(tone: StatusTone.info, title: 'Testing backend connection…', loading: true);
    }
    if (rag.connected) {
      final health = rag.lastHealth;
      final latency = health != null ? '${health.latencyMs}ms' : '';
      final checked = rag.lastCheckedAt != null
          ? ' · ${_relativeTime(rag.lastCheckedAt!)}'
          : '';
      final title = health?.app != null && health!.app.isNotEmpty
          ? 'Backend online · ${health.app}${health.version != null ? ' v${health.version}' : ''}'
          : 'Backend online';
      return StatusBanner(
        tone: StatusTone.success,
        title: title,
        message: 'Connected in $latency$checked · ${rag.indexedCount} book${rag.indexedCount == 1 ? '' : 's'} indexed.',
        actionLabel: 'Re-test',
        onAction: () => ref.read(ragControllerProvider.notifier).testConnection(),
      );
    }
    return StatusBanner(
      tone: rag.enabled ? StatusTone.error : StatusTone.warning,
      title: rag.enabled ? 'Backend offline' : 'RAG disabled',
      message: rag.enabled
          ? (rag.error ?? 'Cannot reach the backend. Check the URL and your network.')
          : 'RAG is off. Use the switch above to enable it.',
      actionLabel: 'Test now',
      onAction: rag.enabled ? () => ref.read(ragControllerProvider.notifier).testConnection() : null,
    );
  }

  Widget _buildIndexedBooksHeader(RagState rag, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.menu_book_rounded,
          size: 16,
          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        ),
        const SizedBox(width: 6),
        Text(
          'Indexed books',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
        const Spacer(),
        Text(
          '${rag.indexedCount} indexed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ),
      ],
    );
  }

  List<_IndexedBookItem> _buildIndexItems(
    RagState rag,
    Map<String, BookModel> titleByAppId,
    Map<String, BookModel> titleByBackendId,
  ) {
    final items = <_IndexedBookItem>[];

    for (final entry in rag.books.entries) {
      final idx = entry.value;
      final book = titleByAppId[entry.key];
      final title = book?.title ?? 'Book';
      items.add(
        _IndexedBookItem(
          appBookId: entry.key,
          title: title,
          status: idx.status,
          progress: idx.progress,
          error: idx.error,
          backendBookId: idx.backendBookId,
          book: book,
        ),
      );
    }

    for (final serverBook in rag.backendBooks) {
      final backendId = (serverBook['book_id'] as String?) ?? '';
      if (backendId.isEmpty) continue;
      final tracked = rag.books.values.any((e) => e.backendBookId == backendId);
      if (tracked) continue;
      final book = titleByBackendId[backendId];
      items.add(
        _IndexedBookItem(
          appBookId: backendId,
          title: (serverBook['title'] as String?) ?? book?.title ?? 'Unknown book',
          status: RagBookStatus.completed,
          progress: 1,
          backendBookId: backendId,
          book: book,
        ),
      );
    }

    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'checked just now';
    if (diff.inMinutes < 60) return 'checked ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'checked ${diff.inHours}h ago';
    return 'checked ${diff.inDays}d ago';
  }
}

class _IndexedBookItem {
  final String appBookId;
  final String title;
  final RagBookStatus status;
  final double progress;
  final String? error;
  final String? backendBookId;
  final BookModel? book;

  const _IndexedBookItem({
    required this.appBookId,
    required this.title,
    required this.status,
    required this.progress,
    this.error,
    this.backendBookId,
    this.book,
  });
}

class _IndexedBookTile extends ConsumerWidget {
  final _IndexedBookItem item;
  final List<BookModel> library;
  final bool isDark;

  const _IndexedBookTile({
    required this.item,
    required this.library,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color, statusLabel) = switch (item.status) {
      RagBookStatus.completed => (
          Icons.check_circle_rounded,
          isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          'Indexed',
        ),
      RagBookStatus.ingesting => (
          Icons.hourglass_top_rounded,
          isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          'Indexing ${(item.progress * 100).toStringAsFixed(0)}%',
        ),
      RagBookStatus.failed => (
          Icons.error_rounded,
          isDark ? AppColors.darkDanger : AppColors.lightDanger,
          'Failed',
        ),
      RagBookStatus.notIndexed => (
          Icons.radio_button_unchecked_rounded,
          isDark ? AppColors.darkMuted : AppColors.lightMuted,
          'Not indexed',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.status == RagBookStatus.failed && item.error != null
                      ? item.error!
                      : statusLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (item.status == RagBookStatus.failed && item.book != null)
            IconButton(
              onPressed: () {
                ref.read(ragControllerProvider.notifier).retryIngest(item.book!);
              },
              icon: Icon(Icons.refresh_rounded, size: 20, color: color),
              tooltip: 'Retry indexing',
            ),
        ],
      ),
    );
  }
}
