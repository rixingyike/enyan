import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gracewords/core/data/audio_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

enum AudioPlayerState { stopped, playing, paused, buffering, completed }

@lazySingleton
class AudioManager {
  final AudioRepository _repository;
  final Player _player = Player();
  final Dio _dio = Dio();

  // State Notifiers
  final ValueNotifier<AudioPlayerState> playerStateNotifier =
      ValueNotifier(AudioPlayerState.stopped);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);

  // Download Progress: Map<String, double> where key is "bookId_chapterId"
  final ValueNotifier<Map<String, double>> downloadProgressNotifier =
      ValueNotifier({});

  // Cache current playing media
  int? _currentBookId;
  int? _currentChapterId;

  AudioManager(this._repository) {
    _init();
  }

  void _init() {
    _player.stream.playing.listen((playing) {
      if (playing) {
        playerStateNotifier.value = AudioPlayerState.playing;
      } else {
        playerStateNotifier.value = AudioPlayerState.paused;
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (buffering) {
        playerStateNotifier.value = AudioPlayerState.buffering;
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        playerStateNotifier.value = AudioPlayerState.completed;
      }
    });

    _player.stream.position.listen((pos) {
      positionNotifier.value = pos;
    });

    _player.stream.duration.listen((dur) {
      durationNotifier.value = dur;
    });

    _player.stream.playing.listen((playing) {
      debugPrint("🎛️ [Audio] Playing: $playing");
    });
  }

  Future<void> initRepository() async {
    await _repository.init();
  }

  Future<bool> isChapterDownloaded(int bookId, int chapterId) async {
    return _repository.isAudioDownloaded(bookId, chapterId);
  }

  Future<void> downloadChapter(int bookId, int chapterId) async {
    final url = _repository.getAudioUrl(bookId, chapterId);
    if (url == null) {
      debugPrint("No URL for book $bookId chapter $chapterId");
      return;
    }

    final key = "${bookId}_$chapterId";
    if (downloadProgressNotifier.value.containsKey(key))
      return; // Already downloading

    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/audio/$bookId/$chapterId.mp3';
      debugPrint("⬇️ [Audio] Starting download for $key to $savePath");

      await Directory('${dir.path}/audio/$bookId').create(recursive: true);

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final newMap =
                Map<String, double>.from(downloadProgressNotifier.value);
            newMap[key] = received / total;
            downloadProgressNotifier.value = newMap;
          }
        },
      );

      final newMap = Map<String, double>.from(downloadProgressNotifier.value);
      newMap.remove(key);
      downloadProgressNotifier.value = newMap;
      debugPrint("✅ [Audio] Download complete: $savePath");
    } catch (e) {
      debugPrint("❌ [Audio] Download error for $key: $e");
      final newMap = Map<String, double>.from(downloadProgressNotifier.value);
      newMap.remove(key);
      downloadProgressNotifier.value = newMap;
    }
  }

  Future<void> playChapter(int bookId, int chapterId,
      {Duration? startPosition}) async {
    try {
      // 1. If already playing the same chapter, just seek
      if (_currentBookId == bookId && _currentChapterId == chapterId) {
        debugPrint("🎵 [Audio] Already playing $bookId:$chapterId. Seeking to $startPosition...");
        if (startPosition != null) {
          await _player.play(); // Ensure it's not paused so seek works reliably
          await _player.seek(startPosition);
        } else {
          await _player.play();
        }
        return;
      }

      // 2. Otherwise load new file
      final file = await _repository.getLocalAudioFile(bookId, chapterId);
      final fileAbsPath = file.absolute.path;
      
      debugPrint("🎵 [Audio] Opening: Book $bookId, Chap $chapterId");
      if (!file.existsSync()) {
        debugPrint("❌ [Audio] ERROR: File NOT found at $fileAbsPath");
        return;
      }

      await _player.open(Media(fileAbsPath), play: false);
      _currentBookId = bookId;
      _currentChapterId = chapterId;
      
      // Wait a tiny bit for the player to be ready for seek
      if (startPosition != null) {
        debugPrint("🎯 [Audio] New file, delay-seeking to: ${startPosition.inSeconds}s");
        await Future.delayed(const Duration(milliseconds: 100));
        await _player.seek(startPosition);
      }
      
      await _player.play();
      debugPrint("▶️ [Audio] Playback started");
    } catch (e) {
      debugPrint("❌ [Audio] Play error: $e");
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentBookId = null;
    _currentChapterId = null;
    playerStateNotifier.value = AudioPlayerState.stopped;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setRate(speed);
  }

  void dispose() {
    _player.dispose();
    playerStateNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    downloadProgressNotifier.dispose();
  }
}
