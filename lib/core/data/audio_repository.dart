import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

@lazySingleton
class AudioRepository {
  // Map<BookId, Map<ChapterId, Url>>
  final Map<int, Map<int, String>> _audioUrls = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Parse the embedded asset file
      // configured in pubspec.yaml as assets/data/bible_audio_urls.txt (need to ensure it is in assets)
      // Wait, currently it is in `data/bible_audio_urls.txt` which is NOT an asset.
      // We need to read it from the file system if we are in dev, or it should be an asset.
      // For the app to work, this file MUST be an asset.
      // I will assume it will be added to assets, but for now I might need to read it differently or
      // request the user to move it.
      // Actually, let's hardcode the parsing logic assuming string input first,
      // and I'll add the file to assets in the next step.

      final String content =
          await rootBundle.loadString('assets/data/bible_audio_urls.txt');
      _parseContent(content);
      _isInitialized = true;
    } catch (e) {
      print("Error initializing AudioRepository: $e");
    }
  }

  void _parseContent(String content) {
    final lines = content.split('\n');
    int currentBookId = 0;

    // Book ID mapping based on the file structure (Genesis=1, etc.)
    // The file has headers like "# 01. Genesis (50 章)"

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        // Parse Header: "# 01. Genesis (50 章)"
        try {
          final parts = line.split('.');
          if (parts.length >= 2) {
            final idStr = parts[0].replaceAll('#', '').trim();
            currentBookId = int.parse(idStr);
            _audioUrls[currentBookId] = {};
          }
        } catch (e) {
          print("Error parsing header: $line");
        }
      } else if (line.startsWith('http')) {
        // Parse URL
        // We need to determine the chapter number.
        // The URLs are like .../C01Genesis%2001.mp3
        // We can just increment chapter counter or try to parse it.
        // simpler is to just increment if we are strictly sequential.
        // But let's try to extract it for safety if possible, or just use list index + 1.
        if (currentBookId > 0) {
          final currentChapterCount = _audioUrls[currentBookId]!.length + 1;
          _audioUrls[currentBookId]![currentChapterCount] = line;
        }
      }
    }
  }

  String? getAudioUrl(int bookId, int chapterId) {
    return _audioUrls[bookId]?[chapterId];
  }

  Future<File> getLocalAudioFile(int bookId, int chapterId) async {
    final dir = await getApplicationDocumentsDirectory();

    // 1. Check individual download (priority)
    final audioDir = Directory('${dir.path}/audio/$bookId');
    final individualFile = File('${audioDir.path}/$chapterId.mp3');
    if (individualFile.existsSync()) {
      return individualFile;
    }

    // 2. Check packs (voice_8k > voice_6k)
    // Structure assumption: packs/voice_6k/audio/bookId/chapterId.mp3 OR packs/voice_6k/bookId/chapterId.mp3
    final packsDir = Directory('${dir.path}/packs');

    // List of pack IDs to check in order
    final packIds = ['voice_8k', 'voice_6k'];

    for (final packId in packIds) {
      // Try path variant 1: packs/$packId/$bookId/$chapterId.mp3
      final file1 = File('${packsDir.path}/$packId/$bookId/$chapterId.mp3');
      if (file1.existsSync()) return file1;

      // Try path variant 2: packs/$packId/audio/$bookId/$chapterId.mp3
      final file2 =
          File('${packsDir.path}/$packId/audio/$bookId/$chapterId.mp3');
      if (file2.existsSync()) return file2;
    }

    // Default to individual path for download target
    if (!audioDir.existsSync()) {
      await audioDir.create(recursive: true);
    }
    return individualFile;
  }

  Future<bool> isAudioDownloaded(int bookId, int chapterId) async {
    final file = await getLocalAudioFile(bookId, chapterId);
    return file.existsSync();
  }
}
