import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../controllers/highlights_controller.dart';
import '../data/highlight_model.dart';
import '../data/text_normalizer.dart';

enum ExplainStatus {
  idle,
  sending, // "Sending to AI..."
  thinking, // "AI is reading your passage..."
  generating, // "Generating explanation..."
  done,
  error,
}

Future<void> showHighlightExplanationSheet(
  BuildContext context, {
  required String bookId,
  required String bookTitle,
  required int pageNumber,
  required String selectedText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HighlightExplanationSheet(
      bookId: bookId,
      bookTitle: bookTitle,
      pageNumber: pageNumber,
      selectedText: selectedText,
    ),
  );
}

class HighlightExplanationSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final String selectedText;

  const HighlightExplanationSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.selectedText,
  });

  @override
  ConsumerState<HighlightExplanationSheet> createState() =>
      _HighlightExplanationSheetState();
}

class _HighlightExplanationSheetState
    extends ConsumerState<HighlightExplanationSheet> {
  HighlightExplanation? _explanation;
  bool _failed = false;
  ExplainStatus _status = ExplainStatus.idle;
  Timer? _statusTimer1;
  Timer? _statusTimer2;

  // Editable passage
  bool _isEditing = false;
  late TextEditingController _editController;
  late String _currentText;

  // Follow-up chat
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();

  static const _quickChips = [
    'Explain in simple Hindi',
    'Give a daily life example',
    'What is the counter-argument?',
    'Key life lesson',
  ];

  @override
  void initState() {
    super.initState();
    _currentText = TextNormalizer.clean(widget.selectedText);
    _editController = TextEditingController(text: _currentText);
    _explain();
  }

  @override
  void dispose() {
    _stopStatusTimers();
    _editController.dispose();
    _chatInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startStatusTimers() {
    _statusTimer1?.cancel();
    _statusTimer2?.cancel();
    setState(() => _status = ExplainStatus.sending);

    _statusTimer1 = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _status == ExplainStatus.sending) {
        setState(() => _status = ExplainStatus.thinking);
      }
    });

    _statusTimer2 = Timer(const Duration(milliseconds: 2600), () {
      if (mounted &&
          (_status == ExplainStatus.sending ||
              _status == ExplainStatus.thinking)) {
        setState(() => _status = ExplainStatus.generating);
      }
    });
  }

  void _stopStatusTimers() {
    _statusTimer1?.cancel();
    _statusTimer2?.cancel();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _explain() async {
    _startStatusTimers();
    final result = await ref
        .read(highlightsControllerProvider.notifier)
        .explain(
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          pageNumber: widget.pageNumber,
          selectedText: _currentText,
        );
    _stopStatusTimers();
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _status = ExplainStatus.error;
        _failed = true;
      });
    } else {
      setState(() {
        _status = ExplainStatus.done;
        _explanation = result;
        _failed = false;
      });
    }
  }

  Future<void> _reExplain() async {
    setState(() {
      _currentText = _editController.text.trim();
      _isEditing = false;
      _explanation = null;
      _failed = false;
    });
    _startStatusTimers();
    await ref
        .read(highlightsControllerProvider.notifier)
        .reExplain(
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          pageNumber: widget.pageNumber,
          selectedText: _currentText,
        );
    _stopStatusTimers();
    if (!mounted) return;
    final explanation = ref.read(highlightsControllerProvider).lastExplanation;
    if (explanation != null) {
      setState(() {
        _status = ExplainStatus.done;
        _explanation = explanation;
        _failed = false;
      });
    } else {
      setState(() {
        _status = ExplainStatus.error;
        _failed = true;
      });
    }
  }

  Future<void> _sendFollowUp(String question) async {
    FocusScope.of(context).unfocus();
    _chatInputController.clear();
    _scrollToBottom();
    await ref
        .read(highlightsControllerProvider.notifier)
        .askFollowUp(question);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightsState = ref.watch(highlightsControllerProvider);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.lightPaper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              children: [
                Icon(
                  Icons.highlight_rounded,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Highlight Explained',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Editable passage card
            _EditablePassageCard(
              text: _currentText,
              isEditing: _isEditing,
              editController: _editController,
              isDark: isDark,
              onToggleEdit: () => setState(() => _isEditing = !_isEditing),
              onReExplain: _reExplain,
            ),
            const SizedBox(height: 12),

            // Scrollable content area
            Expanded(
              child: _buildContentArea(highlightsState, isDark),
            ),

            // Chat input bar (fixed at bottom)
            if (_explanation != null && !_failed)
              _ChatInputBar(
                controller: _chatInputController,
                isDark: isDark,
                isSending: highlightsState.isFollowingUp,
                onSend: _sendFollowUp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sliverSpacer() =>
      const SliverToBoxAdapter(child: SizedBox(height: 10));

  SliverToBoxAdapter _sliverSectionCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
    required bool isDark,
  }) {
    return SliverToBoxAdapter(
      child: _SectionCard(
        icon: icon,
        title: title,
        body: body,
        accent: accent,
        isDark: isDark,
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
              thickness: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Ask Follow-up',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChipsWrap(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickChips.map((chip) {
          return ActionChip(
            label: Text(
              chip,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            backgroundColor:
                isDark ? AppColors.darkCard : AppColors.lightSecondary,
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
              width: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onPressed: () => _sendFollowUp(chip),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContentArea(HighlightsState highlightsState, bool isDark) {
    final isExplaining = highlightsState.isExplaining;
    final streamingText = highlightsState.streamingText;
    final conversation = highlightsState.conversationHistory;
    final chatMessages =
        conversation.where((m) => m.role != 'system').toList();

    // Show the streaming container as soon as explain starts (even before
    // the first token arrives) so the user sees "AI is writing..." immediately
    // instead of a plain spinner. _StreamingState handles empty text with
    // animated dots (waiting for first token).
    if (isExplaining && streamingText != null && _explanation == null) {
      return _StreamingState(text: streamingText, isDark: isDark);
    }

    // Still waiting (e.g. no streamingText yet).
    if (isExplaining && _explanation == null) {
      return _LoadingState(status: _status);
    }

    // Error.
    if (_failed) {
      return _ErrorState(
        message: highlightsState.error,
        onRetry: () {
          setState(() => _failed = false);
          _explain();
        },
      );
    }

    // No explanation yet.
    if (_explanation == null) {
      return _LoadingState(status: _status);
    }

    // Full explanation + follow-up chat.
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _sliverSectionCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Simple Meaning',
          body: _explanation!.simpleMeaning,
          accent: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          isDark: isDark,
        ),
        _sliverSpacer(),
        _sliverSectionCard(
          icon: Icons.menu_book_outlined,
          title: 'Author\'s Context',
          body: _explanation!.authorContext,
          accent: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          isDark: isDark,
        ),
        _sliverSpacer(),
        _sliverSectionCard(
          icon: Icons.psychology_rounded,
          title: 'Reflect',
          body: _explanation!.reflectionQuestion,
          accent: isDark ? AppColors.darkWarning : AppColors.lightWarning,
          isDark: isDark,
        ),
        _sliverSpacer(),
        _sliverSectionCard(
          icon: Icons.auto_awesome_outlined,
          title: 'Analogy',
          body: _explanation!.analogy,
          accent: isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2),
          isDark: isDark,
        ),
        _sliverSpacer(),
        _sliverSectionCard(
          icon: Icons.star_border_rounded,
          title: 'Key Takeaway',
          body: _explanation!.takeaway,
          accent: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          isDark: isDark,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _divider(isDark)),
        SliverToBoxAdapter(child: _quickChipsWrap(isDark)),
        if (chatMessages.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) {
                final msg = chatMessages[index];
                return _ChatBubble(
                  role: msg.role,
                  content: msg.content,
                  isDark: isDark,
                );
              },
              childCount: chatMessages.length,
            ),
          ),
        if (highlightsState.isFollowingUp)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: _TypingIndicator(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

// ─── Editable Passage Card ──────────────────────────────────────────

class _EditablePassageCard extends StatelessWidget {
  final String text;
  final bool isEditing;
  final TextEditingController editController;
  final bool isDark;
  final VoidCallback onToggleEdit;
  final VoidCallback onReExplain;

  const _EditablePassageCard({
    required this.text,
    required this.isEditing,
    required this.editController,
    required this.isDark,
    required this.onToggleEdit,
    required this.onReExplain,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.debossed,
        borderRadius: 14,
        depth: 2.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected Passage',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleEdit,
                child: Icon(
                  isEditing ? Icons.close_rounded : Icons.edit_rounded,
                  size: 18,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing) ...[
            TextField(
              controller: editController,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
              decoration: InputDecoration(
                hintText: 'Edit or paste the correct text here...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightMuted,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightMuted,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReExplain,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-Explain'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ] else ...[
            Text(
              '"$text"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section Card ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool isDark;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.embossed,
        borderRadius: 14,
        depth: 2.5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark
                        ? AppColors.darkInk
                        : AppColors.lightInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String role;
  final String content;
  final bool isDark;

  const _ChatBubble({
    required this.role,
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final card = isDark ? AppColors.darkCard : AppColors.lightPaper;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 14, color: Colors.white),
            ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? primary : card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightMuted,
                        width: 0.5,
                      ),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isUser
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkInk
                          : AppColors.lightInk),
                ),
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 2),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.person, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ───────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome,
              size: 14, color: Colors.white),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
              width: 0.5,
            ),
          ),
          child: const _DotsAnimation(),
        ),
      ],
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.3;
            final value = ((_controller.value - delay) % 1.0);
            final opacity = value < 0.5
                ? (value * 2).clamp(0.3, 1.0)
                : (1.0 - (value - 0.5) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity.toDouble(),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Chat Input Bar ─────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool isSending;
  final ValueChanged<String> onSend;

  const _ChatInputBar({
    required this.controller,
    required this.isDark,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final card = isDark ? AppColors.darkCard : AppColors.lightPaper;

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask a follow-up...',
                  hintStyle: TextStyle(
                    color:
                        isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty && !isSending) {
                    onSend(text.trim());
                  }
                },
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending
                ? null
                : () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) onSend(text);
                  },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSending
                    ? (isDark ? AppColors.darkMuted : AppColors.lightMuted)
                    : primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading State ──────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  final ExplainStatus status;

  const _LoadingState({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    String label;
    IconData icon;

    switch (status) {
      case ExplainStatus.sending:
        label = 'Sending to AI...';
        icon = Icons.cloud_upload_outlined;
        break;
      case ExplainStatus.thinking:
        label = 'AI is reading your passage...';
        icon = Icons.psychology_outlined;
        break;
      case ExplainStatus.generating:
        label = 'Generating explanation...';
        icon = Icons.auto_awesome;
        break;
      case ExplainStatus.idle:
      case ExplainStatus.done:
      case ExplainStatus.error:
        label = 'Analyzing highlight...';
        icon = Icons.auto_awesome;
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 28, color: primary),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streaming State ──────────────────────────────────────────────

class _StreamingState extends StatelessWidget {
  final String text;
  final bool isDark;

  const _StreamingState({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final isEmpty = text.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: primary),
              const SizedBox(width: 8),
              Text(
                isEmpty ? 'Connecting to AI...' : 'AI is writing...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: NeumorphicDecorations.boxDecoration(
                context: context,
                shape: NeumorphicShape.embossed,
                borderRadius: 14,
                depth: 2.5,
              ),
              child: isEmpty
                  // Waiting for first token — show animated dots
                  ? const Center(child: _DotsAnimation())
                  : SingleChildScrollView(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.6,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error State ────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorState({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: isDark ? AppColors.darkDanger : AppColors.lightDanger,
          ),
          const SizedBox(height: 12),
          Text(
            message?.isNotEmpty == true
                ? message!
                : 'Could not explain this highlight.\nMake sure an AI provider is configured.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
