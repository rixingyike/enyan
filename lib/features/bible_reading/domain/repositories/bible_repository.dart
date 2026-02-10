import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/domain/entities/verse.dart';

abstract class BibleRepository {
  Future<List<Book>> getBooks();
  Future<List<Verse>> getVersesByChapter(int bookId, int chapter);
}
