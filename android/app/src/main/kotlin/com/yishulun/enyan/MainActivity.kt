package com.yishulun.enyan

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yishulun.enyan/tts_init"
    private val TAG = "🎯 [MainActivity]"

    // Java-side TTS — used for ALL TTS operations on Android
    // (Rust tts crate's Android backend has a 500ms init timeout that always fails in Flutter)
    private var javaTts: TextToSpeech? = null
    @Volatile private var ttsReady = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Java-side TTS
        initJavaTts()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "initRustTts" -> {
                    try {
                        val heartbeat = initRustTts(this)
                        Log.i(TAG, "Rust Heartbeat: $heartbeat")
                        result.success(heartbeat)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to init Rust TTS: ${e.message}")
                        result.error("INIT_FAILED", e.message, null)
                    }
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    if (ttsReady && javaTts != null && text.isNotEmpty()) {
                        val params = Bundle()
                        params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_MUSIC)
                        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                        val utteranceId = "enyan_${System.currentTimeMillis()}"
                        val speakResult = javaTts!!.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
                        Log.i(TAG, "speak: result=$speakResult, text=${text.take(20)}...")
                        result.success(speakResult == TextToSpeech.SUCCESS)
                    } else {
                        Log.w(TAG, "speak: TTS not ready ($ttsReady) or text empty")
                        result.success(false)
                    }
                }
                "stop" -> {
                    javaTts?.stop()
                    Log.i(TAG, "stop")
                    result.success(true)
                }
                "isSpeaking" -> {
                    val speaking = javaTts?.isSpeaking ?: false
                    result.success(speaking)
                }
                "getVoices" -> {
                    if (ttsReady && javaTts != null) {
                        try {
                            val voices = javaTts!!.voices
                                ?.filter { voice ->
                                    val lang = voice.locale.language.lowercase()
                                    lang == "zh" || lang == "cmn"
                                }
                                ?.mapIndexed { index, voice ->
                                    // Ensure ID is unique
                                    val uniqueId = if (voice.name.isEmpty()) "voice_$index" else voice.name
                                    mapOf(
                                        "id" to uniqueId,
                                        "name" to "${voice.name} (${voice.locale})",
                                        "language" to voice.locale.toString()
                                    )
                                } ?: emptyList()
                            Log.i(TAG, "getVoices: returning ${voices.size} Chinese voices")
                            result.success(voices)
                        } catch (e: Exception) {
                            Log.e(TAG, "getVoices error: ${e.message}")
                            result.success(emptyList<Map<String, String>>())
                        }
                    } else {
                        Log.w(TAG, "getVoices: TTS not ready (ready=$ttsReady)")
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                "setVoice" -> {
                    val voiceId = call.argument<String>("voiceId")
                    if (voiceId != null && ttsReady && javaTts != null) {
                        try {
                            val targetVoice = javaTts!!.voices?.find { it.name == voiceId }
                            if (targetVoice != null) {
                                val setResult = javaTts!!.setVoice(targetVoice)
                                Log.i(TAG, "setVoice '$voiceId': result=$setResult")
                                result.success(setResult == TextToSpeech.SUCCESS)
                            } else {
                                Log.w(TAG, "setVoice: voice '$voiceId' not found")
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "setVoice error: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getTtsStatus" -> {
                    result.success(mapOf(
                        "javaReady" to ttsReady,
                        "voiceCount" to (if (ttsReady) javaTts?.voices?.size ?: 0 else 0)
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initJavaTts() {
        // Directly specify the engine — on Xiaomi, default engine often fails
        // Try to find any available engine and use it explicitly
        val defaultTts = TextToSpeech(this, null)
        val engines = defaultTts.engines ?: emptyList()
        defaultTts.shutdown()

        Log.i(TAG, "Available TTS engines (${engines.size}):")
        for (engine in engines) {
            Log.i(TAG, "  → ${engine.name} (${engine.label})")
        }

        // Pick the best engine
        val preferredOrder = listOf(
            "com.google.android.tts",
            "com.xiaomi.mibrain.speech",
            "com.samsung.SMT",
            "com.huawei.hiai.tts"
        )
        val selectedEngine = preferredOrder.firstOrNull { pref ->
            engines.any { it.name == pref }
        } ?: engines.firstOrNull()?.name

        if (selectedEngine == null) {
            Log.e(TAG, "No TTS engine found on device!")
            return
        }

        Log.i(TAG, "Initializing TTS with engine: $selectedEngine")
        javaTts = TextToSpeech(this, { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsReady = true
                // Set Chinese locale by default
                val localeResult = javaTts?.setLanguage(Locale.CHINESE)
                val voiceCount = javaTts?.voices?.size ?: 0
                Log.i(TAG, "✅ TTS init SUCCESS (engine=$selectedEngine, locale=$localeResult, voices=$voiceCount)")

                // Set utterance progress listener
                javaTts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        Log.i(TAG, "TTS onStart: $utteranceId")
                    }
                    override fun onDone(utteranceId: String?) {
                        Log.i(TAG, "TTS onDone: $utteranceId")
                    }
                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        Log.e(TAG, "TTS onError: $utteranceId")
                    }
                })
            } else {
                Log.e(TAG, "❌ TTS init FAILED (engine=$selectedEngine, status=$status)")
            }
        }, selectedEngine)
    }

    override fun onDestroy() {
        javaTts?.shutdown()
        super.onDestroy()
    }

    private external fun initRustTts(context: Context): String

    companion object {
        init {
            System.loadLibrary("rust_lib_gracewords")
        }
    }
}
