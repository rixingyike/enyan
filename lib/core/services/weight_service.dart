import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

@singleton
class WeightService {
  Map<String, dynamic>? _timestamps;

  Future<void> init() async {
    await loadTimestamps();
  }

  Future<void> loadTimestamps() async {
    if (_timestamps != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/audio_timestamps.json');
      _timestamps = json.decode(jsonString);
      print('✅ Timestamps loaded from assets/audio_timestamps.json');
    } catch (e) {
      print('❌ Error loading timestamps: $e');
    }
  }

  List<List<double>> getChapterTimestamps(int bookId, int chapter) {
    if (_timestamps == null) return [];

    final bookData = _timestamps![bookId.toString()];
    if (bookData == null) return [];

    dynamic chapterData;
    if (bookData is Map) {
      chapterData = bookData[chapter.toString()];
    } else if (bookData is List) {
      // If it's a list, we assume it's for Chapter 1 (some NT data is flat)
      if (chapter == 1) {
        chapterData = bookData;
      }
    }

    if (chapterData == null) {
      print('⚠️ [WeightService] No timestamps for Book $bookId Chapter $chapter');
      return [];
    }

    try {
      return (chapterData as List).map((verse) {
        return (verse as List).map((val) => (val as num).toDouble()).toList();
      }).toList();
    } catch (e) {
      print('❌ [WeightService] Parse error for $bookId:$chapter: $e');
      return [];
    }
  }
}
