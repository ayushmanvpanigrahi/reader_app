import 'dart:convert';
import 'package:reader_app/features/library/data/models/book_model.dart';


class BookmarkModel {
  final String id;
  final String bookId;
  final String bookTitle;
  final BookFormat format;
  final int pageNumber;
  final String? epubCfi;
  final String? chapterTitle;
  final String? note;
  final DateTime createdAt;
  final int colorHex;

  const BookmarkModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.format,
    required this.pageNumber,
    this.epubCfi,
    this.chapterTitle,
    this.note,
    required this.createdAt,
    this.colorHex = 0xFFE57C20,
  });

  BookmarkModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    BookFormat? format,
    int? pageNumber,
    String? epubCfi,
    String? chapterTitle,
    String? note,
    DateTime? createdAt,
    int? colorHex,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      format: format ?? this.format,
      pageNumber: pageNumber ?? this.pageNumber,
      epubCfi: epubCfi ?? this.epubCfi,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'format': format.name,
      'pageNumber': pageNumber,
      'epubCfi': epubCfi,
      'chapterTitle': chapterTitle,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'colorHex': colorHex,
    };
  }

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? '',
      bookTitle: map['bookTitle'] as String? ?? 'Untitled',
      format: BookFormat.fromString(map['format'] as String? ?? 'pdf'),
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 1,
      epubCfi: map['epubCfi'] as String?,
      chapterTitle: map['chapterTitle'] as String?,
      note: map['note'] as String?,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      colorHex: (map['colorHex'] as num?)?.toInt() ?? 0xFFE57C20,
    );
  }

  String toJson() => json.encode(toMap());

  factory BookmarkModel.fromJson(String source) =>
      BookmarkModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
