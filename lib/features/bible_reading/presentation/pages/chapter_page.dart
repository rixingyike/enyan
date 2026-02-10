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
import 'package:gracewords/features/bible_reading/presentation/widgets/tts_control_panel.dart';

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
  final List<Map<String, dynamic>> _verseMappings = [];
  int _currentHighlightIndex = -1;
  int _ttsHeadOffset = 0;

  @override
  void initState() {
    super.initState();
    _saveProgress();

    // TTS Listeners
    _ttsService.currentPositionNotifier.addListener(_onTtsProgress);
    _ttsService.stateNotifier.addListener(_onTtsStateChange);

    // Audio Manager Listeners
    _audioManager.playerStateNotifier.addListener(_onAudioStateChange);
  }

  @override
  void dispose() {
    _ttsService.currentPositionNotifier.removeListener(_onTtsProgress);
    _ttsService.stateNotifier.removeListener(_onTtsStateChange);
    _audioManager.playerStateNotifier.removeListener(_onAudioStateChange);
    super.dispose();
  }

  void _onTtsProgress() {
    if (_settings.isHumanVoice.value)
      return; // Ignore TTS progress if in Human mode

    final currentPos = _ttsService.currentPositionNotifier.value;
    final globalPos = currentPos + _ttsHeadOffset;

    // Find verse
    int foundIndex = -1;
    for (int i = 0; i < _verseMappings.length; i++) {
      final map = _verseMappings[i];
      if (globalPos >= map['start'] && globalPos < map['end']) {
        foundIndex = map['index'];
        break;
      }
    }

    if (foundIndex != -1 && foundIndex != _currentHighlightIndex) {
      setState(() {
        _currentHighlightIndex = foundIndex;
      });
      _scrollToIndex(foundIndex);
    }
  }

  void _onTtsStateChange() {
    if (_settings.isHumanVoice.value) return;

    final state = _ttsService.stateNotifier.value;
    if (state == TtsState.stopped) {
      setState(() {
        _currentHighlightIndex = -1;
      });
    } else if (state == TtsState.completed) {
      _navigateToChapter(widget.initialChapter + 1, autoPlay: true);
    }
  }

  void _onAudioStateChange() {
    if (!_settings.isHumanVoice.value) return;

    final state = _audioManager.playerStateNotifier.value;
    if (state == AudioPlayerState.completed) {
      _navigateToChapter(widget.initialChapter + 1, autoPlay: true);
    } else if (state == AudioPlayerState.stopped) {
      // Maybe clear highlight if we supported it
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

  void _saveProgress() {
    getIt<SettingsService>()
        .saveReadingProgress(widget.book.id, widget.initialChapter, 0.0);
  }

  // Prepares Mappings. Returns full text buffer.
  String _prepareMappings(List<dynamic> verses) {
    StringBuffer buffer = StringBuffer();
    _verseMappings.clear();

    int currentOffset = 0;
    for (int i = 0; i < verses.length; i++) {
      final content = verses[i].content;
      final textPart = "$content\n";
      buffer.write(textPart);

      _verseMappings.add({
        'index': i,
        'start': currentOffset,
        'end': currentOffset + textPart.length,
      });
      currentOffset += textPart.length;
    }
    return buffer.toString();
  }

  void _toggleTts(List<dynamic> verses) async {
    setState(() {
      _showTtsPanel = true;
    });

    if (_settings.isHumanVoice.value) {
      // 真人朗读模式
      final isDownloaded = await _audioManager.isChapterDownloaded(
          widget.book.id, widget.initialChapter);
      if (isDownloaded) {
        _audioManager.playChapter(widget.book.id, widget.initialChapter);
      }
    } else {
      // TTS 模式 (使用系统 TtsService)
      final fullText = _prepareMappings(verses);
      _ttsHeadOffset = 0;
      _ttsService.speak(fullText);
    }
  }

  void _playFromVerse(int index, List<dynamic> verses) {
    // 1. Prepare mappings
    final fullText = _prepareMappings(verses);

    // 2. Calculate start offset
    if (index >= _verseMappings.length) return;

    int startOffset = _verseMappings[index]['start'];

    // 3. Extract text
    String textToPlay = fullText.substring(startOffset);

    // 4. Update head offset
    _ttsHeadOffset = startOffset;

    // 5. Speak
    setState(() {
      _showTtsPanel = true;
      _currentHighlightIndex = index;
    });

    _ttsService.stop();
    _ttsService.speak(textToPlay);
  }

  void _navigateToChapter(int newChapter, {bool autoPlay = false}) {
    if (newChapter < 1) return;
    final total = BibleConstants.bookChapterCounts[widget.book.id] ?? 999;
    if (newChapter > total) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterPage(
          book: widget.book,
          initialChapter: newChapter,
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
        // Use Consumer to handle AutoPlay logic
        listener: (context, state) {
          if (state is ChapterLoaded && widget.autoPlay && !_showTtsPanel) {
            _toggleTts(state.verses);
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                  '${getIt<SettingsService>().currentIsSimplified ? BibleConstants.getSimplifiedFullName(widget.book.id) : BibleConstants.getFullName(widget.book.id, isSimplified: false)} 第 ${widget.initialChapter} 章'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _ttsService.stop();
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
                        // Human Voice Logic
                        final audioState =
                            _audioManager.playerStateNotifier.value;
                        if (audioState == AudioPlayerState.playing ||
                            audioState == AudioPlayerState.buffering) {
                          setState(() => _showTtsPanel = true);
                        } else if (audioState == AudioPlayerState.paused) {
                          setState(() => _showTtsPanel = true);
                          _audioManager.resume();
                        } else {
                          _toggleTts(state.verses);
                        }
                      } else {
                        // TTS Logic (System Only)
                        final ttsState = _ttsService.stateNotifier.value;
                        if (ttsState == TtsState.playing ||
                            ttsState == TtsState.continued) {
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
                    child: const Icon(Icons.play_arrow,
                        size: 48, color: Colors.white),
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
                        return ScrollablePositionedList.builder(
                          itemCount: state.verses.length + 1,
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          itemBuilder: (context, index) {
                            if (index == state.verses.length) {
                              return Column(
                                children: [
                                  const SizedBox(height: 48),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      if (widget.initialChapter > 1)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 16),
                                            textStyle:
                                                const TextStyle(fontSize: 20),
                                          ),
                                          onPressed: () => _navigateToChapter(
                                              widget.initialChapter - 1),
                                          icon:
                                              const Icon(Icons.arrow_back_ios),
                                          label: const Text('上一章'),
                                        ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 16),
                                          textStyle:
                                              const TextStyle(fontSize: 20),
                                        ),
                                        onPressed: () => _navigateToChapter(
                                            widget.initialChapter + 1),
                                        icon:
                                            const Icon(Icons.arrow_forward_ios),
                                        label: const Text('下一章'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 120),
                                ],
                              );
                            }

                            final verse = state.verses[index];
                            final isHighlighted =
                                index == _currentHighlightIndex;

                            return GestureDetector(
                              onDoubleTap: () =>
                                  _playFromVerse(index, state.verses),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(12),
                                decoration: isHighlighted
                                    ? BoxDecoration(
                                        color: const Color(0xFFFFF8E1)
                                            .withOpacity(0.8),
                                        border: Border.all(
                                            color:
                                                Colors.brown.withOpacity(0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.brown.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ])
                                    : null,
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: isHighlighted
                                          ? Colors.brown.shade900
                                          : const Color(0xFF212121),
                                      fontSize: 36,
                                      height: 1.6,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${verse.verseNumber} ',
                                        style: TextStyle(
                                          fontSize: 22,
                                          color: isHighlighted
                                              ? Colors.brown
                                              : Colors.brown.withOpacity(0.7),
                                          fontWeight: FontWeight.bold,
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
                      final startIndex = _currentHighlightIndex >= 0
                          ? _currentHighlightIndex
                          : 0;
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
                      _navigateToChapter(widget.initialChapter + 1,
                          autoPlay: true);
                    },
                    onPreviousChapter: () {
                      _ttsService.stop();
                      _audioManager.stop();
                      _navigateToChapter(widget.initialChapter - 1,
                          autoPlay: true);
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
