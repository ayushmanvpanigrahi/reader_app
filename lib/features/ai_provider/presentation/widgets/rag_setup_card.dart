import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/neumorphic_card.dart';
import '../../../rag/controllers/rag_controller.dart';

/// Compact RAG backend setup card (relocated from the removed ai_settings
/// feature). Shown on the provider list screen while RAG is not configured.
class RagSetupCard extends ConsumerStatefulWidget {
  final bool isDark;

  const RagSetupCard({super.key, required this.isDark});

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
    final isDark = widget.isDark;
    final rag = ref.watch(ragControllerProvider);

    return NeumorphicCard(
      borderRadius: 20,
      depth: 3.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'RAG backend',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const Spacer(),
              _Badge(
                label: rag.enabled && rag.connected
                    ? 'Connected'
                    : rag.enabled
                        ? 'Offline'
                        : 'Disabled',
                connected: rag.enabled && rag.connected,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RAG powers grounded answers over your library. Point it at your backend URL to enable.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkInput : AppColors.secondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _url,
                    enabled: !rag.checking,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    decoration: InputDecoration(
                      hintText: kBackendBaseUrl,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkMuted.withValues(alpha: 0.6)
                            : AppColors.lightMuted.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => ref.read(ragControllerProvider.notifier).updateConfig(baseUrl: v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: rag.checking ? null : () => ref.read(ragControllerProvider.notifier).testConnection(),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: rag.checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 20),
                ),
              ),
            ],
          ),
          if (rag.error != null) ...[
            const SizedBox(height: 8),
            Text(
              rag.error!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkDanger : AppColors.lightDanger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool connected;
  final bool isDark;

  const _Badge({required this.label, required this.connected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
        : (isDark ? AppColors.darkMuted : AppColors.lightMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
