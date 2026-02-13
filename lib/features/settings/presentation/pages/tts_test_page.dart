import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/services/tts_service.dart';
import 'package:gracewords/src/rust/api/simple.dart';

class TtsTestPage extends StatefulWidget {
  const TtsTestPage({super.key});

  @override
  State<TtsTestPage> createState() => _TtsTestPageState();
}

class _TtsTestPageState extends State<TtsTestPage> {
  final TtsService _ttsService = getIt<TtsService>();
  final SettingsService _settings = getIt<SettingsService>();
  final TextEditingController _controller =
      TextEditingController(text: "起初，神创造天地。地是空虚混沌，渊面黑暗。");
  String _logs = "";

  @override
  void initState() {
    super.initState();
    _log("TTS Test Page Initialized");
    _log("Backend: Rust TTS (rSpeak)");
  }

  Future<void> _speak() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    _log("Speaking: $text");
    try {
      await _ttsService.speak(text);
      _log("Speak command sent.");
    } catch (e) {
      _log("Error speaking: $e");
    }
  }

  Future<void> _stop() async {
    _log("Stopping...");
    try {
      await _ttsService.stop();
      _log("Stop command sent.");
    } catch (e) {
      _log("Error stopping: $e");
    }
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      _logs += "${DateTime.now().second}:${DateTime.now().millisecond} - $msg\n";
    });
    debugPrint("[TTS-TEST] $msg");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TTS 语音诊断")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Rust TTS 专用诊断工具",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "当前已启用内嵌 Rust 语音引擎。\n通过下面的下拉列表切换音色，观察不同声效。",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Voice Selector
            _buildVoiceSelector(),
            const SizedBox(height: 24),
            
            // Input
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "测试文本",
              ),
            ),
            const SizedBox(height: 16),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _speak,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("朗读测试"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text("停止"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("运行日志:", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            // Logs
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(
                    _logs,
                    style: const TextStyle(
                      fontFamily: 'Courier', 
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector() {
    return ValueListenableBuilder<String?>(
      valueListenable: _settings.rustVoiceId,
      builder: (context, selectedId, _) {
        return FutureBuilder<List<VoiceInfo>>(
          future: _ttsService.getVoices(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Text("正在获取系统声线...", style: TextStyle(color: Colors.grey));
            }

            final List<VoiceInfo> voices = snapshot.data!;
            String? currentId = selectedId;
            if (currentId == null || !voices.any((VoiceInfo v) => v.id == currentId)) {
              final defaultVoice = voices.firstWhere(
                (VoiceInfo v) => v.name.contains("Mei-Jia") || v.name.contains("Li-mu"),
                orElse: () => voices.first,
              );
              currentId = defaultVoice.id;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentId,
                  isExpanded: true,
                  icon: const Icon(Icons.record_voice_over, color: Colors.brown),
                  items: voices.map<DropdownMenuItem<String>>((VoiceInfo v) {
                    return DropdownMenuItem<String>(
                      value: v.id,
                      child: Text(
                        v.name,
                        style: const TextStyle(fontSize: 14, color: Colors.brown),
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      _log("Switching voice to ID: $id");
                      _ttsService.setVoice(id);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
