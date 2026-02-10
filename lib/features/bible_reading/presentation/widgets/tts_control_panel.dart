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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

            // Audio Source Display
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ValueListenableBuilder<bool>(
                valueListenable: settings.isHumanVoice,
                builder: (context, isHuman, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.brown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isHuman ? "当前：真人朗读" : "当前：机械朗读",
                      style: const TextStyle(
                        color: Colors.brown,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
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
                                fontSize: 12,
                                color: Colors.brown.withOpacity(0.7))),
                        Text('第$totalVerses节',
                            style: TextStyle(
                                fontSize: 12,
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
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        min: 1,
                        max: totalVerses.toDouble(),
                        value: (currentVerse > 0 ? currentVerse : 1)
                            .toDouble()
                            .clamp(1, totalVerses.toDouble()),
                        divisions: totalVerses > 1 ? totalVerses - 1 : 1,
                        label: '第$currentVerse节',
                        onChanged: (value) {
                          onVerseSeek?.call(value.round());
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Main Controls Area
            ValueListenableBuilder<bool>(
              valueListenable: settings.isHumanVoice,
              builder: (context, isHuman, _) {
                if (isHuman) {
                  return _buildHumanVoiceControls(audioManager);
                } else {
                  return _buildTtsControls(ttsService, settings);
                }
              },
            ),
          ],
        ),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.brown)),
      ],
    );
  }

  Widget _buildHumanVoiceControls(AudioManager audioManager) {
    return FutureBuilder<bool>(
      future: audioManager.isChapterDownloaded(bookId, currentChapter),
      builder: (context, snapshot) {
        final downloadKey = "${bookId}_$currentChapter";

        return ValueListenableBuilder<Map<String, double>>(
          valueListenable: audioManager.downloadProgressNotifier,
          builder: (context, progressMap, _) {
            final isDownloading = progressMap.containsKey(downloadKey);
            final progress = progressMap[downloadKey] ?? 0.0;
            final isDownloaded = snapshot.data ?? false;

            if (isDownloading) {
              return Column(
                children: [
                  LinearProgressIndicator(value: progress, color: Colors.brown),
                  const SizedBox(height: 8),
                  Text("下载中... ${(progress * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(color: Colors.brown)),
                ],
              );
            }

            if (!isDownloaded) {
              return Column(
                children: [
                  const Text("本章音频未下载", style: TextStyle(color: Colors.brown)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("下载音频"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      audioManager.downloadChapter(bookId, currentChapter);
                    },
                  ),
                ],
              );
            }

            // If downloaded, show Playback Controls
            return _buildPlayerControls(
              stateNotifier: audioManager.playerStateNotifier,
              isPlayingSelector: (state) {
                return state == AudioPlayerState.playing ||
                    state == AudioPlayerState.buffering;
              },
              onPlayPause: (isPlaying) {
                if (isPlaying) {
                  audioManager.pause();
                } else {
                  if (audioManager.playerStateNotifier.value ==
                      AudioPlayerState.paused) {
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
  }

  Widget _buildTtsControls(TtsService ttsService, SettingsService settings) {
    return ValueListenableBuilder<String>(
      valueListenable: settings.ttsEngine,
      builder: (context, engine, _) {
        if (engine == 'piper') {
          // Piper Controls (Placeholder for now)
          return Center(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Piper TTS 运行中",
                  style: TextStyle(color: Colors.brown)),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.stop_circle,
                    size: 40, color: Colors.brown),
                onPressed: () {
                  onPlay
                      ?.call(); // Toggle or stop? TtsControlPanel expect stop on close.
                  // Actually onClose stops it. onPlay calls _playFromVerse.
                  // We need a way to PAUSE piper. But PiperTtsService is basic.
                  // For now allow Close.
                },
              )
            ],
          ));
        } else {
          return _buildSystemTtsControls(ttsService);
        }
      },
    );
  }

  Widget _buildSystemTtsControls(TtsService ttsService) {
    return _buildPlayerControls(
      stateNotifier: ttsService.stateNotifier,
      isPlayingSelector: (state) {
        return state == TtsState.playing || state == TtsState.continued;
      },
      onPlayPause: (isPlaying) {
        final state = ttsService.stateNotifier.value;
        if (isPlaying) {
          ttsService.pause();
        } else {
          if (state == TtsState.paused) {
            ttsService.resume();
          } else {
            onPlay?.call();
          }
        }
      },
      onPrev: onPreviousChapter,
      onNext: onNextChapter,
    );
  }

  Widget _buildPlayerControls({
    required ValueListenable stateNotifier,
    required bool Function(dynamic) isPlayingSelector,
    required Function(bool) onPlayPause,
    VoidCallback? onPrev,
    VoidCallback? onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildControlBtn(
              icon: Icons.skip_previous, label: "上一章", onTap: onPrev, size: 36),
          ValueListenableBuilder(
            valueListenable: stateNotifier,
            builder: (context, state, _) {
              final isPlaying = isPlayingSelector(state);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
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
                        size: 40,
                        color: Colors.white,
                      ),
                      onPressed: () => onPlayPause(isPlaying),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(isPlaying ? "暂停" : "播放",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.brown)),
                ],
              );
            },
          ),
          _buildControlBtn(
              icon: Icons.skip_next, label: "下一章", onTap: onNext, size: 36),
        ],
      ),
    );
  }
}
