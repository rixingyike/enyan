import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/services/tts_service.dart';
import 'package:gracewords/core/services/pack_download_service.dart';
import 'package:gracewords/features/settings/presentation/pages/tts_test_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = getIt<SettingsService>();
    final packService = getIt<PackDownloadService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // === 文本设置 ===
          _buildSectionHeader('文本设置'),
          ValueListenableBuilder<bool>(
            valueListenable: settings.isSimplified,
            builder: (context, isSimplified, _) {
              return SwitchListTile(
                title: const Text('使用简体中文'),
                subtitle: Text(isSimplified ? '当前：简体' : '当前：繁体'),
                value: isSimplified,
                onChanged: (value) {
                  settings.setSimplified(value);
                },
              );
            },
          ),
          const Divider(),

          // === 朗读设置 ===
          _buildSectionHeader('朗读设置'),
          ValueListenableBuilder<bool>(
            valueListenable: settings.isHumanVoice,
            builder: (context, isHuman, _) {
              return SwitchListTile(
                title: const Text('使用真人朗读'),
                subtitle: Text(isHuman ? '当前：真人朗读 (MP3)' : '当前：机械朗读 (TTS)'),
                value: isHuman,
                onChanged: (value) {
                  settings.setHumanVoice(value);
                },
              );
            },
          ),



          // Sherpa Model Download

          // Speed Control
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
                    min: 0.5,
                    max: 2.0,
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

          // === 资源包下载 ===
          _buildSectionHeader('资源包下载'),
          _buildPackDownloadTile(
            packService: packService,
            packId: 'lang_cht',
            title: '繁体中文语言包',
            subtitle: '下载后可使用繁体中文圣经',
            icon: Icons.language,
          ),
          _buildPackDownloadTile(
            packService: packService,
            packId: 'voice_6k',
            title: '基础语音包',
            subtitle: '基础真人朗读语音',
            icon: Icons.record_voice_over,
          ),
          _buildPackDownloadTile(
            packService: packService,
            packId: 'voice_8k',
            title: '高级语音包',
            subtitle: '高品质真人朗读语音',
            icon: Icons.headphones,
          ),

          const Divider(),

          // === 诊断工具 ===
          _buildSectionHeader('诊断工具'),
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
          const ListTile(
            title: Text('关于'),
            subtitle: Text('大字有声圣经 v1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
        ),
      ),
    );
  }

  Widget _buildPackDownloadTile({
    required PackDownloadService packService,
    required String packId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ValueListenableBuilder<Map<String, PackStatus>>(
      valueListenable: packService.statusNotifier,
      builder: (context, statusMap, _) {
        final status = statusMap[packId] ?? PackStatus.notDownloaded;

        return ListTile(
          leading: Icon(icon, color: Colors.brown),
          title: Text(title),
          subtitle: _buildPackSubtitle(subtitle, status),
          trailing: _buildPackTrailing(packService, packId, status),
        );
      },
    );
  }

  Widget _buildPackSubtitle(String baseSubtitle, PackStatus status) {
    String statusText;
    Color statusColor;

    switch (status) {
      case PackStatus.notDownloaded:
        statusText = baseSubtitle;
        statusColor = Colors.grey;
        break;
      case PackStatus.downloading:
        statusText = '下载中...';
        statusColor = Colors.blue;
        break;
      case PackStatus.downloaded:
        statusText = '已下载';
        statusColor = Colors.green;
        break;
      case PackStatus.error:
        statusText = '下载失败，点击重试';
        statusColor = Colors.red;
        break;
    }

    return Text(statusText, style: TextStyle(color: statusColor, fontSize: 12));
  }

  Widget? _buildPackTrailing(
      PackDownloadService packService, String packId, PackStatus status) {
    switch (status) {
      case PackStatus.notDownloaded:
      case PackStatus.error:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
          ),
          onPressed: () => packService.downloadPack(packId),
          child: const Text('下载'),
        );
      case PackStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case PackStatus.downloaded:
        return const Icon(Icons.check_circle, color: Colors.green);
    }
  }
}
