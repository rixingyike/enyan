import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/src/rust/api/simple.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum TtsState { playing, stopped, paused, continued, completed }

@lazySingleton
class TtsService {
  final SettingsService _settings;
  // State Notifiers
  final ValueNotifier<TtsState> stateNotifier = ValueNotifier(TtsState.stopped);
  final ValueNotifier<double> rateNotifier = ValueNotifier(1.0);
  final ValueNotifier<int> currentPositionNotifier = ValueNotifier(0);

  static const _channel = MethodChannel('com.yishulun.enyan/tts_init');
  final bool _isAndroid = Platform.isAndroid;

  TtsService(this._settings) {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
       if (_isAndroid) {
         // Android: init NDK context for flutter_rust_bridge, but TTS itself uses Java
         try {
           final heartbeat = await _channel.invokeMethod('initRustTts');
           debugPrint("🎯 [TTS] Android NDK context initialized: $heartbeat");
         } catch (e) {
           debugPrint("❌ [TTS] Failed to init Android NDK context: $e");
         }

         // Copy lexicon file to local storage (still used for text processing in Rust)
         final supportDir = await getApplicationSupportDirectory();
         try {
           const lexiconAssetPath = 'assets/chs/bible_lexicon_chs.json';
           final localLexiconPath = '${supportDir.path}/bible_lexicon_chs.json';
           final data = await rootBundle.load(lexiconAssetPath);
           final bytes = data.buffer.asUint8List();
           await File(localLexiconPath).writeAsBytes(bytes);
           debugPrint("🎯 [TTS] Lexicon copied to local: $localLexiconPath");
         } catch (e) {
           debugPrint("⚠️ [TTS] Failed to copy lexicon: $e");
         }
         await customInitTtsWithPath(sharedPath: supportDir.path);

         // Wait for Java TTS to be ready, then get voices
         String? voiceIdToSet = _settings.rustVoiceId.value;
         if (voiceIdToSet == null) {
           final voices = await getVoices();
           if (voices.isNotEmpty) {
             voiceIdToSet = voices.first.id;
             debugPrint("🎯 [TTS] Auto-selected: ${voices.first.name}");
           }
         }
         if (voiceIdToSet != null) {
           await setVoice(voiceIdToSet);
         }
         debugPrint("✅ [TTS] Android TTS initialized (Voice: $voiceIdToSet)");
       } else {
         // Non-Android: use Rust tts crate for everything
         final supportDir = await getApplicationSupportDirectory();
         try {
           const lexiconAssetPath = 'assets/chs/bible_lexicon_chs.json';
           final localLexiconPath = '${supportDir.path}/bible_lexicon_chs.json';
           final data = await rootBundle.load(lexiconAssetPath);
           final bytes = data.buffer.asUint8List();
           await File(localLexiconPath).writeAsBytes(bytes);
         } catch (e) {
           debugPrint("⚠️ [TTS] Failed to copy lexicon: $e");
         }
         await customInitTtsWithPath(sharedPath: supportDir.path);

         String? voiceIdToSet = _settings.rustVoiceId.value;
         if (voiceIdToSet == null) {
           final voices = await rGetVoices();
           try {
             final meiJia = voices.firstWhere((v) => v.name.contains("Mei-Jia"));
             voiceIdToSet = meiJia.id;
           } catch (_) {
             if (voices.isNotEmpty) voiceIdToSet = voices.first.id;
           }
         }
         if (voiceIdToSet != null) {
           await rSetVoice(id: voiceIdToSet);
         }
         debugPrint("✅ [TTS] Rust TTS initialized (Voice: $voiceIdToSet)");
       }
    } catch (e) {
       debugPrint("❌ [TTS] Init failed: $e");
    }
  }

  // ─── Core TTS operations (platform-routed) ───

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    String textToSpeak = text
        .replaceAll(RegExp(r'（.*?）'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '');

    debugPrint("🔊 [TTS] Speaking: ${textToSpeak.substring(0, textToSpeak.length > 20 ? 20 : textToSpeak.length)}...");
    stateNotifier.value = TtsState.playing;
    currentPositionNotifier.value = 0;

    try {
      if (_isAndroid) {
        await _channel.invokeMethod('speak', {'text': textToSpeak});
      } else {
        await rSpeak(text: textToSpeak);
      }
    } catch (e) {
      debugPrint("❌ [TTS] Speak error: $e");
      stateNotifier.value = TtsState.stopped;
    }
  }

  Future<void> stop() async {
    debugPrint("⏹️ [TTS] Stop");
    try {
      if (_isAndroid) {
        await _channel.invokeMethod('stop');
      } else {
        await rStop();
      }
    } catch (e) {
      debugPrint("❌ [TTS] Stop error: $e");
    }
    stateNotifier.value = TtsState.stopped;
    currentPositionNotifier.value = 0;
  }

  Future<void> pause() async {
    await stop();
    stateNotifier.value = TtsState.paused;
    debugPrint("⏸️ [TTS] Paused");
  }

  Future<bool> isSpeaking() async {
    try {
      if (_isAndroid) {
        return await _channel.invokeMethod('isSpeaking') ?? false;
      }
      return await rIsSpeaking();
    } catch (e) {
      return false;
    }
  }

  Future<void> resume() async {
    debugPrint("⚠️ [TTS] Resume called, currently handled by restarting from Panel.");
  }

  Future<void> setRate(double rate) async {
    rateNotifier.value = rate;
  }

  Future<void> setPitch(double pitch) async {
    // TODO
  }

  // ─── Voice management (platform-routed) ───

  Future<List<VoiceInfo>> getVoices() async {
    if (_isAndroid) {
      return await _getAndroidVoices();
    }
    final voices = await rGetVoices();
    debugPrint("🎯 [TTS] rGetVoices returned ${voices.length} voices");
    return voices;
  }

  /// Android: get voices via Java TextToSpeech API with retry for async binding.
  Future<List<VoiceInfo>> _getAndroidVoices() async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final List<dynamic> voiceMaps =
            await _channel.invokeMethod('getVoices') ?? [];
        if (voiceMaps.isNotEmpty) {
          final voices = voiceMaps.map((v) {
            final map = Map<String, String>.from(v);
            return VoiceInfo(id: map['id']!, name: map['name']!);
          }).toList();
          debugPrint("🎯 [TTS] Android getVoices: ${voices.length} voices");
          return voices;
        }
        if (attempt < 4) {
          debugPrint("🎯 [TTS] Android voices empty, retrying (${attempt + 1}/5)...");
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint("❌ [TTS] Android getVoices error: $e");
      }
    }
    debugPrint("⚠️ [TTS] Android getVoices: no voices after retries");
    return [];
  }

  Future<void> setVoice(String id) async {
    debugPrint("🎯 [TTS] Setting voice to $id");
    if (_isAndroid) {
      try {
        await _channel.invokeMethod('setVoice', {'voiceId': id});
      } catch (e) {
        debugPrint("⚠️ [TTS] Android setVoice error: $e");
      }
    } else {
      await rSetVoice(id: id);
    }
    await _settings.setRustVoiceId(id);
  }

  void dispose() {
    stop();
    stateNotifier.dispose();
    rateNotifier.dispose();
    currentPositionNotifier.dispose();
  }
}
