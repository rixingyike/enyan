import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/src/rust/api/simple.dart';

enum TtsState { playing, stopped, paused, continued, completed }

@lazySingleton
class TtsService {
  final SettingsService _settings;
  // State Notifiers
  final ValueNotifier<TtsState> stateNotifier = ValueNotifier(TtsState.stopped);
  final ValueNotifier<double> rateNotifier = ValueNotifier(1.0);
  final ValueNotifier<int> currentPositionNotifier = ValueNotifier(0);

  TtsService(this._settings) {
    _initRustTts();
  }

  Future<void> _initRustTts() async {
    // Rust TTS is lazy-initialized on first call, but we can trigger it early
    try {
       await customInitTts();
       // Apply saved voice if any
       String? voiceIdToSet = _settings.rustVoiceId.value;
       
       if (voiceIdToSet == null) {
         // Auto-select "Mei-Jia" as default if available
         final voices = await rGetVoices();
         try {
           final meiJia = voices.firstWhere((v) => v.name.contains("Mei-Jia"));
           voiceIdToSet = meiJia.id;
           debugPrint("🎯 [TTS] No saved voice, auto-selected default: Mei-Jia");
         } catch (_) {
           // Fallback to whatever first if Mei-Jia is missing (unlikely on macOS)
           if (voices.isNotEmpty) voiceIdToSet = voices.first.id;
         }
       }

       if (voiceIdToSet != null) {
         await rSetVoice(id: voiceIdToSet);
         // If it was auto-selected (current setting is null), save it back to settings
         if (_settings.rustVoiceId.value == null) {
           await _settings.setRustVoiceId(voiceIdToSet);
         }
       }
       debugPrint("✅ [TTS] Rust TTS initialized (Voice: $voiceIdToSet)");
    } catch (e) {
       debugPrint("❌ [TTS] Failed to init Rust TTS: $e");
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Filter out content in brackets (e.g. inline notes)
    // 1. Full-width brackets: （...）
    // 2. Half-width brackets: (...)
    String textToSpeak = text.replaceAll(RegExp(r'（.*?）'), '').replaceAll(RegExp(r'\(.*?\)'), '');

    debugPrint("🔊 [TTS] Speaking: ${textToSpeak.substring(0, textToSpeak.length > 20 ? 20 : textToSpeak.length)}...");
    
    // Reset state
    stateNotifier.value = TtsState.playing;
    currentPositionNotifier.value = 0;

    try {
      // Call Rust
      // Call Rust
      await rSpeak(text: textToSpeak);
      
      // TODO: Receive events from Rust.
      // For now, we assume it plays. We don't know when it ends.
      // This is a limitation without callbacks.
    } catch (e) {
      debugPrint("❌ [TTS] Speak error: $e");
      stateNotifier.value = TtsState.stopped;
    }
  }

  Future<void> stop() async {
    debugPrint("⏹️ [TTS] Stop");
    await rStop();
    stateNotifier.value = TtsState.stopped;
    currentPositionNotifier.value = 0;
  }

  Future<void> pause() async {
    // Rust tts crate stop() effectively pauses/stops.
    await rStop();
    stateNotifier.value = TtsState.paused;
    debugPrint("⏸️ [TTS] Paused");
  }

  Future<bool> isSpeaking() async {
    return await rIsSpeaking();
  }

  Future<void> resume() async {
    // If we want to truly resume, we need start/stop offsets.
    // For now, this is a placeholder. TtsControlPanel should handle restarts.
    debugPrint("⚠️ [TTS] Resume called, currently handled by restarting from Panel.");
  }

  Future<void> setRate(double rate) async {
    rateNotifier.value = rate;
    // Rust side needs set_rate exposed. Currently not exposed.
    // TODO: Add set_rate to simple.rs
    debugPrint("⚠️ [TTS] setRate not implemented in Rust side yet");
  }

  Future<void> setPitch(double pitch) async {
    // TODO
  }

  Future<List<VoiceInfo>> getVoices() async {
    return await rGetVoices();
  }

  Future<void> setVoice(String id) async {
    await rSetVoice(id: id);
    await _settings.setRustVoiceId(id);
  }

  void dispose() {
    stop();
    stateNotifier.dispose();
    rateNotifier.dispose();
    currentPositionNotifier.dispose();
  }
}
