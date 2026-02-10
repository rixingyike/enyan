import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gracewords/core/constants/bible_constants.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_bloc.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_event.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_state.dart';
import 'package:gracewords/features/bible_reading/presentation/pages/chapter_page.dart';
// import 'package:traditional_simplified_converter/traditional_simplified_converter.dart'; // Add later if package works

import 'package:gracewords/features/settings/presentation/pages/settings_page.dart';
import 'package:gracewords/core/services/settings_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Flag handled in _handleAutoNavigation

  @override
  Widget build(BuildContext context) {
    final settings = getIt<SettingsService>();

    return Scaffold(
      body: BlocProvider(
        create: (_) => getIt<BibleBloc>()..add(LoadBooksEvent()),
        child: BlocConsumer<BibleBloc, BibleState>(
          listener: (context, state) {
            if (state is BooksLoaded) {
              _handleAutoNavigation(context, state.books);
            }
          },
          builder: (context, state) {
            if (state is BibleLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is BooksLoaded) {
              // Split books into OT and NT
              final otBooks = state.books.where((b) => b.id <= 39).toList();
              final ntBooks = state.books.where((b) => b.id >= 40).toList();

              return DefaultTabController(
                length: 2,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('大字有声圣经'),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsPage()),
                          );
                        },
                      ),
                    ],
                    bottom: const TabBar(
                      labelStyle:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: TextStyle(fontSize: 16),
                      indicatorColor: Colors.brown,
                      labelColor: Colors.brown,
                      tabs: [
                        Tab(text: "新约"), // New Testament First
                        Tab(text: "旧约"),
                      ],
                    ),
                  ),
                  body: ValueListenableBuilder<bool>(
                    valueListenable: settings.isSimplified,
                    builder: (context, isSimplified, _) {
                      return TabBarView(
                        children: [
                          _buildBookList(ntBooks, isSimplified),
                          _buildBookList(otBooks, isSimplified),
                        ],
                      );
                    },
                  ),
                ),
              );
            } else if (state is BibleError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildBookList(List<dynamic> books, bool isSimplified) {
    // Group books by category
    final groupedBooks = _groupBooks(books, BibleConstants.categories);

    // Build list of slivers for each category
    List<Widget> slivers = [];
    for (var entry in groupedBooks.entries) {
      // Category header
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            entry.key,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
      ));
      // Grid of books in that category
      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final book = entry.value[index];
              final shortName = BibleConstants.getShortName(book.id,
                  isSimplified: isSimplified);
              final fullName = BibleConstants.getFullName(book.id,
                  isSimplified: isSimplified);

              return GestureDetector(
                onTap: () {
                  int targetChapter = 1;
                  if (book.id == 43) targetChapter = 3;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChapterPage(
                          book: book, initialChapter: targetChapter),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Big First Char Logic
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: shortName.isNotEmpty ? shortName[0] : "",
                              style: const TextStyle(fontSize: 40),
                            ),
                            TextSpan(
                              text: shortName.length > 1
                                  ? shortName.substring(1)
                                  : "",
                              style: const TextStyle(fontSize: 24),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: entry.value.length,
          ),
        ),
      ));
    }
    // Add bottom padding
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

    return CustomScrollView(slivers: slivers);
  }

  bool _hasAutoNavigated = false;

  void _handleAutoNavigation(BuildContext context, List<dynamic> books) {
    if (_hasAutoNavigated) return;
    _hasAutoNavigated = true;

    final settings = getIt<SettingsService>();
    final progress = settings.getLastReadingProgress();

    if (progress != null) {
      final lastBookId = progress['bookId'] as int;
      final lastChapter = progress['chapter'] as int;

      // Find book in loaded books
      try {
        final book = books.firstWhere((b) => b.id == lastBookId);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChapterPage(book: book, initialChapter: lastChapter),
          ),
        );
      } catch (e) {
        // Book not found or error, ignore auto-resume
        debugPrint("Auto-resume failed: $e");
      }
    }
  }

  Map<String, List<dynamic>> _groupBooks(
      List<dynamic> books, List<BibleCategory> categories) {
    Map<String, List<dynamic>> groups = {};
    for (var category in categories) {
      List<dynamic> categoryBooks =
          books.where((b) => category.bookIds.contains(b.id)).toList();
      if (categoryBooks.isNotEmpty) {
        groups[category.name] = categoryBooks;
      }
    }
    // Handle remaining? (Should cover all)
    return groups;
  }

  String _stripEnglish(String input) {
    // Regex to keep only Chinese characters? Or just strip (...)
    // Or just take Chinese.
    // Assuming format "中文 (English)"
    if (input.contains("(")) {
      return input.split("(")[0].trim();
    }
    return input;
  }
}
