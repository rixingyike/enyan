import 'package:equatable/equatable.dart';

abstract class BibleEvent extends Equatable {
  const BibleEvent();

  @override
  List<Object> get props => [];
}

class LoadBooksEvent extends BibleEvent {}

class LoadChapterEvent extends BibleEvent {
  final int bookId;
  final int chapter;

  const LoadChapterEvent({required this.bookId, required this.chapter});

  @override
  List<Object> get props => [bookId, chapter];
}
