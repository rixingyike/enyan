import 'package:bloc/bloc.dart';
import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/domain/usecases/get_books.dart';
import 'package:gracewords/features/bible_reading/domain/usecases/get_chapter_content.dart';
import 'package:injectable/injectable.dart';

import 'bible_event.dart';
import 'bible_state.dart';

import 'package:gracewords/core/services/settings_service.dart';

@injectable
class BibleBloc extends Bloc<BibleEvent, BibleState> {
  final GetBooksUseCase getBooksUseCase;
  final GetChapterContentUseCase getChapterContentUseCase;
  final SettingsService settingsService;

  List<Book>? _cachedBooks;

  BibleBloc(
    this.getBooksUseCase,
    this.getChapterContentUseCase,
    this.settingsService,
  ) : super(BibleInitial()) {
    on<LoadBooksEvent>(_onLoadBooks);
    on<LoadChapterEvent>(_onLoadChapter);

    settingsService.isSimplified.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    _cachedBooks = null;
    add(LoadBooksEvent());
  }

  @override
  Future<void> close() {
    settingsService.isSimplified.removeListener(_onSettingsChanged);
    return super.close();
  }

  Future<void> _onLoadBooks(
      LoadBooksEvent event, Emitter<BibleState> emit) async {
    emit(BibleLoading());
    try {
      final books = await getBooksUseCase();
      _cachedBooks = books;
      emit(BooksLoaded(books));
    } catch (e) {
      emit(BibleError(e.toString()));
    }
  }

  Future<void> _onLoadChapter(
      LoadChapterEvent event, Emitter<BibleState> emit) async {
    emit(BibleLoading());
    try {
      // Find book info from cache if available, or fetch it (simplified here assuming cache hits)
      // In real app we might need to fetch book by ID separately if deep linking
      _cachedBooks ??= await getBooksUseCase();
      final book = _cachedBooks!.firstWhere((b) => b.id == event.bookId);

      final verses = await getChapterContentUseCase(
        GetChapterParams(bookId: event.bookId, chapter: event.chapter),
      );
      emit(ChapterLoaded(verses: verses, book: book, chapter: event.chapter));
    } catch (e) {
      emit(BibleError(e.toString()));
    }
  }
}
