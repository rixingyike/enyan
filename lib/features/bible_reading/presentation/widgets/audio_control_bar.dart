import 'package:flutter/material.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/audio_player_manager.dart';
import 'package:just_audio/just_audio.dart';

class AudioControlBar extends StatefulWidget {
  final int bookId;
  final int chapter;

  const AudioControlBar({
    super.key,
    required this.bookId,
    required this.chapter,
  });

  @override
  State<AudioControlBar> createState() => _AudioControlBarState();
}

class _AudioControlBarState extends State<AudioControlBar> {
  late final AudioPlayerManager _audioManager;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _audioManager = getIt<AudioPlayerManager>();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _audioManager.loadChapterAudio(widget.bookId, widget.chapter);
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to load audio: $e");
      // Handle error visually if needed
    }
  }

  @override
  void didUpdateWidget(AudioControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.chapter != widget.chapter) {
      _loadAudio();
    }
  }

  @override
  void dispose() {
    _audioManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox(
        height: 60,
        child: Center(
            child: Text("正在加载音频...", style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        // Ensure it respects bottom notch
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar
            StreamBuilder<Duration>(
              stream: _audioManager.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: _audioManager.durationStream,
                  builder: (context, snapDuration) {
                    final duration = snapDuration.data ?? Duration.zero;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position),
                            style: const TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: position.inMilliseconds
                                .clamp(0, duration.inMilliseconds)
                                .toDouble(),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (val) {
                              _audioManager
                                  .seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),
                        Text(_formatDuration(duration),
                            style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  },
                );
              },
            ),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed Control
                IconButton(
                  icon: const Icon(Icons.speed),
                  onPressed: () => _showSpeedDialog(context),
                  tooltip: '速度',
                ),
                const SizedBox(width: 20),

                // Play/Pause
                StreamBuilder<PlayerState>(
                  stream: _audioManager.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return const CircularProgressIndicator();
                    } else if (playing != true) {
                      return IconButton(
                        icon: const Icon(Icons.play_circle_fill,
                            size: 48, color: Colors.brown),
                        onPressed: _audioManager.play,
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return IconButton(
                        icon: const Icon(Icons.pause_circle_filled,
                            size: 48, color: Colors.brown),
                        onPressed: _audioManager.pause,
                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.replay_circle_filled,
                            size: 48, color: Colors.brown),
                        onPressed: () => _audioManager.seek(Duration.zero),
                      );
                    }
                  },
                ),

                const SizedBox(width: 20),
                // Placeholder for symmetry or other features
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("播放速度"),
        content: StreamBuilder<double>(
          stream: _audioManager.speedStream,
          builder: (context, snapshot) {
            final speed = snapshot.data ?? 1.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                return RadioListTile<double>(
                  title: Text("${s}x"),
                  value: s,
                  groupValue: speed,
                  onChanged: (val) {
                    if (val != null) {
                      _audioManager.setSpeed(val);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    // Optional hours
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
