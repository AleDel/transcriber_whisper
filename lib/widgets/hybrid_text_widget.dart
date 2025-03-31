import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

import '../models/segment.dart';
import '../models/transcription_model.dart';
import '../transcribe_state.dart';

class HybridTextWidget extends TranscriptionWidget {
  final String? waveformImageBase64;
  final ScrollController scrollController;

  const HybridTextWidget({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    this.waveformImageBase64,
    required this.scrollController,
    required super.onWordTap,
    super.autoScrollEnabled = true,
    super.onAutoScrollChanged,
  }) : super(key: key);

  @override
  State<HybridTextWidget> createState() => _HybridTextWidgetState();
}

class _HybridTextWidgetState extends TranscriptionWidgetState<HybridTextWidget> {
  final double zoom = 100;
  int? _selectionStart;
  int? _selectionEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentWord();
    });
    html.document.onContextMenu.listen((event) => event.preventDefault());
  }

  @override
  void didUpdateWidget(covariant HybridTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToCurrentWord();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
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

  Color? _getWordBackgroundColor(int index, int associatedWordIndex) {
    if (associatedWordIndex == widget.currentWordIndex) {
      return Colors.yellow;
    }
    final bool isSelected = _isWordSelected(associatedWordIndex);
    final state = context.read<TranscribeCubit>().state;
    if (state.transcription == null || associatedWordIndex < 0 || associatedWordIndex >= state.transcription!.transsegments.length) {
      return isSelected ? Colors.grey.withOpacity(0.5) : null;
    }
    final List<String> tags = state.transcription!.transsegments[associatedWordIndex].tags;
    if (tags.isNotEmpty) {
      return getMixedTagColor(tags);
    }
    if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transcription.transsegments.isEmpty) {
      return Container();
    }

    double totalDuration = widget.transcription.transsegments.last.end;

    return BlocBuilder<TranscribeCubit, TranscribeState>(
      buildWhen: (previous, current) => previous.transcription != current.transcription || previous.editMode != current.editMode,
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            double totalTextWidth = (totalDuration / 1) * zoom;
            final formattedText = state.textoRealformadoparrafos!;
            final wordsWithSpans = state.wordsWithSpans;
            final realWords = formattedText.split(RegExp(r"\b"));
            List<Widget> realWordWidgets = [];
            List<Widget> transWordWidgets = [];
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
                wordPosition = (wordStart / totalDuration) * totalTextWidth;
                wordWidth = ((wordEnd - wordStart) / totalDuration) * totalTextWidth;
              }
              // Real Word Widget
              realWordWidgets.add(
                Positioned(
                  left: wordPosition,
                  top: 0,
                  height: 30,
                  child: GestureDetector(
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
                    child: Container(
                      width: wordWidth,
                      color: _getWordBackgroundColor(0, associatedWordIndex),
                      alignment: Alignment.center,
                      child: Text(
                        realWord,
                        style: TextStyle(fontSize: 16, color: associatedWordIndex == widget.currentWordIndex ? Colors.blue : Colors.black),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
              // Trans Word Widget
              if (associatedWord != null) {
                transWordWidgets.add(
                  Positioned(
                    left: wordPosition,
                    top: 30,
                    height: 30,
                    child: Container(
                      width: wordWidth,
                      color: _getWordBackgroundColor(0, associatedWordIndex),
                      alignment: Alignment.center,
                      child: Text(
                        associatedWord.spans.map((e) => e.toPlainText()).join(),
                        style: TextStyle(fontSize: 12, color: associatedWordIndex == widget.currentWordIndex ? Colors.blue : Colors.black),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              } else {
                transWordWidgets.add(Positioned(left: wordPosition, top: 30, height: 30, child: Container(width: wordWidth, color: Colors.transparent)));
              }
            }

            return Column(
              children: [
                Container(
                  width: totalTextWidth,
                  height: 60,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey)),
                  child: Stack(
                    children: [
                      if (widget.waveformImageBase64 != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: totalTextWidth,
                            height: 30,
                            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.5),
                            child: Image.memory(base64Decode(widget.waveformImageBase64!), gaplessPlayback: true, fit: BoxFit.fill, isAntiAlias: true),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(width: totalTextWidth * (widget.audioPosition.inMilliseconds / (totalDuration * 1000)), height: 60, color: Colors.blue.withOpacity(0.5)),
                      ),
                      ...realWordWidgets,
                      ...transWordWidgets,
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
