import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/services/tts_service.dart';
import 'package:gracewords/core/services/pack_download_service.dart';
import 'package:gracewords/src/rust/api/simple.dart';
import 'package:gracewords/features/settings/presentation/pages/tts_test_page.dart';
import 'package:gracewords/features/settings/presentation/pages/about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = getIt<SettingsService>();
    final packService = getIt<PackDownloadService>();

    return ValueListenableBuilder<bool>(
      valueListenable: settings.isSimplified,
      builder: (context, isSimplified, _) {
        final fontFamily = isSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC';
        return Scaffold(
          appBar: AppBar(
            title: Text('设置', style: TextStyle(fontFamily: fontFamily)),
            centerTitle: true,
          ),
          body: ListView(
            children: [
              // === 文本设置 ===
              _buildSectionHeader('文本设置', fontFamily),
          // 简体中文 (内嵌)
          ValueListenableBuilder<bool>(
            valueListenable: settings.isSimplified,
            builder: (context, isSimplified, _) {
              return ListTile(
                title: Text('简体中文', style: TextStyle(fontFamily: fontFamily)),
                subtitle: Text('程序内嵌', style: TextStyle(fontFamily: fontFamily)),
                leading: const Icon(Icons.language, color: Colors.brown),
                trailing: isSimplified
                    ? const Icon(Icons.check, color: Colors.brown)
                    : null,
                onTap: () {
                  settings.setSimplified(true);
                },
              );
            },
          ),
          // 繁体中文 (可下载)
          _buildDownloadableOption(
            packService: packService,
            settings: settings,
            packId: 'lang_cht',
            title: '繁体中文',
            subtitleDownloaded: '已下载',
            subtitleNotDownloaded: '需下载语言包',
            getValue: (s) => !s.currentIsSimplified,
            onSelect: () {
              settings.setSimplified(false);
            },
            listenable: settings.isSimplified,
            fontFamily: fontFamily,
          ),

          const Divider(),

          // === 朗读设置 ===
          _buildSectionHeader('朗读设置', fontFamily),
          // Rust TTS (内嵌)
          ValueListenableBuilder<bool>(
            valueListenable: settings.isHumanVoice,
            builder: (context, isHuman, _) {
              return Column(
                children: [
                  ListTile(
                    title: const Text('TTS 保真朗读'),
                    subtitle: const Text('程序内嵌 Rust TTS'),
                    leading: const Icon(Icons.speaker_phone, color: Colors.brown),
                    trailing: !isHuman
                        ? const Icon(Icons.check, color: Colors.brown)
                        : null,
                    onTap: () {
                      settings.setHumanVoice(false);
                    },
                  ),
                  if (!isHuman)
                    _buildRustVoiceSelector(context, settings),
                ],
              );
            },
          ),
          // 基础语音包 (6k)
          _buildDownloadableOption(
            packService: packService,
            settings: settings,
            packId: 'voice_6k',
            title: '真人朗读 (基础)',
            subtitleDownloaded: '基础语音包',
            subtitleNotDownloaded: '需下载基础语音包',
            getValue: (s) => s.isHumanVoice.value && s.voiceQuality.value == 'basic',
            onSelect: () {
              settings.setVoiceQuality('basic');
            },
            listenable: Listenable.merge([settings.isHumanVoice, settings.voiceQuality]),
            fontFamily: fontFamily,
          ),
          // 高级语音包 (8k)
          _buildDownloadableOption(
            packService: packService,
            settings: settings,
            packId: 'voice_8k',
            title: '真人朗读 (高级)',
            subtitleDownloaded: '高级语音包',
            subtitleNotDownloaded: '需下载高级语音包',
            getValue: (s) => s.isHumanVoice.value && s.voiceQuality.value == 'high',
            onSelect: () {
              settings.setVoiceQuality('high');
            },
            listenable: Listenable.merge([settings.isHumanVoice, settings.voiceQuality]),
            fontFamily: fontFamily,
          ),

          const Divider(),

          // === 语速 ===
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '朗读语速',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: getIt<TtsService>().rateNotifier,
            builder: (context, rate, _) {
              return Column(
                children: [
                  Slider(
                    value: rate,
                    max: 2.0,
                    min: 0.5,
                    divisions: 6,
                    label: "${rate}x",
                    onChanged: (val) {
                      getIt<TtsService>().setRate(val);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0.5x',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('1.0x',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('1.5x',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('2.0x',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // === 诊断工具 ===
          _buildSectionHeader('诊断工具', fontFamily),
          ListTile(
            title: const Text('TTS 语音诊断'),
            leading: const Icon(Icons.bug_report),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TtsTestPage()));
            },
          ),
          const Divider(),

          // === 关于 ===
          ListTile(
            title: Text('关于', style: TextStyle(fontFamily: fontFamily)),
            leading: const Icon(Icons.info),
            onTap: () {
               Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRustVoiceSelector(BuildContext context, SettingsService settings) {
    final ttsService = getIt<TtsService>();

    return ValueListenableBuilder<String?>(
      valueListenable: settings.rustVoiceId,
      builder: (context, selectedId, _) {
        return FutureBuilder<List<VoiceInfo>>(
          future: ttsService.getVoices(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final List<VoiceInfo> voices = snapshot.data!;
            // If no voice is selected yet, or selected one is not in list, find a default
            String? currentId = selectedId;
            if (currentId == null || !voices.any((VoiceInfo v) => v.id == currentId)) {
               // Default to Ting-Ting if available, else first one
               final defaultVoice = voices.firstWhere(
                 (VoiceInfo v) => v.name.contains("Ting-Ting") || v.name.contains("Li-mu"),
                 orElse: () => voices.first,
               );
               currentId = defaultVoice.id;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(64, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.brown),
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
                        ttsService.setVoice(id);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildDownloadableOption({
    required PackDownloadService packService,
    required SettingsService settings,
    required String packId,
    required String title,
    required String subtitleDownloaded,
    required String subtitleNotDownloaded,
    required bool Function(SettingsService) getValue,
    required VoidCallback onSelect,
    required Listenable listenable,
    required String fontFamily,
  }) {
    return ValueListenableBuilder<Map<String, PackStatus>>(
      valueListenable: packService.statusNotifier,
      builder: (context, statusMap, _) {
        return ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final status = statusMap[packId] ?? PackStatus.notDownloaded;
            final isDownloaded = status == PackStatus.downloaded;
            final isDownloading = status == PackStatus.downloading;
            final isSelected = getValue(settings);

            Widget? trailingWidget;

            if (isDownloaded) {
              trailingWidget = isSelected
                  ? const Icon(Icons.check, color: Colors.brown)
                  : null;
            } else if (isDownloading) {
              trailingWidget = const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2));
            } else {
              // Not downloaded or Error
              trailingWidget = IconButton(
                icon: const Icon(Icons.cloud_download, color: Colors.brown),
                onPressed: () {
                  packService.downloadPack(packId);
                },
              );
            }

            return ListTile(
              title: Text(title, style: TextStyle(fontFamily: fontFamily)),
              subtitle: Text(isDownloaded
                  ? subtitleDownloaded
                  : (status == PackStatus.error ? "下载失败，点击重试" : subtitleNotDownloaded),
                  style: TextStyle(fontFamily: fontFamily)),
              leading: const Icon(Icons.download, color: Colors.brown), // Unified icon
              trailing: trailingWidget,
              onTap: () {
                if (isDownloaded) {
                  onSelect();
                } else if (status != PackStatus.downloading) {
                   packService.downloadPack(packId);
                }
              },
            );
          },
        );
      },
    );
  }
}
