import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/status_banner.dart';
import 'widgets/embedding_pool_widget.dart';

/// Manage screen for the unified cross-provider embedding pool.
class EmbeddingPoolScreen extends ConsumerWidget {
  const EmbeddingPoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Embedding Pool',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const StatusBanner(
            tone: StatusTone.info,
            title: 'Priority order',
            message:
                'Drag models to reorder. Status reflects the latest rate-limit '
                'snapshots and auto-switch exhaustions. The active embedding '
                'model is highlighted.',
          ),
          const SizedBox(height: 16),
          const EmbeddingPoolWidget(shrinkWrap: true),
        ],
      ),
    );
  }
}
