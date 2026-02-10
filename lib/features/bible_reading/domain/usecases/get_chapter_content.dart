import 'package:equatable/equatable.dart';
import 'package:gracewords/features/bible_reading/domain/entities/verse.dart';
import 'package:gracewords/features/bible_reading/domain/repositories/bible_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetChapterContentUseCase {
  final BibleRepository repository;

  GetChapterContentUseCase(this.repository);

  Future<List<Verse>> call(GetChapterParams params) async {
    return await repository.getVersesByChapter(params.bookId, params.chapter);
  }
}

class GetChapterParams extends Equatable {
  final int bookId;
  final int chapter;

  const GetChapterParams({required this.bookId, required this.chapter});

  @override
  List<Object?> get props => [bookId, chapter];
}
