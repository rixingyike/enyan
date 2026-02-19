import 'package:gracewords/core/database/database_helper.dart';
import 'package:gracewords/features/bible_reading/data/models/book_model.dart';
import 'package:gracewords/features/bible_reading/data/models/verse_model.dart';
import 'package:injectable/injectable.dart';

abstract class BibleLocalDataSource {
  Future<List<BookModel>> getBooks();
  Future<List<VerseModel>> getVerses(int bookId, int chapter);
}

@LazySingleton(as: BibleLocalDataSource)
class BibleLocalDataSourceImpl implements BibleLocalDataSource {
  final DatabaseHelper databaseHelper;

  BibleLocalDataSourceImpl(this.databaseHelper);

  @override
  Future<List<BookModel>> getBooks() async {
    final db = await databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) => BookModel.fromJson(maps[i]));
  }

  @override
  Future<List<VerseModel>> getVerses(int bookId, int chapter) async {
    final db = await databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'verses',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
    );
    return List.generate(maps.length, (i) => VerseModel.fromJson(maps[i]));
  }
}
