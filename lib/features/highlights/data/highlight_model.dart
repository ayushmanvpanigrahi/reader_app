class HighlightExplanation {
  final String simpleMeaning;
  final String authorContext;
  final String reflectionQuestion;
  final String analogy;
  final String takeaway;

  const HighlightExplanation({
    required this.simpleMeaning,
    required this.authorContext,
    required this.reflectionQuestion,
    required this.analogy,
    required this.takeaway,
  });
}

class HighlightModel {
  final String id;
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final String selectedText;
  final HighlightExplanation explanation;
  final DateTime createdAt;
  final int colorHex;

  const HighlightModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.selectedText,
    required this.explanation,
    required this.createdAt,
    this.colorHex = 0xFFE57C20,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'pageNumber': pageNumber,
        'selectedText': selectedText,
        'simpleMeaning': explanation.simpleMeaning,
        'authorContext': explanation.authorContext,
        'reflectionQuestion': explanation.reflectionQuestion,
        'analogy': explanation.analogy,
        'takeaway': explanation.takeaway,
        'createdAt': createdAt.toIso8601String(),
        'colorHex': colorHex,
      };

  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? '',
      pageNumber: json['pageNumber'] as int? ?? 0,
      selectedText: json['selectedText'] as String? ?? '',
      explanation: HighlightExplanation(
        simpleMeaning: json['simpleMeaning'] as String? ?? '',
        authorContext: json['authorContext'] as String? ?? '',
        reflectionQuestion: json['reflectionQuestion'] as String? ?? '',
        analogy: json['analogy'] as String? ?? '',
        takeaway: json['takeaway'] as String? ?? '',
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      colorHex: json['colorHex'] as int? ?? 0xFFE57C20,
    );
  }
}
