import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:gracewords/src/rust/api/simple.dart';

enum TtsState { playing, stopped, paused, continued, completed }

@lazySingleton
class TtsService {
  // State Notifiers
  final ValueNotifier<TtsState> stateNotifier = ValueNotifier(TtsState.stopped);
  final ValueNotifier<double> rateNotifier = ValueNotifier(1.0);
  final ValueNotifier<int> currentPositionNotifier = ValueNotifier(0);

  TtsService() {
    _initRustTts();
  }

  Future<void> _initRustTts() async {
    // Rust TTS is lazy-initialized on first call, but we can trigger it early
    try {
       await customInitTts();
       debugPrint("✅ [TTS] Rust TTS initialized");
    } catch (e) {
       debugPrint("❌ [TTS] Failed to init Rust TTS: $e");
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    debugPrint("🔊 [TTS] Speaking: ${text.substring(0, text.length > 20 ? 20 : text.length)}...");
    
    // Reset state
    stateNotifier.value = TtsState.playing;
    currentPositionNotifier.value = 0;

    try {
      // Call Rust
      await rSpeak(text: text);
      
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
    await stop();
    stateNotifier.value = TtsState.paused;
  }

  Future<void> resume() async {
    // Resume not supported natively by simple stop/start without keeping text.
    // Ideally we should keep track of text and position.
    // For now, doing nothing or just restarting is acceptable for MVP.
    debugPrint("⚠️ [TTS] Resume not fully supported yet in Rust implementation");
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

  void dispose() {
    stop();
    stateNotifier.dispose();
    rateNotifier.dispose();
    currentPositionNotifier.dispose();
  }
}
