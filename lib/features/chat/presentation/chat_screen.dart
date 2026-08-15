import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../ai_provider/data/models/usage_stats.dart';
import '../../ai_provider/domain/notifiers/active_provider_notifier.dart';
import '../../ai_provider/domain/providers.dart';
import '../../ai_provider/presentation/provider_list_screen.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/data/models/book_model.dart';
import '../../rag/controllers/rag_controller.dart';
import '../../rag/data/rag_models.dart';
import '../controllers/chat_controller.dart';
import '../data/chat_message.dart';
import 'markdown_spans.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  static BookModel? _findBook(List<BookModel> books, String? id) {
    if (id == null) return null;
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeProviderProvider).value;
    final chat = ref.watch(chatControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConfigured = active?.isConfigured ?? false;

    final modelId = active?.chatModelId;
    final providerId = active?.provider?.id;
    final usage = (isConfigured && modelId != null && providerId != null)
        ? ref
            .watch(usageStatsProvider(
              (providerId: providerId, modelId: modelId),
            ))
            .value
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Chat'),
            if (isConfigured) ...[
              Text(
                modelId ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (usage != null) ...[
                const SizedBox(height: 2),
                _UsageChip(usage: usage, isDark: isDark),
              ],
            ],
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isConfigured) _buildRagBar(context, chat),
            Expanded(
              child: isConfigured
                  ? _buildConversation(context, chat)
                  : _buildUnconfigured(context, isDark),
            ),
            if (isConfigured) _buildInputBar(context, chat.isStreaming, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRagBar(BuildContext context, ChatState chat) {
    final rag = ref.watch(ragControllerProvider);
    final library = ref.watch(libraryControllerProvider);
    final books = library.books;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = ref.read(chatControllerProvider.notifier);

    if (!rag.enabled) {
      return const SizedBox.shrink();
    }

    final selected = _findBook(books, chat.ragBookId);
    final index = selected != null ? rag.indexFor(selected.id) : null;
    final ragReady = selected != null &&
        rag.canRagFor(selected.id) &&
        chat.ragBookId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                ragReady ? Icons.auto_awesome_rounded : Icons.hub_outlined,
                size: 14,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Book context (RAG)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
              const Spacer(),
              if (index != null && index.status == RagBookStatus.ingesting)
                _RagStatusChip(
                  text: 'Indexing ${(index.progress * 100).toStringAsFixed(0)}%',
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  isDark: isDark,
                ),
              if (index != null && index.status == RagBookStatus.failed)
                _RagStatusChip(
                  text: 'Index failed',
                  color: const Color(0xFFE57373),
                  isDark: isDark,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _RagBookDropdown(
            books: books,
            selectedId: chat.ragBookId,
            onChanged: (id) {
              final book = _findBook(books, id);
              controller.selectRagBook(id, book?.title);
              if (book != null) {
                ref.read(ragControllerProvider.notifier).ingestBook(book);
              }
            },
          ),
          if (chat.ragMeta?.usedRag == true) _RagMetaFooter(meta: chat.ragMeta!, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context, ChatState chat) {
    if (chat.messages.isEmpty) {
      return _buildEmptyConversation(context);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        final isLast = index == chat.messages.length - 1;
        return _MessageBubble(
          message: message,
          isDark: Theme.of(context).brightness == Brightness.dark,
          showStreamingCursor: isLast && message.role == ChatRole.assistant,
        );
      },
    );
  }

  Widget _buildEmptyConversation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ask anything',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat with your selected AI model. Every call tracks tokens and rate limits automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnconfigured(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_rounded,
              size: 44,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No AI provider configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect an OpenAI-compatible endpoint to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 20),
            NeumorphicButton(
              text: 'Configure AI',
              icon: Icons.hub_rounded,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProviderListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isStreaming, bool isDark) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => isStreaming ? null : _send(),
              decoration: InputDecoration(
                hintText: 'Message your AI model…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: primary, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          NeumorphicButton.icon(
            icon: isStreaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            onPressed: isStreaming ? null : _send,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  final UsageStats usage;
  final bool isDark;

  const _UsageChip({required this.usage, required this.isDark});

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return '$tokens';
  }

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_graph_rounded, size: 12, color: primary),
        const SizedBox(width: 4),
        Text(
          '${_formatTokens(usage.totalTokens)} tokens • ${usage.totalRequests} calls',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ),
      ],
    );
  }
}

class _RagBookDropdown extends StatelessWidget {
  final List<BookModel> books;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _RagBookDropdown({
    required this.books,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkInput : AppColors.secondary,
        border: Border.all(
          color: (isDark ? AppColors.darkMuted : AppColors.lightMuted).withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          hint: Text(
            books.isEmpty ? 'No books in library' : 'Ask about a book (optional)',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Ask about a book (optional)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13),
              ),
            ),
            for (final book in books)
              DropdownMenuItem<String>(
                value: book.id,
                child: Text(
                  book.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
          icon: Icon(
            Icons.menu_book_rounded,
            size: 18,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
        ),
      ),
    );
  }
}

class _RagStatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _RagStatusChip({required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RagMetaFooter extends StatelessWidget {
  final RagChatMeta meta;
  final bool isDark;

  const _RagMetaFooter({required this.meta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, size: 13, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Answered from “${meta.bookTitle ?? 'book'}”'
                  '${meta.retrieved != null ? ' · ${meta.retrieved} passage(s) retrieved' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              Icon(
                meta.grounded ? Icons.verified_rounded : Icons.warning_amber_rounded,
                size: 14,
                color: meta.grounded ? primary : const Color(0xFFE5A13C),
              ),
              const SizedBox(width: 4),
              Text(
                meta.grounded ? 'Grounded' : 'Risk',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: meta.grounded ? primary : const Color(0xFFE5A13C),
                ),
              ),
            ],
          ),
          if (meta.citations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in meta.citations)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: muted.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '${c.chapter.isNotEmpty ? c.chapter : c.title} · p.${c.page}',
                      style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final bool showStreamingCursor;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    this.showStreamingCursor = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    final content = message.content;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: isUser
          ? BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: const Radius.circular(18),
                bottomRight: const Radius.circular(4),
              ),
            )
          : NeumorphicDecorations.boxDecoration(
              context: context,
              shape: NeumorphicShape.embossed,
              borderRadius: 18,
              depth: 3,
              color: isDark ? AppColors.darkCard : AppColors.lightPaper,
            ),
      child: content.isEmpty
          ? const _TypingIndicator()
          : SelectableText.rich(
              TextSpan(
                children: [
                  ...MarkdownSpans.build(
                    content,
                    base: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser
                          ? (isDark
                              ? AppColors.darkPrimaryForeground
                              : Colors.white)
                          : (isDark ? AppColors.darkInk : AppColors.lightInk),
                    ),
                  ),
                  if (showStreamingCursor)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: SizedBox(
                          width: 8,
                          height: 14,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              width: 8,
                              height: 16,
                              color: isUser
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isUser
                    ? (isDark ? AppColors.darkPrimaryForeground : Colors.white)
                    : (isDark ? AppColors.darkInk : AppColors.lightInk),
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(isDark: isDark),
            const SizedBox(width: 10),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isDark;

  const _Avatar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkPrimary
        : AppColors.lightPrimary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_controller.value * 2 + i) % 3) / 3;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: 0.35 + phase * 0.65,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
