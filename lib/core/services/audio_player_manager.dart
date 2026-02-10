import 'package:just_audio/just_audio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer();

  // Expose player state streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<double> get speedStream => _player.speedStream;

  // Current state values
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  /// Load audio from assets
  /// Path format: assets/audio/{folderName}/{chapter}.opus
  Future<void> loadChapterAudio(int bookId, int chapter) async {
    try {
      final folderName = _getAudioFolderName(bookId);
      if (folderName == null) {
        throw Exception("Audio not available for book ID $bookId");
      }

      // Ensure chapter is 2 digits for filename e.g. "01.opus"
      final chapterStr = chapter.toString().padLeft(2, '0');

      // Construct asset path
      // e.g. "assets/audio/01_Genesis/01.opus"
      final assetPath = "assets/audio/$folderName/$chapterStr.opus";

      print("Loading audio: $assetPath");
      await _player.setAsset(assetPath);
    } catch (e) {
      print("Error loading audio: $e");
      rethrow;
    }
  }

  String? _getAudioFolderName(int bookId) {
    return _bookFolders[bookId];
  }

  // Mapping from Book ID to folder name
  // Must match the exact directory names in assets/audio/
  static const Map<int, String> _bookFolders = {
    1: "01_Genesis",
    2: "02_Exodus",
    3: "03_Leviticus",
    4: "04_Numbers",
    5: "05_Deuterenomy",
    6: "06_Joshua",
    7: "07_Judges",
    8: "08_Ruth",
    9: "09_ 1 Samuel",
    10: "10_ 2 Samuel",
    11: "11_ 1 Kings",
    12: "12_ 2 Kings",
    13: "13_ 1 Chronicles",
    14: "14_ 2 Chronicles",
    15: "15_Ezra",
    16: "16_Nehemiah",
    17: "17_Esther",
    18: "18_Job",
    19: "19_Psalm",
    20: "20_Proverbs",
    21: "21_Ecclesiastes",
    22: "22_Song of Songs",
    23: "23_Isaiah",
    24: "24_Jeremiah",
    25: "25_Lamentations",
    26: "26_Ezekiel",
    27: "27_Daniel",
    28: "28_Hosea",
    29: "29_Joel",
    30: "30_Amos",
    31: "31_Obadiah",
    32: "32_Jonah",
    33: "33_Micah",
    34: "34_Nahum",
    35: "35_Habakkuk",
    36: "36_Zephaniah",
    37: "37_Haggai",
    38: "38_Zechariah",
    39: "39_Malachi",
    40: "40_Matthew",
    41: "41_Mark",
    42: "42_Luke",
    43: "43_John",
    44: "44_Acts",
    45: "45_Romans",
    46: "46_ 1 Corinthians",
    47: "47_ 2 Corinthians",
    48: "48_Galatians",
    49: "49_Ephesians",
    50: "50_Philippians",
    51: "51_Colossians",
    52: "52_ 1 Thess",
    53: "53_ 2 Thess",
    54: "54_ 1 Timothy",
    55: "55_ 2 Timothy",
    56: "56_Titus",
    57: "57_Philemon",
    58: "58_Hebrews",
    59: "59_James",
    60: "60_ 1 Peter",
    61: "61_ 2 Peter",
    62: "62_ 1 John",
    63: "63_ 2 John",
    64: "64_ 3 John",
    65: "65_Jude",
    66: "66_Revelation",
  };

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
