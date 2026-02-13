import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gracewords/core/di/injection.dart';
import 'package:gracewords/core/services/audio_manager.dart';
import 'package:gracewords/core/services/tts_service.dart';
import 'package:gracewords/features/bible_reading/domain/entities/book.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_bloc.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_event.dart';
import 'package:gracewords/features/bible_reading/presentation/bloc/bible_state.dart';
import 'package:gracewords/core/constants/bible_constants.dart';
import 'package:gracewords/core/services/settings_service.dart';
import 'package:gracewords/core/services/weight_service.dart';
import 'package:gracewords/features/bible_reading/presentation/widgets/tts_control_panel.dart';
import 'package:gracewords/core/services/font_service.dart';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChapterPage extends StatefulWidget {
  final Book book;
  final int initialChapter;
  final bool autoPlay;

  const ChapterPage({
    super.key,
    required this.book,
    required this.initialChapter,
    this.autoPlay = false,
  });

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  final TtsService _ttsService = getIt<TtsService>();
  final AudioManager _audioManager = getIt<AudioManager>();
  final SettingsService _settings = getIt<SettingsService>();
  bool _showTtsPanel = false;

  // Scrolling
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Mapping
  int _currentHighlightIndex = -1;

  @override
  void initState() {
    super.initState();
    _saveProgress();

    // TTS Listeners
    _ttsService.currentPositionNotifier.addListener(_onTtsProgress);
    _ttsService.stateNotifier.addListener(_onTtsStateChangeManual);

    // Audio Manager Listeners
    _audioManager.playerStateNotifier.addListener(_onAudioStateChange);
    _audioManager.positionNotifier.addListener(_onAudioPositionChanged);
  }

  void _onTtsStateChangeManual() {
    final state = _ttsService.stateNotifier.value;
    if (state == TtsState.paused || state == TtsState.stopped) {
      _isTtsPlaying = false;
    }
  }

  @override
  void dispose() {
    _ttsService.currentPositionNotifier.removeListener(_onTtsProgress);
    _ttsService.stateNotifier.removeListener(_onTtsStateChangeManual);
    _audioManager.playerStateNotifier.removeListener(_onAudioStateChange);
    _audioManager.positionNotifier.removeListener(_onAudioPositionChanged);
    super.dispose();
  }

  bool _isTtsPlaying = false;

  void _onTtsProgress() {
    // Deprecated
  }

  List<dynamic> _verses = []; // Cached verses
  List<List<double>> _activeChapterTimestamps = []; // Precise timestamps
  bool _isSeeking = false; // Flag to ignore position updates during seek

  void _onAudioStateChange() {
    if (!_settings.isHumanVoice.value) return;

    final state = _audioManager.playerStateNotifier.value;
    if (state == AudioPlayerState.completed) {
      _navigateToChapter(widget.initialChapter + 1, autoPlay: true);
    }
  }

  void _onAudioPositionChanged() {
    if (!_settings.isHumanVoice.value || _isSeeking) return;
    
    final current = _audioManager.positionNotifier.value;
    final total = _audioManager.durationNotifier.value;
    if (total.inMilliseconds == 0) return;

    int index = -1;

    // Precise Timestamps Only
    if (_activeChapterTimestamps.isNotEmpty) {
        final currentSec = current.inMilliseconds / 1000.0;
        for (int i = 0; i < _activeChapterTimestamps.length; i++) {
            final start = _activeChapterTimestamps[i][0];
            final end = _activeChapterTimestamps[i][1];
            
            // Skip dummy [0,0] at the start if it exists
            if (i == 0 && start == 0 && end == 0) continue;

            if (currentSec >= start && currentSec <= end) {
                // If timestamps have a dummy at 0, then i=1 corresponds to verses[0] (Verse 1)
                // So index = i - 1
                index = (_activeChapterTimestamps[0][0] == 0 && _activeChapterTimestamps[0][1] == 0) ? i - 1 : i;
                break;
            }
        }
    }

    if (index != -1 && index != _currentHighlightIndex) {
        setState(() {
            _currentHighlightIndex = index;
        });
        _scrollToIndex(index);
    }
  }

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  Future<void> _playFromVerse(int index, List<dynamic> verses) async {
    debugPrint("👆 [ChapterPage] Jumping to verse index: $index");
    _saveProgress();
    
    setState(() {
      _showTtsPanel = true;
      _currentHighlightIndex = index;
    });

    if (_settings.isHumanVoice.value) {
      final isDownloaded = await _audioManager.isChapterDownloaded(
          widget.book.id, widget.initialChapter);
      
      if (isDownloaded) {
        // Precise Seek if we have timestamps
        if (_activeChapterTimestamps.isNotEmpty) {
            // Adjust index for dummy [0,0] if it exists
            final hasDummy = _activeChapterTimestamps[0][0] == 0 && _activeChapterTimestamps[0][1] == 0;
            final actualTsIndex = hasDummy ? index + 1 : index;
            
            if (actualTsIndex < _activeChapterTimestamps.length) {
                final startTime = _activeChapterTimestamps[actualTsIndex][0];
                final seekPos = Duration(milliseconds: (startTime * 1000).round());
                debugPrint("🎯 [ChapterPage] Precise seek to ${startTime}s");
                
                setState(() => _isSeeking = true);
                await _audioManager.playChapter(widget.book.id, widget.initialChapter, startPosition: seekPos);
                // Wait briefly for the audio to move before re-enabling sync highlight
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) setState(() => _isSeeking = false);
                return;
            }
        }
        
        // Fallback: Play from start if no timestamps or index out of range
        debugPrint("▶️ [ChapterPage] No timestamps or index out of range, playing from start");
        await _audioManager.playChapter(widget.book.id, widget.initialChapter);
      } else {
        // Option 1: Trigger download (or show toast)
        _audioManager.downloadChapter(widget.book.id, widget.initialChapter);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在下载语音包...')),
        );
      }
    } else {
      _startTtsCoordinator(index, verses);
    }
  }

  void _toggleTts(List<dynamic> verses) async {
    setState(() {
      _showTtsPanel = true;
    });

    if (_settings.isHumanVoice.value) {
      final isDownloaded = await _audioManager.isChapterDownloaded(
          widget.book.id, widget.initialChapter);
      if (isDownloaded) {
        _audioManager.playChapter(widget.book.id, widget.initialChapter);
        if (_currentHighlightIndex == -1) {
          setState(() => _currentHighlightIndex = 0);
        }
      } else {
        _audioManager.downloadChapter(widget.book.id, widget.initialChapter);
      }
    } else {
      _startTtsCoordinator(0, verses);
    }
  }

  Future<void> _startTtsCoordinator(int startIndex, List<dynamic> verses) async {
    if (_isTtsPlaying) {
      await _ttsService.stop();
      _isTtsPlaying = false;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isTtsPlaying = true;
    _ttsService.stateNotifier.value = TtsState.playing;

    for (int i = startIndex; i < verses.length; i++) {
      if (!_isTtsPlaying || !_showTtsPanel) break;

      setState(() {
        _currentHighlightIndex = i;
      });
      _scrollToIndex(i);

      final verse = verses[i];
      final text = verse.content;
      
      await _ttsService.speak(text);
      await Future.delayed(const Duration(milliseconds: 100));

      bool started = false;
      for (int retry = 0; retry < 60; retry++) {
        if (await _ttsService.isSpeaking()) {
          started = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isTtsPlaying) return;
      }
      
      if (!started) continue;

      int idleCount = 0;
      while (idleCount < 2) {
        if (!await _ttsService.isSpeaking()) {
          idleCount++;
        } else {
          idleCount = 0;
        }
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isTtsPlaying) return;
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_isTtsPlaying && _currentHighlightIndex == verses.length - 1) {
      _isTtsPlaying = false;
      _ttsService.stateNotifier.value = TtsState.completed;
      _navigateToChapter(widget.initialChapter + 1, autoPlay: true);
    }
    
    _isTtsPlaying = false;
  }

  void _saveProgress() {
    getIt<SettingsService>()
        .saveReadingProgress(widget.book.id, widget.initialChapter, 0.0);
  }

  void _navigateToChapter(int newChapter, {bool autoPlay = false}) {
    final currentTotal = BibleConstants.bookChapterCounts[widget.book.id] ?? 999;
    final isSimplified = _settings.currentIsSimplified;

    // Handle Backward Book Navigation
    if (newChapter < 1) {
      final prevBookId = widget.book.id - 1;
      if (prevBookId < 1) return; // Already first book

      final prevBookMaxChapter = BibleConstants.bookChapterCounts[prevBookId] ?? 1;
      final prevBook = Book(
        id: prevBookId,
        name: BibleConstants.getFullName(prevBookId, isSimplified: isSimplified),
        shortName: BibleConstants.getShortName(prevBookId, isSimplified: isSimplified),
        chapterCount: prevBookMaxChapter,
        testament: prevBookId >= 40 ? 'NT' : 'OT',
      );

      _performNavigation(prevBook, prevBookMaxChapter, autoPlay);
      return;
    }
    
    // Handle Forward Book Navigation
    if (newChapter > currentTotal) {
      final nextBookId = widget.book.id + 1;
      if (nextBookId > 66) return; // Already last book
      
      final nextBook = Book(
        id: nextBookId,
        name: BibleConstants.getFullName(nextBookId, isSimplified: isSimplified),
        shortName: BibleConstants.getShortName(nextBookId, isSimplified: isSimplified),
        chapterCount: BibleConstants.bookChapterCounts[nextBookId] ?? 1,
        testament: nextBookId >= 40 ? 'NT' : 'OT',
      );

      _performNavigation(nextBook, 1, autoPlay);
      return;
    }

    // Standard Chapter Navigation within same book
    _performNavigation(widget.book, newChapter, autoPlay);
  }

  void _performNavigation(Book book, int chapter, bool autoPlay) {
    _ttsService.stop();
    _audioManager.stop();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterPage(
          book: book,
          initialChapter: chapter,
          autoPlay: autoPlay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BibleBloc>()
        ..add(LoadChapterEvent(
            bookId: widget.book.id, chapter: widget.initialChapter)),
      child: BlocConsumer<BibleBloc, BibleState>(
        listener: (context, state) {
          if (state is ChapterLoaded && widget.autoPlay && !_showTtsPanel) {
            _toggleTts(state.verses);
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                  '${getIt<SettingsService>().currentIsSimplified ? BibleConstants.getSimplifiedFullName(widget.book.id) : BibleConstants.getFullName(widget.book.id, isSimplified: false)} 第 ${widget.initialChapter} 章',
                  style: TextStyle(fontFamily: _settings.currentIsSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  onPressed: () => _navigateToChapter(widget.initialChapter - 1),
                  tooltip: '上一章',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 32),
                  onPressed: () => _navigateToChapter(widget.initialChapter + 1),
                  tooltip: '下一章',
                ),
                const SizedBox(width: 8),
              ],
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _ttsService.stop();
                  _audioManager.stop();
                  Navigator.pop(context);
                },
              ),
            ),
            floatingActionButton: BlocBuilder<BibleBloc, BibleState>(
              builder: (context, state) {
                if (state is ChapterLoaded && !_showTtsPanel) {
                  return FloatingActionButton.large(
                    onPressed: () {
                      if (_settings.isHumanVoice.value) {
                        final audioState = _audioManager.playerStateNotifier.value;
                        if (audioState == AudioPlayerState.playing || audioState == AudioPlayerState.buffering) {
                          setState(() => _showTtsPanel = true);
                        } else if (audioState == AudioPlayerState.paused) {
                          setState(() => _showTtsPanel = true);
                          _audioManager.resume();
                        } else {
                          _toggleTts(state.verses);
                        }
                      } else {
                        final ttsState = _ttsService.stateNotifier.value;
                        if (ttsState == TtsState.playing || ttsState == TtsState.continued) {
                          setState(() => _showTtsPanel = true);
                        } else if (ttsState == TtsState.paused) {
                          setState(() => _showTtsPanel = true);
                          _ttsService.resume();
                        } else {
                          _toggleTts(state.verses);
                        }
                      }
                    },
                    backgroundColor: Colors.brown,
                    child: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
                  );
                }
                return const SizedBox();
              },
            ),
            body: Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is BibleLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is ChapterLoaded) {
                         if (_verses != state.verses) {
                              _verses = state.verses;
                              _activeChapterTimestamps = getIt<WeightService>().getChapterTimestamps(
                                widget.book.id, 
                                widget.initialChapter
                              );
                         }
                        return ScrollablePositionedList.builder(
                          itemCount: state.verses.length + 1,
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemBuilder: (context, index) {
                            if (index == state.verses.length) {
                              return const Column(
                                children: [
                                  SizedBox(height: 160),
                                  Center(child: Text('--- 本章结束 ---', style: TextStyle(color: Colors.grey, fontSize: 16))),
                                  SizedBox(height: 80),
                                ],
                              );
                            }

                            final verse = state.verses[index];
                            final isHighlighted = index == _currentHighlightIndex;
                            final isSimplified = _settings.currentIsSimplified;
                            
                            // Determine font family
                            String fontFamily = isSimplified ? 'LxgwWenKai' : 'LxgwWenkaiTC';
                            // If traditional and not loaded, fallback or handle
                            if (!isSimplified && !getIt<FontService>().isLoaded('LxgwWenkaiTC')) {
                                // You might want to fallback to system font or LxgwWenKai 
                                // if it has some traditional glyphs, but better use default.
                                // Let's keep the requested family, Flutter will fallback to system 
                                // if the family isn't found/loaded.
                            }

                            return GestureDetector(
                              onDoubleTap: () => _playFromVerse(index, state.verses),
                              onTap: () {
                                if (_showTtsPanel) {
                                  _playFromVerse(index, state.verses);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: isHighlighted
                                    ? BoxDecoration(
                                        color: Colors.brown.withOpacity(0.12),
                                        border: const Border(
                                          top: BorderSide(color: Colors.brown, width: 2),
                                          bottom: BorderSide(color: Colors.brown, width: 2),
                                        ),
                                      )
                                    : null,
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: isHighlighted ? Colors.brown.shade900 : const Color(0xFF212121),
                                      fontSize: 36,
                                      height: 1.6,
                                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                                      fontFamily: fontFamily,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${verse.verseNumber} ',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: isHighlighted ? Colors.brown.shade700 : Colors.brown.withOpacity(0.7),
                                          fontWeight: FontWeight.bold,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                      TextSpan(text: verse.content),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      } else if (state is BibleError) {
                        return Center(child: Text('Error: ${state.message}'));
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                if (_showTtsPanel && state is ChapterLoaded)
                  TtsControlPanel(
                    onClose: () {
                      _ttsService.stop();
                      _audioManager.stop();
                      setState(() => _showTtsPanel = false);
                    },
                    onPlay: () {
                      final startIndex = _currentHighlightIndex >= 0 ? _currentHighlightIndex : 0;
                      _playFromVerse(startIndex, state.verses);
                    },
                    currentChapter: widget.initialChapter,
                    currentVerse: _currentHighlightIndex + 1,
                    bookId: widget.book.id,
                    totalVerses: state.verses.length,
                    onVerseSeek: (verseNumber) {
                      _playFromVerse(verseNumber - 1, state.verses);
                    },
                    onNextChapter: () {
                      _ttsService.stop();
                      _audioManager.stop();
                      _navigateToChapter(widget.initialChapter + 1, autoPlay: true);
                    },
                    onPreviousChapter: () {
                      _ttsService.stop();
                      _audioManager.stop();
                      _navigateToChapter(widget.initialChapter - 1, autoPlay: true);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
