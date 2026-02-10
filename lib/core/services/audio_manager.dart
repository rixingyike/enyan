import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gracewords/core/data/audio_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum AudioPlayerState { stopped, playing, paused, buffering, completed }

@lazySingleton
class AudioManager {
  final AudioRepository _repository;
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();

  // State Notifiers
  final ValueNotifier<AudioPlayerState> playerStateNotifier =
      ValueNotifier(AudioPlayerState.stopped);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);

  // Download Progress: Map<String, double> where key is "bookId_chapterId"
  final ValueNotifier<Map<String, double>> downloadProgressNotifier =
      ValueNotifier({});

  AudioManager(this._repository) {
    _init();
  }

  void _init() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playerStateNotifier.value = AudioPlayerState.completed;
      } else if (state.playing) {
        playerStateNotifier.value = AudioPlayerState.playing;
      } else if (state.processingState == ProcessingState.buffering) {
        playerStateNotifier.value = AudioPlayerState.buffering;
      } else {
        playerStateNotifier.value =
            state.processingState == ProcessingState.idle
                ? AudioPlayerState.stopped
                : AudioPlayerState.paused;
      }
    });

    _player.positionStream.listen((pos) {
      positionNotifier.value = pos;
    });

    _player.durationStream.listen((dur) {
      if (dur != null) durationNotifier.value = dur;
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

      // Ensure directory exists
      await Directory('${dir.path}/audio/$bookId').create(recursive: true);

      // Start download
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

      // Download complete
      final newMap = Map<String, double>.from(downloadProgressNotifier.value);
      newMap.remove(key);
      downloadProgressNotifier.value = newMap;
      debugPrint("Download complete: $savePath");
    } catch (e) {
      debugPrint("Download error: $e");
      final newMap = Map<String, double>.from(downloadProgressNotifier.value);
      newMap.remove(key);
      downloadProgressNotifier.value = newMap;
    }
  }

  Future<void> playChapter(int bookId, int chapterId,
      {Duration? startPosition}) async {
    try {
      final file = await _repository.getLocalAudioFile(bookId, chapterId);
      if (!file.existsSync()) {
        debugPrint("File not found: ${file.path}");
        // Optionally try to stream or auto-download?
        // For now, assume logic checks existence before calling play
        return;
      }

      await _player.setFilePath(file.path);
      if (startPosition != null) {
        await _player.seek(startPosition);
      }
      await _player.play();
    } catch (e) {
      debugPrint("Play error: $e");
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
    playerStateNotifier.value = AudioPlayerState.stopped;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void dispose() {
    _player.dispose();
    playerStateNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    downloadProgressNotifier.dispose();
  }
}
