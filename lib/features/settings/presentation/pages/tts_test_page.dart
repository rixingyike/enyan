import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/tts_service.dart';
import 'package:gracewords/src/rust/api/simple.dart';

class TtsTestPage extends StatefulWidget {
  const TtsTestPage({super.key});

  @override
  State<TtsTestPage> createState() => _TtsTestPageState();
}

class _TtsTestPageState extends State<TtsTestPage> {
  final TtsService _ttsService = getIt<TtsService>();
  final TextEditingController _controller =
      TextEditingController(text: "起初，神创造天地。地是空虚混沌，渊面黑暗。");

  List<dynamic> _voices = [];
  Map<String, String>? _selectedVoice;
  String _logs = "";

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    _log("Loading voices...");
    try {
      // Rust Tts 目前不暴露语音列表给 Dart
      // 自动选择在 Rust 内部完成
      /*
      final voices = await _ttsService.instance.getVoices;
      setState(() {
        _voices = voices as List<dynamic>;
      });
      */
      _log("Loaded ${_voices.length} voices.");

      // Try to find current
      // This is tricky because TtsService doesn't expose current voice easily unless we track it.
      // We'll just default to what we think is best using the logic from TtsService
      _findBestVoice();
    } catch (e) {
      _log("Error loading voices: $e");
    }
  }

  void _findBestVoice() {
    try {
      if (_voices.isEmpty) return;

      Map<String, dynamic>? target;

      // 1. Ting-Ting
      try {
        target = _voices.firstWhere((v) {
          final name = v["name"].toString().toLowerCase();
          return name.contains("ting-ting") || name.contains("tingting");
        }) as Map<String, dynamic>?;
        if (target != null) _log("Found Ting-Ting: ${target['name']}");
      } catch (_) {}

      // 2. zh-CN
      if (target == null) {
        try {
          target = _voices.firstWhere((v) {
            return v["locale"].toString() == "zh-CN";
          }) as Map<String, dynamic>?;
          if (target != null) _log("Found zh-CN: ${target['name']}");
        } catch (_) {}
      }

      if (target != null) {
        setState(() {
          _selectedVoice = Map<String, String>.from(
              target!.map((k, v) => MapEntry(k, v.toString())));
        });
      }
    } catch (e) {
      _log("Error finding best voice: $e");
    }
  }

  Future<void> _setVoice(Map<String, String> voice) async {
    _log("Setting voice to: ${voice['name']} (Rust 自动管理，手动设置暂不可用)");
    /*
    try {
      await _ttsService.instance.setVoice(voice);
      setState(() {
        _selectedVoice = voice;
      });
      _log("Voice set successfully.");
    } catch (e) {
      _log("Error setting voice: $e");
    }
    */
  }

  Future<void> _speak() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    _log("Speaking: $text");
    try {
      // await _ttsService.instance.setLanguage("zh-CN"); // Rust 内部已处理
      await _ttsService.speak(text);
    } catch (e) {
      _log("Error speaking: $e");
    }
  }

  void _log(String msg) {
    setState(() {
      _logs += "$msg\n";
    });
    debugPrint("[TTS-TEST] $msg");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TTS 诊断测试")),
      body: Column(
        children: [
          // Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _speak, child: const Text("朗读")),
              ],
            ),
          ),

          const Divider(),

          // Voice Selector
          if (_voices.isNotEmpty)
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: _voices.length,
                itemBuilder: (context, index) {
                  final voice = Map<String, String>.from(
                      _voices[index].map((k, v) => MapEntry(k, v.toString())));
                  final name = voice["name"] ?? "Unknown";
                  final locale = voice["locale"] ?? "-";
                  final isSelected = _selectedVoice?["name"] == name;

                  // Filter for Chinese only to keep list clean? Or show all?
                  // Show all but highlight CH
                  final isChinese = locale.toLowerCase().contains("zh");

                  return Container(
                    color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                    child: ListTile(
                      title: Text(name,
                          style: TextStyle(
                              fontWeight: isChinese
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      subtitle: Text(locale),
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () => _setVoice(voice),
                    ),
                  );
                },
              ),
            ),

          const Divider(),

          // Rust Test
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rust TTS 测试 (flutter_rust_bridge)",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          final text = _controller.text;
                          _log("[Rust] Calling speak_chinese_test('$text')...");
                          try {
                             final res = await speakChineseTest(text: text);
                             _log("[Rust] Result: $res");
                          } catch (e) {
                             _log("[Rust] Error: $e");
                          }
                        },
                        child: const Text("Rust 朗读")),
                  ],
                )
              ],
            ),
          ),

          const Divider(),

          // Logs
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.black12,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Text(_logs,
                    style:
                        const TextStyle(fontFamily: 'Courier', fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
