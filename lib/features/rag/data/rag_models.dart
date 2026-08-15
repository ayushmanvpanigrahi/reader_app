import 'package:flutter/foundation.dart';

import '../../../core/api_config.dart';

/// A provider (base URL + key + model selections) pushed to the backend so
/// server-side RAG can use the same free/OpenAI-compatible providers the app
/// is configured with, and auto-switch when a free plan runs out.
@immutable
class RagProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String? chatModel;
  final String? embeddingModel;
  final int priority;

  const RagProvider({
    required this.id,
    this.name = '',
    required this.baseUrl,
    this.apiKey = '',
    this.chatModel,
    this.embeddingModel,
    this.priority = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'api_key': apiKey,
        'chat_model': chatModel ?? '',
        'embedding_model': embeddingModel ?? '',
        'priority': priority,
      };
}

@immutable
class RagConfig {
  final bool enabled;
  final String baseUrl;

  const RagConfig({
    this.enabled = false,
    this.baseUrl = kBackendBaseUrl,
  });

  RagConfig copyWith({bool? enabled, String? baseUrl}) {
    return RagConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}

/// Result of a backend health probe.
@immutable
class RagHealth {
  final bool ok;
  final int latencyMs;
  final String app;
  final String? version;
  final String? error;

  const RagHealth({
    this.ok = false,
    this.latencyMs = 0,
    this.app = '',
    this.version,
    this.error,
  });
}

enum RagBookStatus { notIndexed, ingesting, completed, failed }

@immutable
class RagBookIndex {
  final RagBookStatus status;
  final String? backendBookId;
  final double progress;
  final String? error;

  const RagBookIndex({
    this.status = RagBookStatus.notIndexed,
    this.backendBookId,
    this.progress = 0,
    this.error,
  });

  RagBookIndex copyWith({
    RagBookStatus? status,
    String? backendBookId,
    double? progress,
    String? error,
  }) {
    return RagBookIndex(
      status: status ?? this.status,
      backendBookId: backendBookId ?? this.backendBookId,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class RagEvent {
  final String type;
  final dynamic data;

  const RagEvent(this.type, this.data);
}

@immutable
class RagCitation {
  final String title;
  final String chapter;
  final int page;
  final double? score;

  const RagCitation({
    required this.title,
    required this.chapter,
    required this.page,
    this.score,
  });

  factory RagCitation.fromJson(Map<String, dynamic> json) {
    return RagCitation(
      title: json['title'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      page: (json['page'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

@immutable
class RagHighlightResult {
  final String simpleMeaning;
  final String authorContext;
  final String reflectionQuestion;
  final String analogy;
  final String takeaway;
  final List<RagCitation> citations;

  const RagHighlightResult({
    this.simpleMeaning = '',
    this.authorContext = '',
    this.reflectionQuestion = '',
    this.analogy = '',
    this.takeaway = '',
    this.citations = const [],
  });
}

@immutable
class RagChatMeta {
  final bool usedRag;
  final String? bookTitle;
  final int? retrieved;
  final bool grounded;
  final List<String> statuses;
  final List<RagCitation> citations;

  const RagChatMeta({
    this.usedRag = false,
    this.bookTitle,
    this.retrieved,
    this.grounded = true,
    this.statuses = const [],
    this.citations = const [],
  });

  RagChatMeta copyWith({
    bool? usedRag,
    String? bookTitle,
    int? retrieved,
    bool? grounded,
    List<String>? statuses,
    List<RagCitation>? citations,
  }) {
    return RagChatMeta(
      usedRag: usedRag ?? this.usedRag,
      bookTitle: bookTitle ?? this.bookTitle,
      retrieved: retrieved ?? this.retrieved,
      grounded: grounded ?? this.grounded,
      statuses: statuses ?? this.statuses,
      citations: citations ?? this.citations,
    );
  }
}
