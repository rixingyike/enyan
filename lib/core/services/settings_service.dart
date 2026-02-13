import 'package:flutter/foundation.dart';
import 'package:gracewords/core/database/database_helper.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class SettingsService {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper;
  static const String _keyLastBookId = 'last_book_id';
  static const String _keyLastChapterId = 'last_chapter_id';
  static const String _keyLastScrollPosition = 'last_scroll_position';
  static const String _keyIsSimplified = 'is_simplified';
  static const String _keyRustVoiceId = 'rust_voice_id';

  final ValueNotifier<bool> isSimplified = ValueNotifier(true);

  SettingsService(this._prefs, this._dbHelper) {
    _init();
  }

  void _init() {
    final val = _prefs.getBool(_keyIsSimplified) ?? true;
    isSimplified.value = val;
    // Audio Mode
    isHumanVoice.value = _prefs.getBool(_keyIsHumanVoice) ?? false;
    voiceQuality.value = _prefs.getString(_keyVoiceQuality) ?? 'auto';
    // TTS Engine
    ttsEngine.value = _prefs.getString(_keyTtsEngine) ?? 'system';
    // TTS Server URL
    ttsServerUrl.value =
        _prefs.getString(_keyTtsServerUrl) ?? 'http://localhost:8080/api/tts';
    // Rust Voice
    rustVoiceId.value = _prefs.getString(_keyRustVoiceId);

    // Ensure DB is set correctly on init
    _dbHelper.switchDatabase(val);
  }

  Future<void> setSimplified(bool value) async {
    isSimplified.value = value;
    await _prefs.setBool(_keyIsSimplified, value);
    await _dbHelper.switchDatabase(value);
  }

  // Audio Mode
  static const String _keyIsHumanVoice = 'is_human_voice';
  final ValueNotifier<bool> isHumanVoice = ValueNotifier(true);

  Future<void> setHumanVoice(bool value) async {
    isHumanVoice.value = value;
    await _prefs.setBool(_keyIsHumanVoice, value);
  }

  // Voice Quality: 'auto' | 'high' | 'basic'
  static const String _keyVoiceQuality = 'voice_quality';
  final ValueNotifier<String> voiceQuality = ValueNotifier('high');

  Future<void> setVoiceQuality(String value) async {
    voiceQuality.value = value;
    await _prefs.setString(_keyVoiceQuality, value);
    // Automatically enable human voice mode when a quality is selected
    if (value == 'high' || value == 'basic') {
      isHumanVoice.value = true;
      await _prefs.setBool(_keyIsHumanVoice, true);
    }
  }

  // TTS Engine: 'system' | 'sherpa'
  static const String _keyTtsEngine = 'tts_engine';
  final ValueNotifier<String> ttsEngine = ValueNotifier('piper');

  Future<void> setTtsEngine(String value) async {
    ttsEngine.value = value;
    await _prefs.setString(_keyTtsEngine, value);
  }

  // TTS Server URL
  static const String _keyTtsServerUrl = 'tts_server_url';
  final ValueNotifier<String> ttsServerUrl =
      ValueNotifier('http://localhost:8080/api/tts');

  Future<void> setTtsServerUrl(String value) async {
    ttsServerUrl.value = value;
    await _prefs.setString(_keyTtsServerUrl, value);
  }

  // Rust Voice Select
  final ValueNotifier<String?> rustVoiceId = ValueNotifier(null);

  Future<void> setRustVoiceId(String? value) async {
    rustVoiceId.value = value;
    if (value != null) {
      await _prefs.setString(_keyRustVoiceId, value);
    } else {
      await _prefs.remove(_keyRustVoiceId);
    }
  }

  // Piper Model Status
  final ValueNotifier<bool> isPiperModelDownloaded = ValueNotifier(false);

  void updatePiperModelStatus(bool downloaded) {
    isPiperModelDownloaded.value = downloaded;
  }

  bool get currentIsSimplified => isSimplified.value;

  Future<void> saveReadingProgress(
      int bookId, int chapter, double scrollPosition) async {
    await _prefs.setInt(_keyLastBookId, bookId);
    await _prefs.setInt(_keyLastChapterId, chapter);
    await _prefs.setDouble(_keyLastScrollPosition, scrollPosition);
  }

  Map<String, dynamic>? getLastReadingProgress() {
    final bookId = _prefs.getInt(_keyLastBookId);
    final chapter = _prefs.getInt(_keyLastChapterId);
    final scroll = _prefs.getDouble(_keyLastScrollPosition);

    if (bookId != null && chapter != null) {
      return {
        'bookId': bookId,
        'chapter': chapter,
        'scrollPosition': scroll ?? 0.0,
      };
    }
    return null;
  }
}
