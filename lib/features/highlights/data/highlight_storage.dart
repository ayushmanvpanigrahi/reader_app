import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'highlight_model.dart';

class HighlightStorage {
  static const _boxName = 'highlights_v1';

  Box<String>? _cached;

  Future<Box<String>> get _box async {
    final cached = _cached;
    if (cached != null && cached.isOpen) return cached;
    final box = await Hive.openBox<String>(_boxName);
    _cached = box;
    return box;
  }

  Future<List<HighlightModel>> loadAll() async {
    final box = await _box;
    final result = <HighlightModel>[];
    for (final value in box.values) {
      try {
        result.add(HighlightModel.fromJson(jsonDecode(value) as Map<String, dynamic>));
      } catch (_) {}
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<List<HighlightModel>> loadForBook(String bookId) async {
    final all = await loadAll();
    return all.where((h) => h.bookId == bookId).toList();
  }

  Future<void> save(HighlightModel highlight) async {
    final box = await _box;
    await box.put(highlight.id, jsonEncode(highlight.toJson()));
  }

  Future<void> remove(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Future<void> clearBook(String bookId) async {
    final box = await _box;
    final toRemove = <String>[];
    for (final entry in box.toMap().entries) {
      try {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        if (json['bookId'] == bookId) toRemove.add(entry.key);
      } catch (_) {}
    }
    await box.deleteAll(toRemove);
  }
}
