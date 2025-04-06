import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/segment.dart';
import '../transcription_cubit.dart';
import '../transcription_state.dart';
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

  Color? _getWordBackgroundColor(int associatedSegmentIndex, List<Segment> expandedSegments) {
    return _isWordSelected(associatedSegmentIndex) ? Colors.grey.withOpacity(0.5) : null;
  }

  TextStyle _getWordTextStyle(int associatedSegmentIndex, List<Segment> expandedSegments) {
    final state = context.read<TranscriptionCubit>().state;
    final effectiveCurrentWordIndex =
    state.extradata?.currentWordIndex == null || state.extradata!.currentWordIndex == -1 ? _lastValidCurrentWordIndex : state.extradata!.currentWordIndex;
    final isCurrentWord = associatedSegmentIndex == effectiveCurrentWordIndex;
    final isPreviousWord = associatedSegmentIndex == effectiveCurrentWordIndex - 1;
    final isNextWord = associatedSegmentIndex == effectiveCurrentWordIndex + 1;
    TextStyle baseStyle = const TextStyle(fontSize: 16.0, color: Colors.black);

    if (state.extradata?.currentWordIndex == null || state.extradata!.currentWordIndex == -1) {
      return baseStyle;
    }
    if (isCurrentWord) {
      baseStyle = widget.currentWordStyle;
    } else if (isPreviousWord) {
      baseStyle = widget.previousWordStyle;
    } else if (isNextWord) {
      baseStyle = widget.nextWordStyle;
    }

    if (state.transcription != null && associatedSegmentIndex >= 0 && associatedSegmentIndex < expandedSegments.length) {
      final Segment segment = expandedSegments[associatedSegmentIndex];
      if (_internalHighlightDifferences && segment.associationType != "coincidencia") {
        baseStyle = baseStyle.copyWith(color: Colors.red);
      }
    }
    return baseStyle;
  }

  List<Segment> _expandSegments(List<Segment> segments) {
    List<Segment> expandedSegments = [];
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      expandedSegments.add(segment);
      if (segment.realWord != null && segment.realWord!.isNotEmpty) {
        final punctuationMatches = RegExp(r'[.,:;¿?¡!-]').allMatches(segment.realWord!);
        int offset = 0;
        for (final match in punctuationMatches) {
          final punctuation = match.group(0);
          if (punctuation != null) {
            final punctuationSegment = Segment(
              word: punctuation,
              realWord: punctuation,
              start: segment.start,
              end: segment.end,
              transcribedOrder: (segment.transcribedOrder! + 0.1).toInt(), // Casting a int
              realOrder: segment.realOrder != null ? (segment.realOrder! + 0.1).toInt() : null, // Casting a int o null
              associationType: AssociationType.punctuation,
              transcribedWords: [],
              transcribedWordsProbabilities: [],
              probability: 0,
            );
            expandedSegments.insert(expandedSegments.indexOf(segment) + 1 + offset, punctuationSegment);
            offset++;
          }
        }
      }
    }
    return expandedSegments;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
        buildWhen: (previous, current) {
      // Reconstruir solo si cambia la transcripción, los segmentos asociados, el texto real, currentWordIndex o audioPosition
      return previous.transcription != current.transcription ||
          previous.transcription?.wordAlignmentSegments != current.transcription?.wordAlignmentSegments ||
          previous.transcription?.referenceText != current.transcription?.referenceText ||
          previous.extradata?.currentWordIndex != current.extradata?.currentWordIndex ||
          previous.extradata?.audioPosition != current.extradata?.audioPosition;
    },
    builder: (context, state) {
    if (state.transcription == null || state.transcription!.wordAlignmentSegments == null || state.transcription!.wordAlignmentSegments!.isEmpty) {
    return const Center(child: Text('No hay transcripción para mostrar'));
    }
    if (state.transcription!.referenceText == null || state.transcription!.referenceText!.isEmpty) {return const Center(child: Text('No hay texto real para mostrar'));
    }
    final realText = state.transcription!.referenceText!;
    final associatedSegments = state.transcription!.wordAlignmentSegments!;
    final expandedSegments = _expandSegments(associatedSegments);
    final paragraphs = realText.split('\n\n');
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
        Expanded(
          child: CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((BuildContext context, int paragraphIndex) {
                  if (paragraphIndex >= paragraphs.length) {
                    return null;
                  }
                  final paragraph = paragraphs[paragraphIndex];
                  List<Widget> wordWidgets = [];
                  List<Segment> paragraphSegments = [];
                  // Filtrar los segmentos que pertenecen al párrafo actual
                  for (var segment in expandedSegments) {
                    // Nueva condición para incluir segmentos de puntuación
                    if (paragraph.contains(segment.realWord ?? "") || paragraph.contains(segment.word) || segment.associationType == "puntuacion") {
                      paragraphSegments.add(segment);
                    }
                  }
                  // Ordenar los segmentos por realOrder si existe, si no por transcribedOrder
                  paragraphSegments.sort((a, b) {
                    if (a.realOrder != null && b.realOrder != null) {
                      return a.realOrder!.compareTo(b.realOrder!);
                    } else if (a.realOrder != null) {
                      return -1; // a va primero
                    } else if (b.realOrder != null) {
                      return 1; // b va primero
                    } else {
                      return a.transcribedOrder!.compareTo(b.transcribedOrder!);
                    }
                  });
                  for (var segment in paragraphSegments) {
                    // Actualizar el índice de la última palabra válida
                    _lastValidCurrentWordIndex = expandedSegments.indexOf(segment);
                    // Mostrar la palabra asociada si no hay coincidencia y si está activado
                    Widget? associatedWordWidget;
                    if (_internalShowAssociatedWords && (_internalShowOnlyDifferentWords ? segment.associationType != "coincidencia" : true)) {
                      final transcribedWords = segment.transcribedWords;
                      if (transcribedWords?.isNotEmpty == true) {
                        associatedWordWidget = Wrap(
                          children: transcribedWords!.map((word) {
                            final index = transcribedWords.indexOf(word);
                            final probability = (segment.transcribedWordsProbabilities?.isNotEmpty == true && index < (segment.transcribedWordsProbabilities?.length ?? 0))
                                ? segment.transcribedWordsProbabilities![index]
                                : 0.0;
                            return Chip(key: ValueKey(word), label: Text('$word (${probability.toStringAsFixed(2)})'));
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
                    final segmentIndex = expandedSegments.indexOf(segment);
                    if (state.extradata?.currentWordIndex != null && state.extradata!.currentWordIndex != -1) {
                      final distance = (segmentIndex - state.extradata!.currentWordIndex).abs();
                      if (distance < 1) {
                        indicatorOpacity = 1.0 - (distance / 3.0);
                      }
                    }
                    final isCurrentWord = state.extradata?.currentWordIndex != null && segmentIndex == state.extradata!.currentWordIndex;
                    // Agregar el segmento al párrafo
                    wordWidgets.add(
                      GestureDetector(
                        key: isCurrentWord ? _currentWordKey : null,
                        onTap: () {
                          if (segment.associationType == "puntuacion") {
                            widget.onWordTap(expandedSegments.indexOf(segment) - 1);
                          } else {
                            widget.onWordTap(expandedSegments.indexOf(segment));
                          }
                        },
                        onSecondaryTapDown: (details) {
                          super.showContextMenu(details.globalPosition, wordIndexes: [segmentIndex]);
                        },
                        onLongPressStart: (details) {
                          setState(() {
                            _selectionStart = segmentIndex;
                            _selectionEnd = segmentIndex;
                          });
                        },
                        onLongPressMoveUpdate: (details) {
                          setState(() {
                            _selectionEnd = segmentIndex;
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
                                    color: isCurrentWord ? Colors.yellow : _getWordBackgroundColor(segmentIndex, expandedSegments),
                                    child: Text(segment.realWord ?? segment.word, style: _getWordTextStyle(segmentIndex, expandedSegments)),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    opacity: indicatorOpacity,
                                    child: const SizedBox(width: 10, height: 10, child: DecoratedBox(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle))),
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
                  return Column(
                    children: [
                      Wrap(children: wordWidgets),
                      const SizedBox(height: 26), // Separación entre párrafos
                    ],
                  );
                }, childCount: paragraphs.length),
              ),
            ],
          ),
        ),
      ],
    );
    },
    );
  }

  @override
  void scrollToCurrentWord() {
    final state = context.read<TranscriptionCubit>().state;
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