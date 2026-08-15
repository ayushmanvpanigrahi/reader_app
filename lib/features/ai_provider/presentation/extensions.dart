import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/ai_model_info.dart';
import '../data/models/ai_provider.dart';

extension ProviderTypeX on ProviderType {
  String get label => switch (this) {
        ProviderType.groq => 'Groq',
        ProviderType.openrouter => 'OpenRouter',
        ProviderType.nvidia => 'NVIDIA NIM',
        ProviderType.anthropic => 'Anthropic',
        ProviderType.openai => 'OpenAI',
        ProviderType.custom => 'Custom',
      };

  IconData get icon => switch (this) {
        ProviderType.openrouter => Icons.hub_rounded,
        ProviderType.groq => Icons.flash_on_rounded,
        ProviderType.nvidia => Icons.memory_rounded,
        ProviderType.openai => Icons.science_rounded,
        ProviderType.anthropic => Icons.psychology_rounded,
        ProviderType.custom => Icons.dns_rounded,
      };

  Color accent(bool isDark) => isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
}

extension ConnectionStatusX on ConnectionStatus {
  String get label => switch (this) {
        ConnectionStatus.connected => 'Connected',
        ConnectionStatus.error => 'Error',
        ConnectionStatus.untested => 'Untested',
        ConnectionStatus.rateExhausted => 'Rate Exhausted',
      };

  Color color(bool isDark) => switch (this) {
        ConnectionStatus.connected => isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
        ConnectionStatus.error => isDark ? AppColors.darkDanger : AppColors.lightDanger,
        ConnectionStatus.untested => isDark ? AppColors.darkMuted : AppColors.lightMuted,
        ConnectionStatus.rateExhausted => isDark ? AppColors.darkWarning : AppColors.lightWarning,
      };

  IconData get icon => switch (this) {
        ConnectionStatus.connected => Icons.check_circle_rounded,
        ConnectionStatus.error => Icons.error_rounded,
        ConnectionStatus.untested => Icons.help_rounded,
        ConnectionStatus.rateExhausted => Icons.hourglass_top_rounded,
      };
}

extension ModelModalityX on ModelModality {
  String get label => switch (this) {
        ModelModality.text => 'Chat/Text',
        ModelModality.embeddings => 'Embeddings',
        ModelModality.vision => 'Vision/Multimodal',
        ModelModality.image => 'Image',
      };
}

extension ModelFamilyX on ModelFamily {
  String get label => switch (this) {
        ModelFamily.meta => 'Meta Llama',
        ModelFamily.mistral => 'Mistral',
        ModelFamily.qwen => 'Qwen',
        ModelFamily.deepseek => 'DeepSeek',
        ModelFamily.openai => 'OpenAI',
        ModelFamily.anthropic => 'Anthropic',
        ModelFamily.google => 'Google',
        ModelFamily.custom => 'Other',
      };
}

String formatCompact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return '$value';
}

String formatContext(int? window) {
  if (window == null || window <= 0) return '—';
  if (window >= 1000000) return '${(window / 1000000).toStringAsFixed(1)}M ctx';
  return '${(window / 1000).round()}k ctx';
}
