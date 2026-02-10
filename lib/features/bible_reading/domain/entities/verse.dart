import 'package:equatable/equatable.dart';

class Verse extends Equatable {
  final int id;
  final int bookId;
  final int chapter;
  final int verseNumber;
  final String content;

  const Verse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verseNumber,
    required this.content,
  });

  @override
  List<Object?> get props => [id, bookId, chapter, verseNumber, content];
}
