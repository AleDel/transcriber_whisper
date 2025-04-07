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
      // Si es un salto de párrafo, agregar el párrafo actual y comenzar uno nuevo
      if (segment.word == "\n\n") {
        if (paragraphWidgets.isNotEmpty) {
          formattedTextWidgets.add(Wrap(children: paragraphWidgets));
          formattedTextWidgets.add(const SizedBox(height: 26)); // Separación entre párrafos
          paragraphWidgets = [];
        }
        continue;
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
      final segmentIndex = i;
      if (effectiveCurrentWordIndex != -1) {
        final distance = (segmentIndex - effectiveCurrentWordIndex).abs();
        if (distance < 1) {
          indicatorOpacity = 1.0 - (distance / 3.0);
        }
      }
      final isCurrentWord = effectiveCurrentWordIndex != -1 && segmentIndex == effectiveCurrentWordIndex;
      // Agregar el segmento al párrafo
      paragraphWidgets.add(
          GestureDetector(
          key: isCurrentWord ? _currentWordKey : null,
          onTap: () {
        if (segment.associationType == AssociationType.punctuation) {
          widget.onWordTap(i - 1);
        } else {
          widget.onWordTap(i);
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
    _selectionEnd = segmentIndex;});
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
                        color: isCurrentWord ? Colors.yellow : _getWordBackgroundColor(segmentIndex, associatedSegments),
                        child: Text(segment.realWord ?? segment.word, style: _getWordTextStyle(segment, segmentIndex, effectiveCurrentWordIndex)),
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
            previous.extradata?.audioPosition != current.extradata?.audioPosition;
      },
      builder: (context, state) {
        if (state.transcription == null || state.transcription!.wordAlignmentSegments == null || state.transcription!.wordAlignmentSegments!.isEmpty) {
          return const Center(child: Text('No hay transcripción para mostrar'));
        }
        if (state.transcription!.referenceText == null || state.transcription!.referenceText!.isEmpty) {
          return const Center(child: Text('No hay texto real para mostrar'));
        }
        final associatedSegments = state.transcription!.wordAlignmentSegments!;
        final effectiveCurrentWordIndex = state.extradata?.currentWordIndex == null || state.extradata!.currentWordIndex == -1 ? _lastValidCurrentWordIndex : state.extradata!.currentWordIndex;
        final formattedTextWidgets = _buildFormattedText(associatedSegments, effectiveCurrentWordIndex);
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
                    delegate: SliverChildListDelegate(formattedTextWidgets.isEmpty ? [const Center(child: Text('No hay texto para mostrar'))] : formattedTextWidgets),
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