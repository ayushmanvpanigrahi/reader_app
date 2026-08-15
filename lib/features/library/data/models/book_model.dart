import 'dart:convert';

enum BookFormat {
  pdf,
  epub;

  static BookFormat fromString(String ext) {
    if (ext.toLowerCase().contains('epub')) return BookFormat.epub;
    return BookFormat.pdf;
  }
}

class BookModel {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final BookFormat format;
  final int fileSizeBytes;
  final int totalPages;
  final int currentPage;
  final String? epubCfi;
  final double progress; // 0.0 to 1.0
  final int coverColorIndex;
  final bool isFavorite;
  final DateTime? lastReadAt;
  final DateTime addedAt;
  final bool isAssetSample;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.fileSizeBytes = 0,
    this.totalPages = 1,
    this.currentPage = 1,
    this.epubCfi,
    this.progress = 0.0,
    this.coverColorIndex = 0,
    this.isFavorite = false,
    this.lastReadAt,
    required this.addedAt,
    this.isAssetSample = false,
  });

  double get progressPercentage => (progress * 100).clamp(0, 100);

  bool get isPdf => format == BookFormat.pdf;
  bool get isEpub => format == BookFormat.epub;

  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    BookFormat? format,
    int? fileSizeBytes,
    int? totalPages,
    int? currentPage,
    String? epubCfi,
    double? progress,
    int? coverColorIndex,
    bool? isFavorite,
    DateTime? lastReadAt,
    DateTime? addedAt,
    bool? isAssetSample,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      epubCfi: epubCfi ?? this.epubCfi,
      progress: progress ?? this.progress,
      coverColorIndex: coverColorIndex ?? this.coverColorIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt ?? this.addedAt,
      isAssetSample: isAssetSample ?? this.isAssetSample,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format.name,
      'fileSizeBytes': fileSizeBytes,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'epubCfi': epubCfi,
      'progress': progress,
      'coverColorIndex': coverColorIndex,
      'isFavorite': isFavorite,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'isAssetSample': isAssetSample,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled Book',
      author: map['author'] as String? ?? 'Unknown Author',
      filePath: map['filePath'] as String? ?? '',
      format: BookFormat.fromString(map['format'] as String? ?? 'pdf'),
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      currentPage: (map['currentPage'] as num?)?.toInt() ?? 1,
      epubCfi: map['epubCfi'] as String?,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      coverColorIndex: (map['coverColorIndex'] as num?)?.toInt() ?? 0,
      isFavorite: map['isFavorite'] as bool? ?? false,
      lastReadAt: map['lastReadAt'] != null
          ? DateTime.tryParse(map['lastReadAt'] as String)
          : null,
      addedAt: map['addedAt'] != null
          ? (DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      isAssetSample: map['isAssetSample'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory BookModel.fromJson(String source) =>
      BookModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
