import 'package:equatable/equatable.dart';
import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/domain/entities/verse.dart';

abstract class BibleState extends Equatable {
  const BibleState();

  @override
  List<Object> get props => [];
}

class BibleInitial extends BibleState {}

class BibleLoading extends BibleState {}

class BooksLoaded extends BibleState {
  final List<Book> books;

  const BooksLoaded(this.books);

  @override
  List<Object> get props => [books];
}

class ChapterLoaded extends BibleState {
  final List<Verse> verses;
  final Book book;
  final int chapter;

  const ChapterLoaded(
      {required this.verses, required this.book, required this.chapter});

  @override
  List<Object> get props => [verses, book, chapter];
}

class BibleError extends BibleState {
  final String message;

  const BibleError(this.message);

  @override
  List<Object> get props => [message];
}
