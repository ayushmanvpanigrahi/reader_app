import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/surface_card.dart';
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
  bool _testSucceeded = false;
  List<AIModelInfo> _fetchedModels = const [];
  AIProvider? _editing;

  String? _nameError;
  String? _urlError;

  bool get _isEdit => widget.providerId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.providerId;
    if (id == null) return;
    try {
      final repo = ref.read(providerRepositoryProvider);
      final provider = repo.byId(id);
      if (provider == null) {
        if (mounted) _showError('Provider not found.');
        return;
      }
      setState(() {
        _editing = provider;
        _name.text = provider.displayName;
        _url.text = provider.baseUrl;
        _detectedType = provider.type;
      });
      final key = await repo.apiKey(id);
      if (mounted) setState(() => _key.text = key ?? '');
    } catch (e) {
      if (mounted) _showError('Failed to load provider: $e');
    }
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
      _validate();
    });
  }

  void _validate() {
    _nameError = _name.text.trim().isEmpty ? 'Display name is required.' : null;
    _urlError = _urlErrorText(_url.text.trim());
  }

  String? _urlErrorText(String url) {
    if (url.isEmpty) return 'Base URL is required.';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'Enter a valid URL, e.g. https://api.groq.com/openai/v1';
    }
    return null;
  }

  Future<void> _testConnection() async {
    final url = _url.text.trim();
    final key = _key.text.trim();
    final urlError = _urlErrorText(url);
    setState(() {
      _urlError = urlError;
      if (urlError != null) {
        _testResult = null;
        return;
      }
      _testing = true;
      _testResult = null;
    });
    if (urlError != null) return;

    try {
      final models = await ModelFetcher.fetch(baseUrl: url, apiKey: key);
      if (!mounted) return;
      if (models.models.isEmpty) {
        setState(() {
          _fetchedModels = const [];
          _testResult = 'Reached endpoint, but no models were found.';
          _testSucceeded = false;
        });
      } else {
        setState(() {
          _fetchedModels = models.models;
          _testResult =
              'Connected in ${models.latencyMs}ms · ${models.models.length} models fetched.';
          _testSucceeded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = _friendlyError(e);
        _testSucceeded = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('connectionTimeout') ||
        s.contains('Connection timeout') ||
        s.contains('Timed out')) {
      return 'Connection timed out. Check the URL and your network.';
    }
    if (s.contains('401') || s.toLowerCase().contains('unauthorized')) {
      return 'Authentication failed (401). Check your API key.';
    }
    if (s.contains('403')) {
      return 'Access forbidden (403). This endpoint rejected the key.';
    }
    if (s.contains('404')) {
      return 'Endpoint not found (404). Check that the URL points to an OpenAI-compatible base.';
    }
    if (s.contains('SocketException') || s.toLowerCase().contains('connection')) {
      return 'Could not connect. Is the endpoint reachable?';
    }
    return 'Connection failed: $e';
  }

  Future<void> _save() async {
    setState(_validate);
    if (_nameError != null || _urlError != null) return;

    final name = _name.text.trim();
    final url = _url.text.trim();
    final key = _key.text.trim();

    setState(() => _saving = true);
    try {
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
        lastStatusName: _testSucceeded
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

      if (repo.activeProviderId() == null || _editing?.isActive == true) {
        await ref.read(activeProviderProvider.notifier).setActiveProvider(id);
      }

      ref.read(providerListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Provider updated.' : 'Provider added.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError('Failed to save provider: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _detectedType.accent(isDark);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Provider' : 'Add Provider',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SurfaceCard(
            borderRadius: 14,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(_detectedType.icon, color: accent, size: 19),
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
                        'Auto-detected from the URL / API key you enter',
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
            errorText: _nameError,
            onChanged: (_) => _onChanged(),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          NeoTextField(
            label: 'Base URL',
            hint: 'https://api.groq.com/openai/v1',
            initialValue: '',
            controller: _url,
            errorText: _urlError,
            helperText: 'OpenAI-compatible endpoint, e.g. https://api.groq.com/openai/v1',
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
          ),
          const SizedBox(height: 20),

          if (_testResult != null) ...[
            StatusBanner(
              tone: _testSucceeded ? StatusTone.success : StatusTone.error,
              title: _testSucceeded ? 'Connection successful' : 'Connection failed',
              message: _testResult,
            ),
            const SizedBox(height: 14),
          ],

          FilledButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 18),
            label: Text(_testing ? 'Testing…' : 'Test & Fetch Models'),
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
          _buildModelsPanel(isDark),
          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Add Provider')),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsPanel(bool isDark) {
    if (_fetchedModels.isEmpty) {
      return SurfaceCard(
        borderRadius: 14,
        child: Text(
          _editing != null
              ? '${_editing!.cachedModelIds.length} models cached. Tap "Test & Fetch Models" to refresh the catalog.'
              : 'No models yet. Tap "Test & Fetch Models" to pull the catalog from this endpoint.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ),
      );
    }
    return SurfaceCard(
      borderRadius: 14,
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
    );
  }
}
