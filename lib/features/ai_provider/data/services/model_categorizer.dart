import '../models/ai_model_info.dart';

const _embeddingPatterns = <String>[
  'embedding',
  '-embed',
  'embedqa',
  'nv-embed',
  'nemoretriever',
  'bge',
  'e5-',
];

/// Pure, side-effect-free model categorization. Given a raw GET /models entry,
/// decides which [ModelCategory] the model belongs to. Provider-specific
/// overrides (NVIDIA `model_type`, OpenRouter `architecture.modality`) are
/// inspected before falling back to id/marker heuristics.
ModelCategory categorizeModel(String id, Map<String, dynamic> raw) {
  final idLower = id.toLowerCase();
  final type = raw['type']?.toString().toLowerCase() ?? '';
  final architecture = raw['architecture'];
  final modality =
      architecture is Map ? architecture['modality']?.toString().toLowerCase() ?? '' : '';
  final inputModalities = raw['input_modalities'];
  final hasImageInput = inputModalities is List && inputModalities.contains('image');

  // Provider-specific overrides.
  if (type == 'embedding' || modality == 'text->embedding') return ModelCategory.embedding;
  if (modality == 'text->image' || modality == 'text->audio' || modality == 'audio->text') {
    return modality == 'text->image' ? ModelCategory.imageGeneration : ModelCategory.audio;
  }

  if (_embeddingPatterns.any(idLower.contains)) return ModelCategory.embedding;
  if (idLower.contains('dall-e') ||
      idLower.contains('stable-diffusion') ||
      idLower.contains('flux') ||
      idLower.contains('sdxl') ||
      idLower.contains('cogview')) {
    return ModelCategory.imageGeneration;
  }
  if (type == 'audio' ||
      idLower.contains('whisper') ||
      idLower.contains('speech') ||
      idLower.contains('tts-') ||
      idLower.contains('stt-')) {
    return ModelCategory.audio;
  }
  if (idLower.contains('vision') ||
      idLower.contains('omni') ||
      idLower.contains('multimodal') ||
      idLower.contains('pixtral') ||
      idLower.contains('-vl') ||
      hasImageInput) {
    return ModelCategory.vision;
  }
  return ModelCategory.textGeneration;
}
