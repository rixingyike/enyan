import 'package:gracewords/features/bible_reading/data/datasources/bible_local_datasource.dart';
import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/domain/entities/verse.dart';
import 'package:gracewords/features/bible_reading/domain/repositories/bible_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BibleRepository)
class BibleRepositoryImpl implements BibleRepository {
  final BibleLocalDataSource localDataSource;

  BibleRepositoryImpl(this.localDataSource);

  @override
  Future<List<Book>> getBooks() async {
    return await localDataSource.getBooks();
  }

  @override
  Future<List<Verse>> getVersesByChapter(int bookId, int chapter) async {
    return await localDataSource.getVerses(bookId, chapter);
  }
}
