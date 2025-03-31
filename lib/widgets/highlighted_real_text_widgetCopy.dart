import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

import '../models/segment.dart';
import '../transcription_widget_abstract.dart';

class HighlightedRealTextWidget extends TranscriptionWidget {
  final ScrollController scrollController;
  final TextStyle currentWordStyle; // Nuevo parámetro
  final TextStyle previousWordStyle; // Nuevo parámetro
  final TextStyle nextWordStyle; // Nuevo parámetro
  const HighlightedRealTextWidget({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    required super.onWordTap,
    required this.scrollController,
    this.currentWordStyle = const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.blue),
    this.previousWordStyle = const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.blue),
    this.nextWordStyle = const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.blue),
  }) : super(key: key);

  @override
  State<HighlightedRealTextWidget> createState() => _HighlightedRealTextWidgetState();
}

class _HighlightedRealTextWidgetState extends TranscriptionWidgetState<HighlightedRealTextWidget> {
  int? _selectionStart;
  int? _selectionEnd;
  final double zoom = 100;
  int _lastValidCurrentWordIndex = 0; // Inicializado en 0

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentWord();
    });
  }

  @override
  void didUpdateWidget(covariant HighlightedRealTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToCurrentWord();
      });
    }
  }

  bool _isWordSelected(int index) {
    if (_selectionStart == null || _selectionEnd == null) {
      return false;
    }
    final int start = _selectionStart!;
    final int end = _selectionEnd!;
    final int lower = start < end ? start : end;
    final int upper = start > end ? start : end;
    return index >= lower && index <= upper;
  }

  Color? _getWordBackgroundColor(int associatedWordIndex) {
    final state = context.read<TranscribeCubit>().state;
    if (state.transcription == null || associatedWordIndex < 0 || associatedWordIndex >= state.transcription!.transsegments.length) {
      return _isWordSelected(associatedWordIndex) ? Colors.grey.withOpacity(0.5) : null;
    }
    final List<String> tags = state.transcription!.transsegments[associatedWordIndex].tags;
    if (tags.isNotEmpty) {
      return getMixedTagColor(tags);
    }
    return _isWordSelected(associatedWordIndex) ? Colors.grey.withOpacity(0.5) : null;
  }

  TextStyle _getWordTextStyle(int associatedWordIndex) {
    final effectiveCurrentWordIndex = widget.currentWordIndex == -1 ? _lastValidCurrentWordIndex : widget.currentWordIndex;
    final isCurrentWord = associatedWordIndex == effectiveCurrentWordIndex;
    final isPreviousWord = associatedWordIndex == effectiveCurrentWordIndex - 1;
    final isNextWord = associatedWordIndex == effectiveCurrentWordIndex + 1;
    if (widget.currentWordIndex == -1) {
      return const TextStyle(fontSize: 16.0, color: Colors.black);
    }
    if (isCurrentWord) {
      return widget.currentWordStyle;
    } else if (isPreviousWord) {
      return widget.previousWordStyle;
    } else if (isNextWord) {
      return widget.nextWordStyle;
    } else {
      return const TextStyle(fontSize: 16.0, color: Colors.black);
    }
  }

  @override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.transsegments.isEmpty || !widget.scrollController.hasClients) {
      return;
    }
    if (!widget.scrollController.hasClients) return;

    final index = widget.currentWordIndex;
    final totalDuration = widget.transcription.transsegments.last.end;
    final totalTextWidth = (totalDuration / 1) * zoom;

    final currentWordStart = widget.transcription.transsegments[index].start;
    final currentWordEnd = widget.transcription.transsegments[index].end;
    final currentWordPosition = (currentWordStart / totalDuration) * totalTextWidth;
    final currentWordWidth = ((currentWordEnd - currentWordStart) / totalDuration) * totalTextWidth;
    final currentWordCenter = currentWordPosition + (currentWordWidth / 2);

    final viewportWidth = widget.scrollController.position.viewportDimension;
    final scrollOffset = currentWordCenter - (viewportWidth / 2);

    widget.scrollController.animateTo(scrollOffset > 0 ? scrollOffset : 0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollToCurrentWord();
        });
        if (state.textoRealformadoparrafos == null || state.textoRealformadoparrafos!.isEmpty) {
          return const Center(child: Text('No hay texto para mostrar'));
        }
        if (state.transcription == null || state.transcription!.transsegments.isEmpty) {
          return const Center(child: Text('No hay transcripción para mostrar'));
        }
        final formattedText = state.textoRealformadoparrafos!;
        final wordsWithSpans = state.wordsWithSpans;
        // 1. Dividir el Texto Real en Párrafos
        final paragraphs = formattedText.split('\n\n');
        return SingleChildScrollView(
          controller: widget.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                paragraphs.map((paragraph) {
                  final realWords = paragraph.split(RegExp(r"\b"));
                  List<Widget> wordWidgets = [];
                  int wordWithSpansIndex = 0;
                  for (int i = 0; i < realWords.length; i++) {
                    String realWord = realWords[i];
                    if (realWord.trim().isEmpty) continue;
                    WordWithSpans? associatedWord;
                    int associatedWordIndex = -1;
                    for (int j = wordWithSpansIndex; j < wordsWithSpans.length; j++) {
                      if (wordWithSpansIndex >= wordsWithSpans.length) break;
                      WordWithSpans currentWordWithSpan = wordsWithSpans[j];
                      if (currentWordWithSpan.realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') == realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')) {
                        associatedWord = currentWordWithSpan;
                        associatedWordIndex = j;
                        wordWithSpansIndex = j + 1;
                        break;
                      }
                    }
                    if (associatedWordIndex != -1) {
                      _lastValidCurrentWordIndex = associatedWordIndex;
                    }
                    Segment? segment;
                    if (associatedWordIndex != -1 && state.transcription != null && associatedWordIndex < state.transcription!.transsegments.length) {
                      segment = state.transcription!.transsegments[associatedWordIndex];
                    }
                    double wordStart = 0;
                    double wordEnd = 0;
                    double wordPosition = 0;
                    double wordWidth = 0;
                    if (segment != null) {
                      wordStart = segment.start;
                      wordEnd = segment.end;
                      double totalDuration = state.transcription!.transsegments.last.end;
                      double totalTextWidth = (totalDuration / 1) * zoom;
                      wordPosition = (wordStart / totalDuration) * totalTextWidth;
                      wordWidth = ((wordEnd - wordStart) / totalDuration) * totalTextWidth;
                    }
                    wordWidgets.add(
                      GestureDetector(
                        onTap: () {
                          if (associatedWordIndex != -1) {
                            widget.onWordTap(associatedWordIndex);
                          }
                        },
                        onSecondaryTapDown: (details) {
                          super.showContextMenu(details.globalPosition, wordIndexes: [associatedWordIndex]);
                        },
                        onLongPressStart: (details) {
                          setState(() {
                            _selectionStart = associatedWordIndex;
                            _selectionEnd = associatedWordIndex;
                          });
                        },
                        onLongPressMoveUpdate: (details) {
                          setState(() {
                            _selectionEnd = associatedWordIndex;
                          });
                        },
                        onLongPressEnd: (details) {
                          final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                          final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                          final List<int> selectedIndexes = List.generate(upper - lower + 1, (i) => lower + i);
                          super.showContextMenu(details.globalPosition, wordIndexes: selectedIndexes);
                        },
                        onLongPressCancel: () {
                          setState(() {
                            _selectionStart = null;
                            _selectionEnd = null;
                          });
                        },
                        child: Container(color: _getWordBackgroundColor(associatedWordIndex), child: Text(realWord, style: _getWordTextStyle(associatedWordIndex))),
                      ),
                    );
                    wordWidgets.add(const SizedBox(width: 5));
                  }
                  return Column(
                    children: [
                      Wrap(children: wordWidgets),
                      const SizedBox(height: 26), // Separación entre párrafos
                    ],
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
