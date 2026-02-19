import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/settings_service.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('关于', style: TextStyle(fontFamily: getIt<SettingsService>().currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icons/app_icon.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                '大字有声圣经',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  fontFamily: getIt<SettingsService>().currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '为弟兄姊妹提供最便捷、清晰、可离线使用的圣经阅读与听经体验。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.brown,
                    height: 1.5,
                    fontFamily: getIt<SettingsService>().currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC',
                  ),
                ),
              ),
              const SizedBox(height: 48),

              Text(
                '作者：金石碼农',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.brown,
                    fontFamily: getIt<SettingsService>().currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC'),
              ),
              const SizedBox(height: 16),
              // Author Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/jinshimanong.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '如果发现有任何错误或有什么建议，请发邮件至 9830131@qq.com，或加作者微信 9830131。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.brown,
                    height: 1.5,
                    fontFamily: getIt<SettingsService>().currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC',
                  ),
                ),
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}
