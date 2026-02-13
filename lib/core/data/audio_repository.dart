import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/di/injection.dart';

@lazySingleton
class AudioRepository {
  // Map<BookId, Map<ChapterId, Url>>
  final Map<int, Map<int, String>> _audioUrls = {};
  bool _isInitialized = false;

  // Book ID to Name mapping for directory names (e.g., 01_创世记)
  static const Map<int, String> _bookNames = {
    1: "创世记", 2: "出埃及记", 3: "利未记", 4: "民数记", 5: "申命记",
    6: "约书亚记", 7: "士师记", 8: "路得记", 9: "撒母耳记上", 10: "撒母耳记下",
    11: "列王纪上", 12: "列王纪下", 13: "历代志上", 14: "历代志下", 15: "以斯拉记",
    16: "尼希米记", 17: "以斯帖记", 18: "约伯记", 19: "诗篇", 20: "箴言",
    21: "传道书", 22: "雅歌", 23: "以赛亚书", 24: "耶利米书", 25: "耶利米哀歌",
    26: "以西结书", 27: "但以理书", 28: "何西阿书", 29: "约珥书", 30: "阿摩司书",
    31: "俄巴底亚书", 32: "约拿书", 33: "弥迦书", 34: "那鸿书", 35: "哈巴谷书",
    36: "西番雅书", 37: "哈该书", 38: "撒迦利亚书", 39: "玛拉基书", 40: "马太福音",
    41: "马可福音", 42: "路加福音", 43: "约翰福音", 44: "使徒行传", 45: "罗马书",
    46: "哥林多前书", 47: "哥林多后书", 48: "加拉太书", 49: "以弗所书", 50: "腓立比书",
    51: "歌罗西书", 52: "帖撒罗尼迦前书", 53: "帖撒罗尼迦后书", 54: "提摩太前书", 55: "提摩太后书",
    56: "提多书", 57: "腓利门书", 58: "希伯来书", 59: "雅各书", 60: "彼得前书",
    61: "彼得后书", 62: "约翰一书", 63: "约翰二书", 64: "约翰三书", 65: "犹大书",
    66: "启示录"
  };

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
      debugPrint("📖 [AudioRepo] Loaded bible_audio_urls.txt (${content.length} chars)");
      _parseContent(content);
      _isInitialized = true;
      debugPrint("✅ [AudioRepo] Initialized with ${_audioUrls.length} books");
      if (_audioUrls.containsKey(40)) {
        debugPrint("📖 [AudioRepo] Matthew (40) has ${_audioUrls[40]!.length} chapters");
      } else {
        debugPrint("❌ [AudioRepo] Matthew (40) NOT FOUND!");
      }
    } catch (e) {
      debugPrint("❌ [AudioRepo] Error initializing: $e");
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
          debugPrint("Error parsing header: $line");
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
    final url = _audioUrls[bookId]?[chapterId];
    debugPrint("🔍 [AudioRepo] getAudioUrl(book: $bookId, chap: $chapterId) -> ${url != null ? 'Found' : 'NULL'}");
    return url;
  }

  Future<File> getLocalAudioFile(int bookId, int chapterId) async {
    final dir = await getApplicationDocumentsDirectory();

    // 0. Check project root data directory (Priority for Development)
    if (kDebugMode) {
      final String bookName = _bookNames[bookId] ?? "";
      final String bookIdPadded = bookId.toString().padLeft(2, '0');
      
      // Determine quality preference
      final settings = getIt<SettingsService>();
      final quality = settings.voiceQuality.value; // 'high', 'basic', 'auto'
      
      List<String> qualityPaths = [];
      if (quality == 'high') {
        // High quality: 8k -> 6k -> mp3
        qualityPaths = ['opus_8k', 'opus_6k', 'hehemp3'];
      } else if (quality == 'basic') {
        // Basic quality: 6k -> 8k -> mp3
        qualityPaths = ['opus_6k', 'opus_8k', 'hehemp3'];
      } else {
        // Auto/Default: 8k -> 6k -> mp3
        qualityPaths = ['opus_8k', 'opus_6k', 'hehemp3'];
      }

      for (final q in qualityPaths) {
        // Format: data/{quality}/{book_id}_{book_name}/{chapter}.{ext}
        final ext = q.contains('mp3') ? 'mp3' : 'opus';
        final String devPath = path.join(Directory.current.path, 'data', q, '${bookIdPadded}_$bookName', '$chapterId.$ext');
        final devFile = File(devPath);
        if (devFile.existsSync()) {
          debugPrint("🎯 [AudioRepo] Dev Match found ($q): $devPath");
          return devFile;
        }
      }
    }

    // 1. Check individual download (priority)
    final audioDir = Directory('${dir.path}/audio/$bookId');
    final individualFile = File('${audioDir.path}/$chapterId.mp3');
    if (individualFile.existsSync()) {
      return individualFile;
    }

    // 2. Check packs based on settings
    final packsDir = Directory('${dir.path}/packs');
    final settings = getIt<SettingsService>();
    final quality = settings.voiceQuality.value;

    List<String> packIds;
    if (quality == 'high') {
      packIds = ['voice_8k'];
    } else if (quality == 'basic') {
      packIds = ['voice_6k'];
    } else {
      packIds = ['voice_8k', 'voice_6k'];
    }

    // New smart lookup logic for packs
    for (final packId in packIds) {
      final packRoot = Directory('${packsDir.path}/$packId');
      if (!packRoot.existsSync()) continue;

      // The structure can be packs/$packId/$bookId_$Name/$chapterId.opus
      // or packs/$packId/audio/$bookId_$Name/$chapterId.opus
      final searchRoots = [
        packRoot,
        Directory('${packRoot.path}/audio'),
      ];

      for (final root in searchRoots) {
        if (!root.existsSync()) {
          debugPrint("🔍 [AudioRepo] Search root not found: ${root.path}");
          continue;
        }

        debugPrint("🔍 [AudioRepo] Scanning root: ${root.path}");

        // Find the book directory (e.g., "12" or "12_2_Kings")
        Directory? bookDir;
        try {
          final entities = root.listSync();
          for (final entity in entities) {
            if (entity is Directory) {
              final name = path.basename(entity.path);
              final bookIdStr = bookId.toString();
              final bookIdPadded = bookIdStr.padLeft(2, '0');
              
              debugPrint("   📁 [AudioRepo] Found dir: $name (Checking for $bookIdStr or $bookIdPadded)");
              // Matches "12", "12_*" or "01", "01_*"
              if (name == bookIdStr || name.startsWith('${bookIdStr}_') ||
                  name == bookIdPadded || name.startsWith('${bookIdPadded}_')) {
                bookDir = entity;
                debugPrint("   ✅ [AudioRepo] Match found: ${bookDir.path}");
                break;
              }
            }
          }
        } catch (e) {
          debugPrint("   ❌ [AudioRepo] List error: $e");
        }

        if (bookDir != null) {
          // Try multiple file variants: 1.mp3, 01.mp3, 1.opus, 01.opus
          final chapterStr = chapterId.toString();
          final chapterPadded = chapterStr.padLeft(2, '0');
          final variants = [
            '$chapterStr.mp3',
            '$chapterPadded.mp3',
            '$chapterStr.opus',
            '$chapterPadded.opus',
          ];

          for (final variant in variants) {
            final filePath = path.join(bookDir.path, variant);
            final file = File(filePath);
            final exists = file.existsSync();
            debugPrint("      ❓ [AudioRepo] Checking file: $filePath -> ${exists ? 'EXISTS' : 'NOT FOUND'}");
            if (exists) {
              debugPrint("   🎯 [AudioRepo] File matched and returning: ${file.path}");
              return file;
            }
          }
          debugPrint("   ⚠️ [AudioRepo] Directory found but no matching file variant in: ${bookDir.path}");
        }
      }
    }

    // Default to individual path for download target
    // Default to individual path
    if (!audioDir.existsSync()) {
      await audioDir.create(recursive: true);
    }
    debugPrint("   🔗 [AudioRepo] No pack found, using individual file path: ${individualFile.path}");
    return individualFile;
  }

  Future<bool> isAudioDownloaded(int bookId, int chapterId) async {
    final file = await getLocalAudioFile(bookId, chapterId);
    return file.existsSync();
  }
}
