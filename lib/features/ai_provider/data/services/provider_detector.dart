import '../models/ai_provider.dart';

class DetectionResult {
  final ProviderType type;
  final String displayName;
  final String keyPrefix;
  final String defaultBaseUrl;

  const DetectionResult({
    required this.type,
    required this.displayName,
    required this.keyPrefix,
    required this.defaultBaseUrl,
  });
}

/// Synchronous, zero-network heuristic provider detection. Runs on every
/// keystroke in the URL or API key field. Prefers URL evidence, then falls
/// back to API key prefixes.
class ProviderDetector {
  const ProviderDetector._();

  static DetectionResult detect({String? url, String? apiKey}) {
    final u = (url ?? '').trim().toLowerCase();
    final k = (apiKey ?? '').trim().toLowerCase();

    if (u.contains('openrouter.ai')) {
      return _r(ProviderType.openrouter, 'OpenRouter', 'sk-or-', 'https://openrouter.ai/api/v1');
    }
    if (u.contains('groq.com')) {
      return _r(ProviderType.groq, 'Groq', 'gsk_', 'https://api.groq.com/openai/v1');
    }
    if (u.contains('nvidia.com')) {
      return _r(ProviderType.nvidia, 'NVIDIA NIM', 'nvapi-', 'https://integrate.api.nvidia.com/v1');
    }
    if (u.contains('anthropic.com')) {
      return _r(ProviderType.anthropic, 'Anthropic', 'sk-ant-', 'https://api.anthropic.com');
    }
    if (u.contains('openai.com') || u.contains('azure')) {
      return _r(ProviderType.openai, 'OpenAI', 'sk-', 'https://api.openai.com/v1');
    }
    if (u.contains('deepseek.com')) {
      return _r(ProviderType.custom, 'DeepSeek', 'sk-', 'https://api.deepseek.com/v1');
    }
    if (u.contains('generativelanguage')) {
      return _r(ProviderType.custom, 'Gemini', 'AIza', 'https://generativelanguage.googleapis.com/v1beta/openai/');
    }
    if (u.contains('mistral.ai')) {
      return _r(ProviderType.custom, 'Mistral', '', 'https://api.mistral.ai/v1');
    }
    if (u.contains('together.xyz')) {
      return _r(ProviderType.custom, 'Together AI', 'tgp_v1_', 'https://api.together.xyz/v1');
    }
    if (u.contains('perplexity.ai')) {
      return _r(ProviderType.custom, 'Perplexity', 'pplx-', 'https://api.perplexity.ai');
    }
    if (u.contains('11434')) {
      return _r(ProviderType.custom, 'Ollama (Local)', '', 'http://localhost:11434/v1');
    }
    if (u.contains(':1234')) {
      return _r(ProviderType.custom, 'LM Studio (Local)', '', 'http://localhost:1234/v1');
    }

    if (k.startsWith('sk-or-')) {
      return _r(ProviderType.openrouter, 'OpenRouter', 'sk-or-', 'https://openrouter.ai/api/v1');
    }
    if (k.startsWith('gsk_')) {
      return _r(ProviderType.groq, 'Groq', 'gsk_', 'https://api.groq.com/openai/v1');
    }
    if (k.startsWith('nvapi-')) {
      return _r(ProviderType.nvidia, 'NVIDIA NIM', 'nvapi-', 'https://integrate.api.nvidia.com/v1');
    }
    if (k.startsWith('sk-ant-')) {
      return _r(ProviderType.anthropic, 'Anthropic', 'sk-ant-', 'https://api.anthropic.com');
    }
    if (k.startsWith('aiza')) {
      return _r(ProviderType.custom, 'Gemini', 'AIza', 'https://generativelanguage.googleapis.com/v1beta/openai/');
    }
    if (k.startsWith('tgp_v1_')) {
      return _r(ProviderType.custom, 'Together AI', 'tgp_v1_', 'https://api.together.xyz/v1');
    }
    if (k.startsWith('pplx-')) {
      return _r(ProviderType.custom, 'Perplexity', 'pplx-', 'https://api.perplexity.ai');
    }

    return _r(ProviderType.custom, 'Custom Provider', '', '');
  }

  static DetectionResult _r(ProviderType type, String name, String prefix, String baseUrl) {
    return DetectionResult(
      type: type,
      displayName: name,
      keyPrefix: prefix,
      defaultBaseUrl: baseUrl,
    );
  }
}
