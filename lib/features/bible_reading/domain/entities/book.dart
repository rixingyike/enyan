import 'package:equatable/equatable.dart';

class Book extends Equatable {
  final int id;
  final String name;
  final String shortName;
  final int chapterCount;
  final String testament; // 'OT' or 'NT'

  const Book({
    required this.id,
    required this.name,
    required this.shortName,
    required this.chapterCount,
    required this.testament,
  });

  @override
  List<Object?> get props => [id, name, shortName, chapterCount, testament];
}
