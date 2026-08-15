import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../../../core/widgets/neumorphic_snackbar.dart';
import '../data/models/ai_model_info.dart';
import '../data/models/ai_provider.dart';
import '../data/services/model_fetcher.dart';
import '../data/services/provider_detector.dart';
import '../domain/notifiers/active_provider_notifier.dart';
import '../domain/notifiers/provider_list_notifier.dart';
import '../domain/providers.dart';
import 'extensions.dart';
import 'widgets/neo_text_field.dart';

class AddEditProviderScreen extends ConsumerStatefulWidget {
  final String? providerId;

  const AddEditProviderScreen({super.key, this.providerId});

  @override
  ConsumerState<AddEditProviderScreen> createState() => _AddEditProviderScreenState();
}

class _AddEditProviderScreenState extends ConsumerState<AddEditProviderScreen> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _key = TextEditingController();

  ProviderType _detectedType = ProviderType.custom;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  List<AIModelInfo> _fetchedModels = const [];
  AIProvider? _editing;

  bool get _isEdit => widget.providerId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.providerId;
    if (id == null) return;
    final repo = ref.read(providerRepositoryProvider);
    final provider = repo.byId(id);
    if (provider == null) return;
    setState(() {
      _editing = provider;
      _name.text = provider.displayName;
      _url.text = provider.baseUrl;
      _detectedType = provider.type;
    });
    final key = await repo.apiKey(id);
    if (mounted) setState(() => _key.text = key ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _detectedType = ProviderDetector.detect(
        url: _url.text,
        apiKey: _key.text,
      ).type;
    });
  }

  Future<void> _testConnection() async {
    final url = _url.text.trim();
    final key = _key.text.trim();
    if (url.isEmpty || key.isEmpty) {
      NeumorphicSnackbar.show(
        context,
        message: 'Enter a base URL and API key first.',
        type: NeoSnackbarType.warning,
      );
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final models = await ModelFetcher.fetch(baseUrl: url, apiKey: key);
      if (models.models.isEmpty) {
        setState(() => _testResult = 'Reached endpoint, but no models found.');
      } else {
        setState(() {
          _fetchedModels = models.models;
          _testResult =
              'Connected (${models.latencyMs}ms) · ${models.models.length} models fetched.';
        });
      }
    } catch (e) {
      setState(() => _testResult = 'Connection failed: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final key = _key.text.trim();
    if (name.isEmpty || url.isEmpty) {
      NeumorphicSnackbar.show(
        context,
        message: 'Display name and base URL are required.',
        type: NeoSnackbarType.warning,
      );
      return;
    }
    setState(() => _saving = true);

    final repo = ref.read(providerRepositoryProvider);
    final id = _editing?.id ?? 'provider_${DateTime.now().millisecondsSinceEpoch}';

    final existing = _editing ??
        AIProvider(
          id: id,
          displayName: name,
          baseUrl: url,
          apiKeyRef: repo.apiKeyRefFor(id),
          typeName: _detectedType.name,
          addedAt: DateTime.now().toUtc(),
        );

    final updated = existing.copyWith(
      displayName: name,
      baseUrl: url,
      typeName: _detectedType.name,
      lastStatusName: _testResult != null && _testResult!.startsWith('Connected')
          ? ConnectionStatus.connected.name
          : existing.lastStatusName,
      lastTestedAt: _testResult != null ? DateTime.now().toUtc() : existing.lastTestedAt,
      cachedModelIds: _fetchedModels.isNotEmpty
          ? [for (final m in _fetchedModels) m.id]
          : existing.cachedModelIds,
    );

    await repo.setApiKey(id, key);
    await repo.save(updated);

    if (_fetchedModels.isNotEmpty) {
      await ref.read(modelRepositoryProvider).cache(id, _fetchedModels);
    }

    // First provider configured automatically becomes the active one.
    if (repo.activeProviderId() == null || _editing?.isActive == true) {
      await ref.read(activeProviderProvider.notifier).setActiveProvider(id);
    }

    ref.read(providerListProvider.notifier).refresh();
    if (mounted) {
      NeumorphicSnackbar.show(
        context,
        message: _isEdit ? 'Provider updated.' : 'Provider added.',
        type: NeoSnackbarType.success,
      );
      Navigator.of(context).pop();
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _detectedType.accent(isDark);

    return Scaffold(
      backgroundColor: AppColors.getStage(context),
      appBar: AppBar(
        backgroundColor: AppColors.getStage(context),
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Provider' : 'Add Provider',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Detected type banner
          NeumorphicCard(
            borderRadius: 18,
            depth: 3,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(_detectedType.icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected: ${_detectedType.label}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Updated automatically from URL / API key',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          NeoTextField(
            label: 'Display name',
            hint: 'e.g. My Groq Key',
            initialValue: '',
            controller: _name,
            onChanged: (_) {},
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          NeoTextField(
            label: 'Base URL',
            hint: 'https://api.groq.com/openai/v1',
            initialValue: '',
            controller: _url,
            keyboardType: TextInputType.url,
            onChanged: (_) => _onChanged(),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          NeoTextField(
            label: 'API key',
            hint: 'sk-…',
            initialValue: '',
            controller: _key,
            obscure: true,
            onChanged: (_) => _onChanged(),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _testConnection(),
            suffix: IconButton(
              icon: Icon(
                Icons.visibility_rounded,
                size: 18,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 20),

          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testResult!.startsWith('Connected')
                        ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                        : (isDark ? AppColors.darkDanger : AppColors.lightDanger))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _testResult!.startsWith('Connected')
                      ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                      : (isDark ? AppColors.darkDanger : AppColors.lightDanger),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: NeumorphicButton(
                  icon: _testing ? null : Icons.wifi_tethering_rounded,
                  text: _testing ? 'Testing…' : 'Test & Fetch Models',
                  onPressed: _testing ? null : _testConnection,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Models',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 8),
          if (_fetchedModels.isEmpty)
            NeumorphicCard(
              borderRadius: 16,
              depth: 2.5,
              padding: const EdgeInsets.all(14),
              child: Text(
                _editing != null
                    ? '${_editing!.cachedModelIds.length} models cached. Re-test to refresh the catalog.'
                    : 'No models yet. Tap "Test & Fetch Models" to pull the catalog from this endpoint.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            )
          else
            NeumorphicCard(
              borderRadius: 16,
              depth: 2.5,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final model in _fetchedModels.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• ${model.id}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ),
                  if (_fetchedModels.length > 5)
                    Text(
                      '+ ${_fetchedModels.length - 5} more',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 32),

          NeumorphicButton(
            icon: _saving ? null : Icons.save_rounded,
            text: _saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Add Provider'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
