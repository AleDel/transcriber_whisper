import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

import '../models/segment.dart';
import '../transcription_widget_abstract.dart';

class HighlightedRealTextWidget extends TranscriptionWidget {
  final ScrollController scrollController;
  final TextStyle currentWordStyle;
  final TextStyle previousWordStyle;
  final TextStyle nextWordStyle;
  final bool showAssociatedWords;
  final bool showOnlyDifferentWords;
  final bool highlightDifferences;
  final ValueChanged<bool> onShowAssociatedWordsChanged;
  final ValueChanged<bool> onShowOnlyDifferentWordsChanged;
  final ValueChanged<bool> onHighlightDifferencesChanged;

  const HighlightedRealTextWidget({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    required super.onWordTap,
    required this.scrollController,
    this.currentWordStyle = const TextStyle(fontSize: 16.0),
    this.previousWordStyle = const TextStyle(fontSize: 16.0),
    this.nextWordStyle = const TextStyle(fontSize: 16.0),
    this.showAssociatedWords = true,
    this.showOnlyDifferentWords = false,
    this.highlightDifferences = false,
    required this.onShowAssociatedWordsChanged,
    required this.onShowOnlyDifferentWordsChanged,
    required this.onHighlightDifferencesChanged,
  }) : super(key: key);

  @override
  State<HighlightedRealTextWidget> createState() => _HighlightedRealTextWidgetState();
}

class _HighlightedRealTextWidgetState extends TranscriptionWidgetState<HighlightedRealTextWidget> {
  int? _selectionStart;
  int? _selectionEnd;
  final double zoom = 100;
  int _lastValidCurrentWordIndex = 0;
  late bool _internalShowAssociatedWords;
  late bool _internalShowOnlyDifferentWords;
  late bool _internalHighlightDifferences;
  final GlobalKey _currentWordKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _internalShowAssociatedWords = widget.showAssociatedWords;
    _internalShowOnlyDifferentWords = widget.showOnlyDifferentWords;
    _internalHighlightDifferences = widget.highlightDifferences;
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

  Color? _getWordBackgroundColor(int alignedSegmentIndex) {
    final state = context.read<TranscribeCubit>().state;
    if (state.transcription == null || state.transcription!.alignedSegments == null || alignedSegmentIndex < 0 || alignedSegmentIndex >= state.transcription!.alignedSegments!.length) {
      return _isWordSelected(alignedSegmentIndex) ? Colors.grey.withOpacity(0.5) : null;
    }
    final Segment segment = state.transcription!.alignedSegments![alignedSegmentIndex];
    if (segment.tags.isNotEmpty) {
      return getMixedTagColor(segment.tags);
    }
    return _isWordSelected(alignedSegmentIndex) ? Colors.grey.withOpacity(0.5) : null;
  }

  TextStyle _getWordTextStyle(int alignedSegmentIndex) {
    final effectiveCurrentWordIndex = widget.currentWordIndex == -1 ? _lastValidCurrentWordIndex : widget.currentWordIndex;
    final isCurrentWord = alignedSegmentIndex == effectiveCurrentWordIndex;
    final isPreviousWord = alignedSegmentIndex == effectiveCurrentWordIndex - 1;
    final isNextWord = alignedSegmentIndex == effectiveCurrentWordIndex + 1;
    TextStyle baseStyle = const TextStyle(fontSize: 16.0, color: Colors.black);

    if (widget.currentWordIndex == -1) {
      return baseStyle;
    }
    if (isCurrentWord) {
      baseStyle = widget.currentWordStyle;
    } else if (isPreviousWord) {
      baseStyle = widget.previousWordStyle;
    } else if (isNextWord) {
      baseStyle = widget.nextWordStyle;
    }
    final state = context.read<TranscribeCubit>().state;
    if (state.transcription != null && alignedSegmentIndex >= 0 && alignedSegmentIndex < state.transcription!.alignedSegments!.length) {
      final Segment segment = state.transcription!.alignedSegments![alignedSegmentIndex];
      if (_internalHighlightDifferences && segment.associationType != "coincidencia") {
        baseStyle = baseStyle.copyWith(color: Colors.red);
      }
    }
    return baseStyle;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
      if (state.textoRealformadoparrafos == null || state.textoRealformadoparrafos!.isEmpty) {
        return const Center(child: Text('No hay texto para mostrar'));
      }
      if (state.transcription == null || state.transcription!.alignedSegments == null || state.transcription!.alignedSegments!.isEmpty) {
        return const Center(child: Text('No hay transcripción para mostrar'));
      }
      final formattedText = state.textoRealformadoparrafos!;
      final alignedSegments = state.transcription!.alignedSegments!;
      final paragraphs = formattedText.split('\n\n');
      List<Widget> paragraphWidgets = [];
      for (String paragraph in paragraphs) {
        List<Widget> wordWidgets = [];
        // Iterar sobre los segmentos alineados en lugar de dividir el párrafo en palabras
        for (int i = 0; i < alignedSegments.length; i++) {
          Segment segment = alignedSegments[i];
          // Verificar si el segmento pertenece al párrafo actual
          if (!paragraph.contains(segment.word) && !paragraph.contains(segment.realWord ?? "")) continue;
          // Verificar si el segmento es un espacio en blanco
          if (segment.word.trim().isEmpty && segment.realWord == null) continue;
          // Actualizar el índice de la última palabra válida
          _lastValidCurrentWordIndex = i;
          // Mostrar la palabra asociada si no hay coincidencia y si está activado
          Widget? associatedWordWidget;
          if (_internalShowAssociatedWords && (_internalShowOnlyDifferentWords ? segment.associationType != "coincidencia" : true)) {
            final transcribedWords = segment.transcribedWords;
            if(transcribedWords?.isNotEmpty == true) {
              associatedWordWidget = Wrap(
                children: transcribedWords!.map((word) {
                  final index = transcribedWords.indexOf(word);
                  final probability = (segment.transcribedWordsProbabilities?.isNotEmpty == true && index < (segment.transcribedWordsProbabilities?.length ?? 0)) ? segment.transcribedWordsProbabilities![index] : 0.0;
                  return Chip(label: Text('$word (${probability.toStringAsFixed(2)})'));
                }).toList(),
              );
            } else {
              associatedWordWidget = null;
            }
          } else {
            associatedWordWidget = null;
          }
          // Calcular la opacidad del indicador
          double indicatorOpacity = 0.0;
          if (widget.currentWordIndex != -1) {
            final distance = (i - widget.currentWordIndex).abs();
            if (distance < 1) {
              indicatorOpacity = 1.0 - (distance / 3.0);
            }
          }
          final isCurrentWord = i == widget.currentWordIndex;
          // Verificar si el segmento es un signo de puntuación
          final isPunctuation = segment.realWord == null && segment.word.trim().isNotEmpty;
          // Si es un signo de puntuación, no lo mostramos como un widget separado
          if (isPunctuation) {
            wordWidgets.add(
              Text(segment.word, style: _getWordTextStyle(i)),
            );
            continue;
          }
          wordWidgets.add(
            GestureDetector(
              key: isCurrentWord ? _currentWordKey : null,
              onTap: () {
                widget.onWordTap(i);
              },
              onSecondaryTapDown: (details) {
                super.showContextMenu(details.globalPosition, wordIndexes: [i]);
              },
              onLongPressStart: (details) {
                setState(() {
                  _selectionStart = i;
                  _selectionEnd = i;
                });
              },
              onLongPressMoveUpdate: (details) {
                setState(() {
                  _selectionEnd = i;
                });
              },
              onLongPressEnd: (details) {
                final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                final List<int> selectedIndexes = List.generate(upper - lower + 1, (j) => lower + j);
                super.showContextMenu(details.globalPosition, wordIndexes: selectedIndexes);
              },
              onLongPressCancel: () {
                setState(() {
                  _selectionStart = null;
                  _selectionEnd = null;
                });
              },
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          color: i == widget.currentWordIndex ? Colors.yellow : _getWordBackgroundColor(i),
                          child: Text(segment.realWord ?? segment.word, style: _getWordTextStyle(i)),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          opacity: indicatorOpacity,
                          child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                        ),
                      ),
                    ],
                  ),
                  if (associatedWordWidget != null) associatedWordWidget,
                ],
              ),
            ),
          );
          wordWidgets.add(const SizedBox(width: 5));
        }
        paragraphWidgets.add(
          Column(
            children: [
              Wrap(children: wordWidgets),
              const SizedBox(height: 26), // Separación entre párrafos
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_internalShowAssociatedWords ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _internalShowAssociatedWords = !_internalShowAssociatedWords;
                    });
                    widget.onShowAssociatedWordsChanged(_internalShowAssociatedWords);
                  },
                ),
                IconButton(
                  icon: Icon(_internalShowOnlyDifferentWords ? Icons.filter_alt : Icons.filter_alt_off),
                  onPressed: () {
                    setState(() {
                      _internalShowOnlyDifferentWords = !_internalShowOnlyDifferentWords;
                    });
                    widget.onShowOnlyDifferentWordsChanged(_internalShowOnlyDifferentWords);
                  },
                ),
                IconButton(
                  icon: Icon(_internalHighlightDifferences ? Icons.text_fields : Icons.format_color_text),
                  onPressed: () {
                    setState(() {
                      _internalHighlightDifferences = !_internalHighlightDifferences;
                    });
                    widget.onHighlightDifferencesChanged(_internalHighlightDifferences);
                  },
                ),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(controller: widget.scrollController, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: paragraphWidgets))),
        ],
      );
        },
    );
  }

  @override
  void scrollToCurrentWord() {
    if (_currentWordKey.currentContext != null) {
      final RenderBox box = _currentWordKey.currentContext!.findRenderObject() as RenderBox;
      final Offset offset = box.localToGlobal(Offset.zero);
      final double currentWordY = offset.dy;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double scrollOffset = widget.scrollController.offset;
      final double targetScrollOffset = currentWordY - (screenHeight / 2) + (box.size.height / 2);
      widget.scrollController.animateTo(targetScrollOffset + scrollOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }
}