import 'package:gracewords/features/bible_reading/domain/entities/book.dart';

class BookModel extends Book {
  const BookModel({
    required super.id,
    required super.name,
    required super.shortName,
    required super.chapterCount,
    required super.testament,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    // 新约从第40卷开始（马太福音）
    final testament = id >= 40 ? 'NT' : 'OT';
    return BookModel(
      id: id,
      name: json['name_zh'] ?? json['name'] ?? '',
      shortName: json['name_en'] ?? json['short_name'] ?? '',
      chapterCount: json['chapter_count'] ?? 0,
      testament: testament,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_zh': name,
      'name_en': shortName,
      'chapter_count': chapterCount,
    };
  }
}
