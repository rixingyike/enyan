import 'package:gracewords/features/bible_reading/domain/entities/verse.dart';

class VerseModel extends Verse {
  const VerseModel({
    required super.id,
    required super.bookId,
    required super.chapter,
    required super.verseNumber,
    required super.content,
  });

  factory VerseModel.fromJson(Map<String, dynamic> json) {
    return VerseModel(
      id: json['id'] ?? 0,
      bookId: json['book_id'] ?? 0,
      chapter: json['chapter'] ?? 0,
      verseNumber: json['verse'] ?? 0,
      content: json['text'] ?? json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verseNumber,
      'text': content,
    };
  }
}
