import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';

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
  final bool highlightDeletedWords;
  final bool showOnlyInsertions; // New filter
  final bool showInsertionsAndDeletionsWithArrows; // New filter
  final ValueChanged<bool> onShowAssociatedWordsChanged;
  final ValueChanged<bool> onShowOnlyDifferentWordsChanged;
  final ValueChanged<bool> onHighlightDifferencesChanged;
  final ValueChanged<bool> onHighlightDeletedWordsChanged;
  final ValueChanged<bool> onShowOnlyInsertionsChanged; // New callback
  final ValueChanged<bool> onShowInsertionsAndDeletionsWithArrowsChanged; // New callback

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
    this.showAssociatedWords = false,
    this.showOnlyDifferentWords = false,
    this.highlightDifferences = false,
    this.highlightDeletedWords = true,
    this.showOnlyInsertions = false, // Default to false
    this.showInsertionsAndDeletionsWithArrows = false, // Default to false
    required this.onShowAssociatedWordsChanged,
    required this.onShowOnlyDifferentWordsChanged,
    required this.onHighlightDifferencesChanged,
    required this.onHighlightDeletedWordsChanged,
    required this.onShowOnlyInsertionsChanged, // New callback
    required this.onShowInsertionsAndDeletionsWithArrowsChanged, // New callback
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
  late bool _internalHighlightDeletedWords;
  late bool _internalShowOnlyInsertions; // New state variable
  late bool _internalShowInsertionsAndDeletionsWithArrows; // New state variable
  final GlobalKey _currentWordKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _internalShowAssociatedWords = widget.showAssociatedWords;
    _internalShowOnlyDifferentWords = widget.showOnlyDifferentWords;
    _internalHighlightDifferences = widget.highlightDifferences;
    _internalHighlightDeletedWords = widget.highlightDeletedWords;
    _internalShowOnlyInsertions = widget.showOnlyInsertions; // Initialize
    _internalShowInsertionsAndDeletionsWithArrows = widget.showInsertionsAndDeletionsWithArrows; // Initialize
  }

  @override
  void didUpdateWidget(covariant HighlightedRealTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        //scrollToCurrentWord();
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

  TextStyle _getWordTextStyle(Segment segment, int segmentIndex, int effectiveCurrentWordIndex) {
    final isCurrentWord = segmentIndex == effectiveCurrentWordIndex;
    final isPreviousWord = segmentIndex == effectiveCurrentWordIndex - 1;
    final isNextWord = segmentIndex == effectiveCurrentWordIndex + 1;
    TextStyle baseStyle = const TextStyle(fontSize: 16.0, color: Colors.black);

    if (isCurrentWord) {
      baseStyle = widget.currentWordStyle;
    } else if (isPreviousWord) {
      baseStyle = widget.previousWordStyle;
    } else if (isNextWord) {
      baseStyle = widget.nextWordStyle;
    }

    // Apply red color if "Highlight Differences" is active and it's not a coincidence
    if (_internalHighlightDifferences && segment.associationType != AssociationType.coincidence) {
      baseStyle = baseStyle.copyWith(color: Colors.red);
    }

    return baseStyle;
  }

  List<Widget> _buildFormattedText(List<Segment> associatedSegments, int effectiveCurrentWordIndex) {
    List<Widget> formattedTextWidgets = [];
    List<Widget> paragraphWidgets = [];
    for (int i = 0; i < associatedSegments.length; i++) {
      final segment = associatedSegments[i];

      // Filter logic
      if ((!_internalShowAssociatedWords &&
          !_internalShowOnlyDifferentWords &&
          !_internalHighlightDifferences &&
          !_internalHighlightDeletedWords &&
          !_internalShowOnlyInsertions &&
          !_internalShowInsertionsAndDeletionsWithArrows) &&
          (segment.associationType != AssociationType.coincidence &&
              segment.associationType != AssociationType.deleted &&
              segment.associationType != AssociationType.punctuation)) {
        // Skip this segment if it's not a coincidence, deleted, or punctuation and no filter is active
        continue;
      }
      // Filter logic for "Highlight Deleted Words"
      if (_internalHighlightDeletedWords &&
          segment.associationType != AssociationType.deleted &&
          segment.associationType != AssociationType.coincidence &&
          segment.associationType != AssociationType.punctuation) {
        // Skip if it's not a deletion
        continue;
      }
      // Filter logic for "Show Only Insertions"
      if (_internalShowOnlyInsertions &&
          segment.associationType != AssociationType.inserted &&
          segment.associationType != AssociationType.coincidence &&
          segment.associationType != AssociationType.punctuation) {
        // Skip if it's not an insertion
        continue;
      }

      // Filter logic for "Show Insertions and Deletions with Arrows"
      if (_internalShowInsertionsAndDeletionsWithArrows &&
          segment.associationType != AssociationType.inserted &&
          segment.associationType != AssociationType.deleted &&
          segment.associationType != AssociationType.coincidence &&
          segment.associationType != AssociationType.punctuation) {
        // Skip if it's not an insertion or deletion
        continue;
      }
      // **Paragraph Break Check (Moved After Filters)**
      if (segment.word == "\n\n") {
        if (paragraphWidgets.isNotEmpty) {
          formattedTextWidgets.add(Wrap(children: paragraphWidgets));
          formattedTextWidgets.add(const SizedBox(height: 76)); // Separación entre párrafos
          paragraphWidgets = [];
        }
        continue; // Skip to the next segment
      }

      // Actualizar el índice de la última palabra válida
      _lastValidCurrentWordIndex = i;

      // Mostrar la palabra asociada si no hay coincidencia y si está activado
      Widget? associatedWordWidget;
      if (_internalShowAssociatedWords && (_internalShowOnlyDifferentWords ? segment.associationType != AssociationType.coincidence : true)) {
        final transcribedWords = segment.transcribedWords;
        if (transcribedWords?.isNotEmpty == true) {
          associatedWordWidget = Wrap(
            children: transcribedWords!.map((word) {
              return Text(word, style: const TextStyle(color: Colors.grey, fontSize: 12.0));
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
      final segmentIndex = i;
      if (effectiveCurrentWordIndex != -1) {
        final distance = (segmentIndex - effectiveCurrentWordIndex).abs();
        if (distance < 1) {
          indicatorOpacity = 1.0 - (distance / 3.0);
        }
      }
      final isCurrentWord = effectiveCurrentWordIndex != -1 && segmentIndex == effectiveCurrentWordIndex;
      // Determinar el texto a mostrar y el widget adicional
      Widget mainWordWidget;
      Widget? additionalWidget;
      if (segment.associationType == AssociationType.inserted) {
        mainWordWidget = const Icon(Icons.arrow_downward, size: 20, color: Colors.green);
        additionalWidget = Text(segment.word, style: const TextStyle(color: Colors.green));
      } else if (segment.associationType == AssociationType.deleted) {
        // Show the deleted word with the default style
        mainWordWidget = Text(
          segment.realWord ?? "",
          style: _getWordTextStyle(segment, segmentIndex, effectiveCurrentWordIndex).copyWith(color: _internalHighlightDeletedWords ? Colors.red : null),
        );
        additionalWidget = null;
        if (_internalShowInsertionsAndDeletionsWithArrows) {
          mainWordWidget = const Icon(Icons.arrow_upward, size: 20, color: Colors.red);
          additionalWidget = Text(segment.realWord ?? "", style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough));
        }
      } else {
        mainWordWidget = Text(segment.realWord ?? segment.word, style: _getWordTextStyle(segment, segmentIndex, effectiveCurrentWordIndex));
        additionalWidget = null;
      }
      // Agregar el segmento al párrafo
      paragraphWidgets.add(
          GestureDetector(
              key: isCurrentWord ? _currentWordKey : null,
              onTap: () {
                // Aquí se llama a forceCurrentWord con el índice de la palabra asociada
                // Pero primero, necesitamos encontrar el segmento correspondiente en audioTranscriptionSegments
                if (widget.transcription.audioTranscriptionSegments != null) {
                  int indexInAudioTranscriptionSegments = -1;
                  if (segment.associationType == AssociationType.punctuation) {
                    // Handle punctuation
                    if (i > 0) {
                      final segmentToFind = associatedSegments[i - 1];
                      for (int j = 0; j < widget.transcription.audioTranscriptionSegments.length; j++) {
                        final audioSegment = widget.transcription.audioTranscriptionSegments[j];
                        if (audioSegment.start == segmentToFind.start && audioSegment.end == segmentToFind.end) {
                          indexInAudioTranscriptionSegments = j;
                          break;
                        }
                      }
                    }
                  } else {
                    // Handle non-punctuation
                    for (int j = 0; j < widget.transcription.audioTranscriptionSegments.length; j++) {
                      final audioSegment = widget.transcription.audioTranscriptionSegments[j];
                      if (audioSegment.start == segment.start && audioSegment.end == segment.end) {
                        indexInAudioTranscriptionSegments = j;
                        break;
                      }
                    }
                  }
                  if (indexInAudioTranscriptionSegments != -1) {
                    widget.onWordTap(indexInAudioTranscriptionSegments);
                  }
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
              onLongPressMoveUpdate: (details) {},
              onLongPressEnd: (details) {
                final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                final List<int> selectedIndexes = List.generate(upper - lower + 1, (j) => lower + j);
                super.showContextMenu(details.globalPosition, wordIndexes: selectedIndexes);
              },onLongPressCancel: () {
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
                      child: Container(color: isCurrentWord ? Colors.yellow : _getWordBackgroundColor(segmentIndex, associatedSegments), child: mainWordWidget),
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
                if (additionalWidget != null) additionalWidget,
                if (associatedWordWidget != null) associatedWordWidget,
              ],
            ),
          ),
      );
      paragraphWidgets.add(const SizedBox(width: 5));
    }
    // Agregar el último párrafo si hay widgets en él
    if (paragraphWidgets.isNotEmpty) {
      formattedTextWidgets.add(Wrap(children: paragraphWidgets));
    }
    return formattedTextWidgets;
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
            previous.extradata?.audioPosition != current.extradata?.audioPosition ||
            previous.extradata?.currentAssociatedWordIndex != current.extradata?.currentAssociatedWordIndex;
      },
      builder: (context, state) {
        if (state.transcription == null || state.transcription!.wordAlignmentSegments == null || state.transcription!.wordAlignmentSegments!.isEmpty) {
          return const Center(child: Column(children: [Text('No hay transcripción para mostrar'), LoadingWidget()]));
        }
        if (state.transcription!.referenceText == null || state.transcription!.referenceText!.isEmpty) {
          return const Center(child: Text('No hay texto real para mostrar'));
        }
        final associatedSegments = state.transcription!.wordAlignmentSegments!;
        final effectiveCurrentWordIndex =
            state.extradata?.currentAssociatedWordIndex == null || state.extradata!.currentAssociatedWordIndex == -1
                ? _lastValidCurrentWordIndex
                : state.extradata!.currentAssociatedWordIndex;
        final formattedTextWidgets = _buildFormattedText(associatedSegments, effectiveCurrentWordIndex);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(internalAutoScrollEnabled ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      setAutoScroll(!internalAutoScrollEnabled);
                    },
                  ),
                  Row(
                    children: [
                      const Text("Show Associated Words"),
                      Switch(
                        value: _internalShowAssociatedWords,
                        onChanged: (value) {
                          setState(() {
                            _internalShowAssociatedWords = value;
                          });
                          widget.onShowAssociatedWordsChanged(value);
                        },
                      ),
                    ],
                  ),
                  /*Row(
                    children: [
                      const Text("Show Only Different Words"),
                      Switch(
                        value: _internalShowOnlyDifferentWords,
                        onChanged: (value) {
                          setState(() {
                            _internalShowOnlyDifferentWords = value;
                          });
                          widget.onShowOnlyDifferentWordsChanged(value);
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Highlight Differences"),
                      Switch(
                        value: _internalHighlightDifferences,
                        onChanged: (value) {
                          setState(() {
                            _internalHighlightDifferences = value;
                          });
                          widget.onHighlightDifferencesChanged(value);
                        },
                      ),
                    ],
                  ),*/
                  Row(
                    children: [
                      const Text("Highlight Deleted Words"),
                      Switch(
                        value: _internalHighlightDeletedWords,
                        onChanged: (value) {
                          setState(() {
                            _internalHighlightDeletedWords = value;
                          });
                          widget.onHighlightDeletedWordsChanged(value);
                        },
                      ),
                    ],
                  ),
                  /*Row(
                    children: [
                      const Text("Show Only Insertions"), // New switch
                      Switch(
                        value: _internalShowOnlyInsertions,
                        onChanged: (value) {
                          setState(() {
                            _internalShowOnlyInsertions = value;
                          });
                          widget.onShowOnlyInsertionsChanged(value);
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Show Insertions/Deletions with Arrows"), // New switch
                      Switch(
                        value: _internalShowInsertionsAndDeletionsWithArrows,
                        onChanged: (value) {
                          setState(() {
                            _internalShowInsertionsAndDeletionsWithArrows = value;
                          });
                          widget.onShowInsertionsAndDeletionsWithArrowsChanged(value);
                        },
                      ),
                    ],
                  ),*/
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(controller: widget.scrollController, child: Padding(padding: const EdgeInsets.all(8.0), child: Wrap(children: formattedTextWidgets))),
            ),
          ],
        );
      },
    );
  }

  @override
  void scrollToCurrentWord() {
    if (_currentWordKey.currentContext != null) {
      final RenderBox renderBox = _currentWordKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final double scrollOffset = position.dy - (MediaQuery.of(context).size.height / 2) + (renderBox.size.height / 2);
      widget.scrollController.animateTo(scrollOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }


}
