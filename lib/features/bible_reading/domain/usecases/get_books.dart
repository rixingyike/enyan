import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/domain/repositories/bible_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetBooksUseCase {
  final BibleRepository repository;

  GetBooksUseCase(this.repository);

  Future<List<Book>> call() async {
    return await repository.getBooks();
  }
}
