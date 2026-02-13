import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gracewords/core/constants/bible_constants.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/audio_manager.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/services/tts_service.dart';

class TtsControlPanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onPlay;
  final ValueChanged<int>? onVerseSeek;
  final int bookId;
  final int currentChapter;
  final int currentVerse;
  final int totalVerses;

  const TtsControlPanel({
    super.key,
    required this.onClose,
    required this.bookId,
    this.currentChapter = 1,
    this.currentVerse = 0,
    this.totalVerses = 0,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onVerseSeek,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ttsService = getIt<TtsService>();
    final audioManager = getIt<AudioManager>();
    final settings = getIt<SettingsService>();

    // Title Format
    final isSimplified = settings.currentIsSimplified;
    final bookName =
        BibleConstants.getFullName(bookId, isSimplified: isSimplified);
    final testament = bookId >= 40
        ? (isSimplified ? "新约" : "新約")
        : (isSimplified ? "旧约" : "舊約");
    final totalChapters = BibleConstants.bookChapterCounts[bookId] ?? 0;

    final title =
        "$testament-$bookName 第 $currentChapter/$totalChapters 章 ${currentVerse > 0 ? "第 $currentVerse/${totalVerses > 0 ? totalVerses : '?'} 节" : ""}";

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Title + Close
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.brown),
                  onPressed: onClose,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Verse Progress Slider
            if (totalVerses > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('第1节',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.withOpacity(0.7))),
                        Text('第$totalVerses节',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.withOpacity(0.7))),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.brown,
                        inactiveTrackColor: Colors.brown.withOpacity(0.3),
                        thumbColor: Colors.brown,
                        overlayColor: Colors.brown.withOpacity(0.2),
                        trackHeight: 4,
                        thumbShape: _TextSliderThumbShape(
                          currentVerse: currentVerse,
                          enabledThumbRadius: 18,
                        ),
                        showValueIndicator: ShowValueIndicator.never,
                      ),
                      child: Slider(
                        min: 1,
                        max: totalVerses.toDouble(),
                        value: (currentVerse > 0 ? currentVerse : 1)
                            .toDouble()
                            .clamp(1, totalVerses.toDouble()),
                        divisions: totalVerses > 1 ? totalVerses - 1 : 1,
                        onChanged: (value) {
                          onVerseSeek?.call(value.round());
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Unified Main Controls Area
            ValueListenableBuilder<bool>(
              valueListenable: settings.isHumanVoice,
              builder: (context, isHuman, _) {
                if (isHuman) {
                  return FutureBuilder<bool>(
                    future: audioManager.isChapterDownloaded(bookId, currentChapter),
                    builder: (context, snapshot) {
                      final isDownloaded = snapshot.data ?? false;
                      final downloadKey = "${bookId}_$currentChapter";

                      return ValueListenableBuilder<Map<String, double>>(
                        valueListenable: audioManager.downloadProgressNotifier,
                        builder: (context, progressMap, _) {
                          final isDownloading = progressMap.containsKey(downloadKey);
                          final progress = progressMap[downloadKey] ?? 0.0;

                          if (isDownloading) {
                             return _buildUnifiedPlayerControls(
                              isPlaying: false,
                              isLoading: true,
                              progress: progress,
                              onPlayPause: () {},
                              onPrev: onPreviousChapter,
                              onNext: onNextChapter,
                            );
                          }

                          if (!isDownloaded) {
                            return _buildUnifiedPlayerControls(
                              isPlaying: false,
                              // Just show play button, handle download inside click
                              onPlayPause: () => audioManager.downloadChapter(bookId, currentChapter),
                              onPrev: onPreviousChapter,
                              onNext: onNextChapter,
                            );
                          }

                          return ValueListenableBuilder<AudioPlayerState>(
                            valueListenable: audioManager.playerStateNotifier,
                            builder: (context, state, _) {
                              final isPlaying = state == AudioPlayerState.playing || state == AudioPlayerState.buffering;
                              return _buildUnifiedPlayerControls(
                                isPlaying: isPlaying,
                                onPlayPause: () {
                                  if (isPlaying) {
                                    audioManager.pause();
                                  } else {
                                    if (state == AudioPlayerState.paused) {
                                      audioManager.resume();
                                    } else {
                                      audioManager.playChapter(bookId, currentChapter);
                                    }
                                  }
                                },
                                onPrev: onPreviousChapter,
                                onNext: onNextChapter,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                } else {
                  // TTS Mode
                  return ValueListenableBuilder<TtsState>(
                    valueListenable: ttsService.stateNotifier,
                    builder: (context, state, _) {
                      final isPlaying = state == TtsState.playing || state == TtsState.continued;
                      return _buildUnifiedPlayerControls(
                        isPlaying: isPlaying,
                        onPlayPause: () {
                          if (isPlaying) {
                            ttsService.pause();
                          } else {
                            // Always use onPlay (restart/continue from current verse) 
                            // as true resume is not supported by Rust engine yet
                            onPlay?.call();
                          }
                        },
                        onPrev: onPreviousChapter,
                        onNext: onNextChapter,
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedPlayerControls({
    required bool isPlaying,
    required VoidCallback onPlayPause,
    VoidCallback? onPrev,
    VoidCallback? onNext,
    bool isLoading = false,
    double progress = 0.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildControlBtn(
              icon: Icons.skip_previous, label: "上一章", onTap: onPrev, size: 36),
          
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        color: Colors.brown,
                      ),
                    ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        color: Colors.brown,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4))
                        ]),
                    child: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 48,
                        color: Colors.white,
                      ),
                      onPressed: onPlayPause,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isLoading ? "下载 ${(progress * 100).toInt()}%" : (isPlaying ? "暂停" : "播放"),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown)
              ),
            ],
          ),
          
          _buildControlBtn(
              icon: Icons.skip_next, label: "下一章", onTap: onNext, size: 36),
        ],
      ),
    );
  }

  Widget _buildControlBtn(
      {required IconData icon,
      required String label,
      VoidCallback? onTap,
      double size = 32}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: size, color: Colors.brown),
          onPressed: onTap,
        ),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown)),
      ],
    );
  }
}

class _TextSliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final int currentVerse;

  _TextSliderThumbShape({
    required this.enabledThumbRadius,
    required this.currentVerse,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw the thumb shadow
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: enabledThumbRadius));
    canvas.drawShadow(shadowPath, Colors.black, 3, true);

    // Draw the thumb circle
    final Paint paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.brown
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, paint);

    // Draw the text (current verse)
    final textSpan = TextSpan(
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
      text: '$currentVerse',
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: textDirection,
    );

    textPainter.layout();

    final Offset textOffset = Offset(
      center.dx - (textPainter.width / 2),
      center.dy - (textPainter.height / 2),
    );

    textPainter.paint(canvas, textOffset);
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool upward;
  _ArrowPainter({required this.color, this.upward = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (upward) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
